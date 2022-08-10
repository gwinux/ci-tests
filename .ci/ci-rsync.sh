#!/usr/bin/bash

pacman -S --needed --noconfirm --noprogressbar openssh rsync
source <(ssh-agent)
ssh-add <(echo -e ${SSH_KEY})

pushd msys2-artifacts
echo "::group::[rsync] msys2-artifacts"
rsync -av ${SS_USER}@${SSH_HOST}:/srv/repo/x86_64/msys2/ .
echo "::endgroup::"
popd

pushd posix-artifacts
echo "::group::[rsync] posix-artifacts"
rsync -av ${SS_USER}@${SSH_HOST}:/srv/repo/x86_64/posix/ .
echo "::endgroup::"
popd
