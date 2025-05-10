#!/bin/bash

# ==============================
# ⚙️ Конфигурационные переменные
# ==============================

# Hugging Face
HF_TOKEN=""
HF_MODEL_BASENAME="flux1-fill-dev.safetensors"
HF_MODEL_FILENAME="${HF_MODEL_BASENAME}"
HF_MODEL_URL="https://huggingface.co/black-forest-labs/FLUX.1-Fill-dev/resolve/main/${HF_MODEL_BASENAME}"

# Docker
DOCKER_IMAGE_NAME="echeg/flux1-fill-dev"
DOCKER_TAG="0.3.9"
DOCKER_REGISTRY="docker.io"                 # ← Или gcr.io, ghcr.io и т.д.
DOCKER_USERNAME="echeg"
DOCKER_PASSWORD=""
DOCKER_CONTEXT_PATH="."                     # ← Папка с Dockerfile

# ========================
# 📦 Установка зависимостей
# ========================

echo "🛠 Устанавливаем зависимости..."
apt-get update && apt-get install -y wget curl docker.io || {
    echo "❌ Ошибка при установке зависимостей"
    exit 1
}

# ======================================
# ⬇️ Загрузка модели с Hugging Face
# ======================================

echo "⬇️ Проверяем наличие модели..."
if [[ -s "${HF_MODEL_FILENAME}" ]]; then
    echo "✅ Модель уже скачана: ${HF_MODEL_FILENAME}"
else
    echo "⬇️ Загружаем модель с Hugging Face..."
    curl -L -H "Authorization: Bearer ${HF_TOKEN}" \
         "${HF_MODEL_URL}" \
         -o "${HF_MODEL_FILENAME}" || {
        echo "❌ Не удалось скачать модель"
        exit 2
    }
fi

# ============================
# 📝 Создание Dockerfile
# ============================

echo "📝 Создаём Dockerfile..."
cat > "${DOCKERFILE_PATH}" <<EOF
# Stage 1: Base image with common dependencies
FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04 as base

COPY ${HF_MODEL_FILENAME} /comfyui/models/diffusion_models/${HF_MODEL_FILENAME}
RUN test -s /comfyui/models/diffusion_models/${HF_MODEL_FILENAME}

CMD ["/start.sh"]
EOF

# ========================
# 🐳 Сборка Docker образа
# ========================

echo "🐳 Собираем Docker-образ..."
docker build -t "${DOCKER_IMAGE_NAME}:${DOCKER_TAG}" "${DOCKER_CONTEXT_PATH}" || {
    echo "❌ Ошибка при сборке Docker-образа"
    exit 3
}

# ====================
# 🔐 Docker Login
# ====================

echo "🔐 Выполняем вход в Docker Registry..."
echo "${DOCKER_PASSWORD}" | docker login "${DOCKER_REGISTRY}" -u "${DOCKER_USERNAME}" --password-stdin || {
    echo "❌ Не удалось войти в Docker"
    exit 4
}

# ===========================
# 🚀 Публикация в Docker Hub
# ===========================

echo "🚀 Загружаем образ..."
docker push "${DOCKER_IMAGE_NAME}:${DOCKER_TAG}" || {
    echo "❌ Ошибка при push в Docker"
    exit 5
}

echo "✅ Успешно завершено!"
