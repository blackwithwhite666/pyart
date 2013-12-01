from libc.stdlib cimport free, calloc
from cpython.ref cimport Py_INCREF, Py_DECREF
from cpython.list cimport PyList_New, PyList_SET_ITEM


cdef extern from "stdint.h" nogil:

    ctypedef unsigned short uint16_t
    ctypedef unsigned int uint32_t
    ctypedef unsigned long uint64_t


cdef extern from "art.h":

    ctypedef int(*art_callback)(void *data, const char *key, uint32_t key_len, void *value) except -1

    ctypedef struct art_tree:
        pass

    ctypedef struct art_iterator:
        pass

    ctypedef struct art_leaf:
        uint16_t ref_count
        void *value
        uint32_t key_len
        unsigned char *key

    int init_art_tree(art_tree *c_tree)
    int destroy_art_tree(art_tree *c_tree)

    uint64_t art_size(art_tree *c_tree)
    void* art_insert(art_tree *c_tree, char *key, int key_len, void *value)
    void* art_delete(art_tree *c_tree, char *key, int key_len)
    void* art_search(art_tree *c_tree, char *key, int key_len)
    art_leaf* art_minimum(art_tree *c_tree)
    art_leaf* art_maximum(art_tree *c_tree)
    int art_iter(art_tree *c_tree, art_callback cb, void *data)
    int art_iter_prefix(art_tree *c_tree, char *prefix, int prefix_len, art_callback cb, void *data)
    int art_copy(art_tree *dst, art_tree *src)

    art_iterator* create_art_iterator(art_tree *tree)
    int destroy_art_iterator(art_iterator *iterator)
    art_leaf* art_iterator_next(art_iterator *iterator)


cdef int incref_object(void *data, const char *key, uint32_t key_len, void *value) except -1:
    Py_INCREF(<object>value)
    return 0


cdef int decref_object(void *data, const char *key, uint32_t key_len, void *value) except -1:
    Py_DECREF(<object>value)
    return 0


cdef int invoke_object(void *data, const char *key, uint32_t key_len, void *value) except -1:
    (<object>data)(key[:key_len], <object>value)
    return 0


cdef int walk_tree(art_tree *c_tree, object callback, bytes prefix=None) except -1:
    cdef char* c_prefix
    cdef Py_ssize_t prefix_len
    if prefix is None:
        return art_iter(c_tree, invoke_object, <void *>callback)
    else:
        c_prefix = prefix
        prefix_len = len(prefix)
        return art_iter_prefix(c_tree, c_prefix, prefix_len, invoke_object, <void *>callback)


cdef object populate_list(Iterator iterator, Py_ssize_t size):
    cdef int i
    cdef object obj
    cdef list l = PyList_New(size)
    for i in range(size):
        obj = iterator.pop()
        if obj is None:
            break
        Py_INCREF(obj)
        PyList_SET_ITEM(l, i, obj)
    return l


