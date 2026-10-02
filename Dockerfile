FROM runpod/comfyui:cuda12.8

COPY provision-hook.sh /provision-hook.sh
RUN chmod +x /provision-hook.sh

# 공식 start.sh에서 ComfyUI 실행 직전에
# provision-hook.sh를 한 줄 삽입
RUN sed -i \
    '/^# Start ComfyUI/i /provision-hook.sh' \
    /start.sh
