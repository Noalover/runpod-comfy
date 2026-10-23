#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# LOGGING
# ============================================================

mkdir -p /workspace
exec > >(tee -a /workspace/provision_debug.log) 2>&1

log(){ echo "[provision] $*"; }

env_len() {
  local var_name="$1"
  local value="${!var_name:-}"
  echo "${#value}"
}

log "SCRIPT STARTED at $(date)"
log "whoami=$(whoami)"
log "pwd=$(pwd)"
log "WORKSPACE=${WORKSPACE:-unset}"
log "COMFY_WORKSPACE=${COMFY_WORKSPACE:-unset}"
log "CIVITAI_TOKEN length=$(env_len CIVITAI_TOKEN)"
log "CIVITAI_API_KEY length=$(env_len CIVITAI_API_KEY)"
log "HF_TOKEN length=$(env_len HF_TOKEN)"
log "HUGGINGFACE_HUB_TOKEN length=$(env_len HUGGINGFACE_HUB_TOKEN)"

# ============================================================
# USER CONFIG
# ============================================================

APT_PACKAGES=(
  "aria2"
  "curl"
  "wget"
  "git"
  "file"
)

PIP_PACKAGES=(
  "gdown"
)

NODES=(
  "https://github.com/ltdrdata/ComfyUI-Manager"
  "https://github.com/cubiq/ComfyUI_essentials"
  "https://github.com/AlekPet/ComfyUI_Custom_Nodes_AlekPet"
  "https://github.com/kijai/ComfyUI-KJNodes"
  "https://github.com/rgthree/rgthree-comfy"
  "https://github.com/NyaamZ/efficiency-nodes-ED"
  "https://github.com/pythongosssss/ComfyUI-Custom-Scripts"
  "https://github.com/willmiao/ComfyUI-Lora-Manager"
  "https://github.com/ssitu/ComfyUI_UltimateSDUpscale"
  "https://github.com/jags111/efficiency-nodes-comfyui"
  "https://github.com/kohya-ss/ComfyUI-Anima-LLLite"
  "https://github.com/ltdrdata/ComfyUI-Impact-Pack"
  "https://github.com/ltdrdata/ComfyUI-Impact-Subpack"
  "https://github.com/yolain/ComfyUI-Easy-Sam3"
  "https://github.com/alisson-anjos/ComfyUI-BFSNodes"
  "https://github.com/numz/ComfyUI-SeedVR2_VideoUpscaler"
  "https://github.com/darksidewalker/ComfyUI-DaSiWa-Nodes"
)

CHECKPOINT_MODELS=(
  #"https://civitai.com/api/download/models/1555027?type=Model&format=SafeTensor"
  "https://civitai.com/api/download/models/2167369?type=Model&format=SafeTensor&size=pruned&fp=fp16"
)

# SAM 3.1:
# Keep one physical copy in models/checkpoints.
# Easy-SAM3 gets a symlink later.
SAM31_MODELS=(
  "https://huggingface.co/Comfy-Org/sam3.1/resolve/main/checkpoints/sam3.1_multiplex_fp16.safetensors"
)

CLIP_VISION_MODELS=(
)

UNET_MODELS=(
  #"https://civitai.com/api/download/models/2513182?type=Model&format=SafeTensor&size=pruned&fp=fp8"
)

LORA_MODELS=(
  #"https://civitai.com/api/download/models/2553688?type=Model&format=SafeTensor"
  "https://civitai.com/api/download/models/3089149?fileId=2968664"
)

VAE_MODELS=(
  #"https://civitai.com/api/download/models/155933?type=Model&format=SafeTensor"
  "https://huggingface.co/circlestone-labs/Anima/resolve/main/split_files/vae/qwen_image_vae.safetensors?download=true"
  "https://huggingface.co/Tongyi-MAI/Z-Image-Turbo/resolve/main/vae/diffusion_pytorch_model.safetensors"
  "https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/vae/minimax_h3_audio_vae_fp32.safetensors"
  "https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/vae/minimax_h3_video_vae_fp16.safetensors"
  "https://huggingface.co/Comfy-Org/Qwen-Image-2.1/resolve/main/vae/qwen_image_2.1_vae_bf16.safetensors"
)

UPSCALE_MODELS=(
  "https://huggingface.co/Kim2091/2x-AnimeSharpV4/resolve/main/2x-AnimeSharpV4_RCAN.safetensors"
  "https://github.com/the-database/MangaJaNai/releases/download/3.0.0/IllustrationJaNai_V3detail.zip"
  #"https://huggingface.co/uwg/upscaler/resolve/main/ESRGAN/4x_NMKD-Siax_200k.pth"
)

# SeedVR2 custom-node models.
SEEDVR2_MODELS=(
  "https://huggingface.co/AInVFX/SeedVR2_comfyUI/resolve/main/seedvr2_ema_7b_fp8_e4m3fn_mixed_block35_fp16.safetensors"
  "https://huggingface.co/numz/SeedVR2_comfyUI/resolve/main/ema_vae_fp16.safetensors"
)

CONTROLNET_MODELS=(
  #"https://huggingface.co/kohya-ss/Anima-LLLite/resolve/main/anima-lllite-any-test-like-v2.safetensors"
  "https://huggingface.co/kohya-ss/Anima-LLLite/resolve/main/anima-lllite-inpainting-v2.safetensors"
  "https://huggingface.co/kohya-ss/Anima-LLLite/resolve/main/anima-lllite-exp-change-2-000007.safetensors"
)

DIFFUSION_MODELS=(
  #"https://civitai.com/api/download/models/3201770?fileId=3083049"
  #"https://huggingface.co/circlestone-labs/Anima/resolve/main/split_files/diffusion_models/anima-base-v1.0.safetensors"
  #"https://civitai.com/api/download/models/3075206?fileId=2954323"
  #"https://civitai.com/api/download/models/3112659?fileId=2992771"
  #"https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/diffusion_models/minimax_h3_fl2va_pruned_int8_convrot.safetensors"
  "https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/diffusion_models/minimax_h3_ref2va_pruned_int8_convrot.safetensors"
  "https://civitai.com/api/download/models/3314675?fileId=3203130"
  "https://civitai.com/api/download/models/3209007?fileId=3090690"
  "https://huggingface.co/Comfy-Org/Qwen-Image-2.1/resolve/main/diffusion_models/qwen_image_2.1_int8_convrot.safetensors"
  #"https://civitai.com/api/download/models/3270517?fileId=3163985"
)

TEXT_ENCODER_MODELS=(
  "https://huggingface.co/circlestone-labs/Anima/resolve/main/split_files/text_encoders/qwen_3_06b_base.safetensors?download=true"

  #"https://huggingface.co/Qwen/Qwen3-4B-GGUF/resolve/main/Qwen3-4B-Q6_K.gguf"

  "https://huggingface.co/Comfy-Org/Krea-2/resolve/main/text_encoders/qwen3vl_4b_fp8_scaled.safetensors"

  "https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/text_encoders/qwen3vl_32b_minimax_h3_int8_convrot.safetensors"

  "https://huggingface.co/Comfy-Org/Qwen-Image-2.1/resolve/main/text_encoders/qwen3vl_8b_int8_convrot.safetensors?download=true"
)

# ============================================================
# INTERNAL CONFIG
# ============================================================

WORKSPACE="${WORKSPACE:-/workspace}"

# ------------------------------------------------------------
# ComfyUI path auto detection
#
# Priority:
# 1. Explicit COMFY_WORKSPACE supplied by wrapper/environment
# 2. RunPod official ComfyUI
# 3. Vast / AI-Dock workspace install
# 4. Vast / AI-Dock internal install
# ------------------------------------------------------------

if [[ -n "${COMFY_WORKSPACE:-}" ]]; then
  :
elif [[ -f "/workspace/runpod-slim/ComfyUI/main.py" ]]; then
  COMFY_WORKSPACE="/workspace/runpod-slim/ComfyUI"
elif [[ -f "/workspace/ComfyUI/main.py" ]]; then
  COMFY_WORKSPACE="/workspace/ComfyUI"
else
  COMFY_WORKSPACE="/workspace/ComfyUI"
fi

INTERNAL_COMFY="${INTERNAL_COMFY:-/opt/workspace-internal/ComfyUI}"

log "Resolved COMFY_WORKSPACE=$COMFY_WORKSPACE"
log "INTERNAL_COMFY=$INTERNAL_COMFY"

# ------------------------------------------------------------
# Python / pip auto detection
#
# Supports:
# - Explicit wrapper supplied Python/Pip
# - RunPod CUDA 13
# - RunPod CUDA 12.8
# - Generic .venv
# - Vast AI-Dock
# - RunPod AI-Dock
# ------------------------------------------------------------

if [[ -n "${PYTHON_BIN:-}" && -x "${PYTHON_BIN}" ]]; then
  :

elif [[ -x "${COMFY_WORKSPACE}/.venv-cu130/bin/python" ]]; then
  PYTHON_BIN="${COMFY_WORKSPACE}/.venv-cu130/bin/python"

elif [[ -x "${COMFY_WORKSPACE}/.venv-cu128/bin/python" ]]; then
  PYTHON_BIN="${COMFY_WORKSPACE}/.venv-cu128/bin/python"

