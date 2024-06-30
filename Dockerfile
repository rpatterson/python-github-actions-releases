# SPDX-FileCopyrightText: 2023 Ross Patterson <me@rpatterson.net>
#
# SPDX-License-Identifier: MIT

# See the note at the bottom about the "Optimal ordering of instructions".


## Image layers shared between all variants.

# Stay as close to an un-customized environment as possible:
ARG PYTHON_MINOR=3.12
ARG DOCKER_BASE_DIGEST=":${PYTHON_MINOR}"
# hadolint ignore=DL3006
FROM python${DOCKER_BASE_DIGEST} AS base
# Defensive shell options:
SHELL ["/bin/bash", "-eu", "-o", "pipefail", "-c"]

# Install operating system packages needed for the image `ENDPOINT`. This is the layer
# in `base` with the longest build time:
RUN \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' \
    >"/etc/apt/apt.conf.d/keep-cache"
COPY [ "./apt/base-lock.txt", "/etc/apt/" ]
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && xargs -t -- \
    apt-get install --no-install-recommends -y <"/etc/apt/base-lock.txt" && \
    rm -v "/etc/apt/base-lock.txt"

# Constant layers, those without variable substitution, where changes don't invalidate
# later build caches:

# Image metadata:
# https://github.com/opencontainers/image-spec/blob/main/annotations.md#pre-defined-annotation-keys
LABEL org.opencontainers.image.title="Project Structure"
LABEL org.opencontainers.image.description="Project structure foundation or template"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.authors="Ross Patterson <me@rpatterson.net>"
LABEL org.opencontainers.image.vendor="rpatterson.net"
ARG PYTHON_MINOR=3.12
LABEL org.opencontainers.image.base.name="docker.io/library/python:${PYTHON_MINOR}"

# Python-specific environment:
ENTRYPOINT [ "entrypoint.sh" ]
CMD [ "python" ]
HEALTHCHECK CMD \
    healthcheck.sh || exit 1


## Container image for use by end users.

# Stay as close to an un-customized environment as possible:
FROM base AS user

# Avoid long re-build times, longest running layers first:

# Install dependencies with fixed versions in a separate layer to optimize build times
# because this step takes the most time and changes the least often:
# Activate the Python virtual environment:
ARG PYTHON_ENV=py312
COPY [ "./requirements/${PYTHON_ENV}/user.txt", "./requirements.txt" ]
ENV VIRTUAL_ENV="/opt/${PROJECT_NAMESPACE}/${PROJECT_NAME}"
WORKDIR "${VIRTUAL_ENV}"
# hadolint ignore=DL3042,SC1091
RUN --mount=type=cache,target=/root/.cache,sharing=locked \
    python3 -m "venv" "./" && \
    source "./bin/activate" && \
    pip3 install --no-deps -r "./requirements.txt" && \
    rm -v "./requirements.txt"

# Install this package in the most common/standard Python way while still being able to
# build the image locally.
ARG PYTHON_WHEEL
COPY [ "${PYTHON_WHEEL}", "${PYTHON_WHEEL}" ]
# hadolint ignore=DL3013,DL3042,SC1091
RUN --mount=type=cache,target=/root/.cache,sharing=locked \
    source "./bin/activate" && \
    pip3 install "${PYTHON_WHEEL}" && \
    rm -rv "./dist/"
WORKDIR "${HOME}"

# Put the `ENTRYPOINT` on the `$PATH`
COPY --link [ "./container/", "/" ]

# Constants that create new build layers:
ARG PROJECT_NAMESPACE=rpatterson
ARG PROJECT_NAME=project-structure
ARG VERSION=

# Image metadata:
LABEL org.opencontainers.image.url="https://gitlab.com/${PROJECT_NAMESPACE}/${PROJECT_NAME}"
LABEL org.opencontainers.image.documentation="https://gitlab.com/${PROJECT_NAMESPACE}/${PROJECT_NAME}"
LABEL org.opencontainers.image.source="https://gitlab.com/${PROJECT_NAMESPACE}/${PROJECT_NAME}"
LABEL org.opencontainers.image.version=${VERSION}

# Container runtime environment:
ENV PROJECT_NAMESPACE="${PROJECT_NAMESPACE}"
ENV PROJECT_NAME="${PROJECT_NAME}"
# Find the same home directory even when run as another user, for example `root`.
ENV HOME="/home/${PROJECT_NAME}"
ENV VIRTUAL_ENV="/opt/${PROJECT_NAMESPACE}/${PROJECT_NAME}"
ENV PATH="${VIRTUAL_ENV}/bin:${HOME}/.local/bin:${PATH}"
# Python-specific environment:
ENV PYTHON_MINOR="${PYTHON_MINOR}"
WORKDIR "${HOME}"