cdef class Tree(object):
    cdef art_tree *_c_tree

    def __cinit__(self):
        self._c_tree = <art_tree *>calloc(1, sizeof(art_tree))
        if self._c_tree is NULL:
            raise MemoryError("Can't allocate memory for tree!")
        if init_art_tree(self._c_tree) != 0:
            raise RuntimeError("Can't initialize new tree!")

    def __dealloc__(self):
        if self._c_tree is not NULL:
            art_iter(self._c_tree, decref_object, NULL)
            destroy_art_tree(self._c_tree)
            free(self._c_tree)

    def __init__(self, *args, **kwargs):
        self.update(*args, **kwargs)

    cdef Py_ssize_t size(self):
        return art_size(self._c_tree)

    cpdef get(self, bytes key, default=None):
        cdef char* c_key = key
        cdef Py_ssize_t length = len(key)
        cdef void* c_value = art_search(self._c_tree, c_key, length)
        if c_value is NULL:
            if default is not None:
                return default
            raise KeyError("Key {0!r} not found!".format(key))
        return <object>c_value

    cpdef pop(self, bytes key, default=None):
        cdef char* c_key = key
        cdef Py_ssize_t length = len(key)
        cdef void* c_value = art_delete(self._c_tree, c_key, length)
        if c_value is NULL:
            if default is not None:
                return default
            raise KeyError("Key {0!r} not found!".format(key))
        cdef object obj = <object>c_value
        Py_DECREF(obj)
        return obj

    cpdef replace(self, bytes key, object value):
        cdef char* c_key = key
        cdef Py_ssize_t length = len(key)
        Py_INCREF(value)
        cdef void* c_value = art_insert(self._c_tree, c_key, length, <void *>value)
        if c_value is NULL:
            return None
        cdef object obj = <object>c_value
        Py_DECREF(obj)
        return obj

    def __len__(self):
        return self.size()

    def __getitem__(self, key):
        return self.get(key)

    def __setitem__(self, key, value):
        self.replace(key, value)

    def __delitem__(self, key):
        self.pop(key)

    def __contains__(self, bytes key not None):
        cdef char* c_key = key
        cdef Py_ssize_t length = len(key)
        cdef void* c_value = art_search(self._c_tree, c_key, length)
        return c_value is not NULL

    property minimum:

        def __get__(self):
            cdef art_leaf* c_leaf = art_minimum(self._c_tree)
            return (c_leaf.key[:c_leaf.key_len], <object>c_leaf.value)

    property maximum:

        def __get__(self):
            cdef art_leaf* c_leaf = art_maximum(self._c_tree)
            return (c_leaf.key[:c_leaf.key_len], <object>c_leaf.value)

    def each(self, callback, prefix=None):
        walk_tree(self._c_tree, callback, prefix)

    def copy(self):
        cdef Tree dst = Tree()
        if art_copy(dst._c_tree, self._c_tree) != 0:
            raise RuntimeError("Tree copy failed!")
        assert art_iter(dst._c_tree, incref_object, NULL) == 0
        return dst

    def __iter__(self):
        return Iterator(self)

    cpdef iterkeys(self):
        return Iterator(self,
            return_keys=True)

    cpdef itervalues(self):
        return Iterator(self,
            return_values=True)

    cpdef iteritems(self):
        return Iterator(self,
            return_keys=True,
            return_values=True)

    def keys(self):
        return populate_list(self.iterkeys(), self.size())

    def values(self):
        return populate_list(self.itervalues(), self.size())

    def items(self):
        return populate_list(self.iteritems(), self.size())

    def update(self, *args, **kwargs):
        if args:
            if len(args) != 1:
                raise TypeError("Update excepted only 1 argument")
            arg = args[0]
            if hasattr(arg, 'iteritems'):
                arg = arg.iteritems()
            elif hasattr(arg, 'items'):
                arg = arg.items()
            for key, value in arg:
                self[key] = value
        for key, value in kwargs.items():
            self[key] = value


cdef class Iterator(object):
    cdef art_iterator *_c_iterator
    cdef bint return_keys
    cdef bint return_values

    def __cinit__(self, Tree tree not None, return_keys=None, return_values=None):
        self._c_iterator = create_art_iterator(tree._c_tree)
        if self._c_iterator is NULL:
            raise MemoryError("Can't allocate memory for iterator!")
        self.return_keys = bool(return_keys)
        self.return_values = bool(return_values)

    def __iter__(self):
        return self

    cdef object pop(self):
        cdef art_leaf* c_leaf = art_iterator_next(self._c_iterator)
        if c_leaf is NULL:
            return None
        if self.return_keys and self.return_values:
            return (c_leaf.key[:c_leaf.key_len], <object>c_leaf.value)
        elif self.return_values:
            return <object>c_leaf.value
        else:
            return c_leaf.key[:c_leaf.key_len]

    def __next__(self):
        cdef object obj = self.pop()
        if obj is None:
            raise StopIteration()
        return obj

    def __dealloc__(self):
        if self._c_iterator is not NULL:
            destroy_art_iterator(self._c_iterator)
