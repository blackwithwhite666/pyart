"""Adaptive Radix Tree (ART) implemetation for python."""

VERSION = (0, 1, 0)

__version__ = '.'.join(map(str, VERSION[0:3]))
__author__ = 'Lipin Dmitriy'
__contact__ = 'blackwithwhite666@gmail.com'
__homepage__ = 'https://github.com/blackwithwhite666/pyart'
__docformat__ = 'restructuredtext'

# -eof meta-

from .tree import Tree
