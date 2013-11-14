from __future__ import absolute_import

from pyart.tests.base import TestCase
from pyart import Tree


class TestTree(TestCase):

    def setUp(self):
        super(TestTree, self).setUp()
        self.tree = Tree()
