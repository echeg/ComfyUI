#!/usr/bin/env bash
set -e

echo ">>> [Script 2] This script will handle Claude analysis and config update."

###############################################################################
# 1. Ожидание нажатия Enter и получение дополнительных комментариев
###############################################################################

echo ">>> [Script 2] Введите дополнительные комментарии по поводу арта (или нажмите Enter, чтобы пропустить):"
read USER_COMMENTS

###############################################################################
# 2. Распаковываем все .zip в /workspace/MyLearningDataset/Images
###############################################################################
echo ">>> [Script 2] Unzipping all .zip in /workspace/MyLearningDataset/Images ..."
find /workspace/MyLearningDataset/Images -type f -name '*.zip' | while read zipf; do
    unzip -o "$zipf" -d /workspace/MyLearningDataset/Images
    rm -f "$zipf"
done

###############################################################################
# 3. Собираем до 35 .txt файлов
###############################################################################
echo ">>> [Script 2] Collecting up to 35 .txt files ..."
TXT_FILES=$(find /workspace/MyLearningDataset/Images -type f -name '*.txt' | head -n 35)

if [ -z "$TXT_FILES" ]; then
  echo "[Script 2] WARNING: No .txt files found (up to 35)."
fi

###############################################################################
# 4. Устанавливаем библиотеку anthropic (если не установлена)
#    И указываем ANTHROPIC_API_KEY
###############################################################################
echo ">>> [Script 2] Installing anthropic library (if needed) ..."
pip install anthropic


###############################################################################
# 5. Запускаем Python-скрипт claude_analysis.py, передавая список файлов
###############################################################################
echo ">>> [Script 2] Sending request to Claude via claude_analysis.py ..."
# Сохраняем список файлов во временный файл
echo "$TXT_FILES" > /tmp/txt_files_list.txt

# Передаем комментарии через переменную окружения
export USER_COMMENTS="$USER_COMMENTS"

# Получаем ответ от скрипта и извлекаем только валидный JSON
PARSED_JSON=$(python /workspace/claude_analysis.py --files-list /tmp/txt_files_list.txt 2>/dev/null | grep -o '{"token".*}' || true)

# Выводим полный ответ для отладки
echo ">>> [Script 2] Raw response from claude_analysis.py:"
echo "$PARSED_JSON"
echo ">>> [Script 2] End of raw response"
echo

# Очистка временного файла
rm -f /tmp/txt_files_list.txt

if [ -z "$PARSED_JSON" ]; then
  echo "[Script 2] ERROR: Claude response is empty or not found."
  exit 1
fi

# Проверка на ошибку (на всякий случай)
if [[ "$PARSED_JSON" == *"error"* ]]; then
  echo "[Script 2] ERROR: JSON parse problem. See logs."
  echo "$PARSED_JSON"
  exit 1
fi

###############################################################################
# 6. Из полученного JSON извлекаем нужные поля и даем возможность их отредактировать
###############################################################################
# Сохраняем JSON во временный файл для редактирования
TMP_JSON="/tmp/claude_response.json"
echo "$PARSED_JSON" > "$TMP_JSON"

echo ">>> [Script 2] Сохранен файл с результатами анализа: $TMP_JSON"
echo ">>> [Script 2] Текущие значения:"
echo "----------------------------------------"
echo "token      = $(echo "$PARSED_JSON" | python -c 'import sys, json; print(json.load(sys.stdin)["token"])')"
echo "art_type   = $(echo "$PARSED_JSON" | python -c 'import sys, json; print(json.load(sys.stdin)["art_type"])')"
echo "style_name = $(echo "$PARSED_JSON" | python -c 'import sys, json; print(json.load(sys.stdin)["style_name"])')"
echo "model_name = $(echo "$PARSED_JSON" | python -c 'import sys, json; print(json.load(sys.stdin)["model_name"])')"
echo "prompts:"
echo "$PARSED_JSON" | python -c 'import sys, json; print("\n".join(json.load(sys.stdin)["prompts"]))'
echo "----------------------------------------"

echo ">>> [Script 2] Пожалуйста, проверьте и отредактируйте файл если нужно: $TMP_JSON"
echo ">>> [Script 2] После завершения редактирования нажмите Enter для продолжения..."
read

