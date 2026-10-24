#!/bin/bash
# Сборщик логов: фильтрует события по ключевым словам и пишет отчёт в report.txt

LOG_FILE="${1:-${LOG_FILE:-/var/log/syslog}}"   # лог можно передать первым аргументом
REPORT="${REPORT:-report.txt}"                  # отчёт пишется в текущую директорию
KEYWORDS="${KEYWORDS:-error fail warning denied}"
TAIL_LINES="${TAIL_LINES:-5}"                   # сколько последних событий показать по каждому слову

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    echo "Использование: $0 [файл_лога]   (по умолчанию /var/log/syslog)"
    echo "Переменные: REPORT, KEYWORDS, TAIL_LINES"
    exit 0
fi

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
    echo "Сформирован: $(date '+%Y-%m-%d %H:%M:%S') на $(hostname)"
    echo "Строк в логе: $(wc -l < "$LOG_FILE")"
    echo "Ключевые слова: $KEYWORDS"
    echo ""

    echo "--- Сводка: сколько строк с каждым словом ---"
    for kw in $KEYWORDS; do
        printf "%-10s %6d\n" "$kw" "$(grep -ci -- "$kw" "$LOG_FILE")"
    done
    echo ""

    # 5-е поле строки syslog — имя программы, например "sshd[812]:"
    echo "--- Топ-5 источников событий ---"
    grep -iE -- "$(echo "$KEYWORDS" | tr ' ' '|')" "$LOG_FILE" \
        | awk '{ sub(/\[.*$/, "", $5); sub(/:$/, "", $5); print $5 }' \
        | sort | uniq -c | sort -rn | head -5
    echo ""

    for kw in $KEYWORDS; do
        echo "--- Последние $TAIL_LINES событий: $kw ---"
        matches=$(grep -i -- "$kw" "$LOG_FILE" | tail -n "$TAIL_LINES")
        if [ -n "$matches" ]; then
            echo "$matches"
        else
            echo "(совпадений нет)"
        fi
        echo ""
    done
} > "$REPORT"

echo "Отчёт сохранён: $REPORT"