## Container image for use by developers.

# Stay as close to the user image as possible:
FROM base AS devel

# Install operating system packages required to build the documentation:
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get install --no-install-recommends -y \
    "texinfo=6.8-6+b1" "texlive-full=2022.20230122-3" "latexmk=1:4.79-1" \
    "ghostscript=10.0.0~dfsg-11+deb12u4" "inkscape=1.2.2-2+b1" "pipx=1.1.0-1"

# Bake in tools used in the inner loop of the development cycle:
# Install tox in the unprivileged user's `${HOME}`:
ENV PIPX_HOME="/${HOME}/.local/pipx"
# hadolint ignore=DL3042
RUN --mount=type=cache,target=/root/.cache,sharing=locked \
    pipx install "tox==4.11.3"

# Put the `ENTRYPOINT` on the `$PATH`
COPY --link [ "./container/", "/" ]

# Constants that create new build layers:
ARG PROJECT_NAMESPACE=rpatterson
ARG PROJECT_NAME=project-structure
ARG VERSION=

# Image metadata:
LABEL org.opencontainers.image.title="Project Structure Development"
LABEL org.opencontainers.image.description="Project structure foundation or template, development image"
LABEL org.opencontainers.image.url="https://gitlab.com/${PROJECT_NAMESPACE}/${PROJECT_NAME}"
LABEL org.opencontainers.image.documentation="https://gitlab.com/${PROJECT_NAMESPACE}/${PROJECT_NAME}"
LABEL org.opencontainers.image.source="https://gitlab.com/${PROJECT_NAMESPACE}/${PROJECT_NAME}"
LABEL org.opencontainers.image.version=${VERSION}

# Container runtime environment:
ENV PROJECT_NAMESPACE="${PROJECT_NAMESPACE}"
ENV PROJECT_NAME="${PROJECT_NAME}"
# Find the same home directory even when run as another user, for example `root`.
ENV HOME="/home/${PROJECT_NAME}"
# Activate the Python virtual environment:
ARG PYTHON_ENV=py312
ENV VIRTUAL_ENV="/usr/local/src/${PROJECT_NAME}/.tox/${PYTHON_ENV}"
ENV PATH="${VIRTUAL_ENV}/bin:${HOME}/.local/bin:${PATH}"
# Set any environment variables used as options in the `./Makefile`:
ENV PYTHON_MINORS="${PYTHON_MINOR}"
# Remain in the checkout `WORKDIR` and make the build tools the default
# command to run.
WORKDIR "/usr/local/src/${PROJECT_NAME}/"
# Have to use the shell form of `CMD` because it needs variable substitution:
# hadolint ignore=DL3025
CMD tox -e "${PYTHON_ENV}"


## Optimal ordering of instructions:
#
# A `./Dockerfile` serves two purposes. It expresses the parts shared between more than
# one image. It also expresses how to avoid unnecessary image build time. These two
# purposes can conflict.
#
# Some instructions can both affect building the image *and* affect the container at
# runtime, for example `ENV` and `WORKDIR`. The shared `base` image target should place
# higher in the file such instructions that are the same for both the end-user and
# developer images. But that means that any changes to those shared instructions
# invalidate the build cache of later layers, including the layer that installs
# development packages in the developer image. That's the layer with the longest build
# times in most projects.
#
# Minimizing built times is important given that updating the images is often necessary
# in the inner loop of the development cycle.  Unnecessary build time there compounds
# into significant lost developer time. It also hurts developers in less quantifiable
# ways, for example frustration, distraction, and so on, that sap focus, creativity and
# productivity. Given that, minimizing build times is more important than avoiding
# repetition.
#
# To that end, the developer image should place at the bottom of layers all cheap,
# short-running instructions where changes invalidate the build layer cache if at all
# possible. If the end-user image should also include those instructions, this means
# repeating them at the bottom of the end-user image layers. Testing confirms these
# instructions invalidate the build cache for later layers:
#
# - `FROM`
# - `SHELL`
# - `RUN`
# - `ARG`
# - `ENV`
# - `WORKDIR`
# - `COPY`
#
# And confirms these instructions do *not* invalidate the build cache:
#
# - `LABEL`
# - `ENTRYPOINT`
# - `CMD`
# - `HEALTHCHECK`
