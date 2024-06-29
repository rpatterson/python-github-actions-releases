#!/bin/bash
#
# Shared set up for local testing of CI/CD

# SPDX-FileCopyrightText: 2023 Ross Patterson <me@rpatterson.net>
#
# SPDX-License-Identifier: MIT

set -eu -o pipefail
export PS4='+$(basename "${0}"):${LINENO}+'
if test "${DEBUG:=false}" = "true"
then
    # Echo commands for easier debugging
    set -x
fi


main() {
    # Workaround Docker runner environment variable prefix:
    # https://gitlab.com/gitlab-org/gitlab-docs/-/issues/1762
    printenv | sed -nE 's|^DOCKER_ENV_([A-Z0-9_]+)=.*|export \1="${DOCKER_ENV_\1}"|p' \
		   >"/tmp/docker-env.sh"
    source "/tmp/docker-env.sh"

    # Run as the user from the environment:
    if test -n "${PUID:-}"
    then
        exec su-exec "${PUID}" "${@}"
    fi

    # Run un-altered as the user passed in by docker:
    exec "$@"
}


main "$@"
