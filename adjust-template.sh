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

LXD_CONTAINER_TEMP="${LXD_CONTAINER_TEMP:-${SCRIPT_DIR}/container-template.yaml}"

UUID="$(id -u)"
GGID="$(id -g)"

# Adjust GID and UID in template to current user GID and UID
rm -f "${LXD_CONTAINER_TEMP}.bak"
cp "$LXD_CONTAINER_TEMP" "${LXD_CONTAINER_TEMP}.bak"

# use sed backreferences - s/()/\1/
sed -i -E "s|(\s+security.uid: ).*|\1\"$UUID\"|" "${LXD_CONTAINER_TEMP}.bak"
sed -i -E "s|(\s+security.gid: ).*|\1\"$GGID\"|" "${LXD_CONTAINER_TEMP}.bak"
sed -i -E "s|(\s+uid: ).*|\1\"$UUID\"|" "${LXD_CONTAINER_TEMP}.bak"
sed -i -E "s|(\s+gid: ).*|\1\"$GGID\"|" "${LXD_CONTAINER_TEMP}.bak"
sed -i -E "s|(connect: unix:/run/user/)[0-9]+(/pulse/native.*)|\1$UUID\2|" \
	"${LXD_CONTAINER_TEMP}.bak"


XORG_REG="^/tmp/.X11-unix/X[0-9]+$"
if [ "$(find /tmp/.X11-unix/ -type s -regex "$XORG_REG" | wc -l)" == "1" ]; then
	X11_SOCKET="$(find /tmp/.X11-unix/ -type s -regex "$XORG_REG")"
	sed -i -E "s|(\s+connect: unix:\@)/tmp/.X11-unix/X0.*|\1$X11_SOCKET|" \
		"${LXD_CONTAINER_TEMP}.bak"
else
	echo "Unable to determine Xorg socket file path, please manually adjust ${LXD_CONTAINER_TEMP} file."
	echo "line: devices->X0->connect"
	echo "connect: unix:@/tmp/.X11-unix/X0"
fi

echo "Script result: "
diff "${LXD_CONTAINER_TEMP}" "${LXD_CONTAINER_TEMP}.bak" || \
	echo "Script did not have to update template"
mv "${LXD_CONTAINER_TEMP}.bak" "${LXD_CONTAINER_TEMP}"
