#!/bin/bash
# toggle-snap-update.sh — переключение автоматического обновления snap-пакетов

set -e

# --- Проверки ---
if ! command -v snap &>/dev/null; then
    echo "Ошибка: snap не найден в системе." >&2
    exit 1
fi

if [[ $EUID -ne 0 ]]; then
    echo "Требуются права root. Запустите через sudo." >&2
    exit 1
fi

# --- Вспомогательные функции оформления ---
c_green=$'\033[1;32m'
c_red=$'\033[1;31m'
c_dim=$'\033[2m'
c_reset=$'\033[0m'

line() { printf '%s\n' "────────────────────────────────────────"; }

# --- Определение текущего состояния ---
if snap refresh --time 2>/dev/null | grep -qE "^hold: (forever|[0-9])"; then
    state="held"
else
    state="active"
fi

# --- Переключение ---
line
if [[ $state == "held" ]]; then
    printf '%sАвтообновления: ПРИОСТАНОВЛЕНЫ%s\n' "$c_red" "$c_reset"
    printf '%s→ Снимаю блокировку...%s\n' "$c_dim" "$c_reset"
    snap refresh --unhold >/dev/null 2>&1
    result="ВКЛЮЧЕНЫ"
    color="$c_green"
else
    printf '%sАвтообновления: АКТИВНЫ%s\n' "$c_green" "$c_reset"
    printf '%s→ Приостанавливаю навсегда...%s\n' "$c_dim" "$c_reset"
    snap refresh --hold >/dev/null 2>&1
    result="ПРИОСТАНОВЛЕНЫ (forever)"
    color="$c_red"
fi
line

# --- Итоговый статус (только ключевые строки) ---
printf 'Новый статус: %s%s%s\n' "$color" "$result" "$c_reset"
printf '%s\n' "$(snap refresh --time | grep -E '^(timer|last|hold|next):')"
line