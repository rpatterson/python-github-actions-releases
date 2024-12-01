.. SPDX-FileCopyrightText: 2023 Ross Patterson <me@rpatterson.net>
..
.. SPDX-License-Identifier: MIT

########################################################################################
Most wanted contributions
########################################################################################

Known bugs and wanted features.

TEMPLATE: clear items and add items for your project.


****************************************************************************************
Required
****************************************************************************************

#. :Docs:

    Add an Open Collective badge.

#. :Upgrade:

    The ``devel-upgrade`` target doesn't add new Vale styles.

#. :Docs:

    Restore `general and module Sphinx indexes
    <https://www.sphinx-doc.org/en/master/usage/restructuredtext/directives.html#special-names>`_
    in the branches for appropriate project types, for example ``(js|ts|etc.)``.


****************************************************************************************
High priority
****************************************************************************************

#. :Docs:

   Docs benefit most from fresh eyes. If you find anything unclear, ask for help. When
   you understand better, contribute changes to the docs to help others.


****************************************************************************************
Nice to have
****************************************************************************************

#. :Release:

    `Homebrew formula and badge <https://formulae.brew.sh/formula/commitizen>`_

#. :Docs:

    Try out `other Sphinx themes
    <https://www.sphinx-doc.org/en/master/tutorial/more-sphinx-customization.html#using-a-third-party-html-theme>`_

#. :Lint:

    Try some of `the linters and formatters
    <https://unibeautify.com/docs/beautifier-stylelint>`_ supported by ``UniBeautify``:

    - ``Stylelint`` `CSS linter <https://stylelint.io/>`_
    - `js-beautify <https://www.npmjs.com/package/js-beautify>`_

#. :Docs:

    Try out the `rinohtype Sphinx renderer
    <https://www.mos6581.org/rinohtype/master/sphinx.html>`_.

#. :Release:

    Build operating system packages, such as ``*.deb``, ``*.rpm``, ``*.msi``, including
    documentation.

#. :Release:

    Add `a badge <https://repology.org/project/python:project-structure/badges>`_ for
    projects that publish packages to more than one repository.

#. :TODO:

    The list items in this document are the most important improvements that this
    project definitely needs. See also ``$ git grep -i -e todo`` comments throughout the
    source for other smaller, potential improvements.

#. :Lint:

    Resolve ignored linter failures::

      $ git grep -i -e \
      'alex disable hooks|hadolint ignore|pylint: disable|type: ignore' \
      -- '*.py'
