#!/bin/bash
# Сборщик логов: фильтрует события по ключевым словам и пишет отчёт в report.txt

LOG_FILE=/var/log/syslog
REPORT=report.txt

echo "=== Отчёт по логу $LOG_FILE ===" > "$REPORT"
date >> "$REPORT"

for kw in error fail warning; do
    echo "--- $kw ---" >> "$REPORT"
    grep -i "$kw" "$LOG_FILE" | tail -n 5 >> "$REPORT"
done

echo "Отчёт сохранён: $REPORT"
