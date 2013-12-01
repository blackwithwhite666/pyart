=================================================
pyart - Adaptive Radix Tree
=================================================

|travis| |bitdeli|

.. |travis| image:: https://secure.travis-ci.org/blackwithwhite666/pyart.png?branch=master
   :alt: Travis badge
   :target: https://travis-ci.org/blackwithwhite666/pyart

.. |bitdeli| image:: https://d2weczhvl823v0.cloudfront.net/blackwithwhite666/pyart/trend.png
   :alt: Bitdeli badge
   :target: https://bitdeli.com/free

This library is a thin python wrapper around ART implementation in https://raw.github.com/armon/hlld

Installing
==========

pystat can be installed via pypi:

::

    pip install pyart


Building
========

Get the source:

::

    git clone https://github.com/blackwithwhite666/pyart.git


Compile extension:

::

     python setup.py build_ext --inplace



Usage
=====

Work with tree as with plain mapping:

::

    from pyart import Tree
    t = Tree()
    t[b'foo'] = 1
    t[b'bar'] = 2
    assert t[b'foo'] == 1
    assert t[b'bar'] == 2
    assert b'foo' in t
    assert b'bar' in t
    assert len(t) == 2
    del t[b'foo']
    assert b'foo' not in t
    assert len(t) == 1


Iteration over each element of tree:

::

    from pyart import Tree
    t = Tree()
    t['foo'] = object()
    def cb(key, value): print(key, value)
    t.each(cb)
    >>> ('foo', <object object at 0x7f186020bd70>)
    t['foobar'] = object()
    t.each(cb)
    >>> ('foo', <object object at 0x7f186020bd70>)
    >>> ('foobar', <object object at 0x7f186020bd80>)
    t.each(cb, prefix=b'foo')
    >>> ('foo', <object object at 0x7f186020bd70>)
    >>> ('foobar', <object object at 0x7f186020bd80>)
    t.each(cb, prefix=b'bar')


Find minimum and maximum:

::

    from pyart import Tree
    t = Tree()
    t[b'test'] = None
    t[b'foo'] = None
    t[b'bar'] = None
    assert t.minimum == (b'bar', None)
    assert t.maximum == (b'test', None)

Copy tree:

::

    from pyart import Tree
    t = Tree()
    t[b'test'] = object()
    c = t.copy()
    assert c[b'test'] is t[b'test']
    assert len(c) == len(t)


TODO
====

- Implement plain python iterator over tree;


Running the test suite
======================

Use Tox to run the test suite:

::

    tox
