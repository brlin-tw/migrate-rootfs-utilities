#!/usr/bin/env bash
# Backup personal data to another medium
#
# Copyright 2025 林博仁(Buo-ren Lin) <buo.ren.lin@gmail.com>
# SPDX-License-Identifier: AGPL-3.0-or-later

init(){
    # shellcheck source-path=SCRIPTDIR
    if ! source "${script_dir}/functions.sh.source"; then
        printf \
            'Error: Unable to load the functions file.\n' \
            1>&2
        exit 2
    fi

    print_progress 'Loading the configuration file...'
    # shellcheck source=SCRIPTDIR/config.sh.source
    if ! source "${script_dir}/config.sh.source"; then
        printf \
            'Error: Unable to load the configuration file.\n' \
            1>&2
        exit 2
    fi
    printf \
        'Info: Configuration file loaded successfully.\n'

    print_progress 'Checking runtime parameters...'
    printf \
        'Info: Checking the running user...\n'
    if test "${EUID}" != 0; then
        printf \
            'Error: This program should be run as the superuser(root).\n' \
            1>&2
        exit 1
    fi

    printf \
        'Info: Checking the DESTINATION_ROOTFS_SPEC parameter...\n'
    if test "${DESTINATION_ROOTFS_SPEC}" == unset; then
        printf \
            'Error: The DESTINATION_ROOTFS_SPEC parameter is not set.\n' \
            1>&2
        exit 1
    fi

    printf \
        'Info: Determining destination paths...\n'
    if test "${DESTINATION_HOMEDIR_SPEC}" == auto; then
        DESTINATION_HOMEDIR_SPEC="${DESTINATION_ROOTFS_SPEC}/home/${USER}"
    fi

    if test "${DESTINATION_DATAFS_SPEC}" == auto; then
        DESTINATION_DATAFS_SPEC="${DESTINATION_ROOTFS_SPEC}/mnt/data"
    fi

    printf \
        'Info: Validating boolean parameters...\n'
    local regex_boolean_values='^(true|false)$'
    local -a boolean_parameters=(
        ENABLE_SYNC_USER_DIRS
        ENABLE_SYNC_STEAM_LIBRARY
        ENABLE_SYNC_SSH_CONFIG_KEYS
        ENABLE_SYNC_DATAFS
        ENABLE_SYNC_GPG_CONFIG_KEYS
        ENABLE_SYNC_FIREFOX_DATA
        ENABLE_SYNC_BASH_HISTORY
        ENABLE_SYNC_GNOME_KEYRING
        ENABLE_SYNC_KDE_WALLET
        ENABLE_SYNC_USER_APPLICATIONS
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

    print_progress 'Determining the start timestamp...'
    local -i \
        start_timestamp \
        end_timestamp
    if ! start_timestamp="$(printf '%(%s)T')"; then
        printf \
            'Error: Unable to determine the start timestamp.\n' \
            1>&2
        exit 2
    fi
    printf \
        'Info: Start timestamp: %s(%s).\n' \
        "$start_timestamp" \
        "$(date --date="@$start_timestamp" '+%Y-%m-%d %H:%M:%S')"

    print_progress 'Determining the user home directory...'
    if test "${SOURCE_HOMEDIR_SPEC}" == auto; then
        if ! user_home_dir="$(
            getent passwd "${USER}" \
                | cut --delimiter=: --fields=6
            )"; then
            printf \
                'Error: Unable to parse the local user home directory.\n' \
                1>&2
            exit 2
        fi
    else
        user_home_dir="${SOURCE_HOMEDIR_SPEC}"
    fi
    printf \
        'Info: User home directory determined to be: %s.\n' \
        "${user_home_dir}"

    if test "${ENABLE_SYNC_USER_DIRS}" == true; then
        if ! sync_user_dirs \
            "${user_home_dir}" \
            "${DESTINATION_HOMEDIR_SPEC}"; then
            printf \
                'Error: Unable to sync common user directories.\n' \
                1>&2
            exit 2
        fi
    fi

    if test "${ENABLE_SYNC_STEAM_LIBRARY}" == true; then
        if ! sync_steam_library \
            "${user_home_dir}" \
            "${DESTINATION_HOMEDIR_SPEC}" \
            "${COMMON_RSYNC_OPTIONS[@]}"; then
            printf \
                'Error: Unable to sync Steam library.\n' \
                1>&2
            exit 2
        fi
    fi

    if test "${ENABLE_SYNC_SSH_CONFIG_KEYS}" == true; then
        if ! sync_ssh_config_and_keys \
            "${user_home_dir}" \
            "${DESTINATION_HOMEDIR_SPEC}" \
            "${COMMON_RSYNC_OPTIONS[@]}"; then
            exit 2
        fi
    fi

    if test "${ENABLE_SYNC_DATAFS}" == true \
        && test "${DESTINATION_DATAFS_SPEC}" != unset; then
        if ! sync_data_filesystem \
            "${DESTINATION_DATAFS_SPEC}" \
            "${COMMON_RSYNC_OPTIONS[@]}"; then
            exit 2
        fi
    fi

    if test "${ENABLE_SYNC_GPG_CONFIG_KEYS}" == true; then
        if ! sync_gnupg_config_and_keys \
            "${user_home_dir}" \
            "${DESTINATION_HOMEDIR_SPEC}" \
            "${COMMON_RSYNC_OPTIONS[@]}"; then
            exit 2
        fi
    fi

    if test "${ENABLE_SYNC_FIREFOX_DATA}" == true; then
        if ! sync_firefox_data \
            "${user_home_dir}" \
            "${DESTINATION_HOMEDIR_SPEC}" \
            "${COMMON_RSYNC_OPTIONS[@]}"; then
            exit 2
        fi
    fi

    if test "${ENABLE_SYNC_BASH_HISTORY}" == true; then
        if ! sync_bash_history \
            "${user_home_dir}" \
            "${DESTINATION_HOMEDIR_SPEC}" \
            "${COMMON_RSYNC_OPTIONS[@]}"; then
            exit 2
        fi
    fi

    if test "${ENABLE_SYNC_GNOME_KEYRING}" == true; then
        if ! sync_gnome_keyring \
            "${user_home_dir}" \
            "${DESTINATION_HOMEDIR_SPEC}" \
            "${COMMON_RSYNC_OPTIONS[@]}"; then
            exit 2
        fi
    fi

    if test "${ENABLE_SYNC_KDE_WALLET}" == true; then
        if ! sync_kde_wallet \
            "${user_home_dir}" \
            "${DESTINATION_HOMEDIR_SPEC}" \
            "${COMMON_RSYNC_OPTIONS[@]}"; then
            exit 2
        fi
    fi

    if test "${ENABLE_SYNC_USER_APPLICATIONS}" == true; then
        if ! sync_user_applications \
            "${user_home_dir}" \
            "${DESTINATION_HOMEDIR_SPEC}" \
            "${COMMON_RSYNC_OPTIONS[@]}"; then
            exit 2
        fi
    fi

    if test "${ENABLE_SYNC_KDE_CONNECT}" == true; then
        if ! sync_kde_connect \
            "${user_home_dir}" \
            "${DESTINATION_HOMEDIR_SPEC}" \
            "${COMMON_RSYNC_OPTIONS[@]}"; then
            exit 2
        fi
    fi

    if test "${ENABLE_SYNC_VBOX_VMS}" == true; then
        if ! sync_vbox_vms \
            "${user_home_dir}" \
            "${DESTINATION_HOMEDIR_SPEC}" \
            "${SOURCE_VBOX_VM_DIR}" \
            "${DESTINATION_VBOX_VM_DIR}" \
            "${COMMON_RSYNC_OPTIONS[@]}"; then
            exit 2
        fi
    fi

    print_progress 'Determining the end timestamp...'
    if ! end_timestamp="$(printf '%(%s)T')"; then
        printf \
            'Error: Unable to determine the end timestamp.\n' \
            1>&2
        exit 2
    fi
    printf \
        'Info: End timestamp: %s(%s).\n' \
        "${end_timestamp}" \
        "$(date --date="@${end_timestamp}" '+%Y-%m-%d %H:%M:%S')"

    printf \
        'Info: Runtime: %s.\n' \
        "$(
            determine_elapsed_time \
                "${start_timestamp}" \
                "${end_timestamp}"
        )"
}

