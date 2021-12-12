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
sudo rsync \
    --archive \
    --acls \
    --one-file-system \
    --checksum \
    --delete \
    --delete-after \
    --delete-excluded \
    --exclude .vagrant/ \
    --exclude /home/brlin/文件/工作空間/第三方專案/ \
    --exclude stage/ \
    --exclude prime/ \
    --human-readable \
    --human-readable \
    --progress \
    --verbose \
    --xattrs \
    /home/brlin/文件/工作空間/ \
    /media/brlin/Ubuntu-portable/home/brlin/文件/工作空間
