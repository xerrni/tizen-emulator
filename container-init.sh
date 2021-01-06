#!/bin/bash
# Copyright (c) 2021, Ernest Borowski, All rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA
#
# Author: Ernest Borowski <e.borowski+git@protonmail.com>
#
set -o errexit
trap 'echo "Aborting due to errexit on line $LINENO. Exit code: $?" >&2' ERR
set -o errtrace
set -e -o pipefail
set -x

if [ "$(command -v sudo)" ]; then
    SUDO="sudo"
else
    SUDO=""
fi
TIZEN_USER="${TIZEN_USER:-$USER}"
# install git, unzip, aria2c
pkgs="$(comm -13 <(dpkg-query -f '${binary:Package}\n' -W | sort) \
    <(echo -e "git\nmake\nunzip\naria2\nmesa-utils\npulseaudio\nx11-apps\nlynx" | sort) |\
    tr "\n" " ")"
if [ "$pkgs" != "" ]; then
    echo "Installing packages: <$pkgs>"
    "$SUDO" apt-get -y update
    # shellcheck disable=SC2086
    "$SUDO" apt-get -y install $pkgs
else
    echo "[Info] All packages were already installed."
fi

cd
if [ ! -d "security-tests" ]; then
    # It is needed so git won't prompt user for ssh fingerprint confirmation.
    ssh_fingerprint="$(ssh-keyscan -p 29418 review.tizen.org 2>&1 | grep -vE "^#.*$")"
    echo "[Info] ssh_fingerprint: ${ssh_fingerprint}"
    grep -qxF "${ssh_fingerprint}" ~/.ssh/known_hosts || \
        echo "${ssh_fingerprint}" >> ~/.ssh/known_hosts

	git clone "ssh://$TIZEN_USER@review.tizen.org:29418/platform/core/test/security-tests"
	cd security-tests
	git fetch "ssh://$TIZEN_USER@review.tizen.org:29418/platform/core/test/security-tests" \
		refs/changes/30/227530/5 && git checkout FETCH_HEAD

	mkdir testing_env/ubnt-18
	cd testing_env/ubnt-18
	unzip ../debs_Ubuntu_18.04_LTS.zip

	"$SUDO" dpkg -i ./*.deb || echo "dpkg found broken dependencies"
	"$SUDO" apt-get -y update
	"$SUDO" apt-get --fix-broken -y install

	if [ ! -d "$HOME/tes" ]; then
		mkdir ~/tes
		cd ~/tes
		unzip "$HOME/security-tests/testing_env/tizen-emulator-scripts.zip"
	fi
	# modprobe inside container will fail, it has to be executed on host machine
	# lxd container profile template already has it specified so it will be automatically
	# inserted before container starts
	find "$HOME/tes" -type f -name '*.sh' -exec \
		sed -i -E 's|^\s*modprobe nbd\s*$|& \|\| echo \"unable to modprobe\"|' {} \;
fi

CMDS=("chmod o+w /dev/stdout"
	  "chmod o+w /dev/stderr"
	  "chmod 666 /dev/kvm")
for cmd in "${CMDS[@]}"; do
	if ! grep -q "$cmd" "$HOME/.bashrc"; then
		echo "$SUDO $cmd" >> "$HOME/.bashrc"
	fi
done

echo "For sample usage please reffer to README.md file inside repository."
