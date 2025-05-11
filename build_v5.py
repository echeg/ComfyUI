import subprocess
import os
import argparse

# Список моделей (имя файла)
MODELS = [
    "flux1-dev.safetensors",
    "flux1-canny-dev.safetensors",
    "flux1-depth-dev.safetensors",
    "flux1-fill-dev.safetensors",
]

STEPS = [
    ("Dockerfile.BaseModel", "base"),
    ("Dockerfile.Nodes",     "nodes"),
    ("Dockerfile.Models",    "models"),
    ("Dockerfile.Worker",    "worker"),
]

DOCKERIGNORE_PATH = ".dockerignore"
ORIGINAL_DOCKERIGNORE = None

def load_original_dockerignore():
    global ORIGINAL_DOCKERIGNORE
    if ORIGINAL_DOCKERIGNORE is None and os.path.exists(DOCKERIGNORE_PATH):
        with open(DOCKERIGNORE_PATH, 'r', encoding='utf-8') as f:
            ORIGINAL_DOCKERIGNORE = f.read()

def write_dockerignore_for(model_file: str):
    """
    Модифицирует .dockerignore: сохраняет оригинал и добавляет правила
    чтобы игнорировать все файлы в models/diffusion_models, кроме текущей модели.
    """
    load_original_dockerignore()
    filter_rules = [
        "# Auto-generated: include only specific model",
        "models/diffusion_models/*",
        f"!models/diffusion_models/{model_file}",
    ]
    with open(DOCKERIGNORE_PATH, 'w', encoding='utf-8') as f:
        if ORIGINAL_DOCKERIGNORE:
            f.write(ORIGINAL_DOCKERIGNORE.rstrip() + "\n")
        f.write("\n".join(filter_rules) + "\n")
    print(f"[INFO] .dockerignore updated: only {model_file} included in context")


def restore_original_dockerignore():
    """
    Восстанавливает исходный .dockerignore из сохранённого.
    """
    if ORIGINAL_DOCKERIGNORE is not None:
        with open(DOCKERIGNORE_PATH, 'w', encoding='utf-8') as f:
            f.write(ORIGINAL_DOCKERIGNORE)
        print("[INFO] .dockerignore restored to original")


def image_exists(tag: str) -> bool:
    """Проверяет наличие локального образа по тегу."""
    return subprocess.call(
        ["docker", "image", "inspect", tag],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    ) == 0


def build_image(dockerfile: str, context: str, tag: str, build_args: dict):
    """Собирает Docker-образ, если он ещё не существует."""
    if image_exists(tag):
        print(f"[SKIP] {tag} уже есть")
        return
    cmd = ["docker", "build", "-f", dockerfile, "-t", tag]
    for k, v in build_args.items():
        cmd += ["--build-arg", f"{k}={v}"]
    cmd.append(context)
    print(f"[BUILD] {tag} из {dockerfile} ...")
    subprocess.check_call(cmd)
    print(f"[OK] Образ {tag} построен")


def push_image(tag: str):
    """Пушит Docker-образ в реестр."""
    print(f"[PUSH] Отправка {tag} ...")
    subprocess.check_call(["docker", "push", tag])
    print(f"[OK] Образ {tag} запушен")


def build_sequence(model_file: str, version: str, do_build: bool, do_push: bool, base_system_tag: str):
    """
    Для каждой модели: модифицируем .dockerignore, собираем шаги на базе общего системного образа.
    """
    name = os.path.splitext(model_file)[0]
    previous_tag = base_system_tag

    write_dockerignore_for(model_file)
    try:
        for dockerfile, suffix in STEPS:
            tag = f"echeg/default-{name}-{suffix}:{version}"
            build_args = {"VERSION": version}
            if suffix == "base":
                build_args["MODEL_FILE"] = model_file
                build_args["BASE_IMAGE"] = previous_tag
            else:
                build_args["BASE_IMAGE"] = previous_tag

            if do_build:
                build_image(dockerfile, ".", tag, build_args)
            if do_push:
                push_image(tag)

            previous_tag = tag
    finally:
        restore_original_dockerignore()


def parse_args():
    parser = argparse.ArgumentParser(
        description="Скрипт для сборки и пуша Docker-образов моделей"
    )
    group = parser.add_mutually_exclusive_group()
    group.add_argument(
        "--build-only", action="store_true",
        help="только собрать образы, без пуша"
    )
    group.add_argument(
        "--push-only", action="store_true",
        help="только запушить существующие образы"
    )
    parser.add_argument(
        "-v", "--version", default="0.2",
        help="версия (тег) для образов"
    )
    return parser.parse_args()


def main():
    args = parse_args()
    do_build = not args.push_only
    do_push = not args.build_only
    print(f"Настройка: build={'yes' if do_build else 'no'}, push={'yes' if do_push else 'no'}")

    # Собираем и пушим единый системный образ
    system_tag = f"echeg/default-system:{args.version}"
    if do_build:
        build_image("Dockerfile.System", ".", system_tag, {"VERSION": args.version})
    if do_push:
        push_image(system_tag)

    # Для каждой модели используем общий системный образ
    for model in MODELS:
        try:
            build_sequence(model, args.version, do_build, do_push, system_tag)
        except subprocess.CalledProcessError as e:
            print(f"[ERROR] Сбой при обработке {model}: {e}")
            break

if __name__ == "__main__":
    main()
