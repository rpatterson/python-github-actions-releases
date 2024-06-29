# SPDX-FileCopyrightText: 2023 Ross Patterson <me@rpatterson.net>
#
# SPDX-License-Identifier: MIT

# See the note at the bottom about the "Optimal ordering of instructions".


## Image layers shared between all variants.

# Stay as close to an un-customized environment as possible:
ARG DOCKER_BASE_DIGEST=":stable"
# hadolint ignore=DL3006
FROM buildpack-deps${DOCKER_BASE_DIGEST} AS base
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
LABEL org.opencontainers.image.base.name="docker.io/library/buildpack-deps:stable"

# Container runtime environment:
ENTRYPOINT [ "entrypoint.sh" ]
CMD [ "bash" ]
HEALTHCHECK CMD \
    healthcheck.sh || exit 1


## Container image for use by end users.

# Stay as close to an un-customized environment as possible:
FROM base AS user

# TEMPLATE: Add image setup specific to the user image, often installable packages built
# from the project.

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
ENV PATH="${HOME}/.local/bin:${PATH}"
WORKDIR "${HOME}"


## Container image for use by developers.

# Stay as close to the user image as possible:
FROM base AS devel

# TEMPLATE: Add image setup specific to the development for this project type, often at
# least installing development tools.

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
ENV PATH="${HOME}/.local/bin:${PATH}"
# Remain in the checkout `WORKDIR` and make the build tools the default
# command to run.
WORKDIR "/usr/local/src/${PROJECT_NAME}/"


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
