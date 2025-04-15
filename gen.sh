#!/bin/zsh

# 设置严格模式
set -euo pipefail

# 定义常量
readonly CONFIG_DIR="$HOME"
readonly BACKUP_DIR="$HOME/.cfconf_backup"
readonly CONFIG_FILES=(
    ".zshrc_cufoon"
    ".zshrc_cufoon_proxy"
    ".zshrc_cufoon_proxy_off"
    ".gitconfig"
    ".npmrc"
    ".vimrc"
)
readonly GEN_CONFIG_FILES=(
    ".zshrc_cufoon_proxy_url_http"
    ".zshrc_cufoon_proxy_url_socks"
    ".gitconfig_cufoon"
)

readonly GEN_TO__zshrc_cufoon="$HOME/.zshrc_cufoon"
readonly GEN_TO__zshrc_cufoon_proxy="$HOME/.zshrc_cufoon_proxy"
readonly GEN_TO__zshrc_cufoon_proxy_off="$HOME/.zshrc_cufoon_proxy_off"
readonly GEN_TO__gitconfig="$HOME/.gitconfig"
readonly GEN_TO__npmrc="$HOME/.npmrc"
readonly GEN_TO__vimrc="$HOME/.vimrc"

readonly GEN_CONFIG__zshrc_cufoon_proxy_url_http="$HOME/.zshrc_cufoon_proxy_url_http"
readonly GEN_CONFIG__zshrc_cufoon_proxy_url_socks="$HOME/.zshrc_cufoon_proxy_url_socks"
readonly GEN_CONFIG__gitconfig_cufoon="$HOME/.gitconfig_cufoon"

# 显示使用方法
show_usage() {
    cat <<EOF
Usage: $(basename $0) [-r XXX] [-l] [-R timestamp] [-y] [http_proxy] [socks_proxy]
Options:
    -r XXX  Control proxy reinput (first digit for HTTP, second for SOCKS, third for GIT)
            |  Example: -r 100 to reinput only http proxy
            |           -r 010 to reinput only socks proxy
            |           -r 001 to reinput only git config
            |           -r 111 to reinput both proxies and git config
    -l      List all available backups
    -R XXX  Restore configuration from backup (XX is the timestamp)
    -y      Skip confirmation and overwrite files
    -h      Show this help message
EOF
    exit 1
}

# 显示文件差异
show_diff() {
    local file=$1
    local new_content=$2
    local temp_file=$(mktemp)

    echo "$new_content" >"$temp_file"

    if [[ -f "$file" ]]; then
        echo "Differences for $file:"
        echo "----------------------------------------"
        colordiff -u "$file" "$temp_file" || true
        echo "----------------------------------------"
    else
        echo "File $file is new and will be created."
        echo "----------------------------------------"
        echo "New content:"
        cat "$temp_file"
        echo "----------------------------------------"
    fi

    rm -f "$temp_file"
}

# 确认操作
confirm_action() {
    local message=$1
    local default=${2:-"n"}
    local prompt

    if [[ $default == "y" ]]; then
        prompt="$message [Y/n] "
    else
        prompt="$message [y/N] "
    fi

    read "response?$prompt"
    response=${response:-$default}

    [[ ${response:0:1} =~ [Yy] ]]
}

# 安全地写入文件，带确认
safe_write_file_with_confirm() {
    local file=$1
    local content=$2
    local skip_confirm=${3:-false}

    if [[ -f "$file" ]]; then
        show_diff "$file" "$content"
        if [[ "$skip_confirm" != "true" ]]; then
            if ! confirm_action "Do you want to overwrite this file?"; then
                echo "Skipping $file"
                return 0
            fi
        fi
    fi

    safe_write_file "$file" "$content"
    echo "Updated $file"
}

