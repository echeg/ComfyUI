#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import sys
import json
from pathlib import Path

try:
    import anthropic
except ImportError:
    print("\nERROR: anthropic library is not installed")
    print("To install, run: pip install anthropic")
    print("or: python -m pip install anthropic\n")
    print(json.dumps({"error": "Missing anthropic library. Please run: pip install anthropic"}))
    sys.exit(1)

# Проверяем версию anthropic
try:
    anthropic_version = anthropic.__version__
    print(f"\nDEBUG - Using anthropic version: {anthropic_version}")
except:
    print("\nWARNING - Could not determine anthropic version")

api_key = os.environ.get("ANTHROPIC_API_KEY", "")
if not api_key:
    print(json.dumps({"error": "No ANTHROPIC_API_KEY provided"}))
    sys.exit(0)

def get_txt_contents(local_path=None):
    """
    Получает содержимое .txt файлов
    """
    txt_contents = []
    
    # Проверяем аргументы командной строки
    if len(sys.argv) > 2 and sys.argv[1] == "--files-list":
        try:
            with open(sys.argv[2], 'r') as f:
                txt_file_list = [line.strip() for line in f if line.strip()]
                
            for f in txt_file_list:
                try:
                    with open(f, 'r', encoding='utf-8') as ff:
                        txt_contents.append(ff.read())
                except Exception as e:
                    print(f"DEBUG - Error reading {f}: {e}")
                    
            return txt_contents
        except Exception as e:
            print(f"DEBUG - Error reading files list: {e}")
    
    # Если список файлов не передан, используем локальную папку
    if local_path:
        try:
            path = Path(local_path)
            if path.exists():
                print(f"\nDEBUG - Reading files from local path: {path}")
                for txt_file in path.glob("*.txt"):
                    try:
                        with open(txt_file, 'r', encoding='utf-8') as f:
                            txt_contents.append(f.read())
                            print(f"DEBUG - Read file: {txt_file.name}")
                    except Exception as e:
                        print(f"DEBUG - Error reading {txt_file}: {e}")
                return txt_contents
        except Exception as e:
            print(f"\nDEBUG - Error accessing local path: {e}")
    
    # Если локальная папка недоступна, используем аргументы командной строки
    txt_file_list = sys.argv[1:]
    if not txt_file_list:
        return txt_contents
        
    for f in txt_file_list:
        try:
            with open(f, 'r', encoding='utf-8') as ff:
                txt_contents.append(ff.read())
        except Exception as e:
            print(f"DEBUG - Error reading {f}: {e}")
            
    return txt_contents

# -----------------------------------------------------------------------------
# 1. Собираем список файлов
# -----------------------------------------------------------------------------
local_path = r"G:\My Drive\Kohya_SS\Flux\SoloBand\IconsGray"
txt_contents = get_txt_contents(local_path)

if not txt_contents:
    print("\nDEBUG - No text files found in local path or arguments")

combined_text = "\n---\n".join(txt_contents)

# Получаем комментарии пользователя из переменной окружения
user_comments = os.environ.get("USER_COMMENTS", "")

# -----------------------------------------------------------------------------
# 2. Формируем промпт для Claude
# -----------------------------------------------------------------------------
prompt_content = f"""You are an AI art director specializing in creating cohesive visual styles. Analyze the input and generate a JSON response that defines a clear artistic direction.

Rules:
1. Always return ONLY valid JSON with no additional text
2. Keep style consistent across all prompts
3. Focus on visual elements, not story
4. Be specific and detailed in descriptions
5. Consider user's additional comments in style selection

Required JSON format:
{{
  "token": "SB_AI",
  "art_type": "Short descriptive name of art category (2-4 words)",
  "style_name": "Clear art style description (3-5 words)",
  "model_name": "SB_AI_art_type_V1",
  "prompts": [
    "6 detailed prompts that match art_type and style",
    "Each 1-2 sentences, focusing on visual elements",
    "Include colors, shapes, textures, composition",
    "Keep consistent style across all prompts",
    "Be specific about materials and techniques",
    "Maintain same level of detail in each prompt"
  ]
}}

Note: For casual art style (SB_AI token):
- Use bright, vibrant colors
- Focus on everyday objects with playful twists
- Keep designs simple but appealing
- Add small decorative details
- Use smooth, rounded shapes
- Maintain light, cheerful mood

Input content to analyze:
---
{combined_text}

Additional user comments:
{user_comments}
"""

# Добавляем отладочный вывод промпта
print("\nDEBUG - Full prompt being sent to Claude:")
print("="*80)
print(prompt_content)
print("="*80)

# -----------------------------------------------------------------------------
# 3. Обращаемся к Anthropic (Claude) с указанной моделью
# -----------------------------------------------------------------------------
try:
    client = anthropic.Anthropic(api_key=api_key)
    message = client.messages.create(
        model="claude-3-sonnet-20240229",
        max_tokens=1024,
        messages=[
            {
                "role": "user",
                "content": prompt_content
            }
        ],
        temperature=0.7,
    )
    raw_reply = message.content[0].text
except Exception as e:
    print(json.dumps({"error": f"Request to Claude failed: {str(e)}"}))
    sys.exit(0)

# -----------------------------------------------------------------------------
# 4. Пытаемся интерпретировать ответ как JSON
# -----------------------------------------------------------------------------
try:
    data = json.loads(raw_reply)
except:
    # Если парсить напрямую не получается, отправим ошибку
    print(json.dumps({"error": "Claude response is not valid JSON", "raw_reply": raw_reply}))
    sys.exit(0)

# -----------------------------------------------------------------------------
# 5. (опционально) Проверяем, что в ответе есть нужные поля
# -----------------------------------------------------------------------------
token = data.get("token", "SB_AI")
art_type = data.get("art_type", "UnknownArtType")
style_name = data.get("style_name", "UnknownStyle")
model_name = data.get("model_name", f"{token}_{art_type}_V1")
prompts = data.get("prompts", [])

# -----------------------------------------------------------------------------
# 6. Выводим финальный JSON в stdout
# -----------------------------------------------------------------------------
out = {
  "token": token,
  "art_type": art_type,
  "style_name": style_name,
  "model_name": model_name,
  "prompts": prompts
}
print(json.dumps(out, ensure_ascii=False))
