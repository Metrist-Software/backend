#!/bin/bash
#
#  Having non-SSL for localhost is inconvenient, because HTTP and HTTPS can subtly differ
#  plus we have trouble hooking into things like Auth0
#
#  Therefore, we download and use `mkcert` to generate certificates and let Phoenix use
#  these for dev mode.
#
set -e

install_mkcert() {
    case `uname -o` in
        GNU/Linux)
            echo "Installing mkcert, expect a sudo prompt..."
            cd /tmp
            wget https://github.com/FiloSottile/mkcert/releases/download/v1.4.3/mkcert-v1.4.3-linux-amd64
            sudo install -m 755 mkcert-v1.4.3-linux-amd64 /usr/local/bin/mkcert
            echo "Assuming Debian system, apt installing certutil"
            sudo apt install libnss3-tools
            ;;
        *)
            echo "Unknown platform, please fix script"
            exit 1
            ;;
    esac
}

check_mkcert() {
   which mkcert || install_mkcert
}

check_mkcert
mkcert -install
mkcert localhost 127.0.0.1 ::1
mv *.pem priv