sync_user_dirs(){
    local user_home_dir="${1}"; shift 1
    local destination_homedir_spec="${1}"; shift 1

    print_progress 'Syncing common user directories...'

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

    print_progress 'Syncing Steam library...'

    steam_library_dir="${user_home_dir}/.local/share/Steam"
    if ! test -e "${steam_library_dir}"; then
        printf \
            'Warning: Steam library not found, skipping...\n' \
            1>&2
        return 0
    fi

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
    local user_home_dir="${1}"; shift 1
    local destination_homedir_spec="${1}"; shift 1
    local -a rsync_options=("${@}"); set --

    print_progress 'Syncing SSH configuration and keys...\n'
    if ! rsync \
        "${rsync_options[@]}" \
        "${user_home_dir}/.ssh/" \
        "${destination_homedir_spec}/.ssh"; then
        printf \
            'Error: Unable to sync the SSH configuration and keys.\n' \
            1>&2
        return 2
    fi
}

sync_data_filesystem(){
    local destination_datafs_spec="${1}"; shift 1
    local -a rsync_options=("${@}"); set --

    print_progress 'Syncing data filesystem...'
    local datafs_dir=/mnt/data
    if ! test -e "${datafs_dir}"; then
        printf \
            '%s: Warning: Data filesystem not found, skipping...\n' \
            "${FUNCNAME[0]}" \
            1>&2
        return 0
    fi

    if ! rsync \
        "${rsync_options[@]}" \
        /mnt/data/ \
        "${destination_datafs_spec}/"; then
        printf \
            'Error: Unable to sync the data filesystem.\n' \
            1>&2
        return 2
    fi
}

