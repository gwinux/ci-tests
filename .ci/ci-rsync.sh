#!/usr/bin/bash

set -eo pipefail

DIR="$( cd "$( dirname "$0" )" && pwd )"
source "$DIR/ci-library.sh"

pacman -S --needed --noconfirm --noprogressbar openssh rsync
source <(ssh-agent)
mkdir -p ~/.ssh
echo "${SSH_HOST} ecdsa-sha2-nistp256 ${SSH_SERVER_KEY}" > ~/.ssh/known_hosts

cat <<<${SSH_KEY} > ~/.ssh/id_ed25515
ssh -i ~/.ssh/id_ed25515 ${SSH_USER}@${SSH_HOST} "echo Connected to remote server"

rsync_pkgs() {
    pushd $1-artifacts > /dev/null
    start_group RSYNC "$1-artifacts"
    if [ "$(/usr/bin/ls -A ./*pkg*)" ]; then
        rsync -av -e 'ssh -i ~/.ssh/id_ed25515' ${SSH_USER}@${SSH_HOST}:/srv/repo/x86_64/$1/ . --include="$1.db*" --include="$1.files*" --exclude="*" 
        repo-add -v -s $1.db.tar.zst ./*.pkg.tar.zst
        rsync -av -e 'ssh -i ~/.ssh/id_ed25515' . ${SSH_USER}@${SSH_HOST}:/srv/repo/x86_64/$1/
    fi
    end_group
    popd > /dev/null
}

rsync_pkgs msys2
rsync_pkgs posix
