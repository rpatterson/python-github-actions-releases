#!/bin/bash
#
# Wrapper for running the Dockerfile linter in a container.

# SPDX-FileCopyrightText: 2023 Ross Patterson <me@rpatterson.net>
#
# SPDX-License-Identifier: MIT

set -eu -o pipefail
shopt -s inherit_errexit
export PS4='+$(basename "${0}"):${LINENO}+'
if test -n "${DEBUG:=}"
then
    # Echo commands for easier debugging
    set -x
fi


main() {
    # Delegate to the container
    exec docker compose run --rm hadolint "$@"
}


main "$@"
