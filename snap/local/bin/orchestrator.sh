#!/bin/bash

set -eo pipefail  # Exit on error

# Orchestrator serves its web UI from ./resources relative to the working
# directory, so run from the snap's orchestrator tree.
cd "${SNAP}/usr/local/orchestrator"

exec "${SNAP}/usr/bin/setpriv" \
    --clear-groups \
    --reuid snap_daemon \
    --regid snap_daemon \
    -- \
    ./orchestrator --config "${SNAP_DATA}/etc/orchestrator.conf.json" http
