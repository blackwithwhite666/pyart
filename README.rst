=================================================
pyart - Adaptive Radix Tree
=================================================

CI status: |cistatus|

.. |cistatus| image:: https://secure.travis-ci.org/blackwithwhite666/pyart.png?branch=master

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


Running the test suite
======================

Use Tox to run the test suite:

::

    tox