elif [[ -x "${COMFY_WORKSPACE}/.venv/bin/python" ]]; then
  PYTHON_BIN="${COMFY_WORKSPACE}/.venv/bin/python"

elif [[ -x "/venv/main/bin/python" ]]; then
  PYTHON_BIN="/venv/main/bin/python"

elif [[ -x "/opt/environments/python/comfyui/bin/python" ]]; then
  PYTHON_BIN="/opt/environments/python/comfyui/bin/python"

else
  PYTHON_BIN="$(command -v python3 || command -v python || true)"
fi

if [[ -n "${PIP_BIN:-}" && -x "${PIP_BIN}" ]]; then
  :

elif [[ -x "${COMFY_WORKSPACE}/.venv-cu130/bin/pip" ]]; then
  PIP_BIN="${COMFY_WORKSPACE}/.venv-cu130/bin/pip"

elif [[ -x "${COMFY_WORKSPACE}/.venv-cu128/bin/pip" ]]; then
  PIP_BIN="${COMFY_WORKSPACE}/.venv-cu128/bin/pip"

elif [[ -x "${COMFY_WORKSPACE}/.venv/bin/pip" ]]; then
  PIP_BIN="${COMFY_WORKSPACE}/.venv/bin/pip"

elif [[ -n "${PYTHON_BIN:-}" && -x "$(dirname "${PYTHON_BIN}")/pip" ]]; then
  PIP_BIN="$(dirname "${PYTHON_BIN}")/pip"

elif [[ -x "/venv/main/bin/pip" ]]; then
  PIP_BIN="/venv/main/bin/pip"

elif [[ -x "/opt/environments/python/comfyui/bin/pip" ]]; then
  PIP_BIN="/opt/environments/python/comfyui/bin/pip"

else
  PIP_BIN="$(command -v pip3 || command -v pip || true)"
fi

if [[ -z "${PYTHON_BIN:-}" || ! -x "${PYTHON_BIN}" ]]; then
  log "ERROR: No usable Python interpreter found"
  exit 1
fi

if [[ -z "${PIP_BIN:-}" || ! -x "${PIP_BIN}" ]]; then
  log "ERROR: No usable pip executable found"
  exit 1
fi

log "PYTHON_BIN=$PYTHON_BIN"
log "PIP_BIN=$PIP_BIN"

APT_INSTALL="${APT_INSTALL:-apt-get install -y --no-install-recommends}"

NODE_REQ_FAILS=()
MODEL_DL_FAILS=()

FAIL_ON_MODEL_DL="${FAIL_ON_MODEL_DL:-0}"

# Network / install robustness.
GIT_TIMEOUT="${GIT_TIMEOUT:-180}"
GIT_RETRIES="${GIT_RETRIES:-3}"
PIP_REQ_TIMEOUT="${PIP_REQ_TIMEOUT:-900}"

# Civitai large-file downloader tuning.
# aria2 uses multiple ranged connections so one bad CDN connection does not
# drag a 20GB+ model down to a few hundred KB/s.
CIVITAI_ARIA2_CONNECTIONS="${CIVITAI_ARIA2_CONNECTIONS:-8}"
CIVITAI_ARIA2_SPLIT="${CIVITAI_ARIA2_SPLIT:-8}"
CIVITAI_ARIA2_MIN_SPLIT_SIZE="${CIVITAI_ARIA2_MIN_SPLIT_SIZE:-4M}"
CIVITAI_CONNECT_TIMEOUT="${CIVITAI_CONNECT_TIMEOUT:-15}"
CIVITAI_IO_TIMEOUT="${CIVITAI_IO_TIMEOUT:-30}"
CIVITAI_MAX_TRIES="${CIVITAI_MAX_TRIES:-20}"
CIVITAI_RETRY_WAIT="${CIVITAI_RETRY_WAIT:-3}"
CIVITAI_LOWEST_SPEED_LIMIT="${CIVITAI_LOWEST_SPEED_LIMIT:-64K}"
CIVITAI_PROBE_TIMEOUT="${CIVITAI_PROBE_TIMEOUT:-30}"

# Host preflight.
HOST_PREFLIGHT="${HOST_PREFLIGHT:-1}"
PREFLIGHT_ATTEMPTS="${PREFLIGHT_ATTEMPTS:-2}"
PREFLIGHT_CONNECT_TIMEOUT="${PREFLIGHT_CONNECT_TIMEOUT:-8}"
PREFLIGHT_TOTAL_TIMEOUT="${PREFLIGHT_TOTAL_TIMEOUT:-25}"

# Reject instances with too little model storage.
PREFLIGHT_MIN_FREE_GB="${PREFLIGHT_MIN_FREE_GB:-100}"

# Remove legacy HF caches.
CLEAN_LEGACY_HF_CACHE="${CLEAN_LEGACY_HF_CACHE:-1}"
LEGACY_HF_CACHE_DIR="${LEGACY_HF_CACHE_DIR:-/workspace/.hf_cache}"

HF_DOWNLOAD_TMP_DIR="${HF_DOWNLOAD_TMP_DIR:-/workspace/.hf_download_tmp}"

HF_RUNTIME_CACHE_DIR="${HF_RUNTIME_CACHE_DIR:-/workspace/.hf_runtime_cache}"

LEGACY_DEFAULT_HF_XET_CACHE="${LEGACY_DEFAULT_HF_XET_CACHE:-${HOME:-/root}/.cache/huggingface/xet}"

HF_ETAG_TIMEOUT="${HF_ETAG_TIMEOUT:-30}"
HF_DOWNLOAD_TIMEOUT="${HF_DOWNLOAD_TIMEOUT:-60}"

PREFLIGHT_FAILURES=()

# ============================================================
# PATH / TOKEN HELPERS
# ============================================================

get_hf_token() {
  if [[ -n "${HF_TOKEN:-}" ]]; then
    echo "$HF_TOKEN"
    return 0
  fi

  if [[ -n "${HUGGINGFACE_HUB_TOKEN:-}" ]]; then
    echo "$HUGGINGFACE_HUB_TOKEN"
    return 0
  fi

  echo ""
}

normalize_comfy_paths() {

  # Vast / AI-Dock internal ComfyUI support.
  #
  # RunPod official already has COMFY_WORKSPACE populated,
  # so this branch normally does nothing there.

  if [[ -d "$INTERNAL_COMFY" && -f "$INTERNAL_COMFY/main.py" ]]; then

    if [[ ! -e "$COMFY_WORKSPACE" ]]; then
      ln -sfn "$INTERNAL_COMFY" "$COMFY_WORKSPACE"
      log "Linked $COMFY_WORKSPACE -> $INTERNAL_COMFY"
    else
      log "$COMFY_WORKSPACE already exists"
    fi
  fi

  if [[ ! -f "$COMFY_WORKSPACE/main.py" ]]; then
    log "ERROR: ComfyUI not found at $COMFY_WORKSPACE"
    exit 1
  fi

  log "ComfyUI found at $COMFY_WORKSPACE"
}

# ============================================================
# LORA MANAGER / CIVITAI API KEY
# ============================================================

get_lora_manager_civitai_key() {

  if [[ -n "${CIVITAI_API_KEY:-}" ]]; then
    printf '%s' "$CIVITAI_API_KEY"
    return 0
  fi

  if [[ -n "${CIVITAI_TOKEN:-}" ]]; then
    printf '%s' "$CIVITAI_TOKEN"
    return 0
  fi

  printf ''
}

