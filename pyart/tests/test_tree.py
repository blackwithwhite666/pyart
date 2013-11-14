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

    def test_get(self):
        self.tree[b'foo'] = object()
        self.assertTrue(self.tree[b'foo'] is self.tree[b'foo'])

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
        self.tree[b'foo'] = 1

        cb = Callback()
        self.tree.each(cb)
        self.assertEqual([
            (b'foo', 1),
        ], cb.result)

        self.tree['foobar'] = 2

        cb = Callback()
        self.tree.each(cb)
        self.assertEqual([
            (b'foo', 1),
            (b'foobar', 2),
        ], cb.result)

        cb = Callback()
        self.tree.each(cb, prefix=b'foo')
        self.assertEqual([
            (b'foo', 1),
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

