# SPDX-FileCopyrightText: 2023 Ross Patterson <me@rpatterson.net>
#
# SPDX-License-Identifier: MIT

# Development, build, and maintenance tasks:
#
# To ease discovery for contributors, place option variables affecting behavior at the
# top. Skip down to `## Top-level targets:` to find targets intended for use by
# developers. The recipes for real targets that follow the top-level targets do the real
# work. If making changes here, start by reading the philosophy commentary at the bottom
# of this file.

# Project specific values:
export PROJECT_NAMESPACE=rpatterson
export PROJECT_NAME=project-structure
# TEMPLATE: Create an Node Package Manager (NPM) organization and set its name here:
export NPM_SCOPE=rpattersonnet
export DOCKER_NAMESPACE=merpatterson
export DOCKER_USER=$(DOCKER_NAMESPACE)
# Match the same Python version available in the `./build-host/` Docker image:
# https://pkgs.alpinelinux.org/packages?name=python3&branch=edge&repo=main&arch=x86_64&maintainer=
PYTHON_SUPPORTED_MINOR=3.12

# Option variables that control behavior:
export TEMPLATE_IGNORE_EXISTING?=false


### "Private" Variables:

# Variables not of concern those running and reading top-level targets. These variables
# most often derive from the environment or other values. Place variables holding
# literal constants or option variables intended for use on the command-line towards the
# top. Otherwise, add variables to the appropriate following grouping. Make requires
# defining variables referenced in targets or prerequisites before those references, in
# contrast with references in recipes. As a result, the Makefile can't place these
# further down for readability and discover.

# Defensive settings for make:
#     https://tech.davis-hansson.com/p/make/
SHELL:=bash
.ONESHELL:
.SHELLFLAGS:=-eu -o pipefail -c
.SILENT:
.DELETE_ON_ERROR:
MAKEFLAGS+=--warn-undefined-variables
MAKEFLAGS+=--no-builtin-rules
export PS1?=$$
# Prefix echoed recipe commands with the recipe line number for debugging:
export PS4?=:$$LINENO+
# Support for debugging make logic:
DEBUG?=false
ifeq ($(DEBUG),true)
MAKEFLAGS+=--debug=basic
endif
EMPTY=
COMMA=,
SPACE=$(EMPTY) $(EMPTY)
# Useful to update targets only one time per run including sub-makes:
export MAKE_RUN_UUID:=$(shell python3 -c "import uuid; print(uuid.uuid4())")
# Workaround missing VCS glob wildcard matches under an editor:
# https://magit.vc/manual/magit/My-Git-hooks-work-on-the-command_002dline-but-not-inside-Magit.html
unexport GIT_LITERAL_PATHSPECS

