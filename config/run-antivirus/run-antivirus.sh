#!/bin/bash
# Проверка системы на вирусы с помощью rkhunter (не зависит от пользователя)

if [ -n "$SUDO_USER" ]; then
    REAL_USER="$SUDO_USER"
    REAL_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
    REAL_GROUP="$(id -gn "$SUDO_USER")"
else
    REAL_USER="$(id -un)"
    REAL_HOME="$HOME"
    REAL_GROUP="$(id -gn)"
fi

LOG="$REAL_HOME/antivirus-report.log"

function Update(){
    echo -e '\e[1;33mОбновляем антивирус...\e[0m'
    sudo rkhunter --versioncheck
    echo -e '\e[1;33mОбновляем антивирусную базу...\e[0m'
    sudo rkhunter --update
}

function Check(){
    echo -e '\e[1;33mВыполняем поиск уязвимостей...\e[0m'
    ERR=$(sudo rkhunter --check --report-warnings-only --logfile "$LOG")

    if [ -n "$ERR" ]; then
        echo -e "Возможные вирусные угрозы:\n$ERR"
        echo -e '\e[0;31m    Внимание, обнаружена вирусная угроза!\e[0m'
    else
        echo -e '\e[1;32m    Проверка на вирусы прошла успешно.\e[0m'
    fi

    sudo chown "$REAL_USER":"$REAL_GROUP" "$LOG"
}

Update
Check
echo -e '\e[1;33mДля продолжения нажмите на любую клавишу...\e[0m'
read -s -n 1 -t 60
