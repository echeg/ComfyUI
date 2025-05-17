#!/usr/bin/env bash
set -e

###############################################################################
# Скрипт: run_gui.sh
# Запускает GUI kohya_ss
###############################################################################

echo ">>> [run_gui] Activating virtualenv и переход в папку проекта..."
cd /workspace/kohya_ss
source venv/bin/activate

echo ">>> [run_gui] Убиваем старый процесс на порту 7860 (если есть)…"
fuser -k 7860/tcp || true

echo ">>> [run_gui] Устанавливаем переменные среды и запускаем GUI..."
export HF_HUB_ENABLE_HF_TRANSFER=0
./gui.sh --listen=0.0.0.0 --share --noverify

