#!/bin/bash
set -eux

# GID/UID
USER_ID=${GUID:-1000}
GROUP_ID=${PGID:-1000}

# Create group/user
getent group rtorrent >/dev/null || groupadd -g "$GROUP_ID" rtorrent
id -u rtorrent &>/dev/null || \
    useradd -m -u "$USER_ID" -g rtorrent -s /bin/bash rtorrent

# Update group/user IDs
groupmod -o -g "$GROUP_ID" rtorrent
usermod -o -u "$USER_ID" rtorrent &>/dev/null

# Copy default config
if [ ! -e /home/rtorrent/.rtorrent.rc ]; then
    cp /tmp/rtorrent.rc.template /home/rtorrent/.rtorrent.rc
    chown rtorrent:rtorrent /home/rtorrent/.rtorrent.rc
fi

# Trap for graceful shutdown
trap 'su - rtorrent -c "screen -S rtorrent -X stuff \"^Q\015\""; wait $SCREEN_PID' SIGTERM

# Start rtorrent in a detached screen session
su - rtorrent -c "screen -dmS rtorrent rtorrent" &

# Wait for the su process to finish
wait $!

# Find screen PID and monitor it
SCREEN_PID=$(pgrep -f "SCREEN -dmS rtorrent")

# Keep the script running until the screen session ends
tail --pid="$SCREEN_PID" -f /dev/null

exit 0