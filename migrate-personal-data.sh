#!/usr/bin/env bash
# Backup personal data to another medium
#
# Copyright 2025 林博仁(Buo-ren Lin) <buo.ren.lin@gmail.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
USER=brlin
DESTINATION_HOMEDIR_SPEC="${DESTINATION_HOMEDIR_SPEC:-unset}"
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

STEAM_RSYNC_OPTIONS=(
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

shopt -s nullglob

init(){
    if test "$(id --user)" != 0; then
        printf \
            'Error: This program should be run as the superuser(root).\n' \
            1>&2
        exit 1
    fi

    if test "${DESTINATION_HOMEDIR_SPEC}" == unset; then
        printf \
            'Error: The DESTINATION_HOMEDIR_SPEC parameter is not set.\n' \
            1>&2
        exit 1
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

    if ! user_home_dir="$(
        getent passwd "${USER}" \
            | cut --delimiter=: --fields=6
        )"; then
        printf \
            'Error: Unable to parse the local user home directory.\n' \
            1>&2
        exit 2
    fi

    if ! sync_common_user_directories \
        "${USER}" \
        "${DESTINATION_HOMEDIR_SPEC}"; then
        printf \
            'Error: Unable to sync common user directories.\n' \
            1>&2
        exit 2
    fi

    if ! sync_steam_library \
        "${user_home_dir}" \
        "${DESTINATION_HOMEDIR_SPEC}" \
        "${STEAM_RSYNC_OPTIONS[@]}"; then
        printf \
            'Error: Unable to sync Steam library.\n' \
            1>&2
        exit 2
    fi

    #sync_ssh_config_and_keys
    #sync_data_filesystem
    #sync_gnupg_config_and_keys

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
    local user_home_dir="${1}"; shift 1
    local destination_homedir_spec="${1}"; shift 1

    printf 'Info: Syncing common user directories...\n'

    user_dirs_file="${user_home_dir}/.config/user-dirs.dirs"
    if ! test -e "${user_dirs_file}"; then
        printf \
            '%s: Error: This function requires the user-dirs definition file to exist.\n' \
            "${FUNCNAME[0]}" \
            1>&2
        return 1
    fi

    # Otherwise we'll get root's paths
    HOME="${user_home_dir}"

    # out of scope
    # shellcheck source=/dev/null
    if ! source "${user_dirs_file}"; then
        printf \
            '%s: Error: Unable to source the user directories definition file.\n' \\
            "${FUNCNAME[0]}" \
            1>&2
        return 2
    fi

    user_dirs=()
    user_dirs_vars=(
        XDG_DESKTOP_DIR
        XDG_DOCUMENTS_DIR
        XDG_DOWNLOAD_DIR
        XDG_MUSIC_DIR
        XDG_PICTURES_DIR
        XDG_PUBLICSHARE_DIR
        XDG_TEMPLATES_DIR
        XDG_VIDEOS_DIR
    )
    for var in "${user_dirs_vars[@]}"; do
        # Variable may not be defined
        if ! test -v "${var}"; then
            continue
        fi

        value="${!var}"
        canonical_path="$(realpath "${value}")"
        canonical_home="$(realpath "${user_home_dir}")"

        # Variable may be set to $HOME when the folder is once missing
        if test "${canonical_path}" == "${canonical_home}"; then
            printf \
                'Warning: The "%s" user directory is a fallback directory, skipping...\n' \
                "${value}"
            continue
        fi

        user_dirs+=("${!var}")
    done

    # We can't delete excluded files here as we don't want to remove the
    # previously synced workspace dir
    user_dirs_rsync_options=(
        "${COMMON_RSYNC_OPTIONS[@]}"
        --checksum
        --delete
        --delete-after
        --delete-excluded

        --exclude .vagrant/
        --exclude cache/
        --exclude .cache/
        --exclude "${user_home_dir}/下載/Telegram Desktop/**"
        --exclude "${user_home_dir}/文件/工作空間/"
    )

    for dir in "${user_dirs[@]}"; do
        if ! test -e "${dir}"; then
            continue
        fi

        dir_name="${dir##*/}"

        printf \
            'Info: Syncing the %s user directory...\n' \
            "${dir_name}"

        if ! rsync \
            "${user_dirs_rsync_options[@]}" \
            "${dir}/" \
            "${destination_homedir_spec}/${dir_name}"; then
            printf \
                'Error: Unable to sync the "%s" user directory.\n' \
                "${dir_name}" \
                1>&2
            return 2
        fi
    done
}

sync_steam_library(){
    local user_home_dir="${1}"; shift 1
    local destination_homedir_spec="${1}"; shift 1
    local -a rsync_options=("${@}"); set --

    steam_library_dir="${user_home_dir}/.local/share/Steam"
    if ! test -e "${steam_library_dir}"; then
        printf \
            'Warning: Steam library not found, skipping...\n' \
            1>&2
        return 0
    fi

    printf \
        'Info: Syncing Steam library...\n'

    if ! rsync \
        "${rsync_options[@]}" \
        "${steam_library_dir}/" \
        "${destination_homedir_spec}/.local/share/Steam"; then
        printf \
            'Error: Unable to sync the Steam library.\n' \
            1>&2
        return 2
    fi
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