provisioning_configure_lora_manager_civitai() {

  local manager_dir="${COMFY_WORKSPACE}/custom_nodes/ComfyUI-Lora-Manager"

  local api_key
  api_key="$(get_lora_manager_civitai_key)"

  if [[ ! -d "$manager_dir" ]]; then
    log "ERROR: LoRA Manager directory is missing: $manager_dir"
    return 1
  fi

  if [[ -z "$api_key" ]]; then
    log "ERROR: Neither CIVITAI_API_KEY nor CIVITAI_TOKEN is set."
    log "LoRA Manager Civitai authentication cannot be configured."
    return 1
  fi

  export CIVITAI_API_KEY="$api_key"

  local settings_path

  if [[ "${LORA_MANAGER_PORTABLE:-0}" == "1" ]]; then

    settings_path="${manager_dir}/settings.json"

  else

    local config_root="${XDG_CONFIG_HOME:-${HOME:-/root}/.config}"
    config_root="${config_root%/}"

    settings_path="${config_root}/ComfyUI-LoRA-Manager/settings.json"

  fi

  log "Configuring LoRA Manager Civitai authentication..."
  log "LoRA Manager settings path: $settings_path"
  log "LoRA Manager Civitai key length=${#api_key}"

  mkdir -p "$(dirname "$settings_path")"

  CIVITAI_LM_KEY="$api_key" \
  "$PYTHON_BIN" - "$settings_path" <<'PY'

import json
import os
import shutil
import sys
import tempfile
import time

from pathlib import Path

settings_path = Path(sys.argv[1])
api_key = os.environ.get("CIVITAI_LM_KEY", "")

if not api_key:
    print("[provision] ERROR: CIVITAI_LM_KEY is empty")
    raise SystemExit(2)

settings_path.parent.mkdir(parents=True, exist_ok=True)

payload = {}

if settings_path.exists():

    try:

        with settings_path.open("r", encoding="utf-8") as f:
            loaded = json.load(f)

        if not isinstance(loaded, dict):
            raise ValueError("settings.json root is not a JSON object")

        payload = loaded

    except Exception as exc:

        backup = settings_path.with_name(
            settings_path.name + f".broken.{int(time.time())}.bak"
        )

        shutil.copy2(settings_path, backup)

        print(
            "[provision] WARNING: Existing LoRA Manager settings were invalid; "
            f"backup created at {backup}: {exc!r}"
        )

        payload = {}

payload["civitai_api_key"] = api_key

fd, tmp_name = tempfile.mkstemp(
    prefix=settings_path.name + ".",
    suffix=".tmp",
    dir=str(settings_path.parent),
)

try:

    with os.fdopen(fd, "w", encoding="utf-8") as f:

        json.dump(
            payload,
            f,
            ensure_ascii=False,
            indent=2,
        )

        f.write("\n")
        f.flush()
        os.fsync(f.fileno())

    os.chmod(tmp_name, 0o600)
    os.replace(tmp_name, settings_path)

finally:

    if os.path.exists(tmp_name):
        os.unlink(tmp_name)

with settings_path.open("r", encoding="utf-8") as f:
    verify = json.load(f)

if verify.get("civitai_api_key") != api_key:

    print(
        "[provision] ERROR: LoRA Manager Civitai key verification failed"
    )

    raise SystemExit(3)

print(
    "[provision] LoRA Manager Civitai key configured and verified "
    f"(length={len(api_key)})"
)
PY

  chmod 600 "$settings_path" || true

  local stored_len

  stored_len="$(
    "$PYTHON_BIN" - "$settings_path" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as f:
    data = json.load(f)

value = data.get("civitai_api_key", "")

print(
    len(value)
    if isinstance(value, str)
    else -1
)
PY
)"

  if [[ "$stored_len" != "${#api_key}" ]]; then

    log "ERROR: LoRA Manager Civitai key length verification failed (stored=$stored_len expected=${#api_key})"

    return 1

  fi

  log "LoRA Manager Civitai authentication is ready."
}

# ============================================================
# PIP HELPERS
# ============================================================

pip_install() {

  if [[ -x "$PIP_BIN" ]]; then

    "$PIP_BIN" install \
      --no-cache-dir \
      "$@"

    return 0
  fi

  if [[ -x "$PYTHON_BIN" ]]; then

    "$PYTHON_BIN" -m pip install \
      --no-cache-dir \
      "$@"

    return 0
  fi

  pip install \
    --no-cache-dir \
    "$@"
}

run_with_retries() {

  local attempts="$1"
  shift

  local timeout_sec="$1"
  shift

  local desc="$1"
  shift

  local n=1
  local rc=0

  while [[ "$n" -le "$attempts" ]]; do

    log "$desc (attempt $n/$attempts, timeout=${timeout_sec}s)"

    set +e

    timeout "$timeout_sec" "$@"

    rc=$?

    set -e

    if [[ $rc -eq 0 ]]; then
      return 0
    fi

    log "$desc failed with rc=$rc"

    sleep $((5 * n))

    n=$((n + 1))

  done

  return "$rc"
}

pip_install_timed() {

  local timeout_sec="$1"
  shift

  if [[ -x "$PIP_BIN" ]]; then

    timeout "$timeout_sec" \
      "$PIP_BIN" install \
      --no-cache-dir \
      "$@"

    return $?
  fi

  if [[ -x "$PYTHON_BIN" ]]; then

    timeout "$timeout_sec" \
      "$PYTHON_BIN" -m pip install \
      --no-cache-dir \
      "$@"

    return $?
  fi

  timeout "$timeout_sec" \
    pip install \
    --no-cache-dir \
    "$@"
}

patch_node_requirements() {

  local repo="$1"
  local requirements="$2"

  # Impact Pack's SAM2 dependency can spend forever building.
  if grep -q 'facebookresearch/sam2' "$requirements" 2>/dev/null; then

    log "Patching requirements: disabling facebookresearch/sam2 in $requirements"

    sed -i \
      '/facebookresearch\/sam2/s/^/# /' \
      "$requirements"

  fi

  # Avoid repeated '# #'.
  sed -i \
    's/^# # /# /' \
    "$requirements" \
    || true
}

provisioning_tune_git() {

  log "Tuning git for unstable host networking..."

  git config --global \
    http.version HTTP/1.1 \
    || true

  git config --global \
    http.lowSpeedLimit 1 \
    || true

  git config --global \
    http.lowSpeedTime 60 \
    || true

  git config --global \
    advice.detachedHead false \
    || true

  export GIT_TERMINAL_PROMPT=0
}

# ============================================================
# HUGGING FACE TEMP/CACHE MANAGEMENT
# ============================================================

provisioning_cleanup_legacy_hf_cache() {

  if [[ "$CLEAN_LEGACY_HF_CACHE" != "1" ]]; then

    log "Legacy HF cache cleanup disabled (CLEAN_LEGACY_HF_CACHE=$CLEAN_LEGACY_HF_CACHE)"

    return 0

  fi

  local path

  for path in \
    "$LEGACY_HF_CACHE_DIR" \
    "$LEGACY_DEFAULT_HF_XET_CACHE"
  do

    [[ -z "$path" ]] && continue
    [[ ! -d "$path" ]] && continue

    local cache_size

    cache_size="$(
      du -sh "$path" 2>/dev/null \
      | awk '{print $1}' \
      || true
    )"

    log "Removing legacy HF cache: $path (${cache_size:-unknown})"

    rm -rf -- "$path"

  done
}

provisioning_configure_hf_runtime() {

  mkdir -p \
    "$HF_DOWNLOAD_TMP_DIR" \
    "$HF_RUNTIME_CACHE_DIR"

  export HF_HOME="$HF_RUNTIME_CACHE_DIR"
  export HF_HUB_CACHE="$HF_RUNTIME_CACHE_DIR/hub"
  export HF_XET_CACHE="$HF_RUNTIME_CACHE_DIR/xet"
  export HF_ASSETS_CACHE="$HF_RUNTIME_CACHE_DIR/assets"
  export HF_TOKEN_PATH="$HF_RUNTIME_CACHE_DIR/token"

  export HF_XET_CHUNK_CACHE_SIZE_BYTES=0
  export HF_XET_SHARD_CACHE_SIZE_LIMIT=0

  export HF_HUB_ETAG_TIMEOUT="$HF_ETAG_TIMEOUT"
  export HF_HUB_DOWNLOAD_TIMEOUT="$HF_DOWNLOAD_TIMEOUT"
}

provisioning_cleanup_hf_artifacts() {

  local path

  for path in \
    "$HF_DOWNLOAD_TMP_DIR" \
    "$HF_RUNTIME_CACHE_DIR"
  do

    [[ -z "$path" ]] && continue
    [[ ! -d "$path" ]] && continue

    local size

    size="$(
      du -sh "$path" 2>/dev/null \
      | awk '{print $1}' \
      || true
    )"

    log "Removing disposable HF data: $path (${size:-unknown})"

    rm -rf -- "$path"

  done
}

provisioning_hf_exit_cleanup() {

  provisioning_cleanup_hf_artifacts \
    || true
}

# ============================================================
# HOST PREFLIGHT
# ============================================================

preflight_record_failure() {

  local message="$1"

  PREFLIGHT_FAILURES+=("$message")

  log "[HOST CHECK: FAIL] $message"
}

preflight_retry_command() {

  local label="$1"
  shift

  local attempt=1
  local rc=1

  while [[ "$attempt" -le "$PREFLIGHT_ATTEMPTS" ]]; do

    log "[HOST CHECK] $label (attempt $attempt/$PREFLIGHT_ATTEMPTS)"

    set +e

    timeout "$PREFLIGHT_TOTAL_TIMEOUT" "$@"

    rc=$?

    set -e

    if [[ $rc -eq 0 ]]; then

      log "[HOST CHECK: OK] $label"

      return 0

    fi

    log "[HOST CHECK] $label failed with rc=$rc"

    sleep $((3 * attempt))

    attempt=$((attempt + 1))

  done

  preflight_record_failure "$label"

  return 1
}

preflight_https() {

  local label="$1"
  local url="$2"

  preflight_retry_command \
    "$label" \
    curl \
      -fsSL \
      --connect-timeout "$PREFLIGHT_CONNECT_TIMEOUT" \
      --max-time "$PREFLIGHT_TOTAL_TIMEOUT" \
      --retry 0 \
      -A "Mozilla/5.0" \
      -o /dev/null \
      "$url"
}

