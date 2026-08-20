#!/bin/bash

# Default to the local orchestrator daemon; callers may override.
export ORCHESTRATOR_API="${ORCHESTRATOR_API:-http://127.0.0.1:3000/api}"

exec "${SNAP}/usr/bin/setpriv" \
    --clear-groups \
    --reuid snap_daemon \
    --regid snap_daemon \
    -- \
    "${SNAP}/usr/bin/orchestrator-client" "$@"
