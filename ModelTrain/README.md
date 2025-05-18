# Докер-образ для обучения моделей (module.train)

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
5. Укажите Volume Mount Path такой же, как в VOLUME_PATH на сетевой диск.
6. Запустите контейнер с этим темплейтом.
7. При старте контейнера выполняется `post_start.sh`:
   - Патчит пути в `train_config.json` под текущий VOLUME_PATH.
   - Проверяет наличие необходимых весов моделей, скачивает их с Hugging Face при необходимости (если их нет, кладет по пути `$VOLUME_PATH/fluxtrain`).
   - Запускает kohya_ss GUI на порту 7860.
   - Загружаем первичные настройки из /workspace/train_config.json
   - Далее нужно загрузить файлы для обучения


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
