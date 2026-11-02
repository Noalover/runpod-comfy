FROM runpod/comfyui:cuda13.0

ARG BUILD_ID=local
ENV RUNPOD_COMFY_BUILD_ID=${BUILD_ID}

# Install tools in the Docker image, not on every paid GPU Pod boot.
RUN apt-get update && apt-get install -y --no-install-recommends \
    git rsync curl wget aria2 file ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY node-repos.txt /opt/runpod-comfy/node-repos.txt
COPY bake.sh /opt/runpod-comfy/bake.sh
RUN chmod +x /opt/runpod-comfy/bake.sh \
    && printf '%s\n' "$RUNPOD_COMFY_BUILD_ID" > /opt/runpod-comfy/build-id \
    && /opt/runpod-comfy/bake.sh

COPY provision-hook.sh /provision-hook.sh
RUN chmod +x /provision-hook.sh

# Keep the original provision-hook.sh, including its KJNodes repair logic.
RUN grep -q '^# Start ComfyUI' /start.sh \
    && sed -i '/^# Start ComfyUI/i /provision-hook.sh' /start.sh
