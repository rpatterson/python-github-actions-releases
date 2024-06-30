#!/bin/bash
#
# Add files tracked in VCS for any bind volume paths that have none.
#
# Useful so that `# dockerd` doesn't create them as `root`.

# SPDX-FileCopyrightText: 2023 Ross Patterson <me@rpatterson.net>
#
# SPDX-License-Identifier: MIT

set -eu -o pipefail
shopt -s inherit_errexit
export PS4='+$(basename "${0}"):${LINENO}+'
if test "${DEBUG:=false}" = "true"
then
    # Echo commands for easier debugging
    set -x
fi


main() {
    source_prefix="${1}"
    shift
    target_prefix="${1}"
    shift

    compose_args="docker compose $(
        for profile in $(docker compose config --profiles)
	do
	    echo "--profile ${profile}"
	done
    )"
    if test "${DEBUG}" = "true"
    then
	${compose_args} config >&2
    fi
    (
	${compose_args} config |
	    sed -nE -e "s#^ *source: *${source_prefix}/(.+)#\1#p" &&
	    ${compose_args} config |
	        sed -nE -e "s#^ *target: *${target_prefix}/(.+)#\1#p"
    ) | sort | uniq | while read "docker_volume_path"
    do
	if test -n "$(git ls-files "${docker_volume_path}")"
	then
	    continue
	fi
	docker_volume_added="true"
	mkdir -pv "${docker_volume_path}"
	cat <<"EOF" >"${docker_volume_path}/.gitignore"
# SPDX-FileCopyrightText: 2023 Ross Patterson <me@rpatterson.net>
#
# SPDX-License-Identifier: MIT

# Ensure the Docker volume exists so `# dockerd` doesn't create this as root:
/*
!.git*
!/Makefile
/*~
EOF
	git add -f "${docker_volume_path}/.gitignore"
	echo "${docker_volume_path}/.gitignore"
    done
}


main "$@"
