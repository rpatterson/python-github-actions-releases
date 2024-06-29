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
export DOCKER_USER?=$(DOCKER_NAMESPACE)
# Match the same Python version available in the `./build-host/` Docker image:
# https://pkgs.alpinelinux.org/packages?name=python3&branch=edge&repo=main&arch=x86_64&maintainer=
PYTHON_SUPPORTED_MINOR=3.12
# TEMPLATE: See comments towards the bottom and update.
GPG_SIGNING_KEYID=2EFF7CCE6828E359

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
ifeq ($(origin MAKE_RUN_UUID), undefined)
    export MAKE_RUN_UUID:=$(shell python3 -c "import uuid; print(uuid.uuid4())")
endif
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
HOST_PKG_NAMES_GPG=gnupg
HOST_PKG_NAMES_GHCLI=gh
HOST_PKG_NAMES_CURL=curl
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
HOST_PKG_NAMES_GHCLI=github-cli
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
CI_COMMIT_BRANCH?=
GITHUB_REF_TYPE?=
GITHUB_REF_NAME?=
ifeq ($(VCS_LOCAL_BRANCH),)
ifneq ($(CI_COMMIT_BRANCH),)
VCS_LOCAL_BRANCH=$(CI_COMMIT_BRANCH)
else ifeq ($(GITHUB_REF_TYPE),branch)
VCS_LOCAL_BRANCH=$(GITHUB_REF_NAME)
endif
endif
VCS_TAG=
CI_COMMIT_TAG?=
ifeq ($(VCS_TAG),)
ifneq ($(CI_COMMIT_TAG),)
VCS_TAG=$(CI_COMMIT_TAG)
else ifeq ($(GITHUB_REF_TYPE),tag)
VCS_TAG=$(GITHUB_REF_NAME)
endif
endif
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
export VCS_BRANCH
# Find the remote and branch for conventional commits release data:
VCS_COMPARE_REMOTE=$(VCS_UPSTREAM_REMOTE)
ifeq ($(VCS_COMPARE_REMOTE),)
VCS_COMPARE_REMOTE=$(VCS_PUSH_REMOTE)
endif
VCS_COMPARE_BRANCH=$(VCS_UPSTREAM_BRANCH)
ifeq ($(VCS_COMPARE_BRANCH),)
VCS_COMPARE_BRANCH=$(VCS_BRANCH)
endif
# Under CI, verify commits and release notes by comparing this branch with the branch
# maintainers would merge this branch into:
CI=false
ifeq ($(CI),true)
ifeq ($(VCS_COMPARE_BRANCH),develop)
VCS_COMPARE_BRANCH=main
else ifneq ($(VCS_BRANCH),main)
VCS_COMPARE_BRANCH=develop
endif
# If pushing to upstream release branches, get release data compared to the preceding
# release:
else ifeq ($(VCS_COMPARE_BRANCH),develop)
VCS_COMPARE_BRANCH=main
endif
VCS_BRANCH_SUFFIX=upgrade
VCS_MERGE_BRANCH=$(VCS_BRANCH:%-$(VCS_BRANCH_SUFFIX)=%)
# The sequence of branches from which to find closest existing build artifacts, such as
# container images:
ifneq ($(VCS_BRANCH),)
VCS_BRANCHES=$(VCS_BRANCH)
ifneq ($(VCS_BRANCH),main)
ifneq ($(VCS_BRANCH),develop)
VCS_BRANCHES+=develop
endif
VCS_BRANCHES+=main
endif
endif

# Values used to build Docker images:
export DOCKER_BUILD_TARGET?=user
export DOCKER_BUILD_ARGS?=--load
export DOCKER_BUILD_PULL?=false
DOCKER_PULL_TARGET=devel
# Values used to tag built images:
DOCKER_OS_DEFAULT=debian
DOCKER_OSES?=$(DOCKER_OS_DEFAULT)
# TEMPLATE: Update for the project language:
DOCKER_LANGUAGE_DEFAULT=
DOCKER_LANGUAGES?=$(DOCKER_LANGUAGE_DEFAULT)
# Build all image variants in parallel:
ifeq ($(DOCKER_LANGUAGES),)
DOCKER_VARIANTS=$(DOCKER_OSES)
DOCKER_DEFAULT=$(DOCKER_OS_DEFAULT)
else
DOCKER_VARIANTS=$(foreach language,$(DOCKER_LANGUAGES),$(DOCKER_OSES:%=%-$(language)))
DOCKER_DEFAULT=$(DOCKER_OS_DEFAULT)-$(DOCKER_LANGUAGE_DEFAULT)
endif
export DOCKER_VARIANT?=$(firstword $(DOCKER_VARIANTS))
export DOCKER_BRANCH_TAG=$(subst /,-,$(VCS_BRANCH))
DOCKER_DEFAULT_TAG=$(DOCKER_DEFAULT)-$(DOCKER_BRANCH_TAG)
GITLAB_CI?=false
GITHUB_ACTIONS?=false
CI_PROJECT_NAMESPACE?=$(CI_UPSTREAM_NAMESPACE)
CI_TEMPLATE_REGISTRY_HOST?=registry.gitlab.com
ifeq ($(GITHUB_ACTIONS),true)
DOCKER_REGISTRY_HOST=ghcr.io
else
DOCKER_REGISTRY_HOST=$(CI_TEMPLATE_REGISTRY_HOST)
endif
export DOCKER_REGISTRY_HOST
CI_REGISTRY?=$(CI_TEMPLATE_REGISTRY_HOST)/$(CI_PROJECT_NAMESPACE)
CI_REGISTRY_IMAGE?=$(CI_REGISTRY)/$(CI_PROJECT_NAME)
DOCKER_REGISTRIES=GITLAB GITHUB DOCKER
DOCKER_REGISTRY=$(firstword $(DOCKER_REGISTRIES))
ifeq ($(GITHUB_ACTIONS),true)
DOCKER_REGISTRY=GITHUB
endif
export DOCKER_REGISTRY
DOCKER_IMAGE_GITLAB=$(CI_REGISTRY_IMAGE)
DOCKER_IMAGE_GITHUB=ghcr.io/$(CI_PROJECT_NAMESPACE)/$(CI_PROJECT_NAME)
DOCKER_IMAGE_DOCKER=$(DOCKER_NAMESPACE)/$(PROJECT_NAME)
export DOCKER_IMAGE=$(DOCKER_IMAGE_$(DOCKER_REGISTRY))
DOCKER_IMAGES=
ifeq ($(GITLAB_CI),true)
DOCKER_IMAGES+=$(DOCKER_IMAGE_GITLAB)
else ifeq ($(GITHUB_ACTIONS),true)
DOCKER_IMAGES+=$(DOCKER_IMAGE_GITHUB)
else
DOCKER_IMAGES+=$(DOCKER_IMAGE_DOCKER)
endif
export DOCKER_PASS?=
DOCKER_COMPOSE_RUN_CMD=docker compose run --rm -T --quiet-pull
DOCKER_COMPOSE_UPGRADE=false
TEST_CODE_PREREQS=./var/log/build-pkgs.log

