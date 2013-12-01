from __future__ import absolute_import

from pyart.tests.base import TestCase
from pyart import Tree


class Callback(object):

    def __init__(self):
        self.result = []

    def __call__(self, *args):
        self.result.append(args)


class TestTree(TestCase):

    def setUp(self):
        super(TestTree, self).setUp()
        self.tree = Tree()

    def test_constructor(self):
        tree = Tree(foo=1, bar=2)
        self.assertEqual(
            [(b'bar', 2), (b'foo', 1)],
            tree.items()
        )

    def test_get(self):
        self.tree[b'foo'] = object()
        self.assertTrue(self.tree[b'foo'] is self.tree[b'foo'])

    def test_for_none(self):
        with self.assertRaises(TypeError):
            self.tree[None]
        with self.assertRaises(TypeError):
            self.tree[None] = 1
        with self.assertRaises(TypeError):
            del self.tree[None]
        with self.assertRaises(TypeError):
            None in self.tree

    def test_mapping(self):
        self.tree[b'foo'] = 1
        self.tree[b'bar'] = 2
        self.assertEqual(self.tree[b'foo'], 1)
        self.assertEqual(self.tree[b'bar'], 2)
        self.assertTrue(b'foo' in self.tree)
        self.assertTrue(b'bar' in self.tree)
        self.assertEqual(len(self.tree), 2)
        del self.tree[b'foo']
        self.assertTrue(b'foo' not in self.tree)
        self.assertTrue(len(self.tree), 1)
        with self.assertRaises(KeyError):
            self.tree[b'foo']

    def test_each(self):
        self.tree[b'foo'] = 3

        cb = Callback()
        self.tree.each(cb)
        self.assertEqual([
            (b'foo', 3),
        ], cb.result)

        self.tree[b'foobar'] = 2

        cb = Callback()
        self.tree.each(cb)
        self.assertEqual([
            (b'foo', 3),
            (b'foobar', 2),
        ], cb.result)

        cb = Callback()
        self.tree.each(cb, prefix=b'foo')
        self.assertEqual([
            (b'foo', 3),
            (b'foobar', 2),
        ], cb.result)

        cb = Callback()
        self.tree.each(cb, prefix=b'foob')
        self.assertEqual([
            (b'foobar', 2),
        ], cb.result)

        cb = Callback()
        self.tree.each(cb, prefix=b'bar')
        self.assertEqual([], cb.result)

    def test_each_exception(self):
        class CustomException(Exception):
            pass

        self.tree[b'bar'] = 1
        self.tree[b'foo'] = 2
        calls = []

        def inner_cb(*args):
            calls.append(args)
            raise CustomException()

        with self.assertRaises(CustomException):
            self.tree.each(inner_cb)

        self.assertEqual([
            (b'bar', 1),
        ], calls)

    def test_min_max_key(self):
        self.tree[b'test'] = None
        self.tree[b'foo'] = None
        self.tree[b'bar'] = None
        self.assertEqual(self.tree.minimum, (b'bar', None))
        self.assertEqual(self.tree.maximum, (b'test', None))

    def test_copy(self):
        self.tree[b'test'] = object()
        another_tree = self.tree.copy()
        self.assertTrue(another_tree[b'test'] is self.tree[b'test'])
        self.assertEqual(len(another_tree), len(self.tree))
        another_tree[b'test'] = object()
        self.assertTrue(another_tree[b'test'] is not self.tree[b'test'])
        another_tree[b'bar'] = object()
        self.assertTrue(b'bar' in another_tree)
        self.assertTrue(b'bar' not in self.tree)
        self.tree[b'foo'] = object()
        self.assertTrue(b'foo' not in another_tree)
        self.assertTrue(b'foo' in self.tree)

    def test_iter(self):
        self.tree[b'foo'] = 1
        self.tree[b'bar'] = 2
        self.assertEqual(
            [b'bar', b'foo'],
            list(self.tree)
        )
        self.assertEqual(
            [b'bar', b'foo'],
            list(self.tree.iterkeys())
        )
        self.assertEqual(
            [2, 1],
            list(self.tree.itervalues())
        )
        self.assertEqual(
            [(b'bar', 2), (b'foo', 1)],
            list(self.tree.iteritems())
        )
        self.assertEqual(
            [b'bar', b'foo'],
            self.tree.keys()
        )
        self.assertEqual(
            [2, 1],
            self.tree.values()
        )
        self.assertEqual(
            [(b'bar', 2), (b'foo', 1)],
            self.tree.items()
        )

    def test_empty_iter(self):
        tree = Tree()
        self.assertEqual([], list(tree))
        self.assertEqual([], list(tree.iteritems()))
        self.assertEqual([], list(tree.iterkeys()))
        self.assertEqual([], list(tree.itervalues()))
        self.assertEqual([], tree.items())
        self.assertEqual([], tree.keys())
        self.assertEqual([], tree.values())

    def test_big_iter(self):
        d = {str(i): i for i in xrange(1024)}
        tree = Tree()
        tree.update(d)
        self.assertEqual(
            sorted(d.keys()),
            tree.keys(),
        )

    def test_iter_from_single(self):
        self.tree['gutenberg'] = None
        self.assertEqual(
            ['gutenberg'],
            self.tree.keys(),
        )

    def test_update_using_kwargs(self):
        self.tree.update(
            foo=1, bar=2, foobar=3, beer=4)
        self.assertEqual(
            [('bar', 2), ('beer', 4), ('foo', 1), ('foobar', 3)],
            self.tree.items()
        )

    def test_update_using_dict(self):
        d = dict(foo=1, bar=2)
        self.tree.update(d)
        self.assertEqual(
            [(b'bar', 2), (b'foo', 1)],
            self.tree.items()
        )

    def test_update_using_empty_dict(self):
        self.tree.update({})
        self.assertEqual([], self.tree.items())

    def test_update_using_list(self):
        l = [(b'foo', 1), (b'bar', 2)]
        self.tree.update(l)
        self.assertEqual(
            [(b'bar', 2), (b'foo', 1)],
            self.tree.items()
        )

    def test_update_using_wrong(self):
        l = [1, 2]
        with self.assertRaises(TypeError):
            self.tree.update(l)
        with self.assertRaises(TypeError):
            self.tree.update({}, {})

    def test_get(self):
        self.tree.update(foo=1)
        self.assertEqual(1, self.tree.get(b'foo'))
        with self.assertRaises(KeyError):
            self.tree.get(b'bar')
        self.assertEqual(2, self.tree.get(b'bar', 2))

    def test_pop(self):
        self.tree[b'foo'] = 1
        self.assertEqual(1, self.tree.pop(b'foo'))

    def test_pop_on_missing_key(self):
        with self.assertRaises(KeyError):
            self.tree.pop(b'foo')
        self.assertEqual(1, self.tree.pop(b'foo', 1))

    def test_iterator_destruction(self):
        #tree = Tree(foo=1, bar=2, foobar=3, beer=4)
        tree = self.tree
        tree.update(foo=1, bar=2, foobar=3, beer=4)
        iterator = iter(tree)
        self.assertEqual(b'bar', next(iterator))
        del iterator