provisioning_host_preflight() {

  if [[ "$HOST_PREFLIGHT" != "1" ]]; then

    log "Host preflight disabled (HOST_PREFLIGHT=$HOST_PREFLIGHT)"

    return 0

  fi

  log "============================================================"
  log "HOST PREFLIGHT START"
  log "This check should finish in roughly 30-90 seconds."
  log "============================================================"

  PREFLIGHT_FAILURES=()

  rm -f \
    /workspace/HOST_PREFLIGHT_FAILED \
    /workspace/HOST_PREFLIGHT_PASSED

  # ----------------------------------------------------------
  # GPU
  # ----------------------------------------------------------

  if command -v nvidia-smi >/dev/null 2>&1; then

    if nvidia-smi >/dev/null 2>&1; then

      log "[HOST CHECK: OK] NVIDIA GPU is visible"

      nvidia-smi \
        --query-gpu=name,uuid,memory.total,driver_version \
        --format=csv,noheader \
        || true

    else

      preflight_record_failure \
        "nvidia-smi exists but cannot access the GPU"

    fi

  else

    preflight_record_failure \
      "nvidia-smi command is missing"

  fi

  # ----------------------------------------------------------
  # Disk
  # ----------------------------------------------------------

  local free_kb=0
  local free_gb=0

  free_kb="$(
    df -Pk "$WORKSPACE" 2>/dev/null \
    | awk 'NR==2 {print $4}' \
    || echo 0
  )"

  if [[ "$free_kb" =~ ^[0-9]+$ ]]; then
    free_gb=$((free_kb / 1024 / 1024))
  fi

  log "[HOST CHECK] Free disk at $WORKSPACE: ${free_gb} GiB"

  if \
    [[ "$PREFLIGHT_MIN_FREE_GB" =~ ^[0-9]+$ ]] \
    && [[ "$PREFLIGHT_MIN_FREE_GB" -gt 0 ]] \
    && [[ "$free_gb" -lt "$PREFLIGHT_MIN_FREE_GB" ]]
  then

    preflight_record_failure \
      "free disk ${free_gb} GiB is below PREFLIGHT_MIN_FREE_GB=${PREFLIGHT_MIN_FREE_GB}"

  fi

  # ----------------------------------------------------------
  # DNS
  # ----------------------------------------------------------

  local domain

  for domain in \
    github.com \
    huggingface.co \
    pypi.org \
    civitai.com
  do

    if getent hosts "$domain" >/dev/null 2>&1; then

      log "[HOST CHECK: OK] DNS: $domain"

    else

      preflight_record_failure \
        "DNS lookup failed: $domain"

    fi

  done

  # ----------------------------------------------------------
  # GitHub smart HTTP
  # ----------------------------------------------------------

  preflight_retry_command \
    "GitHub git clone path" \
    bash -lc \
      'git -c http.version=HTTP/1.1 ls-remote https://github.com/ltdrdata/ComfyUI-Manager.git HEAD >/dev/null' \
    || true

  # ----------------------------------------------------------
  # HTTPS
  # ----------------------------------------------------------

  preflight_https \
    "PyPI HTTPS" \
    "https://pypi.org/simple/pip/" \
    || true

  preflight_https \
    "Hugging Face HTTPS" \
    "https://huggingface.co/api/models/Comfy-Org/MiniMax-H3" \
    || true

  preflight_https \
    "Civitai HTTPS" \
    "https://civitai.com/api/v1/models?limit=1" \
    || true

  local result_file="/workspace/host_preflight_result.txt"

  if [[ ${#PREFLIGHT_FAILURES[@]} -gt 0 ]]; then

    {
      echo "result=FAIL"
      echo "checked_at=$(date --iso-8601=seconds 2>/dev/null || date)"
      echo "free_disk_gib=$free_gb"
      echo "failures=${#PREFLIGHT_FAILURES[@]}"

      for x in "${PREFLIGHT_FAILURES[@]}"; do
        echo "- $x"
      done

    } > "$result_file"

    touch /workspace/HOST_PREFLIGHT_FAILED

    log "============================================================"
    log "HOST PREFLIGHT FAILED"

    for x in "${PREFLIGHT_FAILURES[@]}"; do
      log "  - $x"
    done

    log "Result file: $result_file"
    log "This host is unsuitable for this provisioning run."
    log "Terminate this instance and choose another host."
    log "Provisioning aborted before custom-node/model downloads."
    log "============================================================"

    exit 90

  fi

  {
    echo "result=PASS"
    echo "checked_at=$(date --iso-8601=seconds 2>/dev/null || date)"
    echo "free_disk_gib=$free_gb"
    echo "failures=0"

  } > "$result_file"

  touch /workspace/HOST_PREFLIGHT_PASSED

  log "============================================================"
  log "HOST PREFLIGHT PASSED"
  log "Result file: $result_file"
  log "Continuing provisioning."
  log "============================================================"
}

# ============================================================
# INSTALL PACKAGES
# ============================================================

provisioning_get_apt_packages() {

  if [[ ${#APT_PACKAGES[@]} -eq 0 ]]; then
    return 0
  fi

  log "Installing apt packages: ${APT_PACKAGES[*]}"

  if command -v sudo >/dev/null 2>&1; then

    sudo apt-get update

    sudo $APT_INSTALL \
      "${APT_PACKAGES[@]}"

  else

    apt-get update

    $APT_INSTALL \
      "${APT_PACKAGES[@]}"

  fi
}

provisioning_get_pip_packages() {

  if [[ ${#PIP_PACKAGES[@]} -eq 0 ]]; then
    return 0
  fi

  log "Installing pip packages: ${PIP_PACKAGES[*]}"

  pip_install \
    "${PIP_PACKAGES[@]}"
}

# ============================================================
# HF XET SUPPORT
# ============================================================

provisioning_enable_hf_xet() {

  log "Enabling Hugging Face high-performance Xet downloads (best-effort)..."

  set +e

  pip_install \
    -q \
    huggingface_hub \
    hf_xet

  local rc=$?

  set -e

  if [[ $rc -ne 0 ]]; then

    log "huggingface_hub/hf_xet install failed. Continuing with aria2/wget/curl fallback."

  else

    unset HF_HUB_ENABLE_HF_TRANSFER \
      || true

    export HF_XET_HIGH_PERFORMANCE=1

    log "HF Xet high-performance mode enabled"

  fi
}

provisioning_hf_transfer_download() {

  local dir="$1"
  local url="$2"

  if [[ ! "$url" =~ ^https://huggingface\.co/ ]]; then
    return 1
  fi

  if [[ "$url" != *"/resolve/"* ]]; then
    return 1
  fi

  local clean="${url%%\?*}"
  local rest="${clean#https://huggingface.co/}"

  local repo_id="${rest%%/resolve/*}"
  local after="${rest#${repo_id}/resolve/}"
  local rev="${after%%/*}"
  local file_path="${after#${rev}/}"

  if \
    [[ -z "$repo_id" ]] \
    || [[ -z "$rev" ]] \
    || [[ -z "$file_path" ]] \
    || [[ "$file_path" == "$after" ]]
  then
    return 1
  fi

  mkdir -p \
    "$dir" \
    "$HF_DOWNLOAD_TMP_DIR"

  log "HF direct attempt: repo=$repo_id rev=$rev file=$file_path -> $dir"

  log "HF temporary/resume directory: $HF_DOWNLOAD_TMP_DIR"

  set +e

  "$PYTHON_BIN" - \
    "$repo_id" \
    "$rev" \
    "$file_path" \
    "$dir" \
    "$HF_DOWNLOAD_TMP_DIR" <<'PY'

import json
import os
import struct
import sys

repo_id, rev, file_path, out_dir, temp_dir = sys.argv[1:6]

token = (
    os.environ.get("HF_TOKEN")
    or os.environ.get("HUGGINGFACE_HUB_TOKEN")
    or None
)

try:
    from huggingface_hub import (
        get_hf_file_metadata,
        hf_hub_download,
        hf_hub_url,
    )

except Exception as e:

    print(
        "[provision] huggingface_hub not available:",
        repr(e),
    )

    sys.exit(2)

os.makedirs(
    out_dir,
    exist_ok=True,
)

os.makedirs(
    temp_dir,
    exist_ok=True,
)

dst = os.path.join(
    out_dir,
    os.path.basename(file_path),
)

expected_size = None

try:

    metadata_url = hf_hub_url(
        repo_id=repo_id,
        filename=file_path,
        revision=rev,
    )

    metadata = get_hf_file_metadata(
        metadata_url,
        token=token,
    )

    expected_size = metadata.size

except Exception as e:

    print(
        "[provision] HF metadata check warning:",
        repr(e),
    )


def valid_safetensors_file(path: str) -> bool:

    try:

        file_size = os.path.getsize(path)

        with open(path, "rb") as f:

            raw = f.read(8)

            if len(raw) != 8:
                return False

            header_size = struct.unpack(
                "<Q",
                raw,
            )[0]

            if \
                header_size <= 0 \
                or header_size > file_size - 8:
                return False

            header_raw = f.read(header_size)

            header = json.loads(header_raw)

        max_end = 0

        for key, value in header.items():

            if key == "__metadata__":
                continue

            offsets = value.get("data_offsets")

            if (
                not isinstance(offsets, list)
                or len(offsets) != 2
                or not all(
                    isinstance(x, int)
                    for x in offsets
                )
            ):
                return False

            start, end = offsets

            if start < 0 or end < start:
                return False

            max_end = max(
                max_end,
                end,
            )

        return (
            8
            + header_size
            + max_end
            == file_size
        )

    except Exception:
        return False


if os.path.isfile(dst):

    actual_size = os.path.getsize(dst)

    if \
        expected_size is not None \
        and actual_size == expected_size:

        print(
            f"[provision] HF file already complete, skipping: "
            f"{dst} ({actual_size} bytes)"
        )

        sys.exit(0)

    if \
        expected_size is None \
        and dst.endswith(".safetensors") \
        and valid_safetensors_file(dst):

        print(
            f"[provision] HF metadata unavailable, but safetensors "
            f"structure is complete; skipping: "
            f"{dst} ({actual_size} bytes)"
        )

        sys.exit(0)

    print(
        f"[provision] Existing HF file is incomplete, unverifiable, "
        f"or mismatched; re-downloading: {dst} "
        f"(actual={actual_size}, expected={expected_size})"
    )

    os.remove(dst)


try:

    downloaded_path = hf_hub_download(
        repo_id=repo_id,
        filename=file_path,
        revision=rev,
        token=token,
        local_dir=temp_dir,
    )

    downloaded_size = os.path.getsize(
        downloaded_path
    )

    if \
        expected_size is not None \
        and downloaded_size != expected_size:

        raise OSError(
            f"downloaded size mismatch: "
            f"actual={downloaded_size}, "
            f"expected={expected_size}"
        )

    if downloaded_size < 1024 * 1024:

        raise OSError(
            f"downloaded file is too small: "
            f"{downloaded_size} bytes"
        )

    os.replace(
        downloaded_path,
        dst,
    )

    print(
        f"[provision] HF downloaded directly OK -> {dst}"
    )

    print(
        f"[provision] HF final size: "
        f"{downloaded_size} bytes"
    )

    sys.exit(0)

except Exception as e:

    print(
        "[provision] HF direct download failed:",
        repr(e),
    )

    sys.exit(1)

PY

  local rc=$?

  set -e

  if [[ $rc -eq 0 ]]; then
    return 0
  fi

  return 1
}

# ============================================================
# FILE VALIDATION
# ============================================================

validate_downloaded_file_in_dir() {

  local dir="$1"
  local before_list="$2"

  local after_list
  after_list="$(mktemp)"

  find "$dir" \
    -maxdepth 1 \
    -type f \
    -printf '%p\n' \
    | sort \
    > "$after_list"

  local new_files

  new_files="$(
    comm \
      -13 \
      "$before_list" \
      "$after_list" \
      || true
  )"

  rm -f "$after_list"

  if [[ -z "$new_files" ]]; then

    log "WARNING: No new file detected in $dir. Maybe already existed, or download replaced an existing file."

    return 0

  fi

  local ok=0

  while IFS= read -r file; do

    [[ -z "$file" ]] && continue

    local size

    size="$(
      stat -c%s "$file" 2>/dev/null \
      || echo 0
    )"

    log "Downloaded file: $file"
    log "Size: $size bytes"

    file "$file" \
      || true

    if [[ "$size" -lt 1048576 ]]; then

      log "ERROR: Downloaded file is too small: $file"

      ok=1

      continue

    fi

    case "$file" in

      *.safetensors|*.ckpt|*.pt|*.pth|*.bin)
        ;;

      *)
        log "WARNING: Unknown model extension: $file"
        ;;

    esac

  done <<< "$new_files"

  return "$ok"
}

# ============================================================
# DOWNLOADER
# ============================================================

provisioning_file_looks_complete() {

  local path="$1"
  local expected_size="${2:-0}"

  [[ -f "$path" ]] || return 1

  local actual_size
  actual_size="$(
    stat -c%s "$path" 2>/dev/null \
    || echo 0
  )"

  if \
    [[ "$expected_size" =~ ^[0-9]+$ ]] \
    && [[ "$expected_size" -gt 0 ]]
  then
    [[ "$actual_size" -eq "$expected_size" ]]
    return $?
  fi

  case "$path" in
    *.safetensors|*.safetensors.part)

      "$PYTHON_BIN" - "$path" >/dev/null 2>&1 <<'PY'
import json
import os
import struct
import sys

path = sys.argv[1]

try:
    file_size = os.path.getsize(path)

    if file_size < 16:
        raise ValueError("file too small")

    with open(path, "rb") as f:
        raw = f.read(8)

        if len(raw) != 8:
            raise ValueError("missing safetensors header length")

        header_size = struct.unpack("<Q", raw)[0]

        if header_size <= 0 or header_size > file_size - 8:
            raise ValueError("invalid safetensors header size")

        header = json.loads(
            f.read(header_size)
        )

    max_end = 0

    for key, value in header.items():

        if key == "__metadata__":
            continue

        offsets = value.get("data_offsets")

        if (
            not isinstance(offsets, list)
            or len(offsets) != 2
            or not all(isinstance(x, int) for x in offsets)
        ):
            raise ValueError("invalid data_offsets")

        start, end = offsets

        if start < 0 or end < start:
            raise ValueError("invalid tensor offsets")

        max_end = max(max_end, end)

    if 8 + header_size + max_end != file_size:
        raise ValueError("safetensors payload is incomplete")

except Exception:
    raise SystemExit(1)

raise SystemExit(0)
PY

      return $?
      ;;

    *)
      return 1
      ;;
  esac
}


provisioning_civitai_probe() {

  local source_url="$1"

  local header_file
  header_file="$(mktemp)"

  local effective_url=""
  local rc=0

  set +e

  effective_url="$(
    curl \
      -fsSIL \
      --connect-timeout "$CIVITAI_CONNECT_TIMEOUT" \
      --max-time "$CIVITAI_PROBE_TIMEOUT" \
      --retry 2 \
      --retry-delay 2 \
      --retry-all-errors \
      -A "Mozilla/5.0" \
      -D "$header_file" \
      -o /dev/null \
      -w '%{url_effective}' \
      "$source_url" \
      2>/dev/null
  )"

  rc=$?

  set -e

  if \
    [[ $rc -ne 0 ]] \
    || [[ -z "$effective_url" ]]
  then

    rm -f "$header_file"

    return 1
  fi

  set +e

  "$PYTHON_BIN" - \
    "$header_file" \
    "$effective_url" <<'PY'
import os
import re
import sys
from urllib.parse import unquote, urlsplit

header_path, effective_url = sys.argv[1:3]

blocks = []
current = {}

try:
    with open(
        header_path,
        "r",
        encoding="iso-8859-1",
        errors="replace",
    ) as f:

        for raw in f:

            line = raw.rstrip("\r\n")

            if line.startswith("HTTP/"):
                if current:
                    blocks.append(current)

                current = {}
                continue

            if not line or ":" not in line:
                continue

            key, value = line.split(":", 1)

            current[
                key.strip().lower()
            ] = value.strip()

    if current:
        blocks.append(current)

except Exception:
    blocks = []

headers = blocks[-1] if blocks else {}

filename = ""

content_disposition = headers.get(
    "content-disposition",
    "",
)

if content_disposition:

    m = re.search(
        r"filename\*\s*=\s*(?:UTF-8''|utf-8'')?([^;]+)",
        content_disposition,
        flags=re.IGNORECASE,
    )

    if m:
        filename = unquote(
            m.group(1).strip().strip('"')
        )

    if not filename:

        m = re.search(
            r'filename\s*=\s*"([^"]+)"',
            content_disposition,
            flags=re.IGNORECASE,
        )

        if m:
            filename = m.group(1)

    if not filename:

        m = re.search(
            r"filename\s*=\s*([^;]+)",
            content_disposition,
            flags=re.IGNORECASE,
        )

        if m:
            filename = m.group(1).strip().strip('"')

if not filename:

    filename = unquote(
        os.path.basename(
            urlsplit(effective_url).path
        )
    )

filename = os.path.basename(
    filename.replace("\x00", "")
).strip()

content_length = headers.get(
    "content-length",
    "0",
).strip()

try:
    expected_size = int(content_length)
except Exception:
    expected_size = 0

if expected_size < 0:
    expected_size = 0

print(filename)
print(expected_size)
PY

  rc=$?

  set -e

  rm -f "$header_file"

  return "$rc"
}


provisioning_civitai_aria2_download() {

  local dir="$1"
  local source_url="$2"

  mkdir -p "$dir"

  local probe=()
  local probe_file
  probe_file="$(mktemp)"

  set +e

  provisioning_civitai_probe \
    "$source_url" \
    > "$probe_file"

  local probe_rc=$?

  set -e

  if [[ $probe_rc -eq 0 ]]; then
    mapfile -t probe < "$probe_file"
  fi

  rm -f "$probe_file"

  local filename=""
  local expected_size=0

  if [[ $probe_rc -eq 0 ]]; then

    filename="${probe[0]:-}"
    expected_size="${probe[1]:-0}"

  fi

  # If HEAD probing did not reveal a plausible model filename,
  # fall back to aria2 Content-Disposition mode rather than saving
  # a CDN object name without the proper extension.
  case "$filename" in
    *.safetensors|*.ckpt|*.pt|*.pth|*.bin|*.gguf|*.zip)
      ;;
    *)
      filename=""
      ;;
  esac

  if [[ ! "$expected_size" =~ ^[0-9]+$ ]]; then
    expected_size=0
  fi

  if \
    [[ -n "$filename" ]] \
    && [[ "$filename" != "." ]] \
    && [[ "$filename" != "/" ]]
  then

    local final_path="${dir}/${filename}"
    local part_path="${final_path}.part"
    local part_name="${filename}.part"

    log "Civitai resolved filename: $filename"

    if [[ "$expected_size" -gt 0 ]]; then
      log "Civitai expected size: $expected_size bytes"
    else
      log "Civitai expected size unavailable; safetensors structure will be used for final validation when possible."
    fi

    if provisioning_file_looks_complete \
      "$final_path" \
      "$expected_size"
    then

      local complete_size
      complete_size="$(
        stat -c%s "$final_path" 2>/dev/null \
        || echo 0
      )"

      log "Civitai file already complete, skipping: $final_path ($complete_size bytes)"

      rm -f \
        "${part_path}.aria2" \
        "$part_path" \
        || true

      return 0
    fi

    # If an older run left a partial file under the final name,
    # convert it into the resumable .part path instead of throwing it away.
    if [[ -f "$final_path" ]]; then

      local final_size=0
      local part_size=0

      final_size="$(
        stat -c%s "$final_path" 2>/dev/null \
        || echo 0
      )"

      if [[ -f "$part_path" ]]; then
        part_size="$(
          stat -c%s "$part_path" 2>/dev/null \
          || echo 0
        )"
      fi

      if \
        [[ ! -f "$part_path" ]] \
        || [[ "$final_size" -gt "$part_size" ]]
      then

        log "Preserving existing partial Civitai file for resume: $final_path -> $part_path"

        mv -f \
          -- \
          "$final_path" \
          "$part_path"

      else

        log "Discarding smaller duplicate partial file: $final_path ($final_size bytes; resumable part=$part_size bytes)"

        rm -f \
          -- \
          "$final_path"
      fi
    fi

    log "Civitai download via aria2: connections=$CIVITAI_ARIA2_CONNECTIONS split=$CIVITAI_ARIA2_SPLIT min_split=$CIVITAI_ARIA2_MIN_SPLIT_SIZE"
    log "Civitai resume file: $part_path"

    set +e

    if command -v aria2c >/dev/null 2>&1; then

      aria2c \
        --continue=true \
        --auto-file-renaming=false \
        --allow-overwrite=false \
        --file-allocation=none \
        --max-connection-per-server="$CIVITAI_ARIA2_CONNECTIONS" \
        --split="$CIVITAI_ARIA2_SPLIT" \
        --min-split-size="$CIVITAI_ARIA2_MIN_SPLIT_SIZE" \
        --connect-timeout="$CIVITAI_CONNECT_TIMEOUT" \
        --timeout="$CIVITAI_IO_TIMEOUT" \
        --max-tries="$CIVITAI_MAX_TRIES" \
        --retry-wait="$CIVITAI_RETRY_WAIT" \
        --lowest-speed-limit="$CIVITAI_LOWEST_SPEED_LIMIT" \
        --summary-interval=5 \
        --console-log-level=warn \
        --user-agent="Mozilla/5.0" \
        -o "$part_name" \
        -d "$dir" \
        "$source_url"

      rc=$?

    else

      log "WARNING: aria2c is unavailable; falling back to resumable curl."

      curl \
        -fL \
        --connect-timeout "$CIVITAI_CONNECT_TIMEOUT" \
        --retry "$CIVITAI_MAX_TRIES" \
        --retry-delay "$CIVITAI_RETRY_WAIT" \
        --retry-all-errors \
        --speed-time 60 \
        --speed-limit 65536 \
        -A "Mozilla/5.0" \
        -C - \
        -o "$part_path" \
        "$source_url"

      rc=$?

    fi

    set -e

    if [[ $rc -ne 0 ]]; then

      log "Civitai download failed with rc=$rc"
      log "Partial data was kept for resume: $part_path"

      return "$rc"
    fi

    if ! provisioning_file_looks_complete \
      "$part_path" \
      "$expected_size"
    then

      local bad_size
      bad_size="$(
        stat -c%s "$part_path" 2>/dev/null \
        || echo 0
      )"

      log "ERROR: Civitai download finished but validation failed: $part_path ($bad_size bytes)"

      return 1
    fi

    mv -f \
      -- \
      "$part_path" \
      "$final_path"

    rm -f \
      "${part_path}.aria2" \
      || true

    local downloaded_size
    downloaded_size="$(
      stat -c%s "$final_path" 2>/dev/null \
      || echo 0
    )"

    log "Civitai download complete: $final_path"
    log "Civitai final size: $downloaded_size bytes"

    file "$final_path" \
      || true

    return 0
  fi

  # Metadata probe failed. aria2 can still follow the Civitai redirect and
  # honor Content-Disposition. This mode is less deterministic for resume,
  # but it is still multi-connection and preferable to a single curl stream.
  log "WARNING: Civitai metadata probe failed; using aria2 Content-Disposition mode."

  if ! command -v aria2c >/dev/null 2>&1; then
    log "ERROR: aria2c is required when the Civitai filename probe fails."
    return 1
  fi

  set +e

  (
    cd "$dir"

    aria2c \
      --continue=true \
      --auto-file-renaming=false \
      --allow-overwrite=false \
      --file-allocation=none \
      --content-disposition=true \
      --max-connection-per-server="$CIVITAI_ARIA2_CONNECTIONS" \
      --split="$CIVITAI_ARIA2_SPLIT" \
      --min-split-size="$CIVITAI_ARIA2_MIN_SPLIT_SIZE" \
      --connect-timeout="$CIVITAI_CONNECT_TIMEOUT" \
      --timeout="$CIVITAI_IO_TIMEOUT" \
      --max-tries="$CIVITAI_MAX_TRIES" \
      --retry-wait="$CIVITAI_RETRY_WAIT" \
      --lowest-speed-limit="$CIVITAI_LOWEST_SPEED_LIMIT" \
      --summary-interval=5 \
      --console-log-level=warn \
      --user-agent="Mozilla/5.0" \
      "$source_url"
  )

  rc=$?

  set -e

  return "$rc"
}


