#!/usr/bin/bash

pacman -S --needed --noconfirm --noprogressbar openssh rsync
source <(ssh-agent)
mkdir -p ~/.ssh
echo "Host *" > ~/.ssh/config     
echo " StrictHostKeyChecking no" >> ~/.ssh/config
cat <<<${SSH_KEY} > ~/.ssh/id_ed25515

pushd msys2-artifacts
echo "::group::[rsync] msys2-artifacts"
if [ "$(/usr/bin/ls -A .)" ]; then
    rsync -av -e 'ssh -i ~/.ssh/id_ed25515' . ${SS_USER}@${SSH_HOST}:/srv/repo/x86_64/msys2/
fi
echo "::endgroup::"
popd

pushd posix-artifacts
echo "::group::[rsync] posix-artifacts"
if [ "$(/usr/bin/ls -A .)" ]; then
    rsync -av -e 'ssh -i ~/.ssh/id_ed25515' . ${SSH_USER}@${SSH_HOST}:/srv/repo/x86_64/posix/
fi
echo "::endgroup::"
popd
