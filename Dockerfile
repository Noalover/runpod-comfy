FROM runpod/comfyui:cuda13.0

COPY provision-hook.sh /provision-hook.sh

RUN chmod +x /provision-hook.sh

RUN sed -i \
    '/^# Start ComfyUI/i /provision-hook.sh' \
    /start.sh