provisioning_download_to_dir() {

  local dir="$1"
  local url="$2"

  mkdir -p "$dir"

  local final_url="$url"
  local auth_header=""

  local hf_token
  hf_token="$(get_hf_token)"

  if \
    [[ -n "$hf_token" ]] \
    && [[ "$url" =~ huggingface\.co ]]
  then

    auth_header="Authorization: Bearer ${hf_token}"

  fi

  if [[ "$url" =~ civitai\.com ]]; then

    if [[ "$url" == *"token="* ]]; then

      log "Civitai URL already contains token parameter"

    elif [[ -z "${CIVITAI_TOKEN:-}" ]]; then

      log "WARNING: Civitai URL detected but CIVITAI_TOKEN is empty"

    else

      if [[ "$url" == *"?"* ]]; then
        final_url="${url}&token=${CIVITAI_TOKEN}"
      else
        final_url="${url}?token=${CIVITAI_TOKEN}"
      fi

    fi
  fi

  log "Downloading into $dir"

  if [[ "$url" =~ civitai\.com ]]; then

    log "Source: Civitai URL with token length=$(env_len CIVITAI_TOKEN)"

  else

    log "Source: $url"

  fi

  local before_list
  before_list="$(mktemp)"

  find "$dir" \
    -maxdepth 1 \
    -type f \
    -printf '%p\n' \
    | sort \
    > "$before_list"

  # ----------------------------------------------------------
  # Hugging Face
  # ----------------------------------------------------------

  if [[ "$url" =~ huggingface\.co ]]; then

    provisioning_configure_hf_runtime

    if provisioning_hf_transfer_download \
      "$dir" \
      "$final_url"
    then

      validate_downloaded_file_in_dir \
        "$dir" \
        "$before_list" \
        || true

      provisioning_cleanup_hf_artifacts

      rm -f "$before_list"

      return 0

    else

      log "HF Python downloader failed. Removing partial/cache data before fallback."

      provisioning_cleanup_hf_artifacts

      log "Falling back to aria2/wget/curl."

    fi
  fi

  # ----------------------------------------------------------
  # Civitai
  # ----------------------------------------------------------

  if [[ "$url" =~ civitai\.com ]]; then

    set +e

    provisioning_civitai_aria2_download \
      "$dir" \
      "$final_url"

    local rc=$?

    set -e

    if [[ $rc -ne 0 ]]; then

      log "Civitai aria2/resume download failed with rc=$rc"

      rm -f "$before_list"

      return "$rc"

    fi

    validate_downloaded_file_in_dir \
      "$dir" \
      "$before_list" \
      || true

    rm -f "$before_list"

    return 0
  fi

  # ----------------------------------------------------------
  # General fallback
  # ----------------------------------------------------------

  local name="${url%%\?*}"
  name="${name##*/}"

  local final_path="${dir}/${name}"
  local part_name="${name}.part"
  local part_path="${dir}/${part_name}"

  set +e

  if command -v aria2c >/dev/null 2>&1; then

    if [[ -n "$auth_header" ]]; then

      aria2c \
        --continue=true \
        --auto-file-renaming=false \
        --allow-overwrite=true \
        -x 16 \
        -s 16 \
        -k 1M \
        --header="$auth_header" \
        -o "$part_name" \
        -d "$dir" \
        "$final_url"

    else

      aria2c \
        --continue=true \
        --auto-file-renaming=false \
        --allow-overwrite=true \
        -x 16 \
        -s 16 \
        -k 1M \
        -o "$part_name" \
        -d "$dir" \
        "$final_url"

    fi

    local rc=$?

  elif command -v wget >/dev/null 2>&1; then

    if [[ -n "$auth_header" ]]; then

      wget \
        --continue \
        --header="$auth_header" \
        -O "$part_path" \
        "$final_url"

    else

      wget \
        --continue \
        -O "$part_path" \
        "$final_url"

    fi

    local rc=$?

  else

    if [[ -n "$auth_header" ]]; then

      curl \
        -fL \
        --retry 5 \
        --retry-delay 5 \
        --retry-all-errors \
        -H "$auth_header" \
        -C - \
        -o "$part_path" \
        "$final_url"

    else

      curl \
        -fL \
        --retry 5 \
        --retry-delay 5 \
        --retry-all-errors \
        -C - \
        -o "$part_path" \
        "$final_url"

    fi

    local rc=$?

  fi

  set -e

  if [[ $rc -ne 0 ]]; then

    rm -f "$before_list"

    return "$rc"

  fi

  if [[ ! -f "$part_path" ]]; then

    log "Fallback download reported success but part file is missing: $part_path"

    rm -f "$before_list"

    return 1

  fi

  local part_size

  part_size="$(
    stat -c%s "$part_path" 2>/dev/null \
    || echo 0
  )"

  if [[ "$part_size" -lt 1048576 ]]; then

    log "Fallback download is too small: $part_path ($part_size bytes)"

    rm -f "$before_list"

    return 1

  fi

  mv -f \
    -- \
    "$part_path" \
    "$final_path"

  validate_downloaded_file_in_dir \
    "$dir" \
    "$before_list" \
    || true

  rm -f "$before_list"

  return 0
}

