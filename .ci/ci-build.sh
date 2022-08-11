#!/bin/bash

set -eo pipefail

# AppVeyor and Drone Continuous Integration for MSYS2
# Author: Renato Silva <br.renatosilva@gmail.com>
# Author: Qian Hong <fracting@gmail.com>

DIR="$( cd "$( dirname "$0" )" && pwd )"

# Configure
source "$DIR/ci-library.sh"
mkdir msys2-artifacts posix-artifacts
git_config user.email 'ci@users.noreply.github.com'
git_config user.name  'Gwinux Continuous Integration'
git remote add upstream 'https://github.com/gwinux/POSIX-packages'
git fetch --quiet upstream
# reduce time required to install packages by disabling pacman's disk space checking
sed -i 's/^CheckSpace/#CheckSpace/g' /etc/pacman.conf

pacman --noconfirm -Fy

# Detect
list_commits  || failure 'Could not detect added commits'
list_packages || failure 'Could not detect changed files'
message 'Processing changes' "${commits[@]}"
test -z "${packages}" && success 'No changes in package recipes'

# Build
message 'Building packages' "${packages[@]}"
execute 'Approving recipe quality' check_recipe_quality

message 'Adding an empty local repository'
repo-add $PWD/msys2-artifacts/ci.db.tar.gz
sed -i '1s|^|[ci]\nServer = file://'"$PWD"'/msys2-artifacts/\nSigLevel = Never\n|' /etc/pacman.conf
pacman -Sy

message 'Building packages'
for package in "${packages[@]}"; do
    start_group BUILD "${package}"
    execute 'Fetch keys' "$DIR/fetch-validpgpkeys.sh"
    # Ensure the toolchain is installed before building the package
    execute 'Installing the toolchain' pacman -S --needed --noconfirm --noprogressbar base-devel
    message 'Bump pkgrel version' 
    awk -i inplace -F '=' '/^pkgrel=/ {print $1"="++$2; next;};{print}' "${package}/PKGBUILD"
    execute 'Building binary' makepkg --noconfirm --noprogressbar --nocheck --syncdeps --rmdeps --cleanbuild
    execute 'Building source' makepkg --noconfirm --noprogressbar --allsource
    message "Skipping posix package: ${package}"
    
    msys2_pkg=()
    for pkg in "${package}"/*.pkg.tar.*; do 
        if [[ ${pkg} =~ "${package}"/posix* ]]; then
            mv ${pkg} posix-artifacts
        else
            msys2_pkg+=(${pkg})
        fi
    done

    if [ ${#msys2_pkg[@]} -eq 0 ]; then
        unset package msys2_pkg
        continue
    fi 

    end_group

    if compgen -G "${package}/*.pkg.tar.*" > /dev/null; then continue; fi

    if [ -f $package/.ci-sequential ]; then
        cd "$package"
        for pkg in *.pkg.tar.*; do
            pkgname="$(echo "$pkg" | rev | cut -d- -f4- | rev)"
            start_group INSTALL "${pkgname}"
            grep -qFx "${package}" "$DIR/ci-dont-install-list.txt" || pacman --noprogressbar --upgrade --noconfirm $pkg
            end_group

            start_group DIFF "${pkgname}"
            message "Package info diff for ${pkgname}"
            diff -Nur <(pacman -Si "${pkgname}") <(pacman -Qip "${pkg}") || true

            message "File listing diff for ${pkgname}"
            diff -Nur <(pacman -Fl "$pkgname" | sed -e 's|^[^ ]* |/|' | sort) <(pacman -Ql "$pkgname" | sed -e 's|^[^/]*||' | sort) || true
            end_group

            start_group UNINSTALL "${pkgname}"
            message "Uninstalling $pkgname"
            repo-add $PWD/../msys2-artifacts/ci.db.tar.gz $PWD/$pkg
            pacman -Sy
            pacman -R --recursive --unneeded --noconfirm --noprogressbar "$pkgname"
            end_group
        done
        cd - > /dev/null
    else
        start_group INSTALL "${package}"
        grep -qFx "${package}" "$DIR/ci-dont-install-list.txt" || execute 'Installing' install_packages
        end_group

        start_group DIFF "${package}"
        cd "$package"
        for pkg in *.pkg.tar.*; do
            pkgname="$(echo "$pkg" | rev | cut -d- -f4- | rev)"
            message "Package info diff for ${pkgname}"
            diff -Nur <(pacman -Si "${pkgname}") <(pacman -Qip "${pkg}") || true

            message "File listing diff for ${pkgname}"
            diff -Nur <(pacman -Fl "$pkgname" | sed -e 's|^[^ ]* |/|' | sort) <(pacman -Ql "$pkgname" | sed -e 's|^[^/]*||' | sort) || true
        done
        cd - > /dev/null
        end_group

        start_group "DLL CHECK" "${package}"
        execute 'Checking dll depencencies' list_dll_deps ./pkg
        execute 'Checking dll bases' list_dll_bases ./pkg
        end_group

        start_group UNINSTALL "${package}"
        repo-add $PWD/msys2-artifacts/ci.db.tar.gz "${package}"/*.pkg.tar.*
        pacman -Sy
        message "Uninstalling $package"
        cd "$package"
        export installed_packages=()
        for pkg in *.pkg.tar.*; do
            installed_packages+=("$(echo "$pkg" | rev | cut -d- -f4- | rev)")
        done
        grep -qFx "${package}" "$DIR/ci-dont-install-list.txt" || pacman -R --recursive --unneeded --noconfirm --noprogressbar "${installed_packages[@]}"
        unset installed_packages
        cd - > /dev/null
        end_group
    fi

    mv "${package}"/*.pkg.tar.* msys2-artifacts
    mv "${package}"/*.src.tar.* msys2-artifacts
    unset package
done
success 'All packages built successfully'

cd msys2-artifacts
execute 'SHA-256 checksums' sha256sum *
