#!/bin/bash
#
# Fail with non-zero status if the running container is unhealthy.

# SPDX-FileCopyrightText: 2023 Ross Patterson <me@rpatterson.net>
#
# SPDX-License-Identifier: MIT


set -eu -o pipefail
shopt -s inherit_errexit
export PS4='+$(basename "${0}"):${LINENO}+'
CHOWN_ARGS=""
ADDUSER_ARGS="--quiet"
if test "${DEBUG:=false}" = "true"
then
    # Echo commands for easier debugging
    set -x
    CHOWN_ARGS+="-c"
    ADDUSER_ARGS=""
fi


main() {
    true "TEMPLATE: Replace with the appropriate command to assert container health."
}


main "$@"