sync_gnupg_config_and_keys(){
    local user_home_dir="${1}"; shift 1
    local destination_homedir_spec="${1}"; shift 1
    local -a rsync_options=("${@}"); set --

    print_progress 'Syncing GnuPG configuration and keys...'
    local gpg_home_dir="${user_home_dir}/.gnupg"

    if ! test -e "${gpg_home_dir}"; then
        printf \
            "%s: Warning: The GnuPG home directory isn't exist, skipping...\\n" \
            "${FUNCNAME[0]}" \
            1>&2
        return 0
    fi

    if ! rsync \
        "${rsync_options[@]}" \
        "${gpg_home_dir}/" \
        "${destination_homedir_spec}/.gnupg/"; then
        printf \
            'Error: Unable to sync the GnuPG configuration and keys.\n' \
            1>&2
        return 2
    fi
}

sync_firefox_data(){
    local user_home_dir="${1}"; shift 1
    local destination_homedir_spec="${1}"; shift 1
    local -a rsync_options=("${@}"); set --

    print_progress 'Syncing Firefox data...'
    local firefox_data_dir_relative=/snap/firefox/common/.mozilla
    local source_firefox_data_dir="${user_home_dir}${firefox_data_dir_relative}"
    local destination_firefox_data_dir_spec="${destination_homedir_spec}${firefox_data_dir_relative}"

    if ! test -e "${source_firefox_data_dir}"; then
        printf \
            "%s: Warning: The Firefox data directory doesn't exist, skipping...\\n" \
            "${FUNCNAME[0]}" \
            1>&2
        return 0
    fi

    # NOTE: Rsync exit status 24 means "Partial transfer due to vanished source files", which would happen if the browser is running during the synchonization
    if ! {
            rsync \
            "${rsync_options[@]}" \
            "${source_firefox_data_dir}/" \
            "${destination_firefox_data_dir_spec}" \
            || test "${?}" == 24
        }; then
        printf \
            'Error: Unable to sync the Firefox data.\n' \
            1>&2
        return 2
    fi
}

