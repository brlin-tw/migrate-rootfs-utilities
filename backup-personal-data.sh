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
    --one-file-system
    --human-readable
    --human-readable
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
        --exclude nohup.out
        --exclude .vagrant/
        --exclude cache/
        --exclude .cache/
        --exclude "${USER_HOME_DIR}/下載/Telegram Desktop/**"
        --exclude "${USER_HOME_DIR}/文件/工作空間/"
)

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

# ↓↓↓從這裡開始寫↓↓↓
# printf 'Syncing workspace directories...\n'
# sudo rsync \
#     "${WORKSPACE_RSYNC_OPTIONS[@]}" \
#     /home/brlin/文件/工作空間/ \
#     "${DESTINATION_ADDR}:/mnt/data/文件/工作空間"

printf 'Info: Syncing common user directories...\n'
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
    sudo rsync \
        "${USER_DIRS_RSYNC_OPTIONS[@]}" \
        "${USER_HOME_DIR}/${common_user_dir}" \
        "${DESTINATION_ADDR}:/mnt/data"
done
