# Dockerfile — сборщик логов + HTTP-сервер, который отдаёт report.txt на порту 8080
# /var/log хоста подключается томом только для чтения:
#   docker run -d -p 8080:8080 --name my-app -v /var/log:/var/log:ro my-script

# Этап 1: проверка скрипта shellcheck — при ошибках сборка останавливается
FROM koalaman/shellcheck-alpine:stable AS lint
COPY script.sh /src/script.sh
RUN shellcheck /src/script.sh

# Этап 2: рабочий образ, сам shellcheck в него не попадает
FROM ubuntu:22.04
RUN apt-get update && apt-get install -y --no-install-recommends python3 \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /var/www
COPY --from=lint /src/script.sh /usr/local/bin/script.sh
RUN chmod +x /usr/local/bin/script.sh

ENV INTERVAL=60
EXPOSE 8080
# http.server завершается по SIGINT с кодом 0, а не по SIGTERM с кодом 143
STOPSIGNAL SIGINT

# отчёт пересобирается раз в INTERVAL секунд, http.server отдаёт содержимое /var/www
CMD ["/bin/bash", "-c", "while true; do /usr/local/bin/script.sh; sleep \"$INTERVAL\"; done & exec python3 -m http.server 8080"]