# Values used to install host operating system packages:
HOST_PREFIX=/usr
HOST_PKG_CMD_PREFIX=sudo
HOST_PKG_BIN=apt-get
HOST_PKG_INSTALL_ARGS=install -y
HOST_PKG_NAMES_ENVSUBST=gettext-base
HOST_PKG_NAMES_PIPX=pipx
HOST_PKG_NAMES_IMAGEMAGICK=imagemagick inkscape
HOST_PKG_NAMES_MAKEINFO=texinfo
HOST_PKG_NAMES_LATEXMK=texlive-full
HOST_PKG_NAMES_DOCKER=docker-ce-cli docker-compose-plugin
ifneq ($(shell which "brew"),)
HOST_PREFIX=/usr/local
HOST_PKG_CMD_PREFIX=
HOST_PKG_BIN=brew
HOST_PKG_INSTALL_ARGS=install
HOST_PKG_NAMES_ENVSUBST=gettext
HOST_PKG_NAMES_IMAGEMAGICK=imagemagick librsvg
HOST_PKG_NAMES_LATEXMK=texlive
HOST_PKG_NAMES_DOCKER=docker docker-compose
else ifneq ($(shell which "apk"),)
HOST_PKG_BIN=apk
HOST_PKG_INSTALL_ARGS=add
HOST_PKG_NAMES_ENVSUBST=gettext
HOST_PKG_NAMES_IMAGEMAGICK=imagemagick librsvg
HOST_PKG_NAMES_DOCKER=docker-cli docker-cli-compose
endif
HOST_PKG_CMD=$(HOST_PKG_CMD_PREFIX) $(HOST_PKG_BIN)
# Detect Docker command-line baked into the build-host image:
HOST_TARGET_DOCKER:=$(shell which docker)
ifeq ($(HOST_TARGET_DOCKER),)
HOST_TARGET_DOCKER=$(HOST_PREFIX)/bin/docker
endif
PYTHON_SUPPORTED_ENV=py$(subst .,,$(PYTHON_SUPPORTED_MINOR))
PYTHON_HOST_MINOR=$(PYTHON_SUPPORTED_MINOR)
# Try to be usable for as wide an audience of contributors as possible.  Fallback to the
# default `$ python3` of the contributors host operating system if the canonical Python
# version isn't available:
ifeq ($(shell which "python$(PYTHON_HOST_MINOR)"),)
PYTHON_HOST_MINOR:=$(shell python3 -c \
    'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
endif
export PYTHON_HOST_ENV=py$(subst .,,$(PYTHON_HOST_MINOR))
PIP_COMPILE_ARGS=

# Values derived from the environment:
USER_NAME:=$(shell id -u -n)
USER_FULL_NAME:=$(shell \
    getent passwd "$(USER_NAME)" | cut -d ":" -f 5 | cut -d "," -f 1)
ifeq ($(USER_FULL_NAME),)
USER_FULL_NAME=$(USER_NAME)
endif
USER_EMAIL:=$(USER_NAME)@$(shell hostname -f)
export PUID?=$(shell id -u)
export PGID?=$(shell id -g)
# Capture the path of the checkout directory as seen by the real host running `#
# dockerd` so that following bind volumes have the correct source paths:
export CHECKOUT_DIR?=$(PWD)
export WORKTREE_REL?=
# Managed user-specific directory out of the checkout:
# https://specifications.freedesktop.org/basedir-spec/0.8/ar01s03.html
STATE_DIR=$(HOME)/.local/state/$(PROJECT_NAME)
TZ=Etc/UTC
ifneq ("$(wildcard /usr/share/zoneinfo/)","")
TZ:=$(shell \
  realpath --relative-to=/usr/share/zoneinfo/ \
  $(firstword $(realpath /private/etc/localtime /etc/localtime)) \
)
endif
export TZ
export DOCKER_GID:=$(shell getent group "docker" | cut -d ":" -f 3)

# Values derived from Version Control Systems (VCS):
VCS_LOCAL_BRANCH:=$(shell git branch --show-current)
VCS_TAG=
ifeq ($(VCS_LOCAL_BRANCH),)
# Guess branch name from tag:
ifneq ($(shell echo "$(VCS_TAG)" | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$$'),)
# Publish final releases from the `main` branch:
VCS_LOCAL_BRANCH=main
else ifneq ($(shell echo "$(VCS_TAG)" | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+.+$$'),)
# Publish pre-releases from the `develop` branch:
VCS_LOCAL_BRANCH=develop
endif
endif
# Reproduce Git branch and remote configuration and logic:
VCS_CLONE_REMOTE:=$(shell git config "clone.defaultRemoteName")
ifeq ($(VCS_CLONE_REMOTE),)
VCS_CLONE_REMOTE=origin
endif
VCS_PUSH_REMOTE:=$(shell git config "branch.$(VCS_LOCAL_BRANCH).pushRemote")
ifeq ($(VCS_PUSH_REMOTE),)
VCS_PUSH_REMOTE:=$(shell git config "remote.pushDefault")
endif
ifeq ($(VCS_PUSH_REMOTE),)
VCS_PUSH_REMOTE=$(VCS_CLONE_REMOTE)
endif
VCS_UPSTREAM_REMOTE:=$(shell git config "branch.$(VCS_LOCAL_BRANCH).remote")
ifeq ($(VCS_UPSTREAM_REMOTE),)
VCS_UPSTREAM_REMOTE:=$(shell git config "checkout.defaultRemote")
endif
VCS_UPSTREAM_REF:=$(shell git config "branch.$(VCS_LOCAL_BRANCH).merge")
VCS_UPSTREAM_BRANCH=$(VCS_UPSTREAM_REF:refs/heads/%=%)
# Find the remote and branch for `v*` tags versioning data:
VCS_REMOTE=$(VCS_PUSH_REMOTE)
VCS_BRANCH=$(VCS_LOCAL_BRANCH)
# Find the remote and branch for conventional commits release data:
VCS_COMPARE_REMOTE=$(VCS_UPSTREAM_REMOTE)
ifeq ($(VCS_COMPARE_REMOTE),)
VCS_COMPARE_REMOTE=$(VCS_PUSH_REMOTE)
endif
VCS_COMPARE_BRANCH=$(VCS_UPSTREAM_BRANCH)
ifeq ($(VCS_COMPARE_BRANCH),)
VCS_COMPARE_BRANCH=$(VCS_BRANCH)
endif
# If pushing to upstream release branches, get release data compared to the preceding
# release:
ifeq ($(VCS_COMPARE_BRANCH),develop)
VCS_COMPARE_BRANCH=main
endif
VCS_BRANCH_SUFFIX=upgrade
VCS_MERGE_BRANCH=$(VCS_BRANCH:%-$(VCS_BRANCH_SUFFIX)=%)

# Values used for publishing releases:
# Safe defaults for testing the release process without publishing to the official
# project hosting services, indexes, and registries:
RELEASE_PUBLISH=false
# Publish releases from the `main` or `develop` branches:
ifeq ($(VCS_BRANCH),main)
RELEASE_PUBLISH=true
else ifeq ($(VCS_BRANCH),develop)
# Publish pre-releases from the `develop` branch:
RELEASE_PUBLISH=true
endif

# Variables related to tools managed by `./*compose*.yml`:
DOCKER_COMPOSE_UPGRADE=false

# https://www.sphinx-doc.org/en/master/usage/builders/index.html
# Run these Sphinx builders to test the correctness of the documentation:
# <!--alex disable gals-man-->
DOCS_SPHINX_BUILDERS=html dirhtml singlehtml htmlhelp qthelp epub applehelp latex man \
    texinfo text gettext linkcheck xml pseudoxml
DOCS_SPHINX_ALL_FORMATS=$(DOCS_SPHINX_BUILDERS) devhelp pdf info
# <!--alex enable gals-man-->
DOCS_SPHINX_BUILD_OPTS=
# These builders report false warnings or failures:

# Override variable values if present in `./.env` and if not overridden on the
# command-line:
include $(wildcard .env)

# Finished with `$(shell)`, echo recipe commands going forward
.SHELLFLAGS+= -x


### Top-level targets:

.PHONY: all
## The default target.
all: build


### Build Targets:
#
# Recipes that make artifacts needed for by end-users, development tasks, other recipes.

.PHONY: build
## Perform any necessary local setup common to most operations.
# <!--alex disable hooks-->
build: ./.git/hooks/pre-commit ./var/log/docker-compose-network.log \
		./.tox/build/.tox-info.json ./var/log/npm-install.log
# <!--alex enable hooks-->

.PHONY: build-docs
## Render the static HTML form of the Sphinx documentation
build-docs: $(DOCS_SPHINX_ALL_FORMATS:%=build-docs-%)

.PHONY: build-docs-watch
## Serve the Sphinx documentation with live updates
build-docs-watch: ./.tox/build/.tox-info.json
	mkdir -pv "./build/docs/html/"
	tox exec -e "build" -- sphinx-autobuild -b "html" "./docs/" "./build/docs/html/"

# Done as a separate target because this builder fails every other run without the
# suboptimal `-E` option:
# https://github.com/sphinx-doc/sphinx/issues/11759
.PHONY: build-docs-devhelp
## Render the documentation into the GNOME Devhelp format.
build-docs-devhelp: ./.tox/build/.tox-info.json
	"$(<:%/.tox-info.json=%/bin/sphinx-build)" -b "$(@:build-docs-%=%)" -Wn -E \
	    -j "auto" $(DOCS_SPHINX_BUILD_OPTS) "./docs/" \
	    "./build/docs/$(@:build-docs-%=%)/"
.PHONY: $(DOCS_SPHINX_BUILDERS:%=build-docs-%)
## Render the documentation into a specific format.
$(DOCS_SPHINX_BUILDERS:%=build-docs-%): ./.tox/build/.tox-info.json \
		build-docs-devhelp $(HOST_PREFIX)/bin/convert
	"$(<:%/.tox-info.json=%/bin/sphinx-build)" -b "$(@:build-docs-%=%)" -Wn \
	    -j "auto" -D autosummary_generate="0" "./docs/" \
	    "./build/docs/$(@:build-docs-%=%)/"
.PHONY: build-docs-pdf
## Render the LaTeX documentation into a PDF file.
build-docs-pdf: build-docs-latex
# TODO: Switch to a TeX Live container for SVG support.
	$(MAKE) -C "./build/docs/$(<:build-docs-%=%)/" \
	    LATEXMKOPTS="-f -interaction=nonstopmode" all-pdf
.PHONY: build-docs-info
## Render the Texinfo documentation into a `*.info` file.
build-docs-info: build-docs-texinfo
	$(MAKE) -C "./build/docs/$(<:build-docs-%=%)/" info


### Test Targets:
#
# Recipes that run the test suite.

.PHONY: test
## Run the full suite of tests, coverage checks, and linters.
test: test-lint test-code

.PHONY: test-code
## Run the full suite of tests and coverage checks.
test-code: ./var/log/build-pkgs.log
	true "TEMPLATE: Always specific to the project type"

.PHONY: test-debug
## Run tests directly on the system and start the debugger on errors or failures.
test-debug:
	true "TEMPLATE: Always specific to the project type"

.PHONY: test-lint
## Perform any linter or style checks, including non-code checks.
test-lint: test-lint-code test-lint-docker test-lint-docs test-lint-prose \
		test-lint-licenses

.PHONY: test-lint-licenses
## Lint copyright and license annotations for all files tracked in VCS.
test-lint-licenses: ./var/log/docker-compose-network.log
	docker compose run --rm -T "reuse"

.PHONY: test-lint-code
## Lint source code for errors, style, and other issues.
test-lint-code: test-lint-code-prettier
.PHONY: test-lint-code-prettier
## Lint source code for formatting with Prettier.
test-lint-code-prettier: ./var/log/npm-install.log
	~/.nvm/nvm-exec npm run lint:prettier

.PHONY: test-lint-docs
## Lint documentation for errors, broken links, and other issues.
test-lint-docs: test-lint-docs-rstcheck build-docs test-lint-docs-sphinx-lint \
		test-lint-docs-doc8
# TODO: Audit what checks all tools perform and remove redundant tools.
.PHONY: test-lint-docs-rstcheck
## Lint documentation for formatting errors and other issues with rstcheck.
test-lint-docs-rstcheck: ./.tox/build/.tox-info.json
# Verify reStructuredText syntax. Exclude `./docs/index.rst` because its use of the
# `.. include:: ../README.rst` directive breaks `$ rstcheck`:
#     CRITICAL:rstcheck_core.checker:An `AttributeError` error occured.
# Also exclude `./docs/news*.rst` because it's duplicate headings cause:
#     INFO docs/news.rst:317 Duplicate implicit target name: "bugfixes".
	git ls-files -z '*.rst' ':!docs/index.rst' ':!docs/news*.rst' |
	    xargs -r -0 -- "$(<:%/.tox-info.json=%/bin/rstcheck)"
.PHONY: test-lint-docs-sphinx-lint
## Test the documentation for formatting errors with sphinx-lint.
test-lint-docs-sphinx-lint: ./.tox/build/.tox-info.json
	git ls-files -z '*.rst' | xargs -r -0 -- \
	    "$(<:%/.tox-info.json=%/bin/sphinx-lint)" -e "all" -d "line-too-long"
.PHONY: test-lint-docs-doc8
## Test the documentation for formatting errors with doc8.
test-lint-docs-doc8: ./.tox/build/.tox-info.json
	git ls-files -z '*.rst' ':!docs/news*.rst' |
	    xargs -r -0 -- "$(<:%/.tox-info.json=%/bin/doc8)"

.PHONY: test-lint-prose
## Lint prose text for spelling, grammar, and style.
test-lint-prose: test-lint-prose-vale-markup test-lint-prose-vale-code \
		test-lint-prose-vale-misc test-lint-prose-proselint \
		test-lint-prose-write-good test-lint-prose-alex
.PHONY: test-lint-prose-vale-markup
## Lint prose in all markup files tracked in VCS with Vale.
test-lint-prose-vale-markup: ./var/log/docker-compose-network.log
# https://vale.sh/docs/topics/scoping/#formats
	git ls-files -co --exclude-standard -z ':!docs/news*.rst' ':!LICENSES' \
	    ':!styles/**' ':!requirements/**' |
	    xargs -r -0 -t -- docker compose run --rm -T vale
.PHONY: test-lint-prose-vale-code
## Lint comment prose in all source code files tracked in VCS with Vale.
test-lint-prose-vale-code: ./var/log/docker-compose-network.log
	git ls-files -co --exclude-standard -z ':!styles/**' |
	    xargs -r -0 -t -- \
	    docker compose run --rm -T vale --config="./styles/code.ini"
.PHONY: test-lint-prose-vale-misc
## Lint source code files tracked in VCS but without extensions with Vale.
test-lint-prose-vale-misc: ./var/log/docker-compose-network.log
	git ls-files -co --exclude-standard -z | grep -Ez '^[^.]+$$' |
	    while read -d $$'\0'
	    do
	        cat "$${REPLY}" |
	            docker compose run --rm -T vale --config="./styles/code.ini" \
	                --ext=".pl"
	    done
.PHONY: test-lint-prose-proselint
## Lint prose in all markup files tracked in VCS with proselint.
test-lint-prose-proselint: ./.tox/build/.tox-info.json
	git ls-files -z '*.rst' |
	    xargs -r -0 -- "$(<:%/.tox-info.json=%/bin/proselint)" \
	    --config "./.proselintrc.json"
.PHONY: test-lint-prose-write-good
## Lint prose in all files tracked in VCS with write-good.
test-lint-prose-write-good: ./var/log/npm-install.log
	~/.nvm/nvm-exec npm run "lint:write-good"
.PHONY: test-lint-prose-alex
## Lint prose in all files tracked in VCS with alex.
test-lint-prose-alex: ./var/log/npm-install.log
	~/.nvm/nvm-exec npm run "lint:alex"

.PHONY: test-lint-docker
## Check the style and content of the `./Dockerfile*` files
test-lint-docker: ./var/log/docker-compose-network.log
	git ls-files -z '*Dockerfile*' |
	    xargs -0 -- docker compose run --rm -T hadolint hadolint

.PHONY: test-push
## Verify commits before pushing to the remote.
test-push: ./var/log/git-fetch.log ./.tox/build/.tox-info.json
	vcs_compare_rev="$(VCS_COMPARE_REMOTE)/$(VCS_COMPARE_BRANCH)"
	if ! git fetch "$(VCS_COMPARE_REMOTE)" "$(VCS_COMPARE_BRANCH)"
	then
# For a newly created branch not yet on the remote, compare with the pre-release branch:
	    vcs_compare_rev="$(VCS_COMPARE_REMOTE)/develop"
	fi
	exit_code=0
	(
	    tox exec -e "build" -- \
	        cz check --rev-range "$${vcs_compare_rev}..HEAD" &&
	    tox exec -e "build" -- \
	        python ./bin/cz-check-bump.py --compare-ref "$${vcs_compare_rev}"
	) || exit_code=$$?
	if (( $$exit_code == 3 || $$exit_code == 21 ))
	then
	    exit
	elif (( $$exit_code != 0 ))
	then
	    exit $$exit_code
	else
	    tox exec -e "build" -- \
	        towncrier check --compare-with "$${vcs_compare_rev}"
	fi

.PHONY: test-clean
## Confirm that the checkout has no uncommitted VCS changes.
test-clean:
	if test -n "$$(git status --porcelain)"
	then
	    git status -vv
	    set +x
	    echo "WARNING: Checkout is not clean."
	    false
	fi

.PHONY: test-worktree-%
## Build then run all tests from a new checkout in a clean container.
test-worktree-%: $(HOST_TARGET_DOCKER) ./.env.~out~
	docker compose run --rm build-host \
	    make $(@:test-worktree-%=test-worktree-add-%)
	export WORKTREE_REL="/worktrees/$(VCS_BRANCH)-$(@:test-worktree-%=%)"
	$(MAKE) -C ".$${WORKTREE_REL}/" TEMPLATE_IGNORE_EXISTING="true" \
	    "./.env.~out~"
	cd ".$${WORKTREE_REL}/"
	docker compose run --rm \
	    --workdir "/usr/local/src/project-structure$${WORKTREE_REL}" build-host
.PHONY: test-worktree-add-%
## Create a new worktree based on the current branch adding a suffix.
test-worktree-add-%:
	worktree_branch="$(VCS_BRANCH)-$(@:test-worktree-add-%=%)"
	worktree_rel="worktrees/$${worktree_branch}"
	if git worktree list --porcelain |
	    grep -E "^worktree .+/project-structure/$${worktree_rel}\$$"
	then
	    git worktree remove "./$${worktree_rel}"
	fi
	git worktree add -B "$${worktree_branch}" "./$${worktree_rel}"


### Release Targets:
#
# Recipes that make an changes needed for releases and publish built artifacts to
# end-users.

.PHONY: release
## Publish installable packages if conventional commits require a release.
release: ./var/log/build-pkgs.log
	$(MAKE) test-clean
# Don't release unless from the `main` or `develop` branches:
ifeq ($(RELEASE_PUBLISH),true)
	true "TEMPLATE: Always specific to the project type"
endif

.PHONY: release-bump
## Bump the package version if conventional commits require a release.
release-bump: ./var/log/git-fetch.log ./.tox/build/.tox-info.json \
		./var/log/npm-install.log
	if ! git diff --cached --exit-code
	then
	    set +x
	    echo "CRITICAL: Cannot bump version with staged changes"
	    false
	fi
ifeq ($(VCS_BRANCH),main)
# Also fetch develop for merging back in the final release:
	git fetch --tags "$(VCS_COMPARE_REMOTE)" "develop"
endif
# Update the local branch to the forthcoming version bump commit:
	git switch -C "$(VCS_BRANCH)" "$$(git rev-parse HEAD)"
	exit_code=0
	if test "$(VCS_BRANCH)" = "main" &&
	    tox exec -e "build" -- python ./bin/get-base-version.py $$(
	        tox exec -e "build" -qq -- cz version --project
	    )
	then
# Make a final release from the last pre-release:
	    true
	else
# Do the conventional commits require a release?:
	    tox exec -e "build" -- python ./bin/cz-check-bump.py || exit_code=$$?
	    if (( $$exit_code == 3 || $$exit_code == 21 ))
	    then
# No commits require a release:
	        exit
	    elif (( $$exit_code != 0 ))
	    then
	        exit $$exit_code
	    fi
	fi
# Collect the versions involved in this release according to conventional commits:
	cz_bump_args="--check-consistency --no-verify"
ifneq ($(VCS_BRANCH),main)
	cz_bump_args+=" --prerelease beta"
endif
# Build and stage the release notes:
	next_version=$$(
	    tox exec -e "build" -qq -- cz bump $${cz_bump_args} --yes --dry-run |
	    sed -nE 's|.* ([^ ]+) *→ *([^ ]+).*|\2|p;q'
	) || true
# Assemble the release notes for this next version:
	tox exec -e "build" -qq -- \
	    towncrier build --version "$${next_version}" --draft --yes \
	    >"./docs/news-version.rst"
	git add -- "./docs/news-version.rst"
	tox exec -e "build" -- towncrier build --version "$${next_version}" --yes
# Bump the version in the NPM package metadata:
	~/.nvm/nvm-exec npm --no-git-tag-version version "$${next_version}"
	git add -- "./package*.json"
# Increment the version in VCS
	tox exec -e "build" -- cz bump $${cz_bump_args}
ifeq ($(VCS_BRANCH),main)
# Merge the bumped version back into `develop`:
	$(MAKE) VCS_BRANCH="main" VCS_MERGE_BRANCH="develop" \
	    VCS_REMOTE="$(VCS_COMPARE_REMOTE)" VCS_MERGE_BRANCH="develop" devel-merge
	git switch -C "$(VCS_BRANCH)" "$$(git rev-parse HEAD)"
endif
	$(MAKE) test-clean

.PHONY: release-all
## Run the whole release process, end to end.
release-all: ./var/log/git-fetch.log
# Done as separate sub-makes in the recipe, as opposed to prerequisites, to support
# running as much of the process as possible with `$ make -j`:
	$(MAKE) test-push test
	$(MAKE) release
	$(MAKE) test-clean


### Development Targets:
#
# Recipes used by developers to make changes to the code.

.PHONY: devel-format
## Automatically correct code in this checkout according to linters and style checkers.
devel-format: ./var/log/docker-compose-network.log ./var/log/npm-install.log
	true "TEMPLATE: Always specific to the project type"
# Add license and copyright header to files missing them:
	git ls-files -co --exclude-standard -z ':!*.license' ':!.reuse' ':!LICENSES' \
	    ':!newsfragments/*' ':!docs/news*.rst' ':!styles/**' \
	    ':!requirements/*/*.txt' |
	while read -d $$'\0'
	do
	    if ! (
	        test -e  "$${REPLY}.license" ||
	        grep -Eq 'SPDX-License-Identifier:' "$${REPLY}"
	    )
	    then
	        echo "$${REPLY}"
	    fi
	done | xargs -r -t -- \
	    docker compose run --rm -T "reuse" annotate --skip-unrecognised \
	        --copyright "Ross Patterson <me@rpatterson.net>" --license "MIT"
# Run source code formatting tools implemented in JavaScript:
	~/.nvm/nvm-exec npm run format

.PHONY: devel-upgrade
## Update requirements, dependencies, and other external versions tracked in VCS.
devel-upgrade:
	touch ./requirements/*.txt.in "./.env.in.~prereq~" "./.vale.ini" ./styles/*.ini
	$(MAKE) PIP_COMPILE_ARGS="--upgrade" DOCKER_COMPOSE_UPGRADE=true \
	    "./requirements/$(PYTHON_HOST_ENV)/build.txt" devel-upgrade-pre-commit \
	    devel-upgrade-js "./var/log/vale-rule-levels.log"
.PHONY: devel-upgrade-pre-commit
## Update VCS integration from remotes to the most recent tag.
devel-upgrade-pre-commit: ./.tox/build/.tox-info.json
	tox exec -e "build" -- pre-commit autoupdate
.PHONY: devel-upgrade-js
## Update tools implemented in JavaScript.
devel-upgrade-js: ./var/log/npm-install.log
	~/.nvm/nvm-exec npm update
	~/.nvm/nvm-exec npm outdated
.PHONY: devel-upgrade-docker
## Update the container images of development tools.
devel-upgrade-docker: $(HOST_TARGET_DOCKER)
	touch "./.env.in.~prereq~"
	$(MAKE) DOCKER_COMPOSE_UPGRADE=true "./.env.~out~"

.PHONY: devel-upgrade-branch
## Reset an upgrade branch, commit upgraded dependencies on it, and push for review.
devel-upgrade-branch: ./var/log/git-fetch.log test-clean
	now=$$(date -u)
	$(MAKE) TEMPLATE_IGNORE_EXISTING="true" devel-upgrade
	if $(MAKE) "test-clean"
	then
# No changes from upgrade, exit signaling success but push nothing:
	    exit
	fi
# Only add changes related to the upgrades:
	git add --update '.env.in' './requirements/*/*.txt' \
	    "./.pre-commit-config.yaml" "./package-lock.json" "./.vale.ini"
	git add "./styles/"
# Commit the upgrade changes
	echo ":Upgrade: Upgrade all requirements to the most recent versions as of" \
	    >"./newsfragments/+upgrade-requirements.bugfix.rst"
	echo "          $${now}." >>"./newsfragments/+upgrade-requirements.bugfix.rst"
	git add "./newsfragments/+upgrade-requirements.bugfix.rst"
	git commit --all --gpg-sign -m \
	    "fix(deps): Upgrade to most recent versions"
# Create or reset the feature branch for merge or pull requests:
	git switch -C "$(VCS_BRANCH)-upgrade"
# Fail if upgrading left un-tracked files in VCS:
	$(MAKE) "test-clean"

.PHONY: devel-merge
## Merge this branch with a suffix back into its un-suffixed upstream.
devel-merge: ./var/log/git-fetch.log
	merge_rev="$$(git rev-parse HEAD)"
	git fetch "$(VCS_REMOTE)" "$(VCS_MERGE_BRANCH)"
	git switch -C "$(VCS_MERGE_BRANCH)" --track "$(VCS_REMOTE)/$(VCS_MERGE_BRANCH)"
	git merge --ff --gpg-sign -m \
	    $$'Merge branch \'$(VCS_BRANCH)\' into $(VCS_MERGE_BRANCH)\n\n[ci merge]' \
	    "$${merge_rev}"


### Clean Targets:
#
# Recipes used to restore the checkout to initial conditions.

.PHONY: clean
## Restore the checkout to an initial clone state.
clean:
	docker compose down --remove-orphans --rmi "all" -v || true
	tox exec -e "build" -- pre-commit uninstall \
	    --hook-type "pre-commit" --hook-type "commit-msg" --hook-type "pre-push" \
	    || true
	tox exec -e "build" -- pre-commit clean || true
	git clean -dfx -e "/var" -e "/.env" -e "*~"
	git clean -dfx './var/log/*'


### Real Targets:
#
# Recipes that make actual changes and create and update files for the target.

# TEMPLATE: Add any other prerequisites that are likely to require updating the build
# package.
./var/log/build-pkgs.log: ./var-host/log/make-runs/$(MAKE_RUN_UUID).log
	mkdir -pv "$(dir $(@))"
	echo "TEMPLATE: Always specific to the project type" | tee -a "$(@)"

# Create the Docker compose network a single time under parallel make:
./var/log/docker-compose-network.log:
	$(MAKE) "$(HOST_TARGET_DOCKER)" "./.env.~out~"
	mkdir -pv "$(dir $(@))"
# Workaround broken interactive session detection:
	docker compose pull --quiet "vale" | tee -a "$(@)"
	docker compose run --rm -T --entrypoint "true" vale | tee -a "$(@)"

# Local environment variables and secrets from a template:
./.env.in.~prereq~:
	touch "$(@)"
./.env.in: ./.env.in.~prereq~
ifeq ($(DOCKER_COMPOSE_UPGRADE),true)
# Define the image tag to track in `./compose*.yml` in the default values for the
# `${DOCKER_*_DIGEST}` environment variables and track the locked/frozen image digests
# in `./.env.in` in VCS:
#
# If changes updated the template, prompt the user to reconcile any differences before
# upgrading image digests:
	if test "$(@)" -nt "$(@:%.in=%)"
	then
	    $(call expand_template,$(@),$(@:%.in=%))
	fi
# Create a temporary `./.env` without any image digests so that `$ docker compose`
# reverts to use the image tags, for example `*:latest`:
	grep -vE "DOCKER_[A-Z0-9_]+_DIGEST=@.*" <"$(@)" >"$(@).~upgrade~"
	mv -v --backup="numbered" "$(@).~upgrade~" "$(@)"
	if test -e "$(@:%.in=%)"
	then
	    mv -v "$(@:%.in=%)" "$(@:%.in=%).~upgrade~"
	fi
	envsubst <"$(@)" >"$(@:%.in=%)"
# Pull the most recent images for the given tags:
	services="$$(
	    docker compose config --profiles | while read
	    do
	        docker compose --profile "$${REPLY}" config --services
	    done | sort | uniq | grep -Ev '^($(PROJECT_NAME)|build-host)'
	)"
	docker compose pull $${services}
# Write the image digests for the pulled images back to the `./.env.in` template:
	for service in $${services}
	do
	    env_var="DOCKER_$${service^^}_DIGEST"
	    env_var="$${env_var//-/_}"
	    digest="$$(
	        docker compose config --resolve-image-digests --format "json" \
	            "$${service}" |
	            jq -r ".services.\"$${service}\".image" | cut -d "@" -f "2-"
	    )"
	    echo "$${env_var}=@$${digest}" >>"$(@)"
	done
# Restore the user's possibly customized `./.env` but with the new image digests:
	if test -e "$(@:%.in=%).~upgrade~"
	then
	    grep -vE "DOCKER_[A-Z0-9_]+_DIGEST=@.*" \
	        <"$(@:%.in=%).~upgrade~" >"$(@:%.in=%)"
	    grep -E "DOCKER_[A-Z0-9_]+_DIGEST=@.*" <"$(@)" >>"$(@:%.in=%)"
	fi
else
# There's nothing to change in the template if not upgrading image digests:
	touch "$(@)"
endif
./.env.~out~: ./.env.in
	$(call expand_template,$(<),$(@))


### Development Tools:

# VCS configuration and integration:
# Retrieve VCS data needed for versioning, tags, and releases, release notes. Done in
# it's own target to avoid redundant fetches during release tasks:
./var/log/git-fetch.log: ./var-host/log/make-runs/$(MAKE_RUN_UUID).log
	mkdir -pv "$(dir $(@))"
	git_fetch_args="--tags --prune --prune-tags --force"
	if test "$$(git rev-parse --is-shallow-repository)" = "true"
	then
	    git_fetch_args+=" --unshallow"
	fi
ifneq ($(VCS_BRANCH),)
	if ! git fetch $${git_fetch_args} "$(VCS_REMOTE)" "$(VCS_BRANCH)" |&
	    tee -a "$(@)"
	then
# If the branch is only local, fall back to the pre-release branch:
	    git fetch $${git_fetch_args} "$(VCS_REMOTE)" "develop" |& tee -a "$(@)"
	fi
ifneq ($(VCS_REMOTE)/$(VCS_BRANCH),$(VCS_COMPARE_REMOTE)/$(VCS_COMPARE_BRANCH))
# Fetch any upstream VCS data that forks need:
	git fetch "$(VCS_COMPARE_REMOTE)" "$(VCS_COMPARE_BRANCH)" |& tee -a "$(@)"
endif
ifneq ($(VCS_REMOTE)/$(VCS_BRANCH),$(VCS_COMPARE_REMOTE)/develop)
ifneq ($(VCS_COMPARE_REMOTE)/$(VCS_COMPARE_BRANCH),$(VCS_COMPARE_REMOTE)/develop)
	git fetch "$(VCS_COMPARE_REMOTE)" "develop" |& tee -a "$(@)"
endif
endif
endif
	touch "$(@)"
# A target whose `mtime` reflects files added to or removed from VCS:
./var/log/git-ls-files.log: ./var-host/log/make-runs/$(MAKE_RUN_UUID).log
	mkdir -pv "$(dir $(@))"
	git ls-files >"$(@).~new~"
	if diff --color -u "$(@)" "$(@).~new~"
	then
	    exit
	fi
	mv -v "$(@).~new~" "$(@)"
# <!--alex disable hooks-->
./.git/hooks/pre-commit:
# <!--alex enable hooks-->
	$(MAKE) "./.tox/build/.tox-info.json"
	tox exec -e "build" -- pre-commit install \
	    --hook-type "pre-commit" --hook-type "commit-msg" --hook-type "pre-push"

# Prose linting:
# Map formats unknown by Vale to a common default format:
./var/log/vale-map-formats.log: ./bin/vale-map-formats.py ./.vale.ini \
		./var/log/git-ls-files.log
	$(MAKE) "./.tox/build/.tox-info.json"
	tox exec -e "build" -- python "$(<)" "./styles/code.ini" "./.vale.ini"
# Set Vale levels for added style rules:
# Must be it's own target because Vale sync takes the sets of styles from the
# configuration and the configuration needs the styles to set rule levels:
./var/log/vale-rule-levels.log: ./styles/RedHat/meta.json ./.tox/build/.tox-info.json
	$(MAKE) "./.tox/build/.tox-info.json"
	tox exec -e "build" -- python ./bin/vale-set-rule-levels.py
	tox exec -e "build" -- python ./bin/vale-set-rule-levels.py \
	    --input="./styles/code.ini"
# Update style rule definitions from the remotes:
./styles/RedHat/meta.json: ./var/log/docker-compose-network.log ./.vale.ini \
		./styles/code.ini
	docker compose run --rm -T vale sync
	docker compose run --rm -T vale sync --config="./styles/code.ini"

# Editor and IDE support and integration:
./.dir-locals.el.~out~: ./.dir-locals.el.in
	$(call expand_template,$(<),$(@))

# Manage JavaScript tools:
./var/log/npm-install.log: ./package.json ./var/log/nvm-install.log
	mkdir -pv "$(dir $(@))"
	~/.nvm/nvm-exec npm install | tee -a "$(@)"
./package.json:
	$(MAKE) "./var/log/nvm-install.log"
# https://docs.npmjs.com/creating-a-package-json-file#creating-a-default-packagejson-file
	~/.nvm/nvm-exec npm init --yes --scope="@$(NPM_SCOPE)"
./var/log/nvm-install.log: ./.nvmrc
	$(MAKE) "$(HOME)/.nvm/nvm.sh"
	mkdir -pv "$(dir $(@))"
	set +x
	. "$(HOME)/.nvm/nvm.sh" || true
	nvm install | tee -a "$(@)"
# https://github.com/nvm-sh/nvm#install--update-script
$(HOME)/.nvm/nvm.sh:
	set +x
	wget -qO- "https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh"
	    | bash

# Manage Python tools:
./.tox/build/.tox-info.json: $(HOME)/.local/bin/tox ./tox.ini \
		./requirements/$(PYTHON_HOST_ENV)/build.txt
	tox run -e "$(@:.tox/%/.tox-info.json=%)" --notest
	touch "$(@)"
./requirements/$(PYTHON_SUPPORTED_ENV)/build.txt: ./requirements/build.txt.in \
		$(HOME)/.local/bin/tox
	mkdir -pv "$(dir $(@))"
	tox exec -e "build" -x testenv:build.deps="-r$(<)" -- pip-compile --strip-extras \
	    --generate-hashes --reuse-hashes --allow-unsafe --quiet \
	    $(PIP_COMPILE_ARGS) --output-file "$(@)" "$(<)"
# Only compile versions that the `./build-host/` Docker image can compile but use tools
# without pinned/frozen versions for contributors that don't have the canonical Python
# version installed:
ifneq ($(PYTHON_SUPPORTED_ENV),$(PYTHON_HOST_ENV))
./requirements/$(PYTHON_HOST_ENV)/build.txt: ./requirements/build.txt.in
	mkdir -pv "$(dir $(@))"
	ln -sv --relative --backup="numbered" "$(<)" "$(@)"
endif
$(HOME)/.local/bin/tox:
	$(MAKE) "$(HOST_PREFIX)/bin/pipx"
# https://tox.wiki/en/latest/installation.html#via-pipx
	pipx install --python "python$(PYTHON_HOST_MINOR)" "tox"
	touch "$(@)"
$(HOST_PREFIX)/bin/pipx:
	$(MAKE) "$(STATE_DIR)/log/host-update.log"
	$(HOST_PKG_CMD) $(HOST_PKG_INSTALL_ARGS) "$(HOST_PKG_NAMES_PIPX)"

# Tools needed by Sphinx builders:
$(HOST_PREFIX)/bin/makeinfo:
	$(MAKE) "$(STATE_DIR)/log/host-update.log"
	$(HOST_PKG_CMD) $(HOST_PKG_INSTALL_ARGS) "$(HOST_PKG_NAMES_MAKEINFO)"
$(HOST_PREFIX)/bin/latexmk:
	$(MAKE) "$(STATE_DIR)/log/host-update.log"
	$(HOST_PKG_CMD) $(HOST_PKG_INSTALL_ARGS) "$(HOST_PKG_NAMES_LATEXMK)"
$(HOST_PREFIX)/bin/convert:
	$(MAKE) "$(STATE_DIR)/log/host-update.log"
	$(HOST_PKG_CMD) $(HOST_PKG_INSTALL_ARGS) $(HOST_PKG_NAMES_IMAGEMAGICK)

# Manage tools in containers:
$(HOST_TARGET_DOCKER):
	$(MAKE) "$(STATE_DIR)/log/host-update.log"
	$(HOST_PKG_CMD) $(HOST_PKG_INSTALL_ARGS) "$(HOST_PKG_NAMES_DOCKER)"
	docker info
ifeq ($(HOST_PKG_BIN),brew)
# https://formulae.brew.sh/formula/docker-compose#default
	mkdir -p ~/.docker/cli-plugins
	ln -sfnv "$${HOMEBREW_PREFIX}/opt/docker-compose/bin/docker-compose" \
	    "~/.docker/cli-plugins/docker-compose"
endif

# Support for installing host operating system packages:
$(STATE_DIR)/log/host-update.log:
	if ! $(HOST_PKG_CMD_PREFIX) which $(HOST_PKG_BIN)
	then
	    set +x
	    echo "ERROR: OS not supported for installing system dependencies"
	    false
	fi
	$(HOST_PKG_CMD) update | tee -a "$(@)"

# Useful to update targets only one time per run including sub-makes:
./var-host/log/make-runs/$(MAKE_RUN_UUID).log:
	mkdir -pv "$(dir $(@))"
	rm -rf $(dir $(@))*.log
	date | tee -a "$(@)"


### Makefile "functions":
#
# Snippets used several times, including in different recipes:
# https://www.gnu.org/software/make/manual/html_node/Call-Function.html

# Have to use a placeholder `*.~out~` target instead of the real expanded template
# because targets can't disable `.DELETE_ON_ERROR` on a per-target basis.
#
# Can't use a target and recipe to install `$ envsubst`. Shouldn't update expanded
# templates when `/usr/bin/envsubst` changes but expanding a template requires it to be
# installed. The recipe can't use a sub-make because Make updates any expanded template
# targets used in `include` directives when reading the `./Makefile`, for example
# `./.env`, leading to endless recursion:
define expand_template=
if ! which envsubst
then
    $(HOST_PKG_CMD) update | tee -a "$(STATE_DIR)/log/host-update.log"
    $(HOST_PKG_CMD) $(HOST_PKG_INSTALL_ARGS) $(HOST_PKG_NAMES_ENVSUBST)
fi
if test "$(2:%.~out~=%)" -nt "$(1)"
then
    envsubst <"$(1)" >"$(2)"
    exit
fi
if test ! -e "$(2:%.~out~=%)"
then
    touch -d "@0" "$(2:%.~out~=%)"
fi
envsubst <"$(1)" | diff --color -u "$(2:%.~out~=%)" "-" || true
set +x
echo "WARNING:Template $(1) changed, reconcile and \`$$ touch $(2:%.~out~=%)\`."
set -x
if test ! -s "$(2:%.~out~=%)"
then
    envsubst <"$(1)" >"$(2:%.~out~=%)"
    touch -d "@0" "$(2:%.~out~=%)"
fi
if test "$(TEMPLATE_IGNORE_EXISTING)" = "true"
then
    envsubst <"$(1)" >"$(2:%.~out~=%)"
    exit
fi
exit 1
endef


### Makefile Development:
#
# Development primarily requires a balance of 2 priorities:
#
# - Correctness of the source code and build artifacts
# - Reduce iteration time in the inner loop of development
#
# This project uses Make to balance those priorities. Target recipes capture the
# commands necessary to build artifacts, run tests, and verify the code. Top-level
# targets compose related target recipes for often needed tasks. Targets use
# prerequisites to define when to update build artifacts prevent time wasted on
# unnecessary updates in the inner loop of development.
#
# Make provides an important feature to achieve that second priority, a framework for
# determining when to do work. Targets define build artifact paths. The target's recipe
# lists the commands that create or update that build artifact. The target's
# prerequisites define when to update that target. Make runs the recipe when any of the
# prerequisites have more recent modification times than the target to update the
# target.
#
# For example, if a feature adds library to the project's dependencies, correctness
# requires the project to update the frozen, or locked versions to include the added
# library. The rest of the time the locked or frozen versions don't need updating and it
# wastes significant time to always update them in the inner loop of development. To
# express such relationships in Make, define targets for the files containing the locked
# or frozen versions and add a prerequisite for the file that defines dependencies:
#
#    ./build/bar.txt: ./bar.txt.in
#    	envsubst <"$(<)" >"$(@)"
#
# To that end, use real target and prerequisite files whenever possible when adding
# recipes to this file. Make calls targets whose name doesn't correspond to a real build
# artifact `.PHONY:` targets. Use `.PHONY:` targets to compose sets or real targets and
# define recipes for tasks that don't produce build artifacts, for example, the
# top-level targets.

# If a recipe doesn't produce an appropriate build artifact, define an arbitrary target
# the recipe writes to, such as piping output to a log file. Also use this approach when
# none of the modification times of produced artifacts reflect when any downstream
# targets need updating:
#
#     ./var/log/some-work.log:
#         mkdir -pv "$(dir $(@))"
#         echo "Do some work here" | tee -a "$(@)"
#
# If the recipe produces no output, the recipe can create arbitrary output:
#
#     ./var/log/bar.log:
#         echo "Do some work here"
#         mkdir -pv "$(dir $(@))"
#         date | tee -a "$(@)"
#
# If the recipe of a target needs another target but updating that other target doesn't
# mean that this target's recipe needs to re-run, such as one-time system install tasks,
# use that target in a sub-make instead of a prerequisite:
#
#     ./var/log/bar.log:
#         $(MAKE) "./var/log/qux.log"
#
# This project uses some more Make features than these core features and welcome further
# use of such features:
#
# - `$(@)`:
#   The automatic variable containing the path for the target
#
# - `$(<)`:
#   The automatic variable containing the path for the first prerequisite
#
# - `$(VARIABLE_FOO:%=bar-%)`:
#   Substitution references to generate transformations of space-separated values
#
# - `$ make OPTION_FOO=bar`:
#   Use "option" variables and support overriding on the command-line
#
# Avoid the more "magical" features of Make, to keep it readable, discover-able, and
# otherwise approachable to developers who might not have significant familiarity with
# Make. If you have good, pragmatic reasons to add use of further features, make the
# case for them but avoid them if possible.


### Maintainer targets:
#
# Recipes not used during the usual course of development.

.PHONY: bootstrap-project
bootstrap-project:
# Reproduce an isolated, clean build in a Docker image to reproduce build issues:
	$(MAKE) -C "./build-host/" release
