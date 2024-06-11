# SPDX-FileCopyrightText: 2023 Ross Patterson <me@rpatterson.net>
#
# SPDX-License-Identifier: MIT


## Image layers shared between all variants.

# Stay as close to an un-customized environment as possible:
ARG PYTHON_MINOR=3.12
FROM python:${PYTHON_MINOR} AS base
# Defensive shell options:
SHELL ["/bin/bash", "-eu", "-o", "pipefail", "-c"]

# Project constants:
ARG PROJECT_NAMESPACE=rpatterson
ARG PROJECT_NAME=project-structure
# Image variant constants:
ARG PYTHON_MINOR=3.12

# Least volatile layers first:
# https://github.com/opencontainers/image-spec/blob/main/annotations.md#pre-defined-annotation-keys
LABEL org.opencontainers.image.url="https://gitlab.com/${PROJECT_NAMESPACE}/${PROJECT_NAME}"
LABEL org.opencontainers.image.documentation="https://gitlab.com/${PROJECT_NAMESPACE}/${PROJECT_NAME}"
LABEL org.opencontainers.image.source="https://gitlab.com/${PROJECT_NAMESPACE}/${PROJECT_NAME}"
LABEL org.opencontainers.image.title="Project Structure"
LABEL org.opencontainers.image.description="Project structure foundation or template"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.authors="Ross Patterson <me@rpatterson.net>"
LABEL org.opencontainers.image.vendor="rpatterson.net"
LABEL org.opencontainers.image.base.name="docker.io/library/python:${PYTHON_MINOR}"

ENV PROJECT_NAMESPACE="${PROJECT_NAMESPACE}"
ENV PROJECT_NAME="${PROJECT_NAME}"
# Find the same home directory even when run as another user, for example `root`.
ENV HOME="/home/${PROJECT_NAME}"
# Python-specific environment:
ENV PYTHON_MINOR="${PYTHON_MINOR}"
ENV VIRTUAL_ENV="/opt/${PROJECT_NAMESPACE}/${PROJECT_NAME}"
ENV PATH="${VIRTUAL_ENV}/bin:${HOME}/.local/bin:${PATH}"
ENTRYPOINT [ "entrypoint.sh" ]
CMD [ "python" ]

# Put the `ENTRYPOINT` on the `$PATH`
COPY [ "./bin/entrypoint.sh", "/usr/local/bin/" ]

# Install operating system packages needed for the image `ENDPOINT`:
RUN \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' \
    >"/etc/apt/apt.conf.d/keep-cache"
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install --no-install-recommends -y "gosu=1.14-1+b6"

# Build-time labels:
ARG VERSION=
LABEL org.opencontainers.image.version=${VERSION}


## Container image for use by end users.

# Stay as close to an un-customized environment as possible:
FROM base AS user

# Install dependencies with fixed versions in a separate layer to optimize build times
# because this step takes the most time and changes the least often.
ARG PYTHON_ENV=py312
WORKDIR "${VIRTUAL_ENV}"
COPY [ "./requirements/${PYTHON_ENV}/user.txt", "./requirements.txt" ]
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


## Container image for use by developers.

# Stay as close to the user image as possible for build cache efficiency:
FROM base AS devel

# Least volatile layers first:
LABEL org.opencontainers.image.title="Project Structure Development"
LABEL org.opencontainers.image.description="Project structure foundation or template, development image"

# Activate the Python virtual environment
ENV VIRTUAL_ENV="/usr/local/src/${PROJECT_NAME}/.tox/${PYTHON_ENV}"
ENV PATH="${VIRTUAL_ENV}/bin:${PATH}"
# Install tox in the unprivileged user's `${HOME}`:
ENV PIPX_HOME="/${HOME}/.local/pipx"
# Set any environment variables used as options in the `./Makefile`:
ENV PYTHON_MINORS="${PYTHON_MINOR}"
# Remain in the checkout `WORKDIR` and make the build tools the default
# command to run:
WORKDIR "/usr/local/src/${PROJECT_NAME}/"
# Have to use the shell form of `CMD` because it needs variable substitution:
# hadolint ignore=DL3025
CMD tox -e "${PYTHON_ENV}"

# Install operating system packages required to build the documentation:
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get install --no-install-recommends -y \
    "texinfo=6.8-6+b1" "texlive-full=2022.20230122-3" "latexmk=1:4.79-1" \
    "ghostscript=10.0.0~dfsg-11+deb12u4" "inkscape=1.2.2-2+b1" "pipx=1.1.0-1"

# Bake in tools used in the inner loop of the development cycle:
# hadolint ignore=DL3042
RUN --mount=type=cache,target=/root/.cache,sharing=locked \
    pipx install "tox==4.11.3"
