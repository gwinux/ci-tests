#!/usr/bin/bash

set -eo pipefail

DIR="$( cd "$( dirname "$0" )" && pwd )"

import_key() {
    [[ -d ~/.gnupg ]] && return

    gpg --import <(echo -e ${GPG_KEY})
}

sign_pkgs() {
    for pkg in ${1[@]}; do
        gpg --detach-sign --no-armor "$1"
    done
}

import_key

for d in msys2-artifacts posix-artifacts; do
    echo "::group::[sign] $d"
    sign_pkgs ${d}/*.{pkg,src}.tar.*
    echo "::endgroup::"
done