provisioning_get_models_dir_urlonly() {

  local dir="$1"
  shift || true

  local arr=("$@")

  if [[ ${#arr[@]} -eq 0 ]]; then
    return 0
  fi

  for url in "${arr[@]}"; do

    if ! provisioning_download_to_dir \
      "$dir" \
      "$url"
    then

      log "MODEL DOWNLOAD FAILED: $url"

      MODEL_DL_FAILS+=("$url")

      if [[ "$FAIL_ON_MODEL_DL" == "1" ]]; then

        log "FAIL_ON_MODEL_DL=1 -> exiting due to model download failure."

        exit 1

      fi
    fi

  done
}

# ============================================================
# SAM 3.1 / EASY-SAM3 MODEL LINK
# ============================================================

provisioning_link_sam31_model() {

  local filename="sam3.1_multiplex_fp16.safetensors"

  local src="${COMFY_WORKSPACE}/models/checkpoints/${filename}"

  local sam3_dir="${COMFY_WORKSPACE}/models/sam3"

  local dst="${sam3_dir}/${filename}"

  mkdir -p "$sam3_dir"

  if [[ ! -f "$src" ]]; then

    log "SAM 3.1 source model missing; Easy-SAM3 symlink not created: $src"

    return 0

  fi

  local src_size

  src_size="$(
    stat -c%s "$src" 2>/dev/null \
    || echo 0
  )"

  if \
    [[ ! "$src_size" =~ ^[0-9]+$ ]] \
    || [[ "$src_size" -lt 1048576 ]]
  then

    log "SAM 3.1 source model looks invalid or incomplete; symlink not created: $src ($src_size bytes)"

    return 0

  fi

  if [[ -e "$dst" && ! -L "$dst" ]]; then

    local dst_size

    dst_size="$(
      stat -c%s "$dst" 2>/dev/null \
      || echo 0
    )"

    log "Replacing duplicate Easy-SAM3 SAM 3.1 copy with symlink: $dst ($dst_size bytes)"

    rm -f -- "$dst"

  fi

  ln -sfn \
    "$src" \
    "$dst"

  if [[ -L "$dst" && -e "$dst" ]]; then

    log "SAM 3.1 symlink ready: $dst -> $(readlink "$dst")"

    ls -lh \
      "$src" \
      "$dst" \
      || true

  else

    log "WARNING: SAM 3.1 symlink verification failed: $dst"

  fi
}

# ============================================================
# IMPACT PACK / SUBPACK DETECTOR MODEL RESTORE
# ============================================================

provisioning_download_exact_file() {

  local url="$1"
  local dest="$2"

  mkdir -p "$(dirname "$dest")"

  local size=0

  if [[ -f "$dest" ]]; then

    size="$(
      stat -c%s "$dest" 2>/dev/null \
      || echo 0
    )"

    if [[ "$size" -ge 1048576 ]]; then

      log "Detector model already exists: $dest ($size bytes)"

      return 0

    fi

    log "Detector model exists but is too small. Re-downloading: $dest ($size bytes)"

    rm -f "$dest"

  fi

  local hf_token
  hf_token="$(get_hf_token)"

  local tmp="${dest}.part"

  rm -f "$tmp"

  log "Downloading detector model -> $dest"
  log "Source: $url"

  set +e

  if \
    [[ -n "$hf_token" ]] \
    && [[ "$url" =~ huggingface\.co ]]
  then

    curl \
      -fL \
      --retry 5 \
      --retry-delay 5 \
      --retry-all-errors \
      -H "Authorization: Bearer ${hf_token}" \
      -o "$tmp" \
      "$url"

  else

    curl \
      -fL \
      --retry 5 \
      --retry-delay 5 \
      --retry-all-errors \
      -o "$tmp" \
      "$url"

  fi

  local rc=$?

  set -e

  if [[ $rc -ne 0 ]]; then

    log "DETECTOR MODEL DOWNLOAD FAILED: $url"

    rm -f "$tmp"

    MODEL_DL_FAILS+=("$url")

    if [[ "$FAIL_ON_MODEL_DL" == "1" ]]; then

      log "FAIL_ON_MODEL_DL=1 -> exiting due to detector model download failure."

      exit 1

    fi

    return 0

  fi

  size="$(
    stat -c%s "$tmp" 2>/dev/null \
    || echo 0
  )"

  if [[ "$size" -lt 1048576 ]]; then

    log "DETECTOR MODEL DOWNLOAD FAILED: file is too small: $tmp ($size bytes)"

    rm -f "$tmp"

    MODEL_DL_FAILS+=("$url")

    if [[ "$FAIL_ON_MODEL_DL" == "1" ]]; then

      log "FAIL_ON_MODEL_DL=1 -> exiting due to small detector model file."

      exit 1

    fi

    return 0

  fi

  mv -f \
    "$tmp" \
    "$dest"

  file "$dest" \
    || true

  ls -lh "$dest" \
    || true
}

