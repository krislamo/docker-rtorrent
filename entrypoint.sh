#!/bin/bash
set -eu

# GID/UID
USER_ID=${GUID:-1000}
GROUP_ID=${PGID:-1000}

# Create group/user
getent group rtorrent >/dev/null || groupadd -g "$GROUP_ID" rtorrent
id -u rtorrent &>/dev/null || \
    useradd -m -u "$USER_ID" -g rtorrent -s /bin/bash rtorrent

# Update group/user IDs
groupmod -o -g "$GROUP_ID" rtorrent
usermod -o -u "$USER_ID" rtorrent 2>/dev/null

# Copy default config
if [ ! -e /home/rtorrent/.rtorrent.rc ]; then
    cp /tmp/rtorrent.rc.template /home/rtorrent/.rtorrent.rc
    chown rtorrent:rtorrent /home/rtorrent/.rtorrent.rc
fi

# Execute as the rtorrent user
su - rtorrent -c "rtorrent"
