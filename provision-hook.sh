#!/usr/bin/env bash
# RunPod ComfyUI startup hook (Noalover/runpod-comfy)
# Updates ComfyUI before the existing provision.sh runs, and repairs the
# synthetic Git history of the RunPod-bundled KJNodes without deleting models.
set -euo pipefail

say() { printf '[wrapper] %s\n' "$*"; }
warn() { printf '[wrapper] WARNING: %s\n' "$*" >&2; }

COMFY_WORKSPACE="${COMFY_WORKSPACE:-/workspace/runpod-slim/ComfyUI}"
COMFYUI_REPO="${COMFYUI_REPO:-https://github.com/Comfy-Org/ComfyUI.git}"
KJNODES_REPO="${KJNODES_REPO:-https://github.com/kijai/ComfyUI-KJNodes.git}"
AUTO_UPDATE_COMFYUI="${AUTO_UPDATE_COMFYUI:-1}"
COMFYUI_UPDATE_CHANNEL="${COMFYUI_UPDATE_CHANNEL:-stable}"  # stable or master
AUTO_REPAIR_KJNODES="${AUTO_REPAIR_KJNODES:-1}"
COMFYUI_GIT_TIMEOUT="${COMFYUI_GIT_TIMEOUT:-240}"
COMFYUI_PIP_TIMEOUT="${COMFYUI_PIP_TIMEOUT:-900}"

# These paths contain user-owned data or RunPod-specific state.
# rsync exclusions protect them against --delete in BOTH directions.
PRESERVE_PATHS=(
  --exclude='/models/'
  --exclude='/custom_nodes/'
  --exclude='/input/'
  --exclude='/output/'
  --exclude='/user/'
  --exclude='/temp/'
  --exclude='/.venv*/'
  --exclude='/extra_model_paths.yaml'
  --exclude='/.runpod-bundle-version'
)

choose_python() {
  if [[ -n "${PYTHON_BIN:-}" && -x "$PYTHON_BIN" ]]; then return 0; fi
  local candidate
  for candidate in \
    "$COMFY_WORKSPACE/.venv-cu130/bin/python" \
    "$COMFY_WORKSPACE/.venv-cu128/bin/python" \
    "$COMFY_WORKSPACE/.venv/bin/python"; do
    if [[ -x "$candidate" ]]; then PYTHON_BIN="$candidate"; return 0; fi
  done
  return 1
}

# Select the highest vX.Y.Z tag; exclude release candidates and test builds.
latest_stable_tag() {
  local refs
  refs="$(timeout "$COMFYUI_GIT_TIMEOUT" git ls-remote --refs --tags "$COMFYUI_REPO" 'refs/tags/v[0-9]*')" || return 1
  printf '%s\n' "$refs" \
    | sed -n 's#^.*[[:space:]]refs/tags/##p' \
    | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
    | sort -V | tail -n 1
}

