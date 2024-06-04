#!/bin/bash

# SPDX-FileCopyrightText: 2023 Ross Patterson <me@rpatterson.net>
#
# SPDX-License-Identifier: MIT

# Perform any required volatile run time initialization

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
    # Run as the user from the enironment, adding that user if necessary
    if test -n "${PUID:-}"
    then
        if (( $(id -u) != 0 ))
        then
            set +x
            echo "ERROR: Can't create a user when not run as root" 1>&2
            false
        fi
	PGID="${PGID:-${PUID}}"

	# Ensure the home directory in the image has the correct permissions. Change
	# permissions selectively to avoid time-consuming recursion:
	chown ${CHOWN_ARGS} -R "${PUID}:${PGID}" "/home/${PROJECT_NAME}/"

        # Add an unprivileged user:
        if ! getent group "${PGID}" >"/dev/null"
        then
            addgroup ${ADDUSER_ARGS} --gid "${PGID}" "project-structure"
        fi
        if ! id "${PUID}" >"/dev/null" 2>&1
        then
            # Add a user to the `passwd` DB to support looking up the
            # `~project-structure/` HOME directory:
            adduser ${ADDUSER_ARGS} --uid "${PUID}" --gid "${PGID}" \
	        --disabled-password --gecos "Project Structure,,," "project-structure" \
	        > "/dev/null"
        fi
        if tty_dev=$(tty)
        then
            # Fix interactive session terminal ownership:
            chown "${PUID}" "${tty_dev}"
        fi
        # Run the rest of the command-line arguments as the unprivileged user:
        exec gosu "${PUID}" "${@}"
    fi

    # Run un-altered as the user passed in by docker:
    exec "$@"
}


main "$@"
