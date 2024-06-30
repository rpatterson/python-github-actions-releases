# SPDX-FileCopyrightText: 2023 Ross Patterson <me@rpatterson.net>
# SPDX-License-Identifier: MIT

from importlib.metadata import version as get_version

# Configuration file for the Sphinx documentation builder.

# For the full list of built-in configuration values, see the documentation:
# https://www.sphinx-doc.org/en/master/usage/configuration.html

# -- Project information -----------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#project-information

project = 'Project Structure'
copyright = '2023, Ross Patterson'
author = 'Ross Patterson'
# https://setuptools-scm.readthedocs.io/en/latest/usage/#usage-from-sphinx
release: str = get_version("project-structure")
# for example take major/minor
version: str = ".".join(release.split('.')[:2])

# -- General configuration ---------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#general-configuration

extensions = [
    'sphinx.ext.duration',
    'sphinx.ext.imgconverter',
    'autoapi.extension',
    'sphinx_copybutton',
    'sphinxext.opengraph',
    'notfound.extension',
]

templates_path = ['_templates']
exclude_patterns = []
suppress_warnings = ['epub.unknown_project_files']

# -- Options for HTML output -------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#options-for-html-output

html_theme = 'alabaster'
html_static_path = ['_static']
html_logo = './_static/logo-120.png'
html_favicon = './_static/favicon.ico'

# -- Linter options ----------------------------------------------------------
# Disallow redirects:
linkcheck_allowed_redirects = {}
linkcheck_anchors_ignore = [
    # The default from the Sphinx extension:
    "^!",
    # Tolerate links to source code lines in VCS provider web UIs:
    "^L[0-9]+",
    # Links to Matrix chat rooms:
    "^/#.+:.+",
]
linkcheck_ignore = [
    "https://liberapay.com/.*",
    "https://gitlab.com/.*/(new|edit)",
    "https://github.com/.*/settings",
# TODO: Remove when Repology's PyPI support is stable. Currently it thinks the package
# is no longer in PyPI but the PyPI project page shows a final release:
#     History ends, there are no longer packages for this project in any repositories
#     known to repology, last repository was PyPI
    "https://repology.org/project/python:.*",
]

# -- Extension options -------------------------------------------------------

# https://sphinx-copybutton.readthedocs.io/en/latest/use.html#automatic-exclusion-of-prompts-from-the-copies
copybutton_exclude = '.linenos, .gp, .go'

ogp_site_url = 'http://project-structure.readthedocs.io/'
ogp_image = './_static/logo.png'

# https://sphinx-autoapi.readthedocs.io/en/latest/tutorials.html
autoapi_dirs = ['../src']
autoapi_ignore = ['*migrations*', '*_version*']
autoapi_options = [
    'members',
    'show-inheritance',
    'show-module-summary',
    'special-members',
]
# Support parallel builds and incremental builds:
autoapi_keep_files = True

# -- Other formats -----------------------------------------------------------
latex_logo = './_static/logo.png'
# https://www.sphinx-doc.org/en/master/usage/configuration.html#confval-applehelp_bundle_id
applehelp_bundle_id = 'net.rpatterson.project-structure'
# https://www.sphinx-doc.org/en/master/usage/configuration.html#confval-applehelp_disable_external_tools
applehelp_disable_external_tools = True
