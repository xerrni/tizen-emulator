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

#reliable solution to find script location, works with symlinks
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
    SCRIPT_DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
SCRIPT_DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"


CONTAINER_TEMPLATE="${LXD_CONFIG_FILE:-${SCRIPT_DIR}/container-template.yaml}"
LXD_CONTAINER_NAME="${LXD_CONTAINER_NAME:-tizen-emu}"
LXD_INIT_SCRIPT="${LXD_INIT_SCRIPT:-${SCRIPT_DIR}/container-init.sh}"
TIZEN_USER="${TIZEN_USER:-$USER}"

echo "lcf: $CONTAINER_TEMPLATE lcn: $LXD_CONTAINER_NAME lcis: $LXD_INIT_SCRIPT"

if [ "$(lxc profile list --format csv | grep -cE '^tizen-emulator,.*$')" != 1 ]; then
	lxc profile create tizen-emulator
	lxc profile edit tizen-emulator < "$CONTAINER_TEMPLATE"
fi
if [ "$(lxc list --columns n --format csv | grep -cE "^${LXD_CONTAINER_NAME}$")" != "1" ]; then
	echo "launching lxd container"
	# all used profiles should be specified
	lxc launch ubuntu:18.04 "${LXD_CONTAINER_NAME}" --profile tizen-emulator --profile default
else
	echo "lxd container has been already downloaded"
fi

if [ "$(lxc list --columns ns --format csv "${LXD_CONTAINER_NAME}" |\
		grep -cE "^${LXD_CONTAINER_NAME},RUNNING$")" != "1" ]; then
	echo "starting lxd container"
	lxc start "${LXD_CONTAINER_NAME}"
else
	echo "lxd container has been already started"
fi

if [ ! -f ".ssh/id_rsa" ] || [ ! -f ".ssh/id_rsa.pub" ]; then
	echo "Please provide ssh key that will be used to authenticate with review.tizen.org"
	echo "keys location: $SCRIPT_DIR/.ssh/id_rsa $SCRIPT_DIR/.ssh/id_rsa.pub"
	exit 1
fi
echo "pushing initialization script to container"
LXD_INIT_SCRIPT_NAME=$(basename -- "${LXD_INIT_SCRIPT}")
lxc file push "${LXD_INIT_SCRIPT}" "${LXD_CONTAINER_NAME}/home/ubuntu/${LXD_INIT_SCRIPT_NAME}"
lxc exec "${LXD_CONTAINER_NAME}" -- sudo --user ubuntu --login mkdir -p /home/ubuntu/.ssh
lxc file push "${SCRIPT_DIR}/.ssh/id_rsa"     "${LXD_CONTAINER_NAME}/home/ubuntu/.ssh/"
lxc file push "${SCRIPT_DIR}/.ssh/id_rsa.pub" "${LXD_CONTAINER_NAME}/home/ubuntu/.ssh/"

lxc exec "${LXD_CONTAINER_NAME}" -- chmod +x "/home/ubuntu/${LXD_INIT_SCRIPT_NAME}"
lxc exec "${LXD_CONTAINER_NAME}" -- sudo --user ubuntu --login \
	"TIZEN_USER=$TIZEN_USER" "/home/ubuntu/${LXD_INIT_SCRIPT_NAME}"
