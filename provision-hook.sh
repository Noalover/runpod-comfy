#!/usr/bin/env bash
set -e

echo "[provision-hook] starting"

if [[ -z "${PROVISIONING_SCRIPT:-}" ]]; then
    echo "[provision-hook] PROVISIONING_SCRIPT not set"
    exit 0
fi

curl -fL \
    --retry 5 \
    --retry-delay 3 \
    "$PROVISIONING_SCRIPT" \
    -o /tmp/provision.sh

chmod +x /tmp/provision.sh

export COMFY_WORKSPACE="/workspace/runpod-slim/ComfyUI"
export PYTHON_BIN="/workspace/runpod-slim/ComfyUI/.venv-cu128/bin/python"
export PIP_BIN="/workspace/runpod-slim/ComfyUI/.venv-cu128/bin/pip"

/tmp/provision.sh

echo "[provision-hook] complete"
