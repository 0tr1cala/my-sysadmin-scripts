# Dockerfile — сборщик логов в контейнере
# /var/log хоста внутри контейнера не видно, его нужно подключить томом:
#   docker run --rm -v /var/log:/var/log:ro my-script
FROM ubuntu:22.04
COPY script.sh /usr/local/bin/script.sh
RUN chmod +x /usr/local/bin/script.sh
WORKDIR /var/www
CMD ["/usr/local/bin/script.sh"]
