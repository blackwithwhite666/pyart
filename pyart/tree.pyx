from libc.stdlib cimport malloc, free
from cpython.ref cimport Py_INCREF, Py_DECREF


cdef extern from "stdint.h" nogil:

    ctypedef unsigned short uint16_t
    ctypedef unsigned int uint32_t
    ctypedef unsigned long uint64_t


cdef extern from "art.h":

    ctypedef int(*art_callback)(void *data, const char *key, uint32_t key_len, void *value)

    ctypedef struct art_tree:
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


cdef int incref_object(void *data, const char *key, uint32_t key_len, void *value):
    Py_INCREF(<object>value)
    return 0


cdef int decref_object(void *data, const char *key, uint32_t key_len, void *value):
    Py_DECREF(<object>value)
    return 0


cdef class Tree(object):
    cdef int _initialized
    cdef art_tree *_c_tree

    def __cinit__(self):
        self._initialized = -1
        self._c_tree = <art_tree *>malloc(sizeof(art_tree))
        if self._c_tree is NULL:
            raise MemoryError("Can't allocate memory for tree!")
        self._initialized = init_art_tree(self._c_tree)
        if self._initialized != 0:
            raise RuntimeError("Can't initialize new tree!")

    def __dealloc__(self):
        if self._c_tree is not NULL:
            if self._initialized == 0:
                art_iter(self._c_tree, decref_object, NULL)
                destroy_art_tree(self._c_tree)
            free(self._c_tree)

    def __len__(self):
        return art_size(self._c_tree)

    def __getitem__(self, bytes key):
        cdef char* c_key = key
        cdef Py_ssize_t length = len(key)
        cdef void* c_value = art_search(self._c_tree, c_key, length)
        if c_value is NULL:
            raise KeyError("Key {0!r} not found!".format(key))
        return <object>c_value

    def __setitem__(self, bytes key, object value):
        cdef char* c_key = key
        cdef Py_ssize_t length = len(key)
        Py_INCREF(value)
        cdef void* c_value = art_insert(self._c_tree, c_key, length, <void *>value)
        if c_value is not NULL:
            Py_DECREF(<object>c_value)

    def __delitem__(self, bytes key):
        cdef char* c_key = key
        cdef Py_ssize_t length = len(key)
        cdef void* c_value = art_delete(self._c_tree, c_key, length)
        if c_value is NULL:
            raise KeyError("Key {0!r} not found!".format(key))
        else:
            Py_DECREF(<object>c_value)

    def __contains__(self, bytes key):
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

    def copy(self):
        # TODO: incref all python objects
        cdef Tree dst = Tree()
        if art_copy(dst._c_tree, self._c_tree) != 0:
            raise RuntimeError("Tree copy failed!")
        assert art_iter(dst._c_tree, incref_object, NULL) == 0
        return dst

