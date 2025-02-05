#!/usr/bin/env bash
# Backup personal data to another medium
#
# Copyright 2025 林博仁(Buo-ren Lin) <buo.ren.lin@gmail.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
USER=brlin
USER_HOME_DIR="$(
    getent passwd "${USER}" \
        | cut --delimiter=: --fields=6
)"
DESTINATION_ADDR=root@brlin-Vostro-5481.local
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

# We can't delete excluded files here as we don't want to remove the
# previously synced workspace dir
USER_DIRS_RSYNC_OPTIONS=(
    "${COMMON_RSYNC_OPTIONS[@]}"
    --checksum
    --delete
    --delete-after
    --delete-excluded

    --exclude .vagrant/
    --exclude cache/
    --exclude .cache/
    --exclude "${USER_HOME_DIR}/下載/Telegram Desktop/**"
    --exclude "${USER_HOME_DIR}/文件/工作空間/"
)

SSH_RSYNC_OPTIONS=(
    "${COMMON_RSYNC_OPTIONS[@]}"
)

DATA_RSYNC_OPTIONS=(
    "${COMMON_RSYNC_OPTIONS[@]}"
)

GNUPG_RSYNC_OPTIONS=(
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
    if test "$(id --user)" != 0; then
        printf \
            'Error: This program should be run as the superuser(root).\n' \
            1>&2
        exit 1
    fi

    local -i \
        start_timestamp \
        end_timestamp
    start_timestamp="$(date +%s)"

#     sync_common_user_directories
#     sync_ssh_config_and_keys
    #sync_data_filesystem
    #sync_gnupg_config_and_keys

    end_timestamp="$(date +%s)"
    printf \
        'Info: Runtime: %s\n' \
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

determine_elapsed_time(){
    local -i start_timestamp="${1}"; shift
    local -i end_timestamp="${1}"; shift

    elapsed_seconds="$((end_timestamp - start_timestamp))"

    elapsed_minutes="$((elapsed_seconds / 60))"
    elapsed_seconds="$((elapsed_seconds % 60))"

    elapsed_hours="$((elapsed_minutes / 60))"
    elapsed_minutes="$((elapsed_minutes % 60))"

    elapsed_days="$((elapsed_hours / 24))"
    elapsed_hours="$((elapsed_hours % 24))"

    local flag_more_than_one_minute=false
    if test "${elapsed_days}" -ne 0; then
        flag_more_than_one_minute=true
        printf \
            '%s days, ' \
            "${elapsed_days}"
    fi
    if test "${elapsed_hours}" -ne 0; then
        flag_more_than_one_minute=true
        printf \
            '%s hours, ' \
            "${elapsed_hours}"
    fi
    if test "${elapsed_minutes}" -ne 0; then
        flag_more_than_one_minute=true
        printf \
            '%s minutes, ' \
            "${elapsed_minutes}"
    fi
    if test "${flag_more_than_one_minute}" == false; then
        printf \
            '%s seconds' \
            "${elapsed_seconds}"
    else
        printf \
            'and %s seconds' \
            "${elapsed_seconds}"
    fi
}

sync_common_user_directories(){
    printf 'Info: Syncing common user directories...\n'
    # FIXME: Hardcoded user dir names, should check config
    for common_user_dir in \
        下載 \
        公共 \
        圖片 \
        影片 \
        文件 \
        桌面 \
        模板 \
        軟體 \
        音樂
        do
        if ! test -e "${USER_HOME_DIR}/${common_user_dir}"; then
            continue
        fi
        rsync \
            "${USER_DIRS_RSYNC_OPTIONS[@]}" \
            "${USER_HOME_DIR}/${common_user_dir}" \
            "${DESTINATION_ADDR}:/mnt/data/"
    done
}

sync_ssh_config_and_keys(){
    printf 'Info: Syncing SSH configuration and keys...\n'
    rsync \
        "${SSH_RSYNC_OPTIONS[@]}" \
        "${USER_HOME_DIR}"/.ssh \
        "${DESTINATION_ADDR}:${USER_HOME_DIR}/"
}

sync_data_filesystem(){
    printf 'Info: Syncing data filesystem...\n'
    rsync \
        "${DATA_RSYNC_OPTIONS[@]}" \
        /media/brlin/Ubuntu/ \
        "${DESTINATION_ADDR}:/mnt/data/"
}

sync_gnupg_config_and_keys(){
    printf 'Info: Syncing GnuPG configuration and keys...\n'
    rsync \
        "${GNUPG_RSYNC_OPTIONS[@]}" \
        "${USER_HOME_DIR}"/.gnupg \
        "${DESTINATION_ADDR}:"
}

init
