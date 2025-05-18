# Докер-образ для обучения моделей

## Flow on RunPod
1. Перейдите на https://www.runpod.io/console/user/templates.
2. Выберите образ `echeg/flux-finetune:0.9` в качестве базы.
3. Добавьте переменные среды:
   - **VOLUME_PATH** — путь к volume, где хранятся данные и модели (по умолчанию `/workspace/volume`).
   - **HUGGINGFACE_TOKEN** — токен доступа к Hugging Face для скачивания приватных моделей (обязателен для старта).
   - **JUPYTER_PASSWORD** — чтобы Jupyter был доступен.
4. Прокиньте порты:
   - 7860 — для kohya_ss
   - 8888 — для Jupyter
5. Укажите Volume Mount Path такой же, как в VOLUME_PATH, на сетевой диск.
6. Запустите контейнер с этим темплейтом.
7. При старте контейнера выполняется `post_start.sh`:
   - Патчит пути в `train_config.json` под текущий VOLUME_PATH.
   - Проверяет наличие необходимых весов моделей, скачивает их с Hugging Face при необходимости (если их нет, кладет по пути `$VOLUME_PATH/fluxtrain`).
   - Запускает kohya_ss GUI на порту 7860.
   - Загружает первичные настройки из `/workspace/train_config.json`.
   - Далее нужно загрузить файлы для обучения.

## Поддерживаемые функции
- Предустановленные зависимости
- Автоматическая загрузка необходимых моделей из Hugging Face (ae, clip_l, flux1-dev, t5xxl_fp16)
- Патчинг путей в `train_config.json` под указанный volume
- Запуск GUI kohya_ss для обучения и управления процессом

## Пример запуска
```bash
docker run --name fluxf --gpus all -it -p 7861:7860 -p 8889:8888 -e VOLUME_PATH=/workspace/volume2 -e HUGGINGFACE_TOKEN=hf_token echeg/flux-finetune:0.9
```

## Структура
- `Dockerfile` — описание сборки образа
- `post_start.sh` — скрипт инициализации и запуска
- `train_config.json` — основной конфиг обучения (патчится автоматически)
- `kohya_ss/` — директория с исходниками kohya_ss

## TODO
- Можноо оптимизирвать сам докер сделать чтобы он в базе был на зависимостях от kohya_ss 
- Добавить вебсервис для принятия файлов на которых будет происходить обучение и запуск на них
- Вызывать вебсервис из Dify


## Пример стартового лога
```
Starting Nginx service...
 * Starting nginx nginx
   ...done.
Pod Started
Setting up SSH...
Starting Jupyter Lab...
Jupyter Lab started
Exporting environment variables...
Running post-start script...
>>> [post_start] Checking for mounted volume...
>>> [post_start] Using volume path: /workspace/volume
>>> [post_start] train_config.json пропатчен in-place (/workspace/train_config.json)
>>> [post_start] ae.safetensors already exists, skipping.
>>> [post_start] clip_l.safetensors already exists, skipping.
>>> [post_start] flux1-dev.safetensors already exists, skipping.
>>> [post_start] t5xxl_fp16.safetensors already exists, skipping.
>>> [run_gui] Activating virtualenv и переход в папку проекта...
>>> [run_gui] Убиваем старый процесс на порту 7860 (если есть)…
>>> [run_gui] Устанавливаем переменные среды и запускаем GUI...
2025-05-18 10:38:33.558817: E external/local_xla/xla/stream_executor/cuda/cuda_dnn.cc:9261] Unable to register cuDNN factory: Attempting to register factory for plugin cuDNN when one has already been registered
2025-05-18 10:38:33.558858: E external/local_xla/xla/stream_executor/cuda/cuda_fft.cc:607] Unable to register cuFFT factory: Attempting to register factory for plugin cuFFT when one has already been registered
2025-05-18 10:38:33.559752: E external/local_xla/xla/stream_executor/cuda/cuda_blas.cc:1515] Unable to register cuBLAS factory: Attempting to register factory for plugin cuBLAS when one has already been registered
2025-05-18 10:38:33.563966: I tensorflow/core/platform/cpu_feature_guard.cc:182] This TensorFlow binary is optimized to use available CPU instructions in performance-critical operations.
To enable the following instructions: AVX2 AVX512F AVX512_VNNI AVX512_BF16 FMA, in other operations, rebuild TensorFlow with the appropriate compiler flags.
2025-05-18 10:38:34.076737: W tensorflow/compiler/tf2tensorrt/utils/py_utils.cc:38] TF-TRT Warning: Could not find TensorRT
10:38:36-541207 WARNING  Skipping requirements verification.
10:38:36-543000 INFO     headless: False
10:38:36-543522 INFO     Using shell=True when running external commands...
```