# Читаем обновленный JSON
PARSED_JSON=$(cat "$TMP_JSON")

# Проверяем валидность JSON
if ! echo "$PARSED_JSON" | python -c 'import sys,json; json.load(sys.stdin)' >/dev/null 2>&1; then
    echo "[Script 2] ERROR: Файл содержит невалидный JSON. Пожалуйста, исправьте и попробуйте снова."
    exit 1
fi

# Извлекаем значения из обновленного JSON
TOKEN=$(echo "$PARSED_JSON"      | python -c 'import sys, json; d=json.load(sys.stdin); print(d["token"])')
ART_TYPE=$(echo "$PARSED_JSON"   | python -c 'import sys, json; d=json.load(sys.stdin); print(d["art_type"])')
STYLE_NAME=$(echo "$PARSED_JSON" | python -c 'import sys, json; d=json.load(sys.stdin); print(d["style_name"])')
MODEL_NAME=$(echo "$PARSED_JSON" | python -c 'import sys, json; d=json.load(sys.stdin); print(d["model_name"])')

# Многострочные промпты
PROMPTS=$(echo "$PARSED_JSON"    | python -c '
import sys, json
d=json.load(sys.stdin)
prompts = d.get("prompts", [])
print("\n".join(prompts))
')

echo ">>> [Script 2] Обновленные значения:"
echo "token      = $TOKEN"
echo "art_type   = $ART_TYPE"
echo "style_name = $STYLE_NAME"
echo "model_name = $MODEL_NAME"
echo "prompts:"
echo "$PROMPTS"
echo

echo ">>> [Script 2] Нажмите Enter для продолжения или Ctrl+C для отмены..."
read

# Очистка временного файла
rm -f "$TMP_JSON"

###############################################################################
# 7. Переносим .txt и .png файлы в папку /workspace/MyLearningDataset/Images/1_{model_name}_{style_name}
###############################################################################
NEW_FOLDER="/workspace/MyLearningDataset/Images/1_${MODEL_NAME}_${STYLE_NAME}"
mkdir -p "$NEW_FOLDER"

echo ">>> [Script 2] Moving all .txt and .png files into $NEW_FOLDER ..."
find /workspace/MyLearningDataset/Images -type f \( -name '*.txt' -o -name '*.png' \) -exec mv -f {} "$NEW_FOLDER" \; 2>/dev/null || true

###############################################################################
# 8. Ищем FluxDatasetConfig.json и редактируем нужные поля
###############################################################################
FLUX_CONFIG_PATH=$(find /workspace -name "FluxDatasetConfig.json" | head -n 1)
if [ -z "$FLUX_CONFIG_PATH" ]; then
  echo "[Script 2] ERROR: FluxDatasetConfig.json not found!"
  exit 1
fi

echo ">>> [Script 2] Updating FluxDatasetConfig.json at $FLUX_CONFIG_PATH ..."
cat <<EOF > /workspace/update_flux_config.py
import json

path = r"${FLUX_CONFIG_PATH}"
with open(path, "r", encoding="utf-8") as f:
    config = json.load(f)

config["train_data_dir"] = "/workspace/MyLearningDataset/Images"
config["output_dir"] = "/workspace/MyLearningDataset/Models"
config["output_name"] = "${MODEL_NAME}"
config["huggingface_repo_id"] = "Gerchegg/${MODEL_NAME}"
config["logging_dir"] = "/workspace/MyLearningDataset/Logs"

# Форматируем промпты с дополнительными параметрами
formatted_prompts = []
negative_params = "--n low quality, worst quality, bad anatomy, bad composition, poor, low effort --w 1024 --h 1024 --d 1 --l 3 --s 20"

for prompt in """${PROMPTS}""".split('\n'):
    if prompt.strip():
        formatted_prompt = f"${TOKEN}, {prompt.strip()} {negative_params}"
        formatted_prompts.append(formatted_prompt)

# Объединяем промпты в строку с переносами строк
config["sample_prompts"] = "\n".join(formatted_prompts)

with open(path, "w", encoding="utf-8") as f:
    json.dump(config, f, ensure_ascii=False, indent=2)
EOF

python /workspace/update_flux_config.py

echo ">>> [Script 2] Done. Analysis complete!"
