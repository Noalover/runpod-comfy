#!/usr/bin/env bash
set -euo pipefail

echo "[wrapper] provisioning start"

if [[ -z "${PROVISIONING_SCRIPT:-}" ]]; then
    echo "[wrapper] PROVISIONING_SCRIPT is empty"
    exit 0
fi

curl -fL \
    --retry 5 \
    --retry-delay 3 \
    "$PROVISIONING_SCRIPT" \
    -o /tmp/provision.sh

chmod +x /tmp/provision.sh

export COMFY_WORKSPACE="/workspace/runpod-slim/ComfyUI"
export PYTHON_BIN="${COMFY_WORKSPACE}/.venv-cu128/bin/python"
export PIP_BIN="${COMFY_WORKSPACE}/.venv-cu128/bin/pip"

/tmp/provision.sh

echo "[wrapper] provisioning complete"
