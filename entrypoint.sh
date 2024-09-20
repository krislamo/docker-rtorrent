#!/bin/bash
set -eu

# Polling interval
SLEEP_INTERVAL=${SLEEP_INTERVAL:-2}

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

# Start rtorrent in a detached screen session
su - rtorrent -c "screen -dmS rtorrent rtorrent" &

# Wait for the su process to finish
wait $!

# Find rtorrent PID and monitor it
RTORRENT_PID="$(pgrep -f "^rtorrent$")"

# Trap for graceful shutdown
trap 'su - rtorrent -c "kill -15 $RTORRENT_PID"' SIGTERM SIGINT

# Wait for PID
while kill -0 "$RTORRENT_PID" 2>/dev/null; do sleep "$SLEEP_INTERVAL"; done
exit 0
