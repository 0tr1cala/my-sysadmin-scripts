`script.sh` — сборщик логов: читает `/var/log/syslog` (или файл из первого аргумента, например `/var/log/auth.log`), фильтрует события по ключевым словам `error`, `fail`, `warning`, `denied` и пишет отчёт в `report.txt`. Пример отчёта лежит в `sample_output.txt`.

## Структура

```
my-sysadmin-scripts/
├── script.sh                    # сборщик логов (ДЗ1)
├── sample_output.txt            # пример вывода
├── Dockerfile                   # multi-stage: shellcheck -> ubuntu + python3 http.server на 8080
├── docker-compose.yml           # то же через docker compose
├── storage.sh                   # RAID 1 (/mnt/raid) и LVM (/mnt/logs) на loop-устройствах
└── deploy/
    ├── nginx/my-app.conf        # 80 -> 301 на 443 (TLS) -> 127.0.0.1:8080
    └── systemd/
        ├── storage.service      # поднимает RAID/LVM при загрузке
        └── my-app.service       # контейнер my-app как служба
```

## Схема

```
клиент -> nginx :443 (TLS) -> 127.0.0.1:8080 -> контейнер my-app
                                                 ├── script.sh раз в 60 с читает /var/log (хост, ro)
                                                 └── python3 http.server отдаёт /var/www = /mnt/logs (LVM)
```

## Скрипт

```bash
./script.sh                       # /var/log/syslog -> report.txt
./script.sh /var/log/auth.log     # другой лог
KEYWORDS="sshd sudo" TAIL_LINES=10 REPORT=auth_report.txt ./script.sh /var/log/auth.log
```

Читать `/var/log/syslog` может root или пользователь из группы `adm` (на Ubuntu пользователь `ubuntu` в неё входит), иначе запускайте через `sudo`.

Отчёт: заголовок (лог, время, хост, число строк), сводка по каждому ключевому слову, топ-5 программ-источников, последние `TAIL_LINES` событий по каждому слову.

| Код выхода | Значение |
|-----|----------|
| 0 | отчёт сформирован |
| 1 | файл лога не найден |
| 2 | нет прав на чтение лога |
| 3 | нет прав на запись отчёта |

## Развёртывание

```bash
sudo apt install -y docker.io docker-buildx docker-compose-v2 mdadm lvm2 nginx
sudo usermod -aG docker $USER && newgrp docker

# хранилище: RAID 1 + LVM на loop-устройствах
sudo ./storage.sh

# контейнер (в контейнере нет /var/log хоста — подключаем томом только для чтения)
docker build -t my-script .
docker run -d -p 8080:8080 --name my-app -h my-app \
  -v /var/log:/var/log:ro -v /mnt/logs:/var/www -v /etc/localtime:/etc/localtime:ro my-script
curl http://127.0.0.1:8080/report.txt
# или: docker compose up --build

# nginx + TLS
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/my-app.key -out /etc/ssl/certs/my-app.crt -subj "/CN=my-app.local"
sudo cp deploy/nginx/my-app.conf /etc/nginx/sites-available/my-app
sudo ln -s /etc/nginx/sites-available/my-app /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx

# systemd
docker stop my-app
sudo install -m 755 storage.sh /usr/local/sbin/storage.sh
sudo cp deploy/systemd/*.service /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now storage my-app

curl -kI https://<адрес-машины>
sudo journalctl -u my-app -n 20
```