sync_bash_history(){
    local user_home_dir="${1}"; shift 1
    local destination_homedir_spec="${1}"; shift 1
    local -a rsync_options=("${@}"); set --

    print_progress 'Syncing Bash history...'
    local bash_history_file_relative=/.bash_history
    local source_bash_history_file="${user_home_dir}${bash_history_file_relative}"
    local destination_bash_history_file_spec="${destination_homedir_spec}${bash_history_file_relative}"

    if ! test -e "${source_bash_history_file}"; then
        printf \
            "%s: Warning: The Bash history file doesn't exist, skipping...\\n" \
            "${FUNCNAME[0]}" \
            1>&2
        return 0
    fi

    if ! rsync \
        "${rsync_options[@]}" \
        "${source_bash_history_file}" \
        "${destination_bash_history_file_spec}"; then
        printf \
            'Error: Unable to sync the Bash history file.\n' \
            1>&2
        return 2
    fi
}

sync_gnome_keyring(){
    local user_home_dir="${1}"; shift 1
    local destination_homedir_spec="${1}"; shift 1
    local -a rsync_options=("${@}"); set --

    print_progress 'Syncing GNOME keyring...'
    local gnome_keyring_data_dir_relative=/.local/share/keyrings
    local source_gnome_keyring_data_dir="${user_home_dir}${gnome_keyring_data_dir_relative}"
    local destination_gnome_keyring_data_dir_spec="${destination_homedir_spec}${gnome_keyring_data_dir_relative}"

    if ! test -e "${source_gnome_keyring_data_dir}"; then
        printf \
            "%s: Warning: The GNOME keyring data directory doesn't exist, skipping...\\n" \
            "${FUNCNAME[0]}" \
            1>&2
        return 0
    fi

    if ! rsync \
        "${rsync_options[@]}" \
        "${source_gnome_keyring_data_dir}/" \
        "${destination_gnome_keyring_data_dir_spec}"; then
        printf \
            'Error: Unable to sync the GNOME keyring.\n' \
            1>&2
        return 2
    fi
}

sync_kde_wallet(){
    local user_home_dir="${1}"; shift 1
    local destination_homedir_spec="${1}"; shift 1
    local -a rsync_options=("${@}"); set --

    print_progress 'Syncing KDE Wallet...'
    local kde_wallet_data_dir_relative=/.local/share/kwalletd
    local source_kde_wallet_data_dir="${user_home_dir}${kde_wallet_data_dir_relative}"
    local destination_kde_wallet_data_dir_spec="${destination_homedir_spec}${kde_wallet_data_dir_relative}"

    if ! test -e "${source_kde_wallet_data_dir}"; then
        printf \
            "%s: Warning: The KDE Wallet data directory doesn't exist, skipping...\\n" \
            "${FUNCNAME[0]}" \
            1>&2
        return 0
    fi

    if ! rsync \
        "${rsync_options[@]}" \
        "${source_kde_wallet_data_dir}/" \
        "${destination_kde_wallet_data_dir_spec}"; then
        printf \
            'Error: Unable to sync the KDE Wallet.\n' \
            1>&2
        return 2
    fi
}

sync_user_applications(){
    local user_home_dir="${1}"; shift 1
    local destination_homedir_spec="${1}"; shift 1
    local -a rsync_options=("${@}"); set --

    print_progress 'Syncing user applications...'
    local user_applications_dir_relative=/應用軟體
    local source_user_applications_dir="${user_home_dir}${user_applications_dir_relative}"
    local destination_user_applications_dir_spec="${destination_homedir_spec}${user_applications_dir_relative}"

    if ! test -e "${source_user_applications_dir}"; then
        printf \
            "%s: Warning: The user applications directory doesn't exist, skipping...\\n" \
            "${FUNCNAME[0]}" \
            1>&2
        return 0
    fi

    if ! rsync \
        "${rsync_options[@]}" \
        "${source_user_applications_dir}/" \
        "${destination_user_applications_dir_spec}"; then
        printf \
            'Error: Unable to sync the user applications.\n' \
            1>&2
        return 2
    fi

    printf 'Info: Syncing user applications compatibility link...\n'
    local user_applications_dir_link_relative=/Applications
    local source_user_applications_dir_link="${user_home_dir}${user_applications_dir_link_relative}"

    if ! test -L "${source_user_applications_dir_link}"; then
        printf \
            "%s: Warning: The user applications directory compatibility link doesn't exist, skipping...\\n" \
            "${FUNCNAME[0]}" \
            1>&2
        return 0
    fi

    if ! rsync \
        "${rsync_options[@]}" \
        "${source_user_applications_dir_link}" \
        "${destination_homedir_spec}"; then
        printf \
            'Error: Unable to sync the user applications directory compatibility link.\n' \
            1>&2
        return 2
    fi
}

