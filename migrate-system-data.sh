#!/usr/bin/env bash
# Migrate system data to another rootfs
#
# Copyright 2025 林博仁(Buo-ren Lin) <buo.ren.lin@gmail.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
DESTINATION_ROOTFS_SPEC="${DESTINATION_ROOTFS_SPEC:-unset}"

ENABLE_SYNC_WIREGUARD_CONFIG="${ENABLE_SYNC_WIREGUARD_CONFIG:-true}"
ENABLE_SYNC_UDP2RAW_INSTALLATION="${ENABLE_SYNC_UDP2RAW_INSTALLATION:-true}"
ENABLE_SYNC_BLUETOOTHD_DATA="${ENABLE_SYNC_BLUETOOTHD_DATA:-true}"
ENABLE_SYNC_NETPLAN_CONFIG="${ENABLE_SYNC_NETPLAN_CONFIG:-true}"
ENABLE_SYNC_FPRINTD_DATA="${ENABLE_SYNC_FPRINTD_DATA:-true}"
ENABLE_SYNC_UNMANAGED_APPS="${ENABLE_SYNC_UNMANAGED_APPS:-true}"

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

    --delete
    --delete-after
)

UNMANAGED_APPS_RSYNC_OPTIONS=(
    "${COMMON_RSYNC_OPTIONS[@]}"

    # Exclude common package installation directories
    --exclude /containerd/
    --exclude /google/
    --exclude /megasync/
    --exclude /vagrant/
)

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
        ENABLE_SYNC_UDP2RAW_INSTALLATION
        ENABLE_SYNC_BLUETOOTHD_DATA
        ENABLE_SYNC_NETPLAN_CONFIG
        ENABLE_SYNC_FPRINTD_DATA
        ENABLE_SYNC_UNMANAGED_APPS
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
            "${COMMON_RSYNC_OPTIONS[@]}"; then
            printf \
                'Error: Unable to sync the WireGuard configuration files.\n' \
                1>&2
            exit 2
        fi
    fi

    if test "${ENABLE_SYNC_UDP2RAW_INSTALLATION}" == true; then
        if ! sync_udpraw_installation \
            "${DESTINATION_ROOTFS_SPEC}" \
            "${COMMON_RSYNC_OPTIONS[@]}"; then
            printf \
                'Error: Unable to sync the udp2raw installation.\n' \
                1>&2
            exit 2
        fi
    fi

    if test "${ENABLE_SYNC_BLUETOOTHD_DATA}" == true; then
        if ! sync_bluetoothd_data \
            "${DESTINATION_ROOTFS_SPEC}" \
            "${COMMON_RSYNC_OPTIONS[@]}"; then
            printf \
                'Error: Unable to sync the bluetooth daemon data.\n' \
                1>&2
            exit 2
        fi
    fi

    if test "${ENABLE_SYNC_NETPLAN_CONFIG}" == true; then
        if ! sync_netplan_config \
            "${DESTINATION_ROOTFS_SPEC}" \
            "${COMMON_RSYNC_OPTIONS[@]}"; then
            printf \
                'Error: Unable to sync the Netplan configuration files.\n' \
                1>&2
            exit 2
        fi
    fi

    if test "${ENABLE_SYNC_FPRINTD_DATA}" == true; then
        if ! sync_fprintd_data \
            "${DESTINATION_ROOTFS_SPEC}" \
            "${COMMON_RSYNC_OPTIONS[@]}"; then
            printf \
                'Error: Unable to sync the fingerprint daemon data.\n' \
                1>&2
            exit 2
        fi
    fi

    if test "${ENABLE_SYNC_UNMANAGED_APPS}" == true; then
        if ! sync_unmanaged_apps \
            "${DESTINATION_ROOTFS_SPEC}" \
            "${UNMANAGED_APPS_RSYNC_OPTIONS[@]}"; then
            printf \
                'Error: Unable to sync the unmanaged software installations.\n' \
                1>&2
            exit 2
        fi
    fi

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
    local destination_rootfs_spec="${1}"; shift 1
    local -a rsync_options=("${@}"); set --

    local udp2raw_installation_dir=/opt/udp2raw
    if ! test -e "${udp2raw_installation_dir}"; then
        return 0
    fi

    printf 'Info: Syncing the udp2raw installation...\n'
    if ! rsync \
        "${rsync_options[@]}" \
        "${udp2raw_installation_dir}" \
        "${destination_rootfs_spec}/opt"; then
        printf \
            'Error: Unable to sync the udp2raw installation.\n' \
            1>&2
        return 2
    fi
}

sync_bluetoothd_data(){
    local destination_rootfs_spec="${1}"; shift 1
    local -a rsync_options=("${@}"); set --

    local bluetoothd_data_dir=/var/lib/bluetooth
    if ! test -e "${bluetoothd_data_dir}"; then
        return 0
    fi

    printf \
        'Info: Syncing the bluetooth daemon data...\n'
    if ! rsync \
        "${rsync_options[@]}" \
        "${bluetoothd_data_dir}/" \
        "${destination_rootfs_spec}${bluetoothd_data_dir}"; then
        printf \
            'Error: Unable to sync the bluetooth daemon data.\n' \
            1>&2
        return 2
    fi
}

sync_netplan_config(){
    local destination_rootfs_spec="${1}"; shift 1
    local -a rsync_options=("${@}"); set --

    local netplan_config_dir=/etc/netplan
    if ! test -e "${netplan_config_dir}"; then
        return 0
    fi

    printf \
        'Info: Syncing the Netplan configuration files...\n'
    if ! rsync \
        "${rsync_options[@]}" \
        "${netplan_config_dir}/" \
        "${destination_rootfs_spec}${netplan_config_dir}"; then
        printf \
            'Error: Unable to sync the Netplan configuration files.\n' \
            1>&2
        return 2
    fi
}

sync_fprintd_data(){
    local destination_rootfs_spec="${1}"; shift 1
    local -a rsync_options=("${@}"); set --

    local fprintd_data_dir=/var/lib/fprint
    if ! test -e "${fprintd_data_dir}"; then
        return 0
    fi

    printf \
        'Info: Syncing the fingerprint daemon data...\n'
    if ! rsync \
        "${rsync_options[@]}" \
        "${fprintd_data_dir}/" \
        "${destination_rootfs_spec}${fprintd_data_dir}"; then
        printf \
            'Error: Unable to sync the fingerprint daemon data.\n' \
            1>&2
        return 2
    fi
}

sync_unmanaged_apps(){
    local destination_rootfs_spec="${1}"; shift 1
    local -a rsync_options=("${@}"); set --

    local unmanaged_apps_dir=/opt
    if ! test -e "${unmanaged_apps_dir}"; then
        return 0
    fi

    printf \
        'Info: Syncing the unmanaged software installations...\n'
    if ! rsync \
        "${rsync_options[@]}" \
        "${unmanaged_apps_dir}/" \
        "${destination_rootfs_spec}${unmanaged_apps_dir}"; then
        printf \
            'Error: Unable to sync the unmanaged software installations.\n' \
            1>&2
        return 2
    fi
}

printf \
    'Info: Configuring the defensive interpreter behaviors...\n'
set_opts=(
    -o errexit
    -o errtrace
    -o pipefail
    -o nounset
)
if ! set "${set_opts[@]}"; then
    printf \
        'Error: Unable to configure the defensive interpreter behaviors.\n' \
        1>&2
    exit 2
fi

init
