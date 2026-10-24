#!/bin/bash
# Сборщик логов: фильтрует события по ключевым словам и пишет отчёт в report.txt

LOG_FILE="${1:-/var/log/syslog}"   # лог можно передать первым аргументом
REPORT=report.txt

# проверяем, что лог существует и его можно читать
if [ ! -e "$LOG_FILE" ]; then
    echo "Ошибка: файл лога $LOG_FILE не найден" >&2
    exit 1
fi
if [ ! -r "$LOG_FILE" ]; then
    echo "Ошибка: нет прав на чтение $LOG_FILE (нужен sudo или группа adm)" >&2
    exit 2
fi

# проверяем, что в отчёт можно писать
if ! touch "$REPORT" 2> /dev/null; then
    echo "Ошибка: нет прав на запись в $REPORT" >&2
    exit 3
fi

{
    echo "=== Отчёт по логу $LOG_FILE ==="
    date '+%Y-%m-%d %H:%M:%S'
    for kw in error fail warning; do
        echo "--- $kw ---"
        grep -i -- "$kw" "$LOG_FILE" | tail -n 5
    done
} > "$REPORT"

echo "Отчёт сохранён: $REPORT"
