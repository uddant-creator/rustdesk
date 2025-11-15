#!/bin/bash

function distribution() {
    local DISTRIBUTION=""

    if [ -f "/etc/debian_version" ]; then
        source /etc/os-release
        DISTRIBUTION="${ID}"
    else
        echo "ERROR: Distribution must be ubuntu!"
        exit 1
    fi
}

function root() {
    if [ "$(echo ${USER})" != "root" ]; then
        echo "WARNING: You must be root to run the script!"
        exit 1
    fi
}

function install() {
    if [ -f "/usr/bin/hbbs" ] && [ -f "/usr/bin/hbbr" ]; then
        echo "NOTICE: Installed, no need to reinstall!"
        exit 0
    fi

    local DEB_ARCHITECTURE=$(dpkg --print-architecture)
    local SERVER_PUBLIC_IPV4="$(curl -s -4 https://cloudflare.com/cdn-cgi/trace | grep ip | awk -F '=' '{ print $2 }')"

    wget -q https://github.com/rustdesk/rustdesk-server/releases/download/${LATEST_TAG_NAME}/rustdesk-server-hbbs_${LATEST_TAG_NAME}_${DEB_ARCHITECTURE}.deb
    wget -q https://github.com/rustdesk/rustdesk-server/releases/download/${LATEST_TAG_NAME}/rustdesk-server-hbbr_${LATEST_TAG_NAME}_${DEB_ARCHITECTURE}.deb

    dpkg -i rustdesk-server-hbbs_${LATEST_TAG_NAME}_${DEB_ARCHITECTURE}.deb >/dev/null 2>&1
    dpkg -i rustdesk-server-hbbr_${LATEST_TAG_NAME}_${DEB_ARCHITECTURE}.deb >/dev/null 2>&1

    ufw allow proto tcp from 0.0.0.0/0 to any port 21115:21119 >/dev/null 2>&1
    ufw allow proto udp from 0.0.0.0/0 to any port 21116 >/dev/null 2>&1

    rm rustdesk-server-hbbs_${LATEST_TAG_NAME}_${DEB_ARCHITECTURE}.deb
    rm rustdesk-server-hbbr_${LATEST_TAG_NAME}_${DEB_ARCHITECTURE}.deb

    echo "ID Server: ${SERVER_PUBLIC_IPV4}"
    echo "Key: $(cat /var/lib/rustdesk-server/id_ed25519.pub) (/var/lib/rustdesk-server/id_ed25519.pub)"
    exit 0
}

function update() {
    if [ -f "/usr/bin/hbbs" ] && [ -f "/usr/bin/hbbr" ]; then
        if [ "${LATEST_TAG_NAME}" != "$(hbbs -h | head -1 | awk '{ print $2 }')" ] && [ "${LATEST_TAG_NAME}" != "$(hbbr -h | head -1 | awk '{ print $2 }')" ]; then
            install
        else
            echo "NOTICE: Version \"${LATEST_TAG_NAME}\" is the latest version, no need to update!"
        fi
    else
        echo "NOTICE: Not installed, no need to update!"
    fi
    exit 0
}

function remove() {
    if [ ! -f "/usr/bin/hbbs" ] && [ ! -f "/usr/bin/hbbr" ]; then
        echo "NOTICE: Not installed, no need to remove!"
        exit 0
    fi

    if systemctl is-active --quiet rustdesk-hbbs.service && systemctl is-active --quiet rustdesk-hbbr.service; then
        systemctl stop rustdesk-hbbs.service
        systemctl stop rustdesk-hbbr.service
    fi

    apt purge rustdesk-server-hbbs rustdesk-server-hbbr -y >/dev/null 2>&1
    rm -rf /var/lib/rustdesk-server >/dev/null 2>&1
    rm -rf /var/log/rustdesk-server >/dev/null 2>&1

    ufw delete allow proto tcp from 0.0.0.0/0 to any port 21115:21119 >/dev/null 2>&1
    ufw delete allow proto udp from 0.0.0.0/0 to any port 21116 >/dev/null 2>&1
    exit 0
}

function help() {
    cat <<EOF
USAGE
  bash rustdesk.sh [OPTION]

OPTION
  -h, --help    Show help manual
  -i, --install Install "hbbs" and "hbbr"
  -u, --update  Update "hbbs" and "hbbr"
  -r, --remove  Remove "hbbs" and "hbbr"
EOF
    exit 0
}

function main() {
    distribution
    root

    local LATEST_TAG_NAME=$(curl https://api.github.com/repos/rustdesk/rustdesk-server/releases/latest -s | grep "tag_name" | awk -F '"' '{ print $4 }')

    if [ "$#" -eq 0 ]; then
        help
    fi

    while [ "$#" -gt 0 ]; do
        case "$1" in
            -h|--help)
                help
                ;;
            -i|--install)
                install
                ;;
            -u|--update)
                update
                ;;
            -r|--remove)
                remove
                ;;
            *)
                echo "ERROR: Invalid option \"$1\"!"
                exit 1
                ;;
        esac
        shift
    done
}

main "$@"
