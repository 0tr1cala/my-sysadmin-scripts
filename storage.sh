#!/bin/bash
# RAID 1 (/mnt/raid) и LVM (/mnt/logs) на loop-устройствах.
# Первый запуск создаёт диски-файлы, массив и том; повторный (например, после
# перезагрузки) только подключает файлы заново, собирает массив и монтирует.

set -eu

DIR=/mnt/raid-lab

if [ "$(id -u)" -ne 0 ]; then
    echo "Ошибка: запустите через sudo" >&2
    exit 1
fi
for cmd in losetup mdadm pvcreate mkfs.ext4; do
    if ! command -v "$cmd" > /dev/null 2>&1; then
        echo "Ошибка: нет команды $cmd (sudo apt install -y mdadm lvm2)" >&2
        exit 2
    fi
done

mkdir -p "$DIR" /mnt/raid /mnt/logs
cd "$DIR"

# подключает файл как loop-устройство (или берёт уже подключённое) и печатает его имя
attach() {
    local dev
    dev=$(losetup -j "$PWD/$1" | cut -d: -f1)
    if [ -n "$dev" ]; then
        echo "$dev"
    else
        losetup -fP --show "$PWD/$1"
    fi
}

fresh=0
[ -f disk1.img ] || fresh=1

for i in 1 2 3; do
    [ -f "disk$i.img" ] || dd if=/dev/zero of="disk$i.img" bs=1M count=512 status=none
done
LOOP1=$(attach disk1.img)
LOOP2=$(attach disk2.img)
LOOP3=$(attach disk3.img)
echo "loop-устройства: $LOOP1 $LOOP2 $LOOP3"

if [ "$fresh" -eq 1 ]; then
    # mdadm, pvcreate и lvcreate задают вопросы даже с --force — отвечаем yes
    yes | mdadm --create /dev/md0 --level=1 --raid-devices=2 "$LOOP1" "$LOOP2"
    mdadm --detail --scan >> /etc/mdadm/mdadm.conf
    mkfs.ext4 -q /dev/md0
    yes | pvcreate "$LOOP3"
    vgcreate vg_data "$LOOP3"
    yes | lvcreate -L 200M -n lv_logs vg_data
    mkfs.ext4 -q /dev/vg_data/lv_logs
else
    [ -e /dev/md0 ] || mdadm --assemble /dev/md0 "$LOOP1" "$LOOP2"
    pvscan --cache "$LOOP3" > /dev/null
    vgchange -ay vg_data > /dev/null
fi

mountpoint -q /mnt/raid || mount /dev/md0 /mnt/raid
mountpoint -q /mnt/logs || mount /dev/vg_data/lv_logs /mnt/logs

grep -A1 '^md0' /proc/mdstat
lvs vg_data
df -h /mnt/raid /mnt/logs
