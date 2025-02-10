#!/usr/bin/env bash
# Migrate system data to another rootfs
#
# Copyright 2025 林博仁(Buo-ren Lin) <buo.ren.lin@gmail.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
DESTINATION_ROOTFS_SPEC="${DESTINATION_ROOTFS_SPEC:-unset}"

ENABLE_SYNC_WIREGUARD_CONFIG="${ENABLE_SYNC_WIREGUARD_CONFIG:-true}"

COMMON_RSYNC_OPTIONS=(
    --archive
    --acls
    --exclude '*~'
    --exclude '*.log'
    --exclude '*.log.*'
    --exclude '*.old'
    --exclude nohup.out
    --one-file-system
    --human-readable
    --human-readable

    # COMPAT: Not supported in old version
    #--mkpath

    --progress
    --verbose
    --xattrs
)

WIREGUARD_RSYNC_OPTIONS=(
    "${COMMON_RSYNC_OPTIONS[@]}"
    --delete
    --delete-after
    --delete-excluded
)

set \
    -o errexit \
    -o errtrace \
    -o pipefail

set \
    -o nounset

init(){
    printf \
        'Info: Checking runtime parameters...\n'
    if test "${EUID}" != 0; then
        printf \
            'Error: This program should be run as the superuser(root).\n' \
            1>&2
        exit 1
    fi

    if test "${DESTINATION_ROOTFS_SPEC}" == unset; then
        printf \
            'Error: The DESTINATION_ROOTFS_SPEC parameter is not set.\n' \
            1>&2
        exit 1
    fi

    local regex_boolean_values='^(true|false)$'
    local -a boolean_parameters=(
        ENABLE_SYNC_WIREGUARD_CONFIG
    )
    local validate_failed=false
    for param in "${boolean_parameters[@]}"; do
        if ! [[ "${!param}" =~ ${regex_boolean_values} ]]; then
            printf \
                'Error: Invalid value of the boolean parameter %s(%s).\n' \
                "${param}" \
                "${!param}" \
                1>&2
            validate_failed=true
        fi
    done
    if test "${validate_failed}" == true; then
        printf \
            'Error: Booleans parameter validation failed.\n' \
            1>&2
        exit 1
    fi

    printf \
        'Info: Loading the functions file...\n'
    # shellcheck source-path=SCRIPTDIR
    if ! source "${script_dir}/functions.sh.source"; then
        printf \
            'Error: Unable to load the functions file.\n' \
            1>&2
        exit 2
    fi

    local -i \
        start_timestamp \
        end_timestamp
    if ! start_timestamp="$(printf '%(%s)T')"; then
        printf \
            'Error: Unable to determine the start timestamp.\n' \
            1>&2
        exit 2
    fi

    if test "${ENABLE_SYNC_WIREGUARD_CONFIG}" == true; then
        if ! sync_wireguard_configuration \
            "${DESTINATION_ROOTFS_SPEC}" \
            "${WIREGUARD_RSYNC_OPTIONS[@]}"; then
            printf \
                'Error: Unable to sync the WireGuard configuration files.\n' \
                1>&2
            exit 2
        fi
    fi

    #sync_udpraw_installation

    if ! end_timestamp="$(printf '%(%s)T')"; then
        printf \
            'Error: Unable to determine the end timestamp.\n' \
            1>&2
        exit 2
    fi
    printf \
        'Info: Runtime: %s.\n' \
        "$(
            determine_elapsed_time \
                "${start_timestamp}" \
                "${end_timestamp}"
        )"
}

trap_err(){
    printf \
        '\nScript prematurely aborted on the "%s" command at the line %s of the %s function with the exit status %u.\n' \
        "${BASH_COMMAND}" \
        "${BASH_LINENO[0]}" \
        "${FUNCNAME[1]}" \
        "${?}" \
        1>&2
}
trap trap_err ERR

# Convenience variable definitions
# shellcheck disable=SC2034
{
    if ! test -v BASH_SOURCE; then
        script_path=_stdin_
        script_name=_stdin_
        script_filename=_stdin_
        script_basecommand=_null_
        script_dir=_null_
    else
        script_path="$(
            realpath \
                --strip \
                "${BASH_SOURCE[0]}"
        )"
        script_filename="${BASH_SOURCE##*/}"
        script_dir="${script_path%/*}"
        script_name="${script_filename%%.*}"
        script_basecommand="${0}"
        script_args=("${@}")
    fi
}

sync_wireguard_configuration(){
    local destination_rootfs_spec="${1}"; shift 1
    local -a rsync_options=("${@}"); set --

    local wireguard_config_dir=/etc/wireguard
    if ! test -e "${wireguard_config_dir}"; then
        return 0
    fi

    printf 'Info: Syncing the WireGuard configuration files...\n'
    if ! rsync \
        "${rsync_options[@]}" \
        "${wireguard_config_dir}" \
        "${destination_rootfs_spec}/etc/"; then
        printf \
            'Error: Unable to sync the WireGuard configuration files.\n' \
            1>&2
        return 2
    fi
}

sync_udpraw_installation(){
    printf 'Info: Syncing udp2raw installation...\n'
    rsync \
        "${COMMON_RSYNC_OPTIONS[@]}" \
        /opt/udp2raw \
        "${DESTINATION_ADDR}:/opt"
}

init
