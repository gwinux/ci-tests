#!/usr/bin/bash

set -eo pipefail

DIR="$( cd "$( dirname "$0" )" && pwd )"
source "$DIR/ci-library.sh"

gpg --import <(cat <<<${GPG_KEY}) || failure "Cannot import gpg secret key"

for d in msys2-artifacts posix-artifacts; do
    start_group SIGN "$d"
    for pkg in ${d}/*.{pkg,src}.tar.*; do
        [[ ! -e ${pkg} ]] && continue
        basename ${pkg}
        gpg --detach-sign --no-armor ${pkg}
    done
    end_group
done

success "All packages are signed"