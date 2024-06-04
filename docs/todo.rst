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

#. ``base``: Add an Open Collective badge.

#. ``(js|ts|etc.)``: Restore `general and module Sphinx indexes
   <https://www.sphinx-doc.org/en/master/usage/restructuredtext/directives.html#special-names>`_
   in the branches for appropriate project types.

#. ``ci``: Built docs formats as artifacts and release files.

#. ``ci``: Publish Sphinx docs to `all available documentation hosts
   <https://www.sphinx-doc.org/en/master/faq.html#using-sphinx-with>`_.


****************************************************************************************
High priority
****************************************************************************************

#. Audit ``$ make -j devel-upgrade-branch`` to re-use existing images and otherwise
   reduce runtime as much as possible so that new CI jobs that build images are only run
   when upgrades actually change versions. See if that's enough to run it daily without
   exhausting GitLab's free monthly CI minutes.

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

#. ``docker``: `Docker image build-time labels
   <https://specs.opencontainers.org/image-spec/annotations/?v=v1.0.1>`_::

     org.opencontainers.image.revision
     org.opencontainers.image.ref.name
     org.opencontainers.image.base.digest

#. ``docker``: Container image variants, for example ``*:slim`` or ``*:alpine``:

   The might save less disk space than by using the most widely used base image, given
   that `different images share common image layers
   <https://hub.docker.com/_/buildpack-deps/>`_. This might also have security benefits
   but it also increases risk of incompatibility bugs, whether in the libraries or in
   distribution differences. As such, this probably isn't worth the effort until users
   report convincing use cases.

#. ``docker``: CI/CD for other image platforms:

   This would cause one issue with CI resources. The pipelines already exhaust too much
   of the GitLab free CI/CD minutes for each run. Running the tests in ARM images would
   either consume even more free CI/CD minutes to run on cloud ARM runners. Or would
   take forever by using emulation in the dedicated project runners.

   Docker also lacks important support, creating another issue. Docker provides both the
   capability to build images for non-native platforms *and* run images for non-native
   platforms, both under QEMU emulation, albeit with a significant performance
   penalty. It seems support exists to build a non-native image, run the tests in it,
   and then publish it after passing. But Docker doesn't support local access to built
   multi-platform images, it only supports pushing them to a registry or exporting them
   to some form of filesystem archive. This means following runs of the image tag might
   use a different image than the one built locally. Someone else could have pushed
   another build to the registry between the push and following pull. Even worse,
   changing the ``platform: ...`` in ``./docker-compose*.yml`` requires a ``$ docker
   compose pull ...`` to switch the image. This means pulling again and again some time
   after the push increasingly the likelihood of pulling an image other than the one
   built locally. This leaves a couple options. Parse the manifest digest from the build
   output and then use that to retrieve the digests for each platform's image and then
   use those digests in ``./docker-compose*.yml``. Or output the multi-platform image to
   one of the local filesystem formats, figure how to import from there and do a similar
   dance to retrieve and use the digests. This would be fragile and would take a lot of
   work that is likely wasted effort when Docker or someone else provides a better
   way. IOW, these options would mean wastefully fighting tools and frameworks.

   As such, this probably isn't worth the effort until users report significant
   platform-specific bugs.

#. ``ci``: Add `self-hosted Matrix Hookshot
   <https://matrix-org.github.io/matrix-hookshot/latest/setup.html#installation-via-docker>`_
   to the ``./docker-compose.override.yml``, add `the GitLab integration
   <https://matrix-org.github.io/matrix-hookshot/latest/setup/gitlab.html>`_ and
   document any steps for template adopters.