provisioning_restore_impact_detector_models() {

  log "Restoring Impact Pack / Subpack detector models..."

  local bbox_dir="${COMFY_WORKSPACE}/models/ultralytics/bbox"

  local segm_dir="${COMFY_WORKSPACE}/models/ultralytics/segm"

  local whitelist_dir="${COMFY_WORKSPACE}/user/default/ComfyUI-Impact-Subpack"

  mkdir -p \
    "$bbox_dir" \
    "$segm_dir" \
    "$whitelist_dir"

  provisioning_download_exact_file \
    "https://huggingface.co/licyk/comfyui-extension-models/resolve/main/ComfyUI-Impact-Pack/face_yolov8m.pt" \
    "$bbox_dir/face_yolov8m.pt"

  provisioning_download_exact_file \
    "https://huggingface.co/Tenofas/ComfyUI/resolve/d79945fb5c16e8aef8a1eb3ba1788d72152c6d96/ultralytics/bbox/Eyes.pt" \
    "$bbox_dir/Eyes.pt"

  provisioning_download_exact_file \
    "https://huggingface.co/Bingsu/adetailer/resolve/main/person_yolov8m-seg.pt" \
    "$bbox_dir/person_yolov8m-seg.pt"

  provisioning_download_exact_file \
    "https://huggingface.co/Bingsu/adetailer/resolve/main/person_yolov8m-seg.pt" \
    "$segm_dir/person_yolov8m-seg.pt"

  provisioning_download_exact_file \
    "https://huggingface.co/Bingsu/adetailer/resolve/main/person_yolov8s-seg.pt" \
    "$segm_dir/person_yolov8s-seg.pt"

  cat > "$whitelist_dir/model-whitelist.txt" <<'EOF'
bbox/face_yolov8m.pt
bbox/Eyes.pt
bbox/person_yolov8m-seg.pt
segm/person_yolov8m-seg.pt
segm/person_yolov8s-seg.pt
EOF

  log "Impact detector whitelist written: $whitelist_dir/model-whitelist.txt"

  print_dir_summary \
    "ultralytics bbox" \
    "$bbox_dir"

  print_dir_summary \
    "ultralytics segm" \
    "$segm_dir"
}

# ============================================================
# RUNPOD DETECTION
# ============================================================

is_runpod_official_comfy() {

  if [[ "$COMFY_WORKSPACE" == "/workspace/runpod-slim/ComfyUI" ]]; then
    return 0
  fi

  if [[ -d "/opt/comfyui-baked" ]]; then
    return 0
  fi

  if [[ -f "${COMFY_WORKSPACE}/.runpod-bundle-version" ]]; then
    return 0
  fi

  return 1
}

