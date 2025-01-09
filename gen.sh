#!/bin/zsh

CF_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

cd "$HOME"

OPTION_R_VALUE=""

while getopts r: opt; do
    case $opt in
        r)
            OPTION_R_VALUE="$OPTARG"
            ;;
        \?)
            print -u2 "invalid option: -$OPTARG"
            exit 1
            ;;
    esac
done

OPTION_SHOULD_REINPUT_PROXY_HTTP=""
OPTION_SHOULD_REINPUT_PROXY_SOCKS=""

if [[ -n $OPTION_R_VALUE ]]; then
    OPTION_SHOULD_REINPUT_PROXY_HTTP="${OPTION_R_VALUE[1]}"
    OPTION_SHOULD_REINPUT_PROXY_SOCKS="${OPTION_R_VALUE[2]}"
fi

shift $((OPTIND - 1))

PROXY_URL_HTTP=$1
PROXY_URL_SOCKS=$2

if [[ ! -n "$PROXY_URL_HTTP" ]]; then
    if [ -f ".zshrc_cufoon_proxy_url_http" ]; then
        if [ "$OPTION_SHOULD_REINPUT_PROXY_HTTP" = "1" ]; then
            echo ".zshrc_cufoon_proxy_url_http exist, but you want to resupply."
            read "PROXY_URL_HTTP?your http proxy url: "
        else
            echo ".zshrc_cufoon_proxy_url_http exist, and use it."
            PROXY_URL_HTTP="$(cat .zshrc_cufoon_proxy_url_http)"
        fi
    else
        echo ".zshrc_cufoon_proxy_url_http not exist, please supply a http proxy url."
        read "PROXY_URL_HTTP?your http proxy url: "
    fi
else
    OPTION_SHOULD_REINPUT_PROXY_HTTP="1"
fi

if [[ ! -n "$PROXY_URL_SOCKS" ]]; then
    if [ -f ".zshrc_cufoon_proxy_url_socks" ]; then
        if [ "$OPTION_SHOULD_REINPUT_PROXY_SOCKS" = "1" ]; then
            echo ".zshrc_cufoon_proxy_url_socks exist, but you want to resupply."
            read "PROXY_URL_SOCKS?your socks proxy url: "
        else
            echo ".zshrc_cufoon_proxy_url_socks exist, and use it."
            PROXY_URL_SOCKS="$(cat .zshrc_cufoon_proxy_url_socks)"
        fi
    else
        echo ".zshrc_cufoon_proxy_url_socks not exist, please supply a socks proxy url."
        read "PROXY_URL_SOCKS?your socks proxy url: "
    fi
else
    OPTION_SHOULD_REINPUT_PROXY_SOCKS="1"
fi

RPATH_zshrc_cufoon="$(realpath --relative-to="$HOME" "$CF_SCRIPT_DIR/.zshrc_cufoon")"
RPATH_zshrc_cufoon_proxy="$(realpath --relative-to="$HOME" "$CF_SCRIPT_DIR/.zshrc_cufoon_proxy")"
RPATH_zshrc_cufoon_proxy_off="$(realpath --relative-to="$HOME" "$CF_SCRIPT_DIR/.zshrc_cufoon_proxy_off")"
RPATH_gitconfig="$(realpath --relative-to="$HOME" "$CF_SCRIPT_DIR/.gitconfig")"
RPATH_npmrc="$(realpath --relative-to="$HOME" "$CF_SCRIPT_DIR/.npmrc")"
RPATH_vimrc="$(realpath --relative-to="$HOME" "$CF_SCRIPT_DIR/.vimrc")"

rm .zshrc_cufoon
rm .zshrc_cufoon_proxy
rm .zshrc_cufoon_proxy_off
rm .gitconfig
rm .npmrc
rm .vimrc

SED_SAFE_PROXY_URL_HTTP="$(echo $PROXY_URL_HTTP | sed 's/\//\\\//g')"
SED_SAFE_PROXY_URL_SOCKS="$(echo $PROXY_URL_SOCKS | sed 's/\//\\\//g')"
GEN_zshrc_cufoon_proxy="$(cat $RPATH_zshrc_cufoon_proxy | sed "s/__cufoon_proxy_url_placeholder__/$SED_SAFE_PROXY_URL_HTTP/g")"
GEN_gitconfig="$(cat $RPATH_gitconfig | sed "s/__cufoon_proxy_url_placeholder__/$SED_SAFE_PROXY_URL_SOCKS/g")"

echo "$GEN_zshrc_cufoon_proxy" > .zshrc_cufoon_proxy
echo "$GEN_gitconfig" > .gitconfig
cp "$RPATH_zshrc_cufoon" .zshrc_cufoon
cp "$RPATH_zshrc_cufoon_proxy_off" .zshrc_cufoon_proxy_off
cp "$RPATH_npmrc" .npmrc
cp "$RPATH_vimrc" .vimrc

if [[ ! -f .zshrc_cufoon_proxy_url_http || "$OPTION_SHOULD_REINPUT_PROXY_HTTP" == "1" ]]; then
    echo "$PROXY_URL_HTTP" > .zshrc_cufoon_proxy_url_http
fi

if [[ ! -f .zshrc_cufoon_proxy_url_socks || "$OPTION_SHOULD_REINPUT_PROXY_SOCKS" == "1" ]]; then
    echo "$PROXY_URL_SOCKS" > .zshrc_cufoon_proxy_url_socks
fi