sync_kde_connect(){
    local user_home_dir="${1}"; shift 1
    local destination_homedir_spec="${1}"; shift 1
    local -a rsync_options=("${@}"); set --

    print_progress 'Syncing KDE Connect data...'
    local kde_connect_data_dir_relative=/.config/kdeconnect
    local source_kde_connect_data_dir="${user_home_dir}${kde_connect_data_dir_relative}"
    local destination_kde_connect_data_dir_spec="${destination_homedir_spec}${kde_connect_data_dir_relative}"

    if ! test -e "${source_kde_connect_data_dir}"; then
        printf \
            "%s: Warning: The KDE Connect data directory doesn't exist, skipping...\\n" \
            "${FUNCNAME[0]}" \
            1>&2
        return 0
    fi

    if ! rsync \
        "${rsync_options[@]}" \
        "${source_kde_connect_data_dir}/" \
        "${destination_kde_connect_data_dir_spec}"; then
        printf \
            'Error: Unable to sync the KDE Connect data.\n' \
            1>&2
        return 2
    fi
}

sync_vbox_vms(){
    local user_home_dir="${1}"; shift 1
    local destination_homedir_spec="${1}"; shift 1
    local source_vbox_vm_dir="${1}"; shift 1
    local destination_vbox_vm_dir="${1}"; shift 1
    local -a rsync_options=("${@}"); set --

    print_progress 'Syncing VirtualBox VMs...'

    if test -z "${source_vbox_vm_dir}"; then
        source_vbox_vm_dir="${user_home_dir}/VirtualBox VMs"
        if ! test -e "${source_vbox_vm_dir}"; then
            printf \
                "%s: Warning: The VirtualBox VMs directory doesn't exist, skipping...\\n" \
                "${FUNCNAME[0]}" \
                1>&2
            return 0
        fi
    else
        if ! is_rsync_remote_specification "${source_vbox_vm_dir}" \
            && ! is_absolute_path "${source_vbox_vm_dir}"; then
            source_vbox_vm_dir="${user_home_dir}/${source_vbox_vm_dir}"
            if ! test -e "${source_vbox_vm_dir}"; then
                printf \
                    "%s: Warning: The VirtualBox VMs directory doesn't exist, skipping...\\n" \
                    "${FUNCNAME[0]}" \
                    1>&2
                return 0
            fi
        fi
    fi

    if test -z "${destination_vbox_vm_dir}"; then
        destination_vbox_vm_dir="${destination_homedir_spec%/}/VirtualBox VMs"
    else
        if ! is_rsync_remote_specification "${destination_vbox_vm_dir}" \
            && ! is_absolute_path "${destination_vbox_vm_dir}"; then
            destination_vbox_vm_dir="${destination_homedir_spec}/${destination_vbox_vm_dir}"
        fi
    fi

    if ! rsync \
        "${rsync_options[@]}" \
        "${source_vbox_vm_dir}/" \
        "${destination_vbox_vm_dir}"; then
        printf \
            'Error: Unable to sync the VirtualBox VMs.\n' \
            1>&2
        return 2
    fi
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

required_commands=(
    cut
    date
    getent
    realpath
    rsync
)
flag_required_commands_check_failed=false
for command in "${required_commands[@]}"; do
    if ! command -v "${command}" >/dev/null 2>&1; then
        printf \
            'Error: The required command "%s" is not found in PATH.\n' \
            "${command}" \
            1>&2
        flag_required_commands_check_failed=true
    fi
done
if test "${flag_required_commands_check_failed}" == true; then
    exit 1
fi

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

if ! shopt -s nullglob; then
    printf \
        'Error: Unable to configure the nullglob shell option.\n' \
        1>&2
    exit 2
fi

init
