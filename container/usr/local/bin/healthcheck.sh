#!/bin/bash

# SPDX-FileCopyrightText: 2023 Ross Patterson <me@rpatterson.net>
#
# SPDX-License-Identifier: MIT

# Fail with non-zero status if the running container is unhealthy.

set -eu -o pipefail
shopt -s inherit_errexit
CHOWN_ARGS=""
ADDUSER_ARGS="--quiet"
if test "${DEBUG:=false}" = "true"
then
    # Echo commands for easier debugging
    set -x
    PS4='$0:$LINENO+'
    CHOWN_ARGS+="-c"
    ADDUSER_ARGS=""
fi


main() {
    true "TEMPLATE: Replace with the appropriate command to assert container health."
}


main "$@"
