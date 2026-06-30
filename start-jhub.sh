#!/bin/bash
set -e

# Replicate what s6-overlay's 01-copy-tmp-home init did
if [ -d /tmp_home/jovyan ] && [ "$(ls -A /tmp_home/jovyan 2>/dev/null)" ]; then
    echo "INFO: Copying contents of '/tmp_home/jovyan' to '/home/jovyan'..."
    cp -rn /tmp_home/jovyan/. /home/jovyan/
fi

# exec replaces this shell — CMD inherits the full Kubernetes environment
exec "$@"