#!/bin/bash
set -eu

# GID/UID
USER_ID=${GUID:-1000}
GROUP_ID=${PGID:-1000}

# Polling interval
SLEEP_INTERVAL=${SLEEP_INTERVAL:-2}

# Gluetun config
GLUETUN_FORWARD=${GLUETUN_FORWARD:-false}
GLUETUN_TIMEOUT=${GLUETUN_TIMEOUT:-120}
GLUETUN_INITIAL_DELAY=${GLUETUN_INITIAL_DELAY:-5}

# rtorrent runtime config
RTORRENT_RC=${RTORRENT_RC:-/home/rtorrent/.rtorrent.rc}
RTORRENT_PREFIX=${RTORRENT_PREFIX:-SETTING_}

# Debug
DEBUG=${DEBUG:-false}
DEBUG_DIRECT=${DEBUG_DIRECT:-false}
if [ "$DEBUG" = "true" ]; then
    set -x
fi

# Create group/user
getent group rtorrent >/dev/null || groupadd -g "$GROUP_ID" rtorrent
id -u rtorrent &>/dev/null || \
    useradd -m -u "$USER_ID" -g rtorrent -s /bin/bash rtorrent

# Update group/user IDs
groupmod -o -g "$GROUP_ID" rtorrent
usermod -o -u "$USER_ID" rtorrent &>/dev/null

# Copy default config
if [ ! -e "$RTORRENT_RC" ]; then
    cp /tmp/rtorrent.rc.template "$RTORRENT_RC"
    chown rtorrent:rtorrent "$RTORRENT_RC"
    echo "INFO: Copied template .rtorrent.rc"
fi

# Optionally set forwarded port from Gluetun
if [ "$GLUETUN_FORWARD" = "true" ]; then

    # Is the port range already set?
    if grep -q "^SETTING_network__port_range__set" < <(env); then
        echo "[ERROR]: GLUETUN_FORWARD and SETTING_network__port_range__set is set"
        exit 1
    fi

    # Check if GLUETUN_IP is already set
    if [ -n "${GLUETUN_IP+x}" ]; then
        echo "[ERROR]: GLUETUN_IP is already set"
        exit 1
    fi

    sleep "$GLUETUN_INITIAL_DELAY"
    GLUETUN_START_TIME="$(date +%s)"

    while true; do
        GLUETUN_CURRENT_TIME="$(date +%s)"
        GLUETUN_DIFF_TIME="$((GLUETUN_CURRENT_TIME - GLUETUN_START_TIME))"

        # Timeout check
        if [ "$GLUETUN_DIFF_TIME" -ge "$GLUETUN_TIMEOUT" ]; then
            echo "[ERROR]: Waited $DIFF_TIME/$GLUETUN_TIMEOUT seconds for Gluetun values"
            exit 1
        fi

        # Check forwarded_port and IP
        if [ -f /tmp/gluetun/forwarded_port ]; then
            FORWARDED_PORT="$(cat /tmp/gluetun/forwarded_port)"
            if [ -n "$FORWARDED_PORT" ] && [ "$FORWARDED_PORT" != "0" ]; then
                if [ -f /tmp/gluetun/ip ]; then
                    GLUETUN_IP=$(cat /tmp/gluetun/ip)
                    if [ -n "$GLUETUN_IP" ] && [ "$GLUETUN_IP" != "" ]; then
                        break
                    fi
                fi
            fi
        fi

        # Waiting
        echo "Waiting ($GLUETUN_DIFF_TIME/$GLUETUN_TIMEOUT seconds) for Gluetun values"
        sleep 5
    done

    # Set range
    # shellcheck disable=SC2034
    export SETTING_network__port_range__set="${FORWARDED_PORT}-${FORWARDED_PORT}"
fi

# Replace key/values
while IFS='=' read -r ENVVAR VALUE; do
    if [[ $ENVVAR == ${RTORRENT_PREFIX}* ]]; then
        KEY="${ENVVAR#"$RTORRENT_PREFIX"}"
        KEY="${KEY//__/.}"
        if ! grep -q "^${KEY}" "$RTORRENT_RC"; then
            echo "[WARN]: \"$KEY\" does not exist in $RTORRENT_RC and was not updated"
        else
            if [ "$DEBUG" = "true" ]; then
                echo "[DEBUG] Updating \"$KEY\" to \"$VALUE\""
            fi
            sed -i "s|^${KEY}.*|${KEY} = ${VALUE}|" "$RTORRENT_RC"
        fi
    else
        if [ "$DEBUG" = "true" ]; then
            echo "[DEBUG] \"$ENVVAR\" doesn't have the prefix \"$RTORRENT_PREFIX\""
        fi
    fi
done < <(env)

# See final config if DEBUG
if [ "$DEBUG" = "true" ]; then
    cat "$RTORRENT_RC"
fi

# Start rtorrent in a detached screen session
# NOTE: Running without a screen isn't supported but might output config errors
if [ ! "$DEBUG_DIRECT" = "true" ]; then
    su - rtorrent -c "screen -dmS rtorrent rtorrent" &
else
    su - rtorrent -c "rtorrent" &
fi

# Wait for the su process to finish
wait $!

# Find rtorrent PID and monitor it
RTORRENT_PID="$(pgrep -f "^rtorrent$")"

# Trap for graceful shutdown
trap 'su - rtorrent -c "kill -15 $RTORRENT_PID"' SIGTERM SIGINT

# Wait for PID
[ "$DEBUG" = "true" ] && set +x
while kill -0 "$RTORRENT_PID" 2>/dev/null; do sleep "$SLEEP_INTERVAL"; done
exit 0
