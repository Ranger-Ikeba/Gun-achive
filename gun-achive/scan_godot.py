#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
scan_godot.py — сканер проекта Godot v2.

Гарантированно читает как текст: .gd, .tscn, .tres, .godot, .cfg, .import,
.obj, .mtl, .gltf, .dae, .svg, .json, .md, .txt и т.д.
Бинарные (.png, .wav, .glb, .uid) — только метаданные.

Запуск:
    python scan_godot.py
    python scan_godot.py -o report.txt --debug
"""

import argparse
import os
import sys
from datetime import datetime
from pathlib import Path

# ---------------------------------------------------------------------------
# НАСТРОЙКИ
# ---------------------------------------------------------------------------

EXCLUDE_DIRS = {
    ".godot", ".git", ".svn", ".hg", ".import",
    "node_modules", ".vscode", ".idea",
    "__pycache__", ".mypy_cache", ".pytest_cache",
    "venv", ".venv",
}

# Файлы, которые не нужно включать в отчёт (сам скрипт и его вывод)
EXCLUDE_FILES = {
    "scan_godot.py",
    "godot_scan_report.txt",
}

# ВСЕГДА читаем как текст (без эвристики)
FORCE_TEXT_EXTENSIONS = {
    # Godot
    ".gd", ".tscn", ".tres", ".godot", ".cfg", ".import",
    ".gdshader", ".gdshaderinc", ".shader",
    # Текстовые 3D-форматы
    ".obj", ".mtl", ".gltf", ".dae", ".svg",
    # C#
    ".cs", ".csproj", ".sln",
    # Данные / конфиги
    ".json", ".txt", ".md", ".xml", ".yaml", ".yml",
    ".ini", ".toml", ".env", ".csv", ".editorconfig",
    # Web
    ".html", ".css", ".js", ".ts",
    # Локализация
    ".po", ".pot",
    # Скрипты
    ".sh", ".bat", ".ps1",
}

# ВСЕГДА бинарные — только метаданные
FORCE_BINARY_EXTENSIONS = {
    # Godot 4.x UID — реально бинарные
    ".uid",
    # 3D
    ".fbx", ".glb", ".blend", ".3ds", ".stl",
    # Изображения
    ".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tga", ".gif", ".ico",
    # Аудио
    ".wav", ".ogg", ".mp3", ".flac",
    # Шрифты
    ".ttf", ".otf", ".woff", ".woff2",
    # Архивы / сборки
    ".pck", ".zip", ".7z", ".rar", ".tar", ".gz",
    # Бинарники
    ".exe", ".dll", ".so", ".dylib", ".bin", ".dat",
}


# ---------------------------------------------------------------------------
# ВСПОМОГАТЕЛЬНЫЕ
# ---------------------------------------------------------------------------

def human_size(n: int) -> str:
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if n < 1024.0:
            return f"{n} {unit}" if unit == "B" else f"{n:.2f} {unit}"
        n /= 1024.0
    return f"{n:.2f} PB"


def collect_files(root: Path):
    files = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in EXCLUDE_DIRS]
        for name in filenames:
            if name in EXCLUDE_FILES:
                continue
            files.append(Path(dirpath) / name)
    return sorted(files, key=lambda p: str(p).lower())


def read_text(path: Path) -> str:
    for enc in ("utf-8", "utf-8-sig", "cp1251", "latin-1"):
        try:
            with open(path, "r", encoding=enc) as f:
                return f.read()
        except UnicodeDecodeError:
            continue
        except OSError as e:
            return f"[ОШИБКА ЧТЕНИЯ: {e}]"
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError as e:
        return f"[ОШИБКА ЧТЕНИЯ: {e}]"


def has_nulls(path: Path, sample: int = 8192) -> bool:
    try:
        with open(path, "rb") as f:
            return b"\x00" in f.read(sample)
    except OSError:
        return True


def classify(path: Path) -> str:
    """'text' | 'binary' | 'unknown'"""
    ext = path.suffix.lower()
    if ext in FORCE_TEXT_EXTENSIONS:
        return "text"
    if ext in FORCE_BINARY_EXTENSIONS:
        return "binary"
    return "unknown"


# ---------------------------------------------------------------------------
# ОСНОВНОЕ
# ---------------------------------------------------------------------------

def scan(root: Path, output: Path, include_binary_meta: bool,
         max_size_mb: float, debug: bool):
    files = collect_files(root)
    total = len(files)
    max_bytes = int(max_size_mb * 1024 * 1024)

    print(f"Проект:  {root}")
    print(f"Файлов:  {total}")
    print(f"Отчёт:   {output}")
    print()

    text_count = binary_count = unknown_count = 0

    with open(output, "w", encoding="utf-8", newline="\n") as out:
        out.write("=" * 100 + "\n")
        out.write("ОТЧЁТ СКАНИРОВАНИЯ ПРОЕКТА GODOT\n")
        out.write("=" * 100 + "\n")
        out.write(f"Проект:       {root}\n")
        out.write(f"Дата:         {datetime.now():%Y-%m-%d %H:%M:%S}\n")
        out.write(f"Всего файлов: {total}\n")
        out.write(f"Платформа:    {sys.platform}\n")
        out.write("=" * 100 + "\n\n")

        # ---- Оглавление ----
        out.write("### ОГЛАВЛЕНИЕ ###\n\n")
        for p in files:
            out.write(f"  {p.relative_to(root).as_posix()}\n")
        out.write("\n")

        # ---- Содержимое ----
        out.write("### СОДЕРЖИМОЕ ФАЙЛОВ ###\n\n")

        skipped_big = []
        for i, p in enumerate(files, 1):
            rel = p.relative_to(root).as_posix()
            try:
                st = p.stat()
                size = st.st_size
                mtime = datetime.fromtimestamp(st.st_mtime)
            except OSError:
                size, mtime = 0, None

            kind = classify(p)

            if kind == "text":
                text_count += 1
            elif kind == "binary":
                binary_count += 1
            else:
                unknown_count += 1

            if debug:
                print(f"  [{i}/{total}] {kind:<7} {rel} ({human_size(size)})")
            else:
                print(f"[{i}/{total}] {rel}  ({human_size(size)})")

            out.write("-" * 100 + "\n")
            out.write(f"ФАЙЛ: {rel}\n")
            out.write(f"Размер: {human_size(size)} ({size} байт)\n")
            if mtime:
                out.write(f"Изменён: {mtime:%Y-%m-%d %H:%M:%S}\n")
            out.write(f"Тип: {kind}\n")
            out.write("-" * 100 + "\n")

            if size > max_bytes:
                skipped_big.append(rel)
                out.write(f"[ПРОПУЩЕН: > {max_size_mb} МБ]\n\n\n")
                continue

            # --- ТЕКСТ ---
            if kind == "text":
                content = read_text(p)
                if not content.strip():
                    out.write("[ПУСТОЙ ФАЙЛ]\n")
                else:
                    out.write(content)
                    if not content.endswith("\n"):
                        out.write("\n")

            # --- БИНАРНЫЙ ---
            elif kind == "binary":
                if include_binary_meta:
                    out.write("[БИНАРНЫЙ ФАЙЛ — содержимое не отображается]\n")
                    try:
                        with open(p, "rb") as f:
                            head = f.read(32)
                        out.write("Первые 32 байта (hex): "
                                  + " ".join(f"{b:02x}" for b in head) + "\n")
                    except OSError:
                        pass
                else:
                    out.write("[БИНАРНЫЙ ФАЙЛ — пропущен]\n")

            # --- НЕИЗВЕСТНЫЙ ---
            else:
                if has_nulls(p):
                    if include_binary_meta:
                        out.write("[БИНАРНЫЙ (эвристика) — содержимое не отображается]\n")
                    else:
                        out.write("[НЕИЗВЕСТНЫЙ — пропущен]\n")
                else:
                    out.write("[НЕИЗВЕСТНЫЙ, но текстовый — вывожу содержимое]\n")
                    content = read_text(p)
                    out.write(content)
                    if content and not content.endswith("\n"):
                        out.write("\n")

            out.write("\n\n")

        # ---- Итог ----
        out.write("=" * 100 + "\n")
        out.write("КОНЕЦ ОТЧЁТА\n")
        out.write(f"Текстовых файлов:    {text_count}\n")
        out.write(f"Бинарных файлов:     {binary_count}\n")
        out.write(f"Неизвестных:         {unknown_count}\n")
        if skipped_big:
            out.write(f"\nПропущены из-за размера (>{max_size_mb} МБ):\n")
            for f in skipped_big:
                out.write(f"  {f}\n")
        out.write("=" * 100 + "\n")

    print()
    print(f"Готово! Отчёт: {output.resolve()}")
    print(f"Размер: {human_size(output.stat().st_size)}")
    print(f"Текстовых: {text_count}, бинарных: {binary_count}, неизвестных: {unknown_count}")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(description="Сканер проекта Godot v2")
    ap.add_argument("-p", "--path", default=".", help="Корень проекта (по умолчанию: текущая папка)")
    ap.add_argument("-o", "--output", default="godot_scan_report.txt", help="Выходной файл")
    ap.add_argument("--no-binary", action="store_true", help="Не включать метаданные бинарных")
    ap.add_argument("--max-size", type=float, default=20.0, help="Макс. размер текстового файла, МБ")
    ap.add_argument("--debug", action="store_true", help="Показывать классификацию каждого файла")
    args = ap.parse_args()

    root = Path(args.path).resolve()
    if not root.is_dir():
        print(f"Ошибка: {root} не папка", file=sys.stderr)
        sys.exit(1)
    if not (root / "project.godot").exists():
        print("⚠  project.godot не найден — это точно проект Godot?")

    output = Path(args.output)
    if not output.is_absolute():
        output = root / output

    scan(root, output,
         include_binary_meta=not args.no_binary,
         max_size_mb=args.max_size,
         debug=args.debug)


if __name__ == "__main__":
    main()
