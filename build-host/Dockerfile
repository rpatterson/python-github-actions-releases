# SPDX-FileCopyrightText: 2023 Ross Patterson <me@rpatterson.net>
#
# SPDX-License-Identifier: MIT

## Container image in which to build, test, and release projects.

FROM docker:cli

# Least volatile layers first:

# Project constants:
ARG PROJECT_NAMESPACE=rpatterson
ARG PROJECT_NAME=project-structure

# https://github.com/opencontainers/image-spec/blob/main/annotations.md#pre-defined-annotation-keys
LABEL org.opencontainers.image.url="https://gitlab.com/${PROJECT_NAMESPACE}/${PROJECT_NAME}"
LABEL org.opencontainers.image.documentation="https://gitlab.com/${PROJECT_NAMESPACE}/${PROJECT_NAME}/-/blob/develop/build-host/README.rst"
LABEL org.opencontainers.image.source="https://gitlab.com/${PROJECT_NAMESPACE}/${PROJECT_NAME}/-/blob/develop/build-host/Dockerfile"
LABEL org.opencontainers.image.title="Project Structure Build Host"
LABEL org.opencontainers.image.description="Container image in which to build, test, and release projects."
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.authors="Ross Patterson <me@rpatterson.net>"
LABEL org.opencontainers.image.vendor="rpatterson.net"
LABEL org.opencontainers.image.base.name="docker.io/library/docker:latest"
# Build-time labels:
LABEL org.opencontainers.image.version=1.0.0

ENV PROJECT_NAMESPACE="${PROJECT_NAMESPACE}"
ENV PROJECT_NAME="${PROJECT_NAME}"
# Find the same home directory even when run as another user, for example `root`:
ENV HOME="/home/runner"
ENV PATH="${HOME}/.local/bin:${PATH}"
# Render template targets without user input:
ENV TEMPLATE_IGNORE_EXISTING=true
# Prevent Node Version Manager (NVM) installing into `/bin/versions/**`:
ENV NVM_DIR="${HOME}/.nvm"
# Node.js releases compatible with Alpine Linux based on musl libc:
# https://github.com/nvm-sh/nvm/issues/1102#issuecomment-550572252
ENV NVM_NODEJS_ORG_MIRROR="https://unofficial-builds.nodejs.org/download/release"

ENTRYPOINT [ "docker-entrypoint.sh", "init-job.sh", "entrypoint.sh" ]
CMD [ "make", "-j", "release-all" ]

# More volatile layers and layers with longer build times last:

# Install the operating system packages needed to use the `./Makefile`.  Also install
# any operating system packages the `./Makefile` might install to optimize build times:
# hadolint ignore=DL3018
RUN --mount=type=cache,sharing=locked,target=/var/cache/apk \
    apk add \
    "shadow" \
    "coreutils" \
    "make" \
    "bash" \
    "su-exec" \
    "git" \
    "gettext" \
    "grep" \
    "pipx" \
    "gnupg" \
    "curl" \
    "imagemagick" \
    "librsvg" \
    "texlive-luatex" \
    "texmf-dist-binextra" \
    "texinfo" \
    "texmf-dist-latex" \
    "texmf-dist-lang" \
    "texmf-dist-latexrecommended" \
    "texmf-dist-fontsrecommended" \
    "texmf-dist-latexextra" \
    "github-cli" \
    && groupdel "docker" \
    && apk del "shadow"

# Bake external build dependencies into the image:
# hadolint ignore=DL3042,DL4006,SC1091
RUN --mount=type=cache,target=/root/.cache,sharing=locked \
    pipx install "tox==4.11.3" && \
    wget -qO- "https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh" | \
        bash && \
    echo 'nvm_get_arch() { nvm_echo x64-musl; }' >>"${HOME}/.nvm/nvm.sh" && \
	. "${HOME}/.nvm/nvm.sh" || true && \
    nvm install "20" && \
    mkdir -pv "${HOME}/.local/state/${PROJECT_NAME}/log/"

# Configure the VCS client for the image user:
ARG USER_SIGNINGKEY
RUN --mount=type=cache,target=/root/.cache,sharing=locked \
    git config -f "${HOME}/.gitconfig" "user.name" "CI Runner" && \
    git config -f "${HOME}/.gitconfig" "user.email" \
    "runner@build-host.${PROJECT_NAMESPACE:-rpatterson}.localhost" && \
    git config --global user.signingkey "${USER_SIGNINGKEY}"

COPY [ "./bin/init-job.sh",  "./bin/entrypoint.sh", "/usr/local/bin/" ]