is_runpod_baked_node() {

  local node_name="$1"
  local node_path="$2"

  # Only skip it when:
  # 1. This really looks like official RunPod ComfyUI
  # 2. The baked node actually exists.
  if ! is_runpod_official_comfy; then
    return 1
  fi

  if [[ ! -d "$node_path" ]]; then
    return 1
  fi

  case "$node_name" in

    ComfyUI-Manager|ComfyUI-KJNodes)
      return 0
      ;;

    *)
      return 1
      ;;

  esac
}

# ============================================================
# CUSTOM NODES
# ============================================================

provisioning_get_nodes() {

  local nodes_dir="${COMFY_WORKSPACE}/custom_nodes"

  mkdir -p "$nodes_dir"

  provisioning_tune_git

  for repo in "${NODES[@]}"; do

    local dir="${repo##*/}"

    local path="${nodes_dir}/${dir}"

    local requirements="${path}/requirements.txt"

    # --------------------------------------------------------
    # Official RunPod bundled nodes
    #
    # Keep the version included in the official image when the
    # node is already present.
    # --------------------------------------------------------

    if is_runpod_baked_node \
      "$dir" \
      "$path"
    then

      log "RunPod baked node detected; keeping bundled version: $dir"

      continue

    fi

    # --------------------------------------------------------
    # Existing node
    # --------------------------------------------------------

    if [[ -d "$path/.git" ]]; then

      if ! run_with_retries \
        "$GIT_RETRIES" \
        "$GIT_TIMEOUT" \
        "Updating node: $repo" \
        git -C "$path" pull --ff-only
      then

        log "Git pull failed or timed out. Keeping existing copy and continuing: $repo"

        NODE_REQ_FAILS+=(
          "$repo (git pull failed)"
        )

      fi

    else

      log "Node not present, cloning: $repo"

      rm -rf "$path"

      if ! run_with_retries \
        "$GIT_RETRIES" \
        "$GIT_TIMEOUT" \
        "Cloning node: $repo" \
        git clone \
          --depth=1 \
          --recursive \
          "$repo" \
          "$path"
      then

        log "Git clone failed or timed out. Skipping this node and continuing: $repo"

        rm -rf "$path"

        NODE_REQ_FAILS+=(
          "$repo (git clone failed)"
        )

        continue

      fi
    fi

    requirements="${path}/requirements.txt"

    if [[ -f "$requirements" ]]; then

      log "Installing requirements: $requirements"

      patch_node_requirements \
        "$repo" \
        "$requirements"

      set +e

      pip_install_timed \
        "$PIP_REQ_TIMEOUT" \
        -r "$requirements"

      local rc=$?

      set -e

      if [[ $rc -ne 0 ]]; then

        log "Node requirements FAILED or timed out with rc=$rc: $repo"

        NODE_REQ_FAILS+=(
          "$repo (requirements failed rc=$rc)"
        )

      fi

    else

      log "No requirements.txt for node: $repo"

    fi

  done
}

# ============================================================
# SUMMARY / VERIFY
# ============================================================

print_dir_summary() {

  local label="$1"
  local dir="$2"

  log "---- $label: $dir ----"

  if [[ -d "$dir" ]]; then

    find "$dir" \
      -maxdepth 1 \
      \( -type f -o -type l \) \
      | while read -r f
        do
          ls -lh "$f" || true
        done

  else

    log "Directory missing: $dir"

  fi
}

verify_critical_models() {

  log "Verifying critical model directories..."

  print_dir_summary \
    "checkpoints" \
    "${COMFY_WORKSPACE}/models/checkpoints"

  print_dir_summary \
    "sam3" \
    "${COMFY_WORKSPACE}/models/sam3"

  print_dir_summary \
    "vae" \
    "${COMFY_WORKSPACE}/models/vae"

  print_dir_summary \
    "upscale_models" \
    "${COMFY_WORKSPACE}/models/upscale_models"

  print_dir_summary \
    "SEEDVR2" \
    "${COMFY_WORKSPACE}/models/SEEDVR2"

  print_dir_summary \
    "diffusion_models" \
    "${COMFY_WORKSPACE}/models/diffusion_models"

  print_dir_summary \
    "text_encoders" \
    "${COMFY_WORKSPACE}/models/text_encoders"

  local checkpoint_count

  checkpoint_count="$(
    find \
      "${COMFY_WORKSPACE}/models/checkpoints" \
      -maxdepth 1 \
      -type f \
      \( \
        -name "*.safetensors" \
        -o -name "*.ckpt" \
      \) \
      ! -name "sam3.1_multiplex_fp16.safetensors" \
      | wc -l \
      || true
  )"

  log "Real checkpoint file count=$checkpoint_count"

  if [[ "$checkpoint_count" -eq 0 ]]; then

    log "WARNING: No real checkpoint file found in ${COMFY_WORKSPACE}/models/checkpoints"

    log "Existing default model may only be symlinked or bundled elsewhere."

  fi
}

print_summary() {

  if [[ ${#NODE_REQ_FAILS[@]} -gt 0 ]]; then

    log "---- Node requirements failures ----"

    for x in "${NODE_REQ_FAILS[@]}"; do
      log "  - $x"
    done

  fi

  if [[ ${#MODEL_DL_FAILS[@]} -gt 0 ]]; then

    log "---- Model download failures ----"

    for x in "${MODEL_DL_FAILS[@]}"; do
      log "  - $x"
    done

  fi

  if \
    [[ ${#NODE_REQ_FAILS[@]} -eq 0 ]] \
    && [[ ${#MODEL_DL_FAILS[@]} -eq 0 ]]
  then

    log "No recorded node/model failures."

  fi
}

# ============================================================
# START
# ============================================================

provisioning_start() {

  normalize_comfy_paths

  provisioning_cleanup_legacy_hf_cache

  provisioning_cleanup_hf_artifacts

  trap provisioning_hf_exit_cleanup EXIT

  # ----------------------------------------------------------
  # Check the host first.
  #
  # Avoid wasting time downloading/installing packages on a bad
  # host.
  # ----------------------------------------------------------

  provisioning_host_preflight

  # ----------------------------------------------------------
  # Base packages
  # ----------------------------------------------------------

  provisioning_get_apt_packages

  # ----------------------------------------------------------
  # Custom nodes
  # ----------------------------------------------------------

  provisioning_get_nodes

  # ----------------------------------------------------------
  # LoRA Manager Civitai auth
  # ----------------------------------------------------------

  provisioning_configure_lora_manager_civitai

  # ----------------------------------------------------------
  # User pip packages
  # ----------------------------------------------------------

  provisioning_get_pip_packages

  # ----------------------------------------------------------
  # Hugging Face Xet
  # ----------------------------------------------------------

  provisioning_enable_hf_xet

  # ----------------------------------------------------------
  # Models
  # ----------------------------------------------------------

  provisioning_get_models_dir_urlonly \
    "${COMFY_WORKSPACE}/models/checkpoints" \
    "${CHECKPOINT_MODELS[@]}"

  provisioning_get_models_dir_urlonly \
    "${COMFY_WORKSPACE}/models/checkpoints" \
    "${SAM31_MODELS[@]}"

  provisioning_link_sam31_model

  provisioning_get_models_dir_urlonly \
    "${COMFY_WORKSPACE}/models/unet" \
    "${UNET_MODELS[@]}"

  provisioning_get_models_dir_urlonly \
    "${COMFY_WORKSPACE}/models/loras" \
    "${LORA_MODELS[@]}"

  provisioning_get_models_dir_urlonly \
    "${COMFY_WORKSPACE}/models/controlnet" \
    "${CONTROLNET_MODELS[@]}"

  provisioning_get_models_dir_urlonly \
    "${COMFY_WORKSPACE}/models/vae" \
    "${VAE_MODELS[@]}"

  provisioning_get_models_dir_urlonly \
    "${COMFY_WORKSPACE}/models/upscale_models" \
    "${UPSCALE_MODELS[@]}"

  provisioning_get_models_dir_urlonly \
    "${COMFY_WORKSPACE}/models/SEEDVR2" \
    "${SEEDVR2_MODELS[@]}"

  provisioning_get_models_dir_urlonly \
    "${COMFY_WORKSPACE}/models/diffusion_models" \
    "${DIFFUSION_MODELS[@]}"

  provisioning_get_models_dir_urlonly \
    "${COMFY_WORKSPACE}/models/text_encoders" \
    "${TEXT_ENCODER_MODELS[@]}"

  provisioning_get_models_dir_urlonly \
    "${COMFY_WORKSPACE}/models/clip_vision" \
    "${CLIP_VISION_MODELS[@]}"

  # ----------------------------------------------------------
  # Impact detector models
  #
  # Do this after custom-node installation because some node
  # install/update processes can replace their related model
  # directories.
  # ----------------------------------------------------------

  provisioning_restore_impact_detector_models

  # ----------------------------------------------------------
  # Verify
  # ----------------------------------------------------------

  verify_critical_models

  print_summary

  log "============================================================"
  log "Provisioning complete."
  log "COMFY_WORKSPACE=$COMFY_WORKSPACE"
  log "PYTHON_BIN=$PYTHON_BIN"
  log "PIP_BIN=$PIP_BIN"
  log "============================================================"
}

provisioning_start