APT_LOCK_FILES=$(wildcard ./apt/*-lock.txt)

# Values derived from or overridden by CI environments:
CI_UPSTREAM_NAMESPACE=$(PROJECT_NAMESPACE)
CI_PROJECT_NAME?=$(PROJECT_NAME)
ifeq ($(CI),true)
TEMPLATE_IGNORE_EXISTING=true
endif
GITHUB_REPOSITORY_OWNER?=$(CI_UPSTREAM_NAMESPACE)
# Is this checkout a fork of the upstream project?:
CI_IS_FORK?=false
ifeq ($(GITLAB_CI),true)
USER_EMAIL=$(USER_NAME)@runners-manager.gitlab.com
ifneq ($(VCS_BRANCH),develop)
ifneq ($(VCS_BRANCH),main)
DOCKER_REGISTRIES=GITLAB
endif
endif
ifneq ($(CI_PROJECT_NAMESPACE),$(CI_UPSTREAM_NAMESPACE))
CI_IS_FORK=true
DOCKER_REGISTRIES=GITLAB
DOCKER_IMAGES+=$(DOCKER_REGISTRY_HOST)/$(CI_UPSTREAM_NAMESPACE)/$(CI_PROJECT_NAME)
endif
else ifeq ($(GITHUB_ACTIONS),true)
USER_EMAIL=$(USER_NAME)@actions.github.com
ifneq ($(VCS_BRANCH),develop)
ifneq ($(VCS_BRANCH),main)
DOCKER_REGISTRIES=GITHUB
endif
endif
ifneq ($(GITHUB_REPOSITORY_OWNER),$(CI_UPSTREAM_NAMESPACE))
CI_IS_FORK=true
DOCKER_REGISTRIES=GITHUB
DOCKER_IMAGES+=ghcr.io/$(GITHUB_REPOSITORY_OWNER)/$(CI_PROJECT_NAME)
endif
endif
DOCKER_IMAGES+=$(DOCKER_IMAGE)
# Take GitHub auth from the environment under GitHub actions but from secrets on other
# project hosts:
GITHUB_TOKEN?=
PROJECT_GITHUB_PAT?=
ifeq ($(GITHUB_TOKEN),)
GITHUB_TOKEN?=$(PROJECT_GITHUB_PAT)
else ifeq ($(PROJECT_GITHUB_PAT),)
PROJECT_GITHUB_PAT=$(GITHUB_TOKEN)
endif
GH_TOKEN?=$(GITHUB_TOKEN)
export GH_TOKEN
export GITHUB_TOKEN
export PROJECT_GITHUB_PAT

# Values used for publishing releases:
# Safe defaults for testing the release process without publishing to the official
# project hosting services, indexes, and registries:
RELEASE_PUBLISH=false
# Publish releases from the `main` or `develop` branches:
GITHUB_RELEASE_ARGS=--prerelease
# Only publish releases from the `main` or `develop` branches and only under the
# canonical CI/CD platform:
ifeq ($(GITLAB_CI),true)
ifeq ($(VCS_BRANCH),main)
RELEASE_PUBLISH=true
GITHUB_RELEASE_ARGS=
else ifeq ($(VCS_BRANCH),develop)
# Publish pre-releases from the `develop` branch:
RELEASE_PUBLISH=true
endif
DOCKER_PLATFORMS=
ifeq ($(RELEASE_PUBLISH),true)
# TEMPLATE: Choose the platforms on which your users run the image. These default
# platforms should cover most common end-user platforms, including modern Apple M1 CPUs,
# Raspberry Pi devices, and AWS Graviton instances:
DOCKER_PLATFORMS=linux/amd64 linux/arm64 linux/arm/v7
endif
endif
CI_REGISTRY_USER?=$(CI_PROJECT_NAMESPACE)
VCS_REMOTE_PUSH_URL?=
CODECOV_TOKEN?=
CI_PROJECT_ID?=
export CI_PROJECT_ID
CI_JOB_TOKEN?=
export CI_JOB_TOKEN
CI_REGISTRY_PASSWORD?=
export CI_REGISTRY_PASSWORD

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

.PHONY: start
## Run the local development end-to-end stack services in the background as daemons.
start: $(HOST_TARGET_DOCKER) \
		./var-docker/$(DOCKER_DEFAULT)/log/build-user.log ./.env.~out~
	docker compose down
	docker compose up -d

.PHONY: run
## Run the local development end-to-end stack services in the foreground for debugging.
run: $(HOST_TARGET_DOCKER) ./var-docker/$(DOCKER_DEFAULT)/log/build-user.log \
		./.env.~out~
	docker compose down
	docker compose up


### Build Targets:
#
# Recipes that make artifacts needed for by end-users, development tasks, other recipes.

.PHONY: build
## Set up everything for development from a checkout, local and in containers.
# <!--alex disable hooks-->
build: ./.git/hooks/pre-commit ./var/log/docker-compose-network.log \
		./.tox/build/.tox-info.json ./var/log/npm-install.log build-docker
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


## Docker Build Targets:
#
# Strive for as much consistency as possible in development tasks between the local host
# and inside containers. To that end, most of the `*-docker` container target recipes
# should run the corresponding `*-local` local host target recipes inside the
# development container. Top level targets, such as `test`, should run as much as
# possible inside the development container.

.PHONY: build-docker
## Set up for development in Docker containers.
build-docker: $(DOCKER_VARIANTS:%=build-docker-%)
.PHONY: $(DOCKER_VARIANTS:%=build-docker-%)
# Need to use `$(eval $(call))` to reference the variant in the target *and*
# prerequisite:
define build_docker_template=
build-docker-$(1): ./var-docker/$(1)/log/build-devel.log \
		./var-docker/$(1)/log/build-user.log
endef
$(foreach variant,$(DOCKER_VARIANTS),$(eval $(call build_docker_template,$(variant))))

.PHONY: build-docker-tags
## Print the list of tags for this image variant in all registries.
build-docker-tags: ./.tox/build/.tox-info.json
	MAKEFLAGS="" DEBUG="false" $(MAKE) --quiet --no-print-directory \
	    $(DOCKER_REGISTRIES:%=build-docker-tags-%)

.PHONY: $(DOCKER_REGISTRIES:%=build-docker-tags-%)
## Print the list of image tags for the current registry and variant.
$(DOCKER_REGISTRIES:%=build-docker-tags-%): ./.tox/build/.tox-info.json
	test -e "./var/log/git-fetch.log"
	docker_image="$(DOCKER_IMAGE_$(@:build-docker-tags-%=%))"
	target_variant="$(DOCKER_BUILD_TARGET)-$(DOCKER_VARIANT)"
# Print only the branch tag if this image variant is the default variant:
ifeq ($(DOCKER_VARIANT),$(DOCKER_DEFAULT))
	echo "$${docker_image}:$(DOCKER_BUILD_TARGET)-$(DOCKER_BRANCH_TAG)"
ifeq ($(DOCKER_BUILD_TARGET),user)
	echo "$${docker_image}:$(DOCKER_BRANCH_TAG)"
endif
endif
# Print any other unqualified or default tags only for images built from the `main`
# branch.  Users can count on these to be stable:
ifeq ($(VCS_BRANCH),main)
# Print only the variant with no qualifier for the branch:
	echo "$${docker_image}:$${target_variant}"
# Print tags qualified by the major and minor versions so that users can avoid breaking
# changes:
	VERSION="$$(tox exec -e "build" -qq -- cz version --project)"
	major_version="$$(echo $${VERSION} | sed -nE 's|([0-9]+).*|\1|p')"
	minor_version="$$(
	    echo "$${VERSION}" | sed -nE 's|([0-9]+\.[0-9]+).*|\1|p'
	)"
	if test "v$${minor_version}" != "$(DOCKER_BRANCH_TAG)"
	then
	    echo "$${docker_image}:$${target_variant}-v$${minor_version}"
	fi
	if test "v$${major_version}" != "$(DOCKER_BRANCH_TAG)"
	then
	    echo "$${docker_image}:$${target_variant}-v$${major_version}"
	fi
# Print the rest of the unqualified tags only for the default variant:
ifeq ($(DOCKER_VARIANT),$(DOCKER_DEFAULT))
	if test "v$${minor_version}" != "$(DOCKER_BRANCH_TAG)"
	then
	    echo "$${docker_image}:v$${minor_version}"
	fi
	if test "v$${major_version}" != "$(DOCKER_BRANCH_TAG)"
	then
	    echo "$${docker_image}:v$${major_version}"
	fi
	echo "$${docker_image}:latest"
endif
endif

.PHONY: build-docker-build
## Run the actual commands used to build the Docker container image.
build-docker-build: ./Dockerfile $(HOST_TARGET_DOCKER) ./.tox/build/.tox-info.json \
		$(HOME)/.local/state/docker-multi-platform/log/host-install.log \
		./var/log/git-fetch.log \
		./var/log/docker-login-DOCKER.log
	pull_target="devel"
ifneq ($(DOCKER_BUILD_TARGET),base)
ifneq ($(DOCKER_BUILD_TARGET),bootstrap)
	pull_target="$(DOCKER_BUILD_TARGET)"
endif
endif
	tag_suffix="$(DOCKER_VARIANT)-$(DOCKER_BRANCH_TAG)"
ifeq ($(DOCKER_BUILD_PULL),true)
# Pull the image and simulate building it here:
	docker image pull --quiet "$(DOCKER_IMAGE):$${pull_target}-$${tag_suffix}"
	docker image ls --digests "$(
	    docker compose config --images $(PROJECT_NAME)-devel | head -n 1
	)" | tee -a "$(@)"
	exit
endif
# Workaround broken interactive session detection:
	docker pull "buildpack-deps"
# Pull images to use as build caches:
	docker_build_caches=""
ifeq ($(CI),true)
# Don't cache when building final releases on `main`
ifneq ($(VCS_BRANCH),main)
	if $(MAKE) DOCKER_PULL_TARGET="$${pull_target}" pull-docker
	then
	    docker_build_caches+=" --cache-from"
	    docker_build_caches+="  $(DOCKER_IMAGE):$${pull_target}-$${tag_suffix}"
	fi
endif
endif
# Assemble the tags for all the variant permutations:
	$(MAKE) "./var/log/git-fetch.log"
ifeq ($(DOCKER_BUILD_TARGET),base)
	build_target="$(DOCKER_BUILD_TARGET)"
else
	build_target="$${pull_target}"
endif
	docker_build_args="--target $${build_target}"
# Always apply the fully qualified variant tag with all components:
	for image in $(foreach \
	    registry,$(DOCKER_REGISTRIES),$(DOCKER_IMAGE_$(registry)))
	do
	    docker_build_args+=" --tag $${image}:$${build_target}-$${tag_suffix}"
	done
ifneq ($(DOCKER_BUILD_TARGET),base)
	for image_tag in $$(
	    MAKEFLAGS="" DEBUG="false" $(MAKE) --quiet --no-print-directory \
	        build-docker-tags
	)
	do
	    docker_build_args+=" --tag $${image_tag}"
	done
endif
# https://github.com/moby/moby/issues/39003#issuecomment-879441675
	docker buildx build --progress plain $(DOCKER_BUILD_ARGS) \
	    --build-arg BUILDKIT_INLINE_CACHE="1" \
	    --build-arg DOCKER_BASE_DIGEST="$(DOCKER_BASE_DIGEST)" \
	    --build-arg VERSION="$$(
	        tox exec -e "build" -qq -- cz version --project
	    )" $${docker_build_args} $${docker_build_caches} --file "$(<)" "./"


### Test Targets:
#
# Recipes that run the test suite.

.PHONY: test
## Run the full suite of tests, coverage checks, and linters.
test: test-lint test-docker

.PHONY: test-code
## Run the full suite of tests and coverage checks.
test-code: $(TEST_CODE_PREREQS)
	true "TEMPLATE: Always specific to the project type"

.PHONY: test-debug
## Run tests directly on the system and start the debugger on errors or failures.
test-debug:
	true "TEMPLATE: Always specific to the project type"

.PHONY: test-docker
## Run the full suite of tests, coverage checks, and code linters in all variants.
test-docker: $(DOCKER_VARIANTS:%=test-docker-devel-%) \
		$(DOCKER_VARIANTS:%=test-docker-user-%)
.PHONY: $(DOCKER_VARIANTS:%=test-docker-devel-%) \
		$(DOCKER_VARIANTS:%=test-docker-user-%)
define test_docker_template=
# Run code tests inside the development Docker container for consistency:
test-docker-devel-$(1): ./var/log/docker-compose-network.log \
		./var-docker/$(1)/log/build-devel.log ./var/log/build-pkgs.log
	export DOCKER_VARIANT="$(1)"
	$(DOCKER_COMPOSE_RUN_CMD) $$(PROJECT_NAME)-devel \
	    make TEST_CODE_PREREQS= test-code
# Upload any build or test artifacts to CI/CD providers
	if test "$$(GITLAB_CI)" = "true" &&
	    test "$$(@:test-docker-devel-%=%)" = "$$(DOCKER_DEFAULT)"
	then
	    if test "$$(CODECOV_TOKEN)" != ""
	    then
	        $$(MAKE) "$$(HOME)/.local/bin/codecov"
# TEMPLATE: Write coverage results in Cobertura XML format to
# `./build/reports/coverage.xml` and un-comment:
#	        codecov --nonZero -t "$$(CODECOV_TOKEN)" --file \
#	            "./build/reports/coverage.xml"
	    elif test "$$(CI_IS_FORK)" != "true"
	    then
	        set +x
	        echo "ERROR: CODECOV_TOKEN missing from ./.env or CI secrets"
	        false
	    fi
	fi
# Test that the end-user image can run commands:
test-docker-user-$(1): ./var/log/docker-compose-network.log \
		./var-docker/$(1)/log/build-user.log
	export DOCKER_VARIANT="$(1)"
# TEMPLATE: Change the command to confirm the user image has a working installation of
# the package:
	$(DOCKER_COMPOSE_RUN_CMD) --no-deps $$(PROJECT_NAME) true
endef
$(foreach variant,$(DOCKER_VARIANTS),$(eval $(call test_docker_template,$(variant))))

.PHONY: test-lint
## Perform any linter or style checks, including non-code checks.
test-lint: test-lint-code test-lint-docker test-lint-docs test-lint-prose \
		test-lint-licenses

.PHONY: test-lint-licenses
## Lint copyright and license annotations for all files tracked in VCS.
test-lint-licenses: ./var/log/docker-compose-network.log
	$(DOCKER_COMPOSE_RUN_CMD) "reuse"

.PHONY: test-lint-code
## Lint source code for errors, style, and other issues.
test-lint-code: test-lint-code-prettier
.PHONY: test-lint-code-prettier
## Lint source code for formatting with Prettier.
test-lint-code-prettier: ./var/log/npm-install.log ./var/log/build-pkgs.log
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
	    ':!styles/**' ':!requirements/**' ':!apt/*-lock.txt' |
	    xargs -r -0 -t -- $(DOCKER_COMPOSE_RUN_CMD) vale
.PHONY: test-lint-prose-vale-code
## Lint comment prose in all source code files tracked in VCS with Vale.
test-lint-prose-vale-code: ./var/log/docker-compose-network.log
	git ls-files -co --exclude-standard -z ':!styles/**' |
	    xargs -r -0 -t -- \
	    $(DOCKER_COMPOSE_RUN_CMD) vale --config="./styles/code.ini"
.PHONY: test-lint-prose-vale-misc
## Lint source code files tracked in VCS but without extensions with Vale.
test-lint-prose-vale-misc: ./var/log/docker-compose-network.log
	git ls-files -co --exclude-standard -z | grep -Ez '^[^.]+$$' |
	    while read -d $$'\0'
	    do
	        cat "$${REPLY}" |
	            $(DOCKER_COMPOSE_RUN_CMD) vale --config="./styles/code.ini" \
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
test-lint-docker: ./var/log/docker-compose-network.log \
		./var/log/docker-login-DOCKER.log \
		$(DOCKER_VARIANTS:%=test-lint-docker-volumes-%)
	git ls-files -z '*Dockerfile*' |
	    xargs -0 -- $(DOCKER_COMPOSE_RUN_CMD) hadolint hadolint
.PHONY: $(DOCKER_VARIANTS:%=test-lint-docker-volumes-%)
## Prevent Docker volumes owned by `root` for one Python version.
$(DOCKER_VARIANTS:%=test-lint-docker-volumes-%):
	$(MAKE) DOCKER_VARIANT="$(@:test-lint-docker-volumes-%=%)" \
	    test-lint-docker-volumes
.PHONY: test-lint-docker-volumes
## Prevent Docker volumes owned by `root`.
test-lint-docker-volumes:
# Ensure that any bind mount volume paths exist in VCS so that `# dockerd` doesn't
# create them as `root`:
	if test -n "$$(
	    ./bin/docker-add-volume-paths.sh "$(CHECKOUT_DIR)$(WORKTREE_REL)" \
	        "/usr/local/src/$(PROJECT_NAME)$(WORKTREE_REL)"
	)"
	then
	    set +x
	    echo "\
	ERROR: Docker bind mount paths didn't exist, force added ignore files.
	       Review ignores above in case they need changes or followup."
	    git status
	    false
	fi

.PHONY: test-push
## Verify commits before pushing to the remote.
test-push: ./var/log/git-fetch.log ./.tox/build/.tox-info.json
	vcs_compare_rev="$(VCS_COMPARE_REMOTE)/$(VCS_COMPARE_BRANCH)"
ifeq ($(CI),true)
ifeq ($(VCS_COMPARE_BRANCH),main)
# On `main`, compare with the preceding commit on `main`:
	vcs_compare_rev="$(VCS_COMPARE_REMOTE)/$(VCS_COMPARE_BRANCH)^"
endif
endif
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
	WORKTREE_REL="/worktrees/$${worktree_branch}"
	if git worktree list --porcelain |
	    grep -E "^worktree .+/project-structure$${WORKTREE_REL}\$$"
	then
	    git worktree remove ".$${WORKTREE_REL}"
	fi
	git worktree add -B "$${worktree_branch}" ".$${WORKTREE_REL}"


### Release Targets:
#
# Recipes that make an changes needed for releases and publish built artifacts to
# end-users.

.PHONY: release
## Publish installable packages if conventional commits require a release.
release: release-pkgs release-docker

.PHONY: release-pkgs
## Publish installable packages if conventional commits require a release.
release-pkgs: ./var/log/build-pkgs.log ./var/log/docker-compose-network.log \
		./var/log/git-fetch.log $(HOST_PREFIX)/bin/gh
	$(MAKE) test-clean
# Don't release unless from the `main` or `develop` branches:
ifeq ($(RELEASE_PUBLISH),true)
# Import the private signing key from CI secrets
	$(MAKE) "./var/log/gpg-import.log"
	true "TEMPLATE: Always specific to the project type"
	export VERSION=$$(tox exec -e "build" -qq -- cz version --project)
# Create a GitLab release
	release_cli_args="--description ./docs/news-version.rst"
	release_cli_args+=" --tag-name v$${VERSION}"
	release_cli_args+=" --assets-link {\
	\"name\":\"Docker-Hub-Container-Registry\",\
	\"url\":\"https://hub.docker.com/r/$(DOCKER_USER)/$(CI_PROJECT_NAME)/tags\",\
	\"link_type\":\"image\"\
	}"
	docker compose pull gitlab-release-cli
	docker compose run --rm gitlab-release-cli release-cli \
	    --server-url "$(CI_SERVER_URL)" --project-id "$(CI_PROJECT_ID)" \
	    create $${release_cli_args}
# Create a GitHub release
	gh release create "v$${VERSION}" $(GITHUB_RELEASE_ARGS) \
	    --notes-file "./docs/news-version.rst" ./dist/project?structure-*
endif

.PHONY: release-docker
## Publish all container images to all container registries.
release-docker: $(DOCKER_VARIANTS:%=release-docker-%) release-docker-readme
	$(MAKE) test-clean
.PHONY: $(DOCKER_VARIANTS:%=release-docker-%)
define release_docker_template=
release-docker-$(1): ./var-docker/$(1)/log/build-devel.log \
		./var-docker/$(1)/log/build-user.log \
		$$(DOCKER_REGISTRIES:%=./var/log/docker-login-%.log) \
		./.tox/build/.tox-info.json \
		$$(HOME)/.local/state/docker-multi-platform/log/host-install.log
	export DOCKER_VARIANT="$$(@:release-docker-%=%)"
# Build other platforms in emulation and rely on the layer cache for bundling the
# native images built before into the manifests:
	export DOCKER_BUILD_ARGS="--push"
	if test "$$(DOCKER_PLATFORMS)" != ""
	then
	    DOCKER_BUILD_ARGS+=" --platform \
	$$(subst $$(EMPTY) ,$$(COMMA),$$(DOCKER_PLATFORMS))"
	fi
# Push the development manifest and images:
	$$(MAKE) DOCKER_BUILD_TARGET="devel" build-docker-build
# Push the end-user manifest and images:
	$$(MAKE) build-docker-build
endef
$(foreach variant,$(DOCKER_VARIANTS),$(eval $(call release_docker_template,$(variant))))
.PHONY: release-docker-readme
## Update Docker Hub `README.md` by using the `./README.rst` reStructuredText version.
release-docker-readme: ./var/log/docker-compose-network.log
# Only for final releases:
ifeq ($(VCS_BRANCH),main)
ifeq ($(DOCKER_VARIANT),$(DOCKER_DEFAULT))
	$(MAKE) "./var/log/docker-login-DOCKER.log"
	docker compose up docker-pushrm
endif
endif

.PHONY: release-bump
## Bump the package version if conventional commits require a release.
release-bump: ./var/log/git-fetch.log ./.tox/build/.tox-info.json \
		./var/log/npm-install.log ./var/log/git-remotes.log
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
ifeq ($(RELEASE_PUBLISH),true)
	cz_bump_args+=" --gpg-sign"
# Import the private signing key from CI secrets
	$(MAKE) ./var/log/gpg-import.log
endif
# Capture the release notes for *only this* release for creating the GitHub release.
# Have to run before the real `$ towncrier build` run without the `--draft` option
# because it deletes the `newsfragments`.
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
ifeq ($(CI),true)
	git push --no-verify "$(VCS_COMPARE_REMOTE)" "HEAD:develop"
endif
	git switch -C "$(VCS_BRANCH)" "$$(git rev-parse HEAD)"
endif
ifneq ($(GITHUB_ACTIONS),true)
ifneq ($(PROJECT_GITHUB_PAT),)
# Make the tag available for creating the following GitHub release but push to GitHub
# *before* pushing to GitLab to avoid a race with repository mirroring:
	git push --no-verify "github" tag "v$${next_version}"
endif
endif
ifeq ($(CI),true)
# Push only this tag to avoid clashes with any preceding failed release:
	git push --no-verify "$(VCS_REMOTE)" tag "v$${next_version}"
# Also push the branch:
	git push --no-verify "$(VCS_REMOTE)" "HEAD:$(VCS_BRANCH)"
endif
	$(MAKE) test-clean

.PHONY: release-all
## Run the whole release process, end to end.
release-all: ./var/log/git-fetch.log
# Done as separate sub-makes in the recipe, as opposed to prerequisites, to support
# running as much of the process as possible with `$ make -j`:
ifeq ($(DOCKER_VARIANT),$(DOCKER_DEFAULT))
	$(MAKE) test-push test
else
	$(MAKE) test-docker test-lint-code
endif
ifeq ($(GITLAB_CI),true)
	$(MAKE) release-docker
endif
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
	    ':!requirements/*/*.txt' ':!apt/*-lock.txt' |
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
	    $(DOCKER_COMPOSE_RUN_CMD) "reuse" annotate --skip-unrecognised \
	        --copyright "Ross Patterson <me@rpatterson.net>" --license "MIT"
# Run source code formatting tools implemented in JavaScript:
	~/.nvm/nvm-exec npm run format

.PHONY: devel-upgrade
## Update requirements, dependencies, and other external versions tracked in VCS.
devel-upgrade:
	touch ./requirements/*.txt.in ./apt/*-lock.txt "./.env.in.~prereq~" "./.vale.ini" ./styles/*.ini
	$(MAKE) PIP_COMPILE_ARGS="--upgrade" DOCKER_COMPOSE_UPGRADE=true \
	    "./requirements/$(PYTHON_HOST_ENV)/build.txt" devel-upgrade-pre-commit \
	    devel-upgrade-js "./.env.~out~" devel-upgrade-apt \
	    "./var/log/vale-rule-levels.log"
.PHONY: devel-upgrade-pre-commit
## Update VCS integration from remotes to the most recent tag.
devel-upgrade-pre-commit: ./.tox/build/.tox-info.json
	tox exec -e "build" -- pre-commit autoupdate
.PHONY: devel-upgrade-js
## Update tools implemented in JavaScript.
devel-upgrade-js: ./var/log/npm-install.log
	~/.nvm/nvm-exec npm update
	~/.nvm/nvm-exec npm outdated
.PHONY: devel-upgrade-compose
## Update the container images of development tools.
devel-upgrade-compose: $(HOST_TARGET_DOCKER)
	touch "./.env.in.~prereq~"
	$(MAKE) DOCKER_COMPOSE_UPGRADE=true "./.env.~out~"
.PHONY: devel-upgrade-apt
## Update the versions of APT packages installed into the container image:
devel-upgrade-apt: $(APT_LOCK_FILES)

.PHONY: devel-upgrade-branch
## Reset an upgrade branch, commit upgraded dependencies on it, and push for review.
devel-upgrade-branch: ./var/log/git-fetch.log test-clean ./var/log/gpg-import.log \
		./var/log/git-remotes.log
	remote_branch_exists=false
	if git fetch "$(VCS_REMOTE)" "$(VCS_BRANCH)-upgrade"
	then
	    remote_branch_exists=true
	fi
	now=$$(date -u)
	$(MAKE) DOCKER_BUILD_PULL="true" TEMPLATE_IGNORE_EXISTING="true" devel-upgrade
	if $(MAKE) "test-clean"
	then
# No changes from upgrade, exit signaling success but push nothing:
	    exit
	fi
# Only add changes related to the upgrades:
	git add --update '.env.in' './requirements/*/*.txt' './apt/*-lock.txt' \
	    "./.pre-commit-config.yaml" "./package-lock.json" "./.vale.ini"
	git add "./styles/"
# Commit the upgrade changes
	echo ":Upgrade: Upgrade all requirements to the most recent versions as of" \
	    >"./newsfragments/+upgrade-requirements.bugfix.rst"
	echo "          $${now}." >>"./newsfragments/+upgrade-requirements.bugfix.rst"
	git add "./newsfragments/+upgrade-requirements.bugfix.rst"
	git_commit_args="--all --gpg-sign"
	git commit $${git_commit_args} -m \
	    "fix(deps): Upgrade to most recent versions"
# Create or reset the feature branch for merge or pull requests:
	git switch -C "$(VCS_BRANCH)-upgrade"
# Fail if upgrading left un-tracked files in VCS:
	$(MAKE) "test-clean"
ifeq ($(CI),true)
# Push any upgrades to the remote for review. Specify both the ref and the expected ref
# for `--force-with-lease=` to support pushing to more than one mirror or remote by
# using more than one `pushUrl`:
	git_push_args="--no-verify"
	if test "$${remote_branch_exists=true}" = "true"
	then
	    git_push_args+=" --force-with-lease=\
	$(VCS_BRANCH)-upgrade:$(VCS_REMOTE)/$(VCS_BRANCH)-upgrade"
	fi
	git push $${git_push_args} "$(VCS_REMOTE)" "HEAD:$(VCS_BRANCH)-upgrade"
endif

.PHONY: devel-merge
## Merge this branch with a suffix back into its un-suffixed upstream.
devel-merge: ./var/log/git-remotes.log ./var/log/git-fetch.log
	merge_rev="$$(git rev-parse HEAD)"
	git fetch "$(VCS_REMOTE)" "$(VCS_MERGE_BRANCH)"
	git switch -C "$(VCS_MERGE_BRANCH)" --track "$(VCS_REMOTE)/$(VCS_MERGE_BRANCH)"
	git merge --ff --gpg-sign -m \
	    $$'Merge branch \'$(VCS_BRANCH)\' into $(VCS_MERGE_BRANCH)\n\n[ci merge]' \
	    "$${merge_rev}"
ifeq ($(CI),true)
	git push --no-verify "$(VCS_REMOTE)" "HEAD:$(VCS_MERGE_BRANCH)"
endif


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
	git clean -dfx -e "/var" -e "/.env" -e "*~" -e "/var-docker"
	git clean -dfx './var/log/*' './var-docker/*/log/*' "./var-docker/*/.tox/*" \
	    "./var-docker/*/project_structure.egg-info/*"


### Real Targets:
#
# Recipes that make actual changes and create and update files for the target.

# TEMPLATE: Add any other prerequisites that are likely to require updating the build
# package.
./var/log/build-pkgs.log: ./var-host/log/make-runs/$(MAKE_RUN_UUID).log \
		 ./var/log/docker-compose-network.log \
		./var-docker/$(DOCKER_VARIANT)/log/build-devel.log
	mkdir -pv "$(dir $(@))"
	$(DOCKER_COMPOSE_RUN_CMD) $(PROJECT_NAME)-devel \
	    echo "TEMPLATE: Always specific to the project type" | tee -a "$(@)"

# Lock installed operating system package versions for reproducible image builds:
define devel_upgrade_apt_template=
$(1): ./var-docker/$(DOCKER_DEFAULT)/log/build-$(1:./apt/%-lock.txt=%).log
	docker run --rm --entrypoint "dpkg-query" \
	    $$(DOCKER_IMAGE):$(1:./apt/%-lock.txt=%)-$$(DOCKER_DEFAULT_TAG) \
	    -f='$$$${binary:Package}=$$$${Version}\n' -W >"$$(@)"
endef
$(foreach lock_file,$(APT_LOCK_FILES),\
    $(eval $(call devel_upgrade_apt_template,$(lock_file))))

# Build Docker container images:
# Build the base layer common to both published images:
define build_docker_base_template=
./var-docker/$(1)/log/build-base.log: \
		./Dockerfile ./container/usr/local/bin/entrypoint.sh \
		./.tox/build/.tox-info.json \
		$$(HOME)/.local/state/docker-multi-platform/log/host-install.log \
		./var/log/docker-login-DOCKER.log
	true DEBUG Updated prereqs: $$(?)
	mkdir -pv "$$(dir $$(@))"
	$$(MAKE) DOCKER_VARIANT="$(1)" DOCKER_BUILD_TARGET="base" \
	    build-docker-build | tee -a "$$(@)"
endef
$(foreach variant,$(DOCKER_VARIANTS),\
    $(eval $(call build_docker_base_template,$(variant))))
# Build the development image:
define build_docker_devel_template=
./var-docker/$(1)/log/build-devel.log: ./Dockerfile \
		./var-docker/$(1)/log/build-base.log \
		./.tox/build/.tox-info.json \
		$$(HOME)/.local/state/docker-multi-platform/log/host-install.log \
		./var/log/docker-login-DOCKER.log
	true DEBUG Updated prereqs: $$(?)
	mkdir -pv "$$(dir $$(@))"
	$$(MAKE) DOCKER_VARIANT="$(1)" DOCKER_BUILD_TARGET="devel" \
	    build-docker-build | tee -a "$$(@)"
endef
$(foreach variant,$(DOCKER_VARIANTS),\
    $(eval $(call build_docker_devel_template,$(variant))))
# Build the user image:
define build_docker_user_template=
./var-docker/$(1)/log/build-user.log: ./Dockerfile \
		./var-docker/$(1)/log/build-base.log \
		./.tox/build/.tox-info.json \
		$$(HOME)/.local/state/docker-multi-platform/log/host-install.log \
		./var/log/docker-login-DOCKER.log ./var/log/build-pkgs.log
	true DEBUG Updated prereqs: $$(?)
	mkdir -pv "$$(dir $$(@))"
	$$(MAKE) DOCKER_VARIANT="$(1)" DOCKER_BUILD_TARGET="user" \
	    build-docker-build | tee -a "$$(@)"
endef
$(foreach variant,$(DOCKER_VARIANTS),\
    $(eval $(call build_docker_user_template,$(variant))))
# https://docs.docker.com/build/building/multi-platform/#building-multi-platform-images
$(HOME)/.local/state/docker-multi-platform/log/host-install.log:
	$(MAKE) "$(HOST_TARGET_DOCKER)"
	mkdir -pv "$(dir $(@))"
	if ! docker context inspect "multi-platform" |& tee -a "$(@)"
	then
	    docker context create "multi-platform" |& tee -a "$(@)"
	fi
	if ! docker buildx inspect |& tee -a "$(@)" |
	    grep -q '^ *Endpoint: *multi-platform *'
	then
	    (
	        docker buildx create --use "multi-platform" --bootstrap
	        2>"/dev/null" || true
	    ) | tee -a "$(@)"
	fi
./var/log/docker-login-DOCKER.log: ./.env.~out~
	$(MAKE) "$(HOST_TARGET_DOCKER)"
	mkdir -pv "$(dir $(@))"
	if test -n "$${DOCKER_PASS}"
	then
	    printenv "DOCKER_PASS" | docker login -u "$(DOCKER_USER)" --password-stdin
	elif test "$(CI_IS_FORK)" != "true"
	then
	    echo "ERROR: DOCKER_PASS missing from ./.env or CI secrets"
	    false
	fi
	date | tee -a "$(@)"
# TEMPLATE: Add a cleanup rule for the GitLab container registry under the project
# settings.
./var/log/docker-login-GITLAB.log: ./.env.~out~
	$(MAKE) "$(HOST_TARGET_DOCKER)"
	mkdir -pv "$(dir $(@))"
	if test -n "$${CI_REGISTRY_PASSWORD}"
	then
	    printenv "CI_REGISTRY_PASSWORD" |
	        docker login -u "$(CI_REGISTRY_USER)" --password-stdin "$(CI_REGISTRY)"
	elif test "$(CI_IS_FORK)" != "true"
	then
	    echo "ERROR: CI_REGISTRY_PASSWORD missing from ./.env or CI secrets"
	    false
	fi
	date | tee -a "$(@)"
# TEMPLATE: Connect the GitHub container registry to the repository by using the
# `Connect` button at the bottom of the container registry's web UI.
./var/log/docker-login-GITHUB.log: ./.env.~out~
	$(MAKE) "$(HOST_TARGET_DOCKER)"
	mkdir -pv "$(dir $(@))"
	if test -n "$${PROJECT_GITHUB_PAT}"
	then
	    printenv "PROJECT_GITHUB_PAT" |
	        docker login -u "$(GITHUB_REPOSITORY_OWNER)" --password-stdin "ghcr.io"
	elif test "$(CI_IS_FORK)" != "true"
	then
	    echo "ERROR: PROJECT_GITHUB_PAT missing from ./.env or CI secrets"
	    false
	fi
	date | tee -a "$(@)"

# Perform any initial setup needed by more than one container, such as the network and
# shared volumes:
./var/log/docker-compose-network.log: ./home/.bash_history
	$(MAKE) "$(HOST_TARGET_DOCKER)" "./.env.~out~"
	mkdir -pv "$(dir $(@))"
# Workaround broken interactive session detection:
	docker compose pull --quiet "vale"
# Create the Docker compose network a single time under parallel make:
	$(DOCKER_COMPOSE_RUN_CMD) --entrypoint "date" vale | tee -a "$(@)"
# Create any mount points for bind volumes that `# dockerd` shouldn't or can't create,
# such as directory bind volumes that root shouldn't own by or file bind volumes that `#
# dockerd` shouldn't create as directories:
./home/.bash_history:
	touch "$(@)"

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

./README.md: README.rst ./var/log/docker-compose-network.log
	$(MAKE) "$(HOST_TARGET_DOCKER)"
	$(DOCKER_COMPOSE_RUN_CMD) "pandoc"


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
# Initialize minimal VCS configuration, useful in automation such as CI:
./var/log/git-remotes.log: ./.env.~out~
	mkdir -pv "$(dir $(@))"
	set +x
ifneq ($(VCS_REMOTE_PUSH_URL),)
	if ! git remote get-url --push --all "origin" |
	    grep -q -F "$(VCS_REMOTE_PUSH_URL)"
	then
	    echo "INFO:Adding push url for remote 'origin'"
	    git remote set-url --push --add "origin" "$(VCS_REMOTE_PUSH_URL)" |
	        tee -a "$(@)"
	fi
endif
ifneq ($(GITHUB_ACTIONS),true)
ifneq ($(PROJECT_GITHUB_PAT),)
# Also add a fetch remote for the `$ gh` command-line tool to detect:
	if ! git remote get-url "github" >"/dev/null"
	then
	    echo "INFO:Adding remote 'github'"
	    git remote add "github" \
	        "https://$(PROJECT_GITHUB_PAT)@github.com/$(CI_PROJECT_PATH).git" |
	        tee -a "$(@)"
	fi
else ifneq ($(CI_IS_FORK),true)
	set +x
	echo "ERROR: PROJECT_GITHUB_PAT missing from ./.env or CI secrets"
	false
endif
endif
	set -x
# Fail fast if there's still no push access:
	git push --no-verify "origin" "HEAD:$(VCS_BRANCH)" | tee -a "$(@)"

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
	$(DOCKER_COMPOSE_RUN_CMD) vale sync
	$(DOCKER_COMPOSE_RUN_CMD) vale sync --config="./styles/code.ini"

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

# Install the code test coverage publishing tool:
$(HOME)/.local/bin/codecov: \
		./build-host/container/usr/local/bin/install-codecov.sh \
		$(HOST_PREFIX)/bin/curl
	"$(<)"
$(HOST_PREFIX)/bin/curl:
	$(MAKE) "$(STATE_DIR)/log/host-update.log"
	$(HOST_PKG_CMD) $(HOST_PKG_INSTALL_ARGS) "$(HOST_PKG_NAMES_CURL)"

# GNU Privacy Guard (GPG) signing key creation and management in CI:
export GPG_PASSPHRASE?=
GPG_SIGNING_PRIVATE_KEY?=
./var/ci-cd-signing-subkey.asc: $(HOST_PREFIX)/bin/gpg
# Signing release commits and artifacts requires a GPG private key in the CI/CD
# environment. Use a subkey that you can revoke without affecting your main key. This
# recipe captures what I had to do to export a private signing subkey. It's not widely
# tested so you should probably only use this for reference. It worked for me but this
# process risks leaking your main private key so confirm all your assumptions and
# results well.
#
# 1. Create a signing subkey with a *new*, *separate* passphrase:
#    https://wiki.debian.org/Subkeys#How.3F
# 2. Get the long key ID for that private subkey:
#	gpg --list-secret-keys --keyid-format "long"
# 3. Export *only* that private subkey and verify that the main secret key packet is the
#    GPG dummy packet and that the only other private key included is the intended
#    subkey:
#	gpg --armor --export-secret-subkeys "$(GPG_SIGNING_KEYID)!" |
#	    gpg --list-packets
# 4. Export that key as text to a file:
	gpg --armor --export-secret-subkeys "$(GPG_SIGNING_KEYID)!" >"$(@)"
# 5. Confirm that a temporary GNU PG directory can import the exported key and that it
#    can sign files:
#	gnupg_homedir=$$(mktemp -d --suffix=".d" "gnupd.XXXXXXXXXX")
#	printenv 'GPG_PASSPHRASE' >"$${gnupg_homedir}/.passphrase"
#	gpg --homedir "$${gnupg_homedir}" --batch --import <"$(@)"
#	echo "Test signature content" >"$${gnupg_homedir}/test-sig.txt"
#	gpgconf --kill gpg-agent
#	gpg --homedir "$${gnupg_homedir}" --batch --pinentry-mode "loopback" \
#	    --passphrase-file "$${gnupg_homedir}/.passphrase" \
#	    --local-user "$(GPG_SIGNING_KEYID)!" --sign "$${gnupg_homedir}/test-sig.txt"
#	gpg --batch --verify "$${gnupg_homedir}/test-sig.txt.gpg"
# 6. Add the contents of this target as a `GPG_SIGNING_PRIVATE_KEY` secret in CI and the
# passphrase for the signing subkey as a `GPG_PASSPHRASE` secret in CI
./var/log/gpg-import.log: $(HOST_PREFIX)/bin/gpg ./.env.~out~
# In each CI run, import the private signing key from the CI secrets
	mkdir -pv "$(dir $(@))"
ifneq ($(and $(GPG_SIGNING_PRIVATE_KEY),$(GPG_PASSPHRASE)),)
	printenv "GPG_SIGNING_PRIVATE_KEY" | gpg --batch --import | tee -a "$(@)"
	echo 'default-key:0:"$(GPG_SIGNING_KEYID)' | gpgconf --change-options gpg
	git config --global user.signingkey "$(GPG_SIGNING_KEYID)"
# "Unlock" the signing key for the rest of this CI run:
	printenv 'GPG_PASSPHRASE' >"./var/ci-cd-signing-subkey.passphrase"
	true | gpg --batch --pinentry-mode "loopback" \
	    --passphrase-file "./var/ci-cd-signing-subkey.passphrase" \
	    --sign | gpg --list-packets
else
ifneq ($(CI_IS_FORK),true)
	set +x
	echo "ERROR: GPG_SIGNING_PRIVATE_KEY or GPG_PASSPHRASE " \
	    "missing from ./.env or CI secrets"
	false
endif
	date | tee -a "$(@)"
endif
$(HOST_PREFIX)/bin/gpg:
	$(MAKE) "$(STATE_DIR)/log/host-update.log"
	$(HOST_PKG_CMD) $(HOST_PKG_INSTALL_ARGS) "$(HOST_PKG_NAMES_GPG)"

$(HOST_PREFIX)/bin/gh:
	$(MAKE) "$(STATE_DIR)/log/host-update.log"
	$(HOST_PKG_CMD) $(HOST_PKG_INSTALL_ARGS) "$(HOST_PKG_NAMES_GHCLI)"

# TEMPLATE: Optionally, use the following command to generate a GitLab CI/CD runner
# configuration, register it with your project, compare it with the template
# prerequisite, apply the appropriate changes and then run by using `$ docker compose up
# gitlab-runner`. Useful to conserve shared runner minutes:
./var/gitlab-runner/config/config.toml: ./gitlab-runner/config/config.toml.in
	docker compose run --rm gitlab-runner register \
	    --url "https://gitlab.com/" --docker-image "docker" --executor "docker"


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
if test "$(CI)" != "true"
then
    envsubst <"$(1)" | diff --color -u "$(2:%.~out~=%)" "-" || true
fi
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

.PHONY: pull-docker
## Pull an existing image best to use as a cache for building new images
pull-docker: ./var/log/git-fetch.log $(HOST_TARGET_DOCKER)
	export VERSION=$$(tox exec -e "build" -qq -- cz version --project)
	tag_prefix="$(DOCKER_PULL_TARGET)-$(DOCKER_VARIANT)"
	for vcs_branch in $(VCS_BRANCHES)
	do
	    for docker_image in $(DOCKER_IMAGES)
	    do
	        if docker pull "$(DOCKER_IMAGE):$${tag_prefix}-$${vcs_branch}"
	        then
	            exit
	        fi
	    done
	done
	set +x
	echo "ERROR: Could not pull any existing docker image"
	false

# TEMPLATE: Only necessary if you customize the `./build-host/` image.  Different
# projects can use the same image, even across individuals and organizations.  If you do
# need to customize the image, then run this every time the image changes. See the
# `./var/log/docker-login*.log` targets for the authentication environment variables to
# set or login to those container registries manually and `$ touch` these targets.
.PHONY: bootstrap-project
bootstrap-project: ./var/log/docker-login-GITLAB.log ./var/log/docker-login-GITHUB.log
# Initially seed the build host Docker image to bootstrap CI/CD environments
	$(MAKE) -C "./build-host/" release
