from libc.stdlib cimport malloc, free
from cpython.ref cimport Py_INCREF, Py_DECREF


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


cdef class Tree(object):
    cdef art_tree *_c_tree

    def __cinit__(self):
        self._c_tree = <art_tree *>malloc(sizeof(art_tree))
        if self._c_tree is NULL:
            raise MemoryError("Can't allocate memory for tree!")
        if init_art_tree(self._c_tree) != 0:
            raise RuntimeError("Can't initialize new tree!")

    def __dealloc__(self):
        if self._c_tree is not NULL:
            art_iter(self._c_tree, decref_object, NULL)
            destroy_art_tree(self._c_tree)
            free(self._c_tree)

    def __len__(self):
        return art_size(self._c_tree)

    def __getitem__(self, bytes key not None):
        cdef char* c_key = key
        cdef Py_ssize_t length = len(key)
        cdef void* c_value = art_search(self._c_tree, c_key, length)
        if c_value is NULL:
            raise KeyError("Key {0!r} not found!".format(key))
        return <object>c_value

    def __setitem__(self, bytes key not None, object value):
        cdef char* c_key = key
        cdef Py_ssize_t length = len(key)
        Py_INCREF(value)
        cdef void* c_value = art_insert(self._c_tree, c_key, length, <void *>value)
        if c_value is not NULL:
            Py_DECREF(<object>c_value)

    def __delitem__(self, bytes key not None):
        cdef char* c_key = key
        cdef Py_ssize_t length = len(key)
        cdef void* c_value = art_delete(self._c_tree, c_key, length)
        if c_value is NULL:
            raise KeyError("Key {0!r} not found!".format(key))
        else:
            Py_DECREF(<object>c_value)

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


cdef class Iterator(object):
    cdef art_iterator *_c_iterator

    def __cinit__(self, Tree tree not None):
        self._c_iterator = create_art_iterator(tree._c_tree)
        if self._c_iterator is NULL:
            raise MemoryError("Can't allocate memory for iterator!")

    def __iter__(self):
        return self

    def __next__(self):
        cdef art_leaf* c_leaf = art_iterator_next(self._c_iterator)
        if c_leaf is NULL:
            raise StopIteration()
        return (c_leaf.key[:c_leaf.key_len], <object>c_leaf.value)

    def __dealloc__(self):
        if self._c_iterator is not NULL:
            destroy_art_iterator(self._c_iterator)
