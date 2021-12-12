#!/usr/bin/env bash
# Backup personal data to another medium

# 於任何命令失敗（結束狀態非零）時中止腳本運行
# 流水線(pipeline)中的任何組成命令失敗視為整條流水線失敗
set \
    -o errexit \
    -o errtrace \
    -o pipefail

# 如果任何變數在未設值的狀況下被參照的話就中止腳本運行
set \
    -o nounset

# 方便給別人改的變數宣告放在這裡，變數名稱建議大寫英文與底線
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
WORKSPACE_RSYNC_OPTIONS=(
    "${COMMON_RSYNC_OPTIONS[@]}"
    --checksum
    --delete
    --delete-after
    --delete-excluded
    --exclude .vagrant/
    --exclude cache/
    --exclude .cache/
    --exclude "${USER_HOME_DIR}/文件/工作空間/第三方專案/**"
    --exclude stage/
    --exclude prime/
)

# We can't delete excluded files here as we don't want to remove the
# previously synced workspace dir
USER_DIRS_RSYNC_OPTIONS=(
    "${COMMON_RSYNC_OPTIONS[@]}"
    --exclude .vagrant/
    --exclude cache/
    --exclude .cache/
    --exclude "${USER_HOME_DIR}/下載/Telegram Desktop/**"
    --exclude "${USER_HOME_DIR}/文件/工作空間/"
)

WIREGUARD_RSYNC_OPTIONS=(
    "${COMMON_RSYNC_OPTIONS[@]}"
    --delete
    --delete-after
    --delete-excluded
)

SSH_RSYNC_OPTIONS=(
    "${COMMON_RSYNC_OPTIONS[@]}"
)

# ↓↓↓從這裡開始寫↓↓↓
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

    sync_workspace_directories
    sync_common_user_directories
    sync_wireguard_configuration
    sync_ssh_config_and_keys

    end_timestamp="$(date +%s)"
    printf \
        'Info: Runtime: %s\n' \
        "$(
            determine_elapsed_time \
                "${start_timestamp}" \
                "${end_timestamp}"
        )"
}

# ERR情境所觸發的陷阱函式，用來進行腳本錯誤退出的後續處裡
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

# 便利變數設定
# shellcheck disable=SC2034
{
    if ! test -v BASH_SOURCE; then
        # 處理腳本直接透過 stdin 餵給直譯器的情境
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

sync_workspace_directories(){
    printf 'Syncing workspace directories...\n'
    rsync \
        "${WORKSPACE_RSYNC_OPTIONS[@]}" \
        "${USER_HOME_DIR}/文件/工作空間" \
        "${DESTINATION_ADDR}:/mnt/data/文件"
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
        rsync \
            "${USER_DIRS_RSYNC_OPTIONS[@]}" \
            "${USER_HOME_DIR}/${common_user_dir}" \
            "${DESTINATION_ADDR}:/mnt/data/"
    done
}

sync_wireguard_configuration(){
    printf 'Info: Syncing WireGuard configuration files...\n'
    rsync \
        "${WIREGUARD_RSYNC_OPTIONS[@]}" \
        /etc/wireguard \
        "${DESTINATION_ADDR}:/etc/"
}

sync_ssh_config_and_keys(){
    printf 'Info: Syncing SSH configuration and keys...\n'
    rsync \
        "${SSH_RSYNC_OPTIONS[@]}" \
        "${USER_HOME_DIR}"/.ssh \
        "${DESTINATION_ADDR}:${USER_HOME_DIR}/"
}

init
