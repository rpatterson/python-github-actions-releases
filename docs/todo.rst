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

#. ``docker``: Add ``HEALTHCHECK`` template to ``./Dockerfile``.

#. ``docker``: Missing ``LABEL`` tag: ``"org.opencontainers.image.base.name":
   "docker.io/library/python:"``

#. ``base``: Rename ``docker-compose*.yml`` files to `the newer canonical
   <https://docs.docker.com/compose/compose-application-model/#the-compose-file>`_
   ``compose*.yml`` names.

#. ``docker``: Switch to the newer and more explicit `'include:' section
   <https://docs.docker.com/compose/compose-file/14-include/>`_ in the YAML.

#. ``base``: Cleanup Docker Compose repetition with `YAML anchors
   <https://docs.docker.com/compose/compose-file/10-fragments/>`_ and `compose
   extensions <https://docs.docker.com/compose/compose-file/11-extension/>`_.

#. ``docker``: Maybe `use 'extends:'
   <https://docs.docker.com/compose/multiple-compose-files/extends/>`_ for the
   ``*-devel`` service? When should the configuration use ``extends:`` and when should
   it use YAML anchors?

#. ``base``: Add an Open Collective badge.

#. ``(js|ts|etc.)``: Restore `general and module Sphinx indexes
   <https://www.sphinx-doc.org/en/master/usage/restructuredtext/directives.html#special-names>`_
   in the branches for appropriate project types.


****************************************************************************************
High priority
****************************************************************************************

#. Any documentation improvements:

   Docs benefit most from fresh eyes. If you find anything confusing, ask for help. When
   you understand better, contribute changes to the docs to help others.


****************************************************************************************
Nice to have
****************************************************************************************

#. ``base``: Better final release notes when nothing changed after the last pre-release.

#. ``base``: `Homebrew formula and badge <https://formulae.brew.sh/formula/commitizen>`_

#. ``base``: Try out `other Sphinx themes
   <https://www.sphinx-doc.org/en/master/tutorial/more-sphinx-customization.html#using-a-third-party-html-theme>`_

#. ``base``: Try some of `the linters and formatters
   <https://unibeautify.com/docs/beautifier-stylelint>`_ supported by ``UniBeautify``:

   - ``Stylelint`` `CSS linter <https://stylelint.io/>`_
   - `js-beautify <https://www.npmjs.com/package/js-beautify>`_

#. ``base``: Try out the `rinohtype Sphinx renderer
   <https://www.mos6581.org/rinohtype/master/sphinx.html>`_.

#. ``base``: Build operating system packages, such as ``*.deb``, ``*.rpm``, ``*.msi``,
   including documentation.

#. ``base``: Add `a badge
   <https://repology.org/project/python:project-structure/badges>`_ for projects that
   publish packages to more than one repository.
