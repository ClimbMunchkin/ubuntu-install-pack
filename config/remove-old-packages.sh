#!/bin/bash
echo "Удаляем старые версии snap-пакетов..."
set -eu


if [ -n "$SUDO_USER" ]; then
    REAL_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
else
    REAL_HOME="$HOME"
fi

# Получаем свободное место ДО очистки (в мегабайтах)
before=$(df / | awk 'NR==2 {print $4}')

LANG=en_US.UTF-8 snap list --all | awk '/disabled/{print $1, $3}' |
while read snapname revision; do
 sudo snap remove "$snapname" --revision="$revision"
done

echo "Удаляем старые версии flatpak-пакетов..."
sudo flatpak uninstall --unused --delete-data -y && flatpak repair



echo "Очистка кеша, временных файлов и мусора..."

sudo apt autoremove -y 
sudo apt clean 
sudo journalctl --vacuum-time=7d 
rm -rf "$REAL_HOME/.cache/*" 
sudo rm -rf /var/tmp/*


# Получаем свободное место ПОСЛЕ очистки
after=$(df / | awk 'NR==2 {print $4}')

# Рассчитываем разницу
freed=$(( (after - before) * 1024 ))  # Конвертируем в байты
freed_mb=$((freed / 1024 / 1024))  # Конвертируем в мегабайты

echo "Освобождено: $freed_mb MB"

read -s -n 1 -t 2
