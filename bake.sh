#!/usr/bin/env bash
# Preinstall the newest stable ComfyUI and selected custom nodes at IMAGE BUILD
# time, before any paid GPU Pod starts. KJNodes is not managed here.
set -euo pipefail

BAKED_COMFY="/opt/comfyui-baked"
BAKE_DIR="/opt/runpod-comfy"
REPOS_FILE="$BAKE_DIR/node-repos.txt"
STAMP_DIR="$BAKE_DIR/baked-node-stamps"
CORE_REPO="https://github.com/Comfy-Org/ComfyUI.git"
PIP_CONSTRAINT_FILE="/opt/comfyui-runtime-constraints.txt"
PYTHON_BIN="python3.12"

die() { echo "[bake] ERROR: $*" >&2; exit 1; }
log() { echo "[bake] $*"; }

[[ -f "$BAKED_COMFY/main.py" ]] || die "Official baked ComfyUI is missing"
[[ -f "$REPOS_FILE" ]] || die "Node manifest is missing"
[[ -f "$PIP_CONSTRAINT_FILE" ]] || die "CUDA pip constraints are missing"
mkdir -p "$STAMP_DIR"

# Detect accidental modification. The original startup hook still owns the
# KJNodes repair behavior; this build step never updates its repository.
KJ_DIR="$BAKED_COMFY/custom_nodes/ComfyUI-KJNodes"
[[ -d "$KJ_DIR" ]] || die "Official KJNodes directory is missing"
kj_before="$(git -C "$KJ_DIR" rev-parse HEAD 2>/dev/null || true)"
export PIP_CONSTRAINT="$PIP_CONSTRAINT_FILE"

log "Resolving latest stable ComfyUI tag"
stable_tag="$(git ls-remote --refs --tags "$CORE_REPO" 'refs/tags/v[0-9]*' \
  | sed -n 's#^.*[[:space:]]refs/tags/##p' \
  | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
  | sort -V | tail -n 1)"
[[ -n "$stable_tag" ]] || die "No stable ComfyUI release found"
git clone --depth=1 --single-branch --branch "$stable_tag" "$CORE_REPO" /tmp/comfy-core-source
git -C /tmp/comfy-core-source switch -c master
git -C /tmp/comfy-core-source config remote.origin.fetch '+refs/heads/master:refs/remotes/origin/master'
git -C /tmp/comfy-core-source fetch --depth=1 origin master
git -C /tmp/comfy-core-source branch --set-upstream-to=origin/master master
core_sha="$(git -C /tmp/comfy-core-source rev-parse HEAD)"

log "Installing ComfyUI $stable_tag requirements with CUDA constraints"
"$PYTHON_BIN" -m pip install --disable-pip-version-check --prefer-binary --no-cache-dir \
  -r /tmp/comfy-core-source/requirements.txt

# Preserve official bundled nodes (especially KJNodes), models and user data.
rsync -a --delete \
  --exclude='/custom_nodes/' \
  --exclude='/models/' \
  --exclude='/input/' \
  --exclude='/output/' \
  --exclude='/user/' \
  --exclude='/temp/' \
  --exclude='/.venv*/' \
  --exclude='/extra_model_paths.yaml' \
  --exclude='/.runpod-bundle-version' \
  /tmp/comfy-core-source/ "$BAKED_COMFY/"

bundle_file="$BAKED_COMFY/.runpod-bundle-version"
[[ -f "$bundle_file" ]] || die "Official bundle version file is missing"
sed -i "s/^COMFYUI_VERSION=.*/COMFYUI_VERSION=$stable_tag/" "$bundle_file"
grep -q "^COMFYUI_VERSION=$stable_tag$" "$bundle_file" || die "Cannot record core version"
printf 'NOALOVER_CORE_SHA=%s\n' "$core_sha" >> "$bundle_file"

log "Cloning custom nodes and installing their requirements"
while IFS= read -r repo || [[ -n "$repo" ]]; do
  [[ -z "$repo" || "$repo" == \#* ]] && continue
  name="${repo##*/}"
  [[ "$name" == "ComfyUI-KJNodes" ]] && die "KJNodes must not be built by this script"
  [[ "$name" =~ ^[A-Za-z0-9_.-]+$ ]] || die "Invalid node directory name: $name"
  node_path="$BAKED_COMFY/custom_nodes/$name"

  if [[ -d "$node_path" ]]; then
    git clone --depth=1 --recursive "$repo" "/tmp/bake-$name"
    rsync -a --delete "/tmp/bake-$name/" "$node_path/"
    rm -rf -- "/tmp/bake-$name"
  else
    git clone --depth=1 --recursive "$repo" "$node_path"
  fi

  req="$node_path/requirements.txt"
  req_hash="none"
  if [[ -f "$req" ]]; then
    req_hash="$(sha256sum "$req" | awk '{print $1}')"
    # Match the existing provision.sh SAM2 exclusion without editing the
    # node's tracked requirements.txt (which would break future git pulls).
    temp_req="$(mktemp "$node_path/.runpod-req.XXXXXX")"
    sed '/facebookresearch\/sam2/s/^/# /;s/^# # /# /' "$req" > "$temp_req"
    if ! "$PYTHON_BIN" -m pip install --disable-pip-version-check --prefer-binary \
      --no-cache-dir -r "$temp_req"; then
      rm -f -- "$temp_req"
      die "Dependency installation failed: $name"
    fi
    rm -f -- "$temp_req"
  fi

  node_sha="$(git -C "$node_path" rev-parse HEAD)"
  printf '%s|%s|%s\n' "${RUNPOD_COMFY_BUILD_ID:-local}" "$node_sha" "$req_hash" \
    > "$STAMP_DIR/$name"
  log "Baked $name: ${node_sha:0:12}"
done < "$REPOS_FILE"

kj_after="$(git -C "$KJ_DIR" rev-parse HEAD 2>/dev/null || true)"
[[ "$kj_before" == "$kj_after" ]] || die "KJNodes unexpectedly changed during baking"

"$PYTHON_BIN" -m pip check || die "Dependency conflicts found"
rm -rf -- /tmp/comfy-core-source
log "Bake succeeded: ComfyUI $stable_tag ($core_sha); KJNodes preserved"