update_comfyui() {
  if [[ "$AUTO_UPDATE_COMFYUI" != 1 ]]; then say 'ComfyUI automatic update disabled'; return 0; fi
  if [[ ! -f "$COMFY_WORKSPACE/main.py" ]]; then warn "ComfyUI missing: $COMFY_WORKSPACE"; return 0; fi
  if [[ ! -d "$COMFY_WORKSPACE/.git" ]]; then
    warn 'ComfyUI has no Git metadata; refusing to replace an unrecognized installation'
    return 0
  fi
  for tool in git rsync timeout; do
    if ! command -v "$tool" >/dev/null 2>&1; then warn "$tool missing: skipping ComfyUI update"; return 0; fi
  done
  if ! choose_python; then warn 'ComfyUI Python venv missing: skipping update'; return 0; fi

  local ref stage backup new_sha existing_sha result
  case "$COMFYUI_UPDATE_CHANNEL" in
    stable)
      if ! ref="$(latest_stable_tag)" || [[ -z "$ref" ]]; then
        warn 'Could not query stable ComfyUI tags. Keeping the installed version.'
        return 0
      fi
      ;;
    master) ref=master ;;
    *) warn "Unknown COMFYUI_UPDATE_CHANNEL=$COMFYUI_UPDATE_CHANNEL; use stable or master"; return 0 ;;
  esac
  say "ComfyUI target: $ref ($COMFYUI_UPDATE_CHANNEL)"

  # Only protect edits to core code. RunPod's synthetic commit also tracks
  # bundled custom_nodes, which are deliberately user-managed and may change.
  local -a core_paths=(-- .
    ':(exclude)custom_nodes' ':(exclude)models' ':(exclude)input'
    ':(exclude)output' ':(exclude)user' ':(exclude)temp'
    ':(exclude)extra_model_paths.yaml' ':(exclude).runpod-bundle-version'
    ':(exclude).venv' ':(exclude).venv-cu128' ':(exclude).venv-cu130')
  if ! git -C "$COMFY_WORKSPACE" diff --quiet --ignore-submodules "${core_paths[@]}"; then
    warn 'Local ComfyUI source edits detected; skipping automatic replacement.'
    return 0
  fi
  if ! git -C "$COMFY_WORKSPACE" diff --cached --quiet --ignore-submodules "${core_paths[@]}"; then
    warn 'Staged ComfyUI edits detected; skipping automatic replacement.'
    return 0
  fi
  local untracked_core
  untracked_core="$(git -C "$COMFY_WORKSPACE" ls-files --others --exclude-standard "${core_paths[@]}" | sed -n '1p')"
  if [[ -n "$untracked_core" ]]; then
    warn "Untracked core-root file exists ($untracked_core); refusing to delete it"
    return 0
  fi

  # Avoid cloning and pip work on every restart if already at target.
  local target_sha="" target_ref
  if [[ "$COMFYUI_UPDATE_CHANNEL" == stable ]]; then
    target_ref="refs/tags/$ref"
    # Annotated tags use the ^{} peeled object to identify the commit.
    target_sha="$(timeout "$COMFYUI_GIT_TIMEOUT" git ls-remote --tags "$COMFYUI_REPO" \
      "$target_ref" "${target_ref}^{}" 2>/dev/null \
      | awk -v peeled="${target_ref}^{}" -v direct="$target_ref" \
          '$2==peeled {print $1; found=1; exit} $2==direct {base=$1} END {if (!found && base!="") print base}' \
      | tail -n 1)" || true
  else
    target_sha="$(timeout "$COMFYUI_GIT_TIMEOUT" git ls-remote "$COMFYUI_REPO" refs/heads/master 2>/dev/null \
      | awk '$2=="refs/heads/master" {print $1; exit}')" || true
  fi
  existing_sha="$(git -C "$COMFY_WORKSPACE" rev-parse HEAD 2>/dev/null || true)"
  if [[ -n "$target_sha" && "$target_sha" == "$existing_sha" ]]; then
    say "ComfyUI is already current ($ref, ${existing_sha:0:12})"
    return 0
  fi

  # Keep all staging and backups outside ComfyUI so --delete cannot remove them.
  if ! stage="$(mktemp -d "${COMFY_WORKSPACE%/*}/.comfy-stage.XXXXXXXX")"; then
    warn 'Could not allocate staging directory'; return 0
  fi
  if ! backup="$(mktemp -d "${COMFY_WORKSPACE%/*}/.comfy-backup.XXXXXXXX")"; then
    warn 'Could not allocate backup directory'; rm -rf -- "$stage"; return 0
  fi

  # Clone into a clean directory, instead of pulling from RunPod's fake commit.
  if ! timeout "$COMFYUI_GIT_TIMEOUT" git -c http.version=HTTP/1.1 clone \
    --depth=1 --single-branch --branch "$ref" "$COMFYUI_REPO" "$stage/source"; then
    warn "ComfyUI clone failed ($ref); keeping installed version"
    rm -rf -- "$stage" "$backup"
    return 0
  fi

  if [[ "$COMFYUI_UPDATE_CHANNEL" == stable ]]; then
    # Release tags produce detached HEADs. Give Manager a real local branch;
    # the startup hook, rather than a blind 'git pull', maintains stable tags.
    if ! git -C "$stage/source" switch -c master >/dev/null ||
       ! git -C "$stage/source" config remote.origin.fetch '+refs/heads/master:refs/remotes/origin/master' ||
       ! timeout "$COMFYUI_GIT_TIMEOUT" git -C "$stage/source" fetch --depth=1 origin master >/dev/null ||
       ! git -C "$stage/source" branch --set-upstream-to=origin/master master >/dev/null; then
      warn 'Could not configure upstream for release branch; keeping installed version'
      rm -rf -- "$stage" "$backup"
      return 0
    fi
  fi

  new_sha="$(git -C "$stage/source" rev-parse HEAD)"
  existing_sha="$(git -C "$COMFY_WORKSPACE" rev-parse HEAD 2>/dev/null || true)"
  if [[ "$new_sha" == "$existing_sha" ]]; then
    say "ComfyUI is already current ($ref, ${new_sha:0:12})"
    rm -rf -- "$stage" "$backup"
    return 0
  fi
  if [[ ! -f "$stage/source/main.py" || ! -f "$stage/source/requirements.txt" ]]; then
    warn 'New checkout is incomplete; keeping installed version'
    rm -rf -- "$stage" "$backup"
    return 0
  fi

  # Image pins torch/torchvision/torchaudio through PIP_CONSTRAINT. Do not
  # unset that constraint: changing CUDA wheels can break the entire pod.
  say 'Installing dependencies for the target ComfyUI version (CUDA pins retained)'
  if ! timeout "$COMFYUI_PIP_TIMEOUT" "$PYTHON_BIN" -m pip install \
      --disable-pip-version-check --prefer-binary -r "$stage/source/requirements.txt"; then
    warn 'ComfyUI dependency update failed; keeping the current source'
    rm -rf -- "$stage" "$backup"
    return 0
  fi

  # Back up ONLY the core (never duplicate GBs of model and user data).
  say 'Backing up the existing ComfyUI core'
  if ! rsync -a "${PRESERVE_PATHS[@]}" "$COMFY_WORKSPACE/" "$backup/"; then
    warn 'Core backup failed; not touching installed ComfyUI'
    rm -rf -- "$stage" "$backup"
    return 0
  fi

  say "Applying ComfyUI $ref (${new_sha:0:12})"
  result=0
  rsync -ac --delete "${PRESERVE_PATHS[@]}" "$stage/source/" "$COMFY_WORKSPACE/" || result=$?
  if [[ "$result" -eq 0 ]]; then
    [[ -f "$COMFY_WORKSPACE/main.py" && -f "$COMFY_WORKSPACE/requirements.txt" ]] || result=2
    if [[ "$(git -C "$COMFY_WORKSPACE" rev-parse HEAD 2>/dev/null || true)" != "$new_sha" ]]; then
      warn "post-copy Git HEAD=$(git -C "$COMFY_WORKSPACE" rev-parse HEAD 2>/dev/null || true), expected=$new_sha"
      result=3
    fi
  fi
  if [[ "$result" -ne 0 ]]; then
    warn "ComfyUI copy/verification failed (rc=$result); restoring backup core"
    if ! rsync -ac --delete "${PRESERVE_PATHS[@]}" "$backup/" "$COMFY_WORKSPACE/"; then
      warn "RESTORE FAILED. A copy of the original core remains at $backup"
      rm -rf -- "$stage"
      return 0
    fi
    rm -rf -- "$stage" "$backup"
    return 0
  fi

  say "ComfyUI updated successfully: $ref (${new_sha:0:12})"
  rm -rf -- "$stage" "$backup"
}

repair_kjnodes() {
  [[ "$AUTO_REPAIR_KJNODES" == 1 ]] || return 0
  local kj="$COMFY_WORKSPACE/custom_nodes/ComfyUI-KJNodes"
  if [[ ! -d "$kj/.git" ]]; then say 'KJNodes not installed as a Git repository; skipping'; return 0; fi
  local branch origin modified
  branch="$(git -C "$kj" branch --show-current 2>/dev/null || true)"
  origin="$(git -C "$kj" remote get-url origin 2>/dev/null || true)"
  if [[ "$origin" != "$KJNODES_REPO" ]]; then
    warn "KJNodes has an unexpected remote ($origin); not replacing it"
    return 0
  fi
  if [[ "$branch" == main ]]; then
    say 'KJNodes is already on main; tracking configuration is preserved'
    if [[ -z "$(git -C "$kj" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)" ]]; then
      git -C "$kj" branch --set-upstream-to=origin/main main 2>/dev/null || true
    fi
    return 0
  fi
  if [[ "$branch" != master ]]; then
    warn "KJNodes is on $branch (not RunPod master); skipping automatic repair"
    return 0
  fi
  modified="$(git -C "$kj" status --porcelain --untracked-files=no 2>/dev/null || true)"
  if [[ -n "$modified" ]]; then warn 'KJNodes contains local tracked edits; skipping automatic repair'; return 0; fi

  say 'Repairing RunPod KJNodes synthetic master -> upstream main'
  if ! timeout "$COMFYUI_GIT_TIMEOUT" git -C "$kj" fetch origin main; then
    warn 'KJNodes fetch failed; original version retained'; return 0
  fi
  git -C "$kj" branch backup-runpod-master master 2>/dev/null || true
  if git -C "$kj" show-ref --verify --quiet refs/heads/main; then
    if ! git -C "$kj" switch main; then warn 'KJNodes switch failed; original version retained'; return 0; fi
  else
    if ! git -C "$kj" switch -c main --track origin/main; then
      warn 'KJNodes switch failed; original version retained'; return 0
    fi
  fi
  git -C "$kj" branch --set-upstream-to=origin/main main || true
  say 'KJNodes upstream branch repaired'
  if [[ -f "$kj/requirements.txt" ]]; then
    if ! timeout "$COMFYUI_PIP_TIMEOUT" "$PYTHON_BIN" -m pip install \
        --disable-pip-version-check --prefer-binary -r "$kj/requirements.txt"; then
      warn 'KJNodes dependency installation failed; inspect the node startup log'
    fi
  fi
}

say 'Provisioning started'
if [[ -z "${PROVISIONING_SCRIPT:-}" ]]; then
  warn 'PROVISIONING_SCRIPT is empty; running only the updater'
else
  if ! curl -fL --retry 5 --retry-delay 3 \
     "$PROVISIONING_SCRIPT" -o /tmp/provision.sh; then
    warn 'Could not download PROVISIONING_SCRIPT'
    exit 1
  fi
  chmod +x /tmp/provision.sh
fi

if [[ -z "${PIP_CONSTRAINT:-}" && -f /opt/comfyui-runtime-constraints.txt ]]; then
  export PIP_CONSTRAINT=/opt/comfyui-runtime-constraints.txt
fi

if choose_python; then
  export PYTHON_BIN
  export PIP_BIN="${PIP_BIN:-${PYTHON_BIN%/python}/pip}"
  say "PYTHON_BIN=$PYTHON_BIN"
else
  warn 'ComfyUI venv missing; core update and KJNodes requirements will be skipped'
  PYTHON_BIN=''
fi

# Fail open on updates so a GitHub outage does not block ComfyUI startup.
update_comfyui
if [[ -n "$PYTHON_BIN" ]]; then repair_kjnodes; fi

if [[ -n "${PROVISIONING_SCRIPT:-}" ]]; then
  say 'Running the existing provision.sh (custom nodes and models unchanged)'
  /tmp/provision.sh
fi
say 'Provisioning completed'
