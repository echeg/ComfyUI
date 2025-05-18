#!/usr/bin/env bash
set -e

###############################################################################
# Direct download of specific model files from Hugging Face
###############################################################################

echo ">>> [post_start] Checking for mounted volume..."
VOLUME_PATH=${VOLUME_PATH:-"/workspace/volume"}
echo ">>> [post_start] Using volume path: $VOLUME_PATH"

MODEL_DIR="$VOLUME_PATH/fluxtrain"
mkdir -p "$MODEL_DIR"

# List of files to download
FILES=(
  "ae.safetensors"
  "clip_l.safetensors"
  #"flux1-dev-fp8.safetensors" # FP8 not used
  "flux1-dev.safetensors"
  "t5xxl_fp16.safetensors"
)

REPO_URL="https://huggingface.co/OwlMaster/FLUX_LoRA_Train/resolve/main"

if [ -z "$HUGGINGFACE_TOKEN" ]; then
  echo ">>> [post_start] ERROR: HUGGINGFACE_TOKEN environment variable is not set."
  echo ">>> [post_start] Please set your Hugging Face token and restart."
else
  for file in "${FILES[@]}"; do
    target_file="$MODEL_DIR/$file"
    if [ -f "$target_file" ]; then
      echo ">>> [post_start] $file already exists, skipping."
    else
      echo ">>> [post_start] Downloading $file ..."
      curl -L -H "Authorization: Bearer $HUGGINGFACE_TOKEN" -o "$target_file" "$REPO_URL/$file"
      if [ $? -eq 0 ]; then
        echo ">>> [post_start] $file downloaded successfully."
      else
        echo ">>> [post_start] ERROR: Failed to download $file."
      fi
    fi
  done
fi

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