# 列出所有可用的备份
list_backups() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        echo "No backups found."
        exit 0
    fi

    echo "Available backups:"
    echo "Timestamp           Last Modified"
    echo "---------------------------------------"
    for backup in "$BACKUP_DIR"/*; do
        if [[ -d "$backup" ]]; then
            timestamp=$(basename "$backup")
            modified=$(date -r "$backup" "+%Y-%m-%d %H:%M:%S")
            echo "$timestamp      $modified"
        fi
    done
}

# 从备份恢复配置
restore_backup() {
    local timestamp=$1
    local backup_path="$BACKUP_DIR/$timestamp"

    if [[ ! -d "$backup_path" ]]; then
        echo "Error: Backup $timestamp not found" >&2
        exit 1
    fi

    echo "Restoring configuration from backup: $timestamp"

    # 先备份当前配置
    backup_configs

    # 恢复所有配置文件
    for file in "${CONFIG_FILES[@]}"; do
        if [[ -f "$backup_path/$file" ]]; then
            cp -f "$backup_path/$file" "$HOME/$file"
            chmod 600 "$HOME/$file"
        fi
    done

    # 恢复GEN配置文件
    for file in "${GEN_CONFIG_FILES[@]}"; do
        if [[ -f "$backup_path/$file" ]]; then
            cp -f "$backup_path/$file" "$HOME/$file"
            chmod 600 "$HOME/$file"
        fi
    done

    echo "Configuration restored successfully!"
    exit 0
}

# 验证URL格式
validate_url() {
    local url=$1
    # 放宽主机名规则，允许除URL分隔符外的字符
    if [[ ! $url =~ ^(http|https|socks|socks5)://[^:/?#]+:[0-9]+$ ]]; then
        echo "Error: Invalid proxy URL format: $url" >&2
        return 1
    fi

    # 提取端口并校验范围
    local port=$(awk -F: '{print $NF}' <<<"$url")
    if [[ $port -lt 1 || $port -gt 65535 ]]; then
        echo "Error: Port must be between 1 and 65535" >&2
        return 1
    fi

    return 0
}

# 安全地读取文件
safe_read_file() {
    local file=$1
    if [[ -f "$file" && -r "$file" ]]; then
        cat "$file"
    else
        echo "Error: Wrong file: $file, please remove it!"
        exit 1
    fi
}

# 安全地写入文件
safe_write_file() {
    local file=$1
    local content=$2
    echo "$content" >"$file"
    chmod 600 "$file" # 设置安全的文件权限
}

# 备份现有配置
backup_configs() {
    local backup_dir="$BACKUP_DIR/$(date +%Y%m%d%H%M%S)"
    mkdir -p "$backup_dir"

    local have_config_file=0
    # 备份配置文件
    for file in "${CONFIG_FILES[@]}"; do
        if [[ -f "$HOME/$file" ]]; then
            have_config_file=1
            cp "$HOME/$file" "$backup_dir/" 2>/dev/null || true
        fi
    done

    # 备份GEN配置文件
    for file in "${GEN_CONFIG_FILES[@]}"; do
        if [[ -f "$HOME/$file" ]]; then
            have_config_file=1
            cp "$HOME/$file" "$backup_dir/" 2>/dev/null || true
        fi
    done

    if [[ $have_config_file == "1" ]]; then
        echo "Configuration files backed up to: $backup_dir"
    else
        rm -rf "$backup_dir"
    fi
}

# 获取脚本所在目录的绝对路径
CF_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 切换到用户主目录
cd "$HOME"

# 初始化变量
OPTION_R_VALUE="000"
OPTION_RESTORE_TIMESTAMP=""
SKIP_CONFIRM=false
OPTION_SHOULD_REINPUT_PROXY_HTTP="0"
OPTION_SHOULD_REINPUT_PROXY_SOCKS="0"
OPTION_SHOULD_REINPUT_GITCONFIG="0"

# 临时关闭一下未定义检查
set +u
# 解析命令行选项
while getopts "hr:lR:y" opt; do
    case $opt in
    h)
        show_usage
        ;;
    r)
        OPTION_R_VALUE="$OPTARG"
        ;;
    l)
        list_backups
        exit 0
        ;;
    R)
        OPTION_RESTORE_TIMESTAMP="$OPTARG"
        ;;
    y)
        SKIP_CONFIRM=true
        ;;
    \?)
        echo "Error: Unknown option -$OPTARG" >&2
        show_usage
        exit 1
        ;;
    :)
        echo "Error: Missing argument for -$OPTARG" >&2
        show_usage
        exit 1
        ;;
    esac
done

# 恢复未定义检查
set -u

# 移除已处理的选项, 也就是移除 - -- 这种参数（它们由 getopts 处理过了）
shift $((OPTIND - 1))

# ---------------------------------------------------------

# 如果指定了恢复选项，执行恢复操作
if [[ -n "$OPTION_RESTORE_TIMESTAMP" ]]; then
    restore_backup "$OPTION_RESTORE_TIMESTAMP"
fi

# 如果提供了 -r 选项，解析其值
if [[ -n "$OPTION_R_VALUE" ]]; then
    if ! [[ "$OPTION_R_VALUE" =~ ^[01]{3}$ ]]; then
        echo "Error: -r parameter must be a combination of three digits (0 or 1)" >&2
        show_usage
    fi
    OPTION_SHOULD_REINPUT_PROXY_HTTP="${OPTION_R_VALUE:0:1}"
    OPTION_SHOULD_REINPUT_PROXY_SOCKS="${OPTION_R_VALUE:1:1}"
    OPTION_SHOULD_REINPUT_GITCONFIG="${OPTION_R_VALUE:2:1}"
fi

# 获取命令行参数中的代理 URL
PROXY_URL_HTTP=${1:-}
PROXY_URL_SOCKS=${2:-}

# 处理 HTTP 代理 URL
if [[ -z "$PROXY_URL_HTTP" ]]; then
    if [[ -f "$GEN_CONFIG__zshrc_cufoon_proxy_url_http" ]]; then
        if [ "${OPTION_SHOULD_REINPUT_PROXY_HTTP:-0}" = "1" ]; then
            echo "HTTP proxy configuration exists, but reinput requested."
            read "PROXY_URL_HTTP?Enter HTTP proxy URL: "
            validate_url "$PROXY_URL_HTTP" || exit 1
        else
            echo "Using existing HTTP proxy configuration."
            PROXY_URL_HTTP="$(safe_read_file "$GEN_CONFIG__zshrc_cufoon_proxy_url_http")"
        fi
    else
        echo "HTTP proxy configuration not found, please provide a new one."
        read "PROXY_URL_HTTP?Enter HTTP proxy URL: "
        validate_url "$PROXY_URL_HTTP" || exit 1
    fi
else
    validate_url "$PROXY_URL_HTTP" || exit 1
    OPTION_SHOULD_REINPUT_PROXY_HTTP="1"
fi

# 处理 SOCKS 代理 URL
if [[ -z "$PROXY_URL_SOCKS" ]]; then
    if [[ -f "$GEN_CONFIG__zshrc_cufoon_proxy_url_socks" ]]; then
        if [ "${OPTION_SHOULD_REINPUT_PROXY_SOCKS:-0}" = "1" ]; then
            echo "SOCKS proxy configuration exists, but reinput requested."
            read "PROXY_URL_SOCKS?Enter SOCKS proxy URL: "
            validate_url "$PROXY_URL_SOCKS" || exit 1
        else
            echo "Using existing SOCKS proxy configuration."
            PROXY_URL_SOCKS="$(safe_read_file "$GEN_CONFIG__zshrc_cufoon_proxy_url_socks")"
        fi
    else
        echo "SOCKS proxy configuration not found, please provide a new one."
        read "PROXY_URL_SOCKS?Enter SOCKS proxy URL: "
        validate_url "$PROXY_URL_SOCKS" || exit 1
    fi
else
    validate_url "$PROXY_URL_SOCKS" || exit 1
    OPTION_SHOULD_REINPUT_PROXY_SOCKS="1"
fi

GITCONFIG_NAME=""
GITCONFIG_EMAIL=""
# 处理 git 配置
if [[ -f "$GEN_CONFIG__gitconfig_cufoon" ]]; then
    if [ "${OPTION_SHOULD_REINPUT_GITCONFIG:-0}" = "1" ]; then
        echo "git configuration exists, but reinput requested."
        read "GITCONFIG_NAME?Enter git user name: "
        read "GITCONFIG_EMAIL?Enter git user email: "
    else
        echo "Using existing git configuration."
        GITCONFIG_FROM_FILE="$(safe_read_file "$GEN_CONFIG__gitconfig_cufoon")"
        GITCONFIG_FROM_FILE_TRIMMED="$(echo "$GITCONFIG_FROM_FILE" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
        GITCONFIG_NAME="$(echo "$GITCONFIG_FROM_FILE_TRIMMED" | sed -n "1p")"
        GITCONFIG_EMAIL="$(echo "$GITCONFIG_FROM_FILE_TRIMMED" | sed -n "2p")"
    fi
else
    echo "git configuration not found, please provide a new one."
    read "GITCONFIG_NAME?Enter git user name: "
    read "GITCONFIG_EMAIL?Enter git user email: "
fi

# 备份现有配置
backup_configs

# 获取各配置文件相对于用户主目录的路径
RPATH_zshrc_cufoon="$(realpath --relative-to="$HOME" "$CF_SCRIPT_DIR/.zshrc_cufoon")"
RPATH_zshrc_cufoon_proxy="$(realpath --relative-to="$HOME" "$CF_SCRIPT_DIR/.zshrc_cufoon_proxy")"
RPATH_zshrc_cufoon_proxy_off="$(realpath --relative-to="$HOME" "$CF_SCRIPT_DIR/.zshrc_cufoon_proxy_off")"
RPATH_gitconfig="$(realpath --relative-to="$HOME" "$CF_SCRIPT_DIR/.gitconfig")"
RPATH_npmrc="$(realpath --relative-to="$HOME" "$CF_SCRIPT_DIR/.npmrc")"
RPATH_vimrc="$(realpath --relative-to="$HOME" "$CF_SCRIPT_DIR/.vimrc")"

# 处理代理 URL 中的斜杠
SED_SAFE_PROXY_URL_HTTP="$(echo $PROXY_URL_HTTP | sed 's/\//\\\//g')"
SED_SAFE_PROXY_URL_SOCKS="$(echo $PROXY_URL_SOCKS | sed 's/\//\\\//g')"
SED_SAFE_GITCONFIG_NAME="$(echo $GITCONFIG_NAME | sed 's/\//\\\//g')"
SED_SAFE_GITCONFIG_EMAIL="$(echo $GITCONFIG_EMAIL | sed 's/\//\\\//g')"

# 在生成新配置之前显示差异并确认
echo "The following changes will be made:"

# 生成并预览 gitconfig
GEN_gitconfig="$(cat "$RPATH_gitconfig" | sed "s/__cufoon_proxy_url_placeholder__/$SED_SAFE_PROXY_URL_SOCKS/g")"
GEN_gitconfig="$(echo "$GEN_gitconfig" | sed "s/__cufoon_name_placeholder__/$SED_SAFE_GITCONFIG_NAME/g")"
GEN_gitconfig="$(echo "$GEN_gitconfig" | sed "s/__cufoon_email_placeholder__/$SED_SAFE_GITCONFIG_EMAIL/g")"
safe_write_file_with_confirm "$GEN_TO__gitconfig" "$GEN_gitconfig" "$SKIP_CONFIRM"

# 生成并预览 zshrc_cufoon_proxy
GEN_zshrc_cufoon_proxy="$(cat $RPATH_zshrc_cufoon_proxy | sed "s/__cufoon_proxy_url_placeholder__/$SED_SAFE_PROXY_URL_HTTP/g")"
safe_write_file_with_confirm "$GEN_TO__zshrc_cufoon_proxy" "$GEN_zshrc_cufoon_proxy" "$SKIP_CONFIRM"

# 复制其他配置文件，显示差异并确认
for file in ".zshrc_cufoon_proxy_off" ".zshrc_cufoon" ".npmrc" ".vimrc"; do
    if [[ -f "$CF_SCRIPT_DIR/$file" ]]; then
        content=$(cat "$CF_SCRIPT_DIR/$file")
        safe_write_file_with_confirm "$HOME/$file" "$content" "$SKIP_CONFIRM"
    fi
done

# 设置适当的文件权限
chmod 600 "$HOME"/.zshrc_cufoon* "$HOME"/.gitconfig "$HOME"/.npmrc "$HOME"/.vimrc

# 保存代理URL配置
if [[ ! -f "$GEN_CONFIG__zshrc_cufoon_proxy_url_http" || "$OPTION_SHOULD_REINPUT_PROXY_HTTP" == "1" ]]; then
    safe_write_file_with_confirm ".zshrc_cufoon_proxy_url_http" "$PROXY_URL_HTTP" "$SKIP_CONFIRM"
fi

if [[ ! -f "$GEN_CONFIG__zshrc_cufoon_proxy_url_socks" || "$OPTION_SHOULD_REINPUT_PROXY_SOCKS" == "1" ]]; then
    safe_write_file_with_confirm ".zshrc_cufoon_proxy_url_socks" "$PROXY_URL_SOCKS" "$SKIP_CONFIRM"
fi

if [[ ! -f "$GEN_CONFIG__gitconfig_cufoon" || "$OPTION_SHOULD_REINPUT_GITCONFIG" == "1" ]]; then
    safe_write_file_with_confirm ".gitconfig_cufoon" "$(printf "%s\n%s" "$GITCONFIG_NAME" "$GITCONFIG_EMAIL")" "$SKIP_CONFIRM"
fi

echo "WorkENV configuration has been updated successfully!"
