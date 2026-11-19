#!/bin/bash
# snap-hold-selector.sh — менеджер блокировок Snap с массовым выбором

if [[ $EUID -ne 0 ]]; then
    zenity --error --text="Требуются права root. Запустите через sudo." 2>/dev/null
    exit 1
fi

declare -A initial_status
declare -A current_status
tmp_args=$(mktemp)

# Фильтр системных пакетов
system_snaps="^(bare|core.*|snapd.*|gnome-.*|mesa-.*|gtk.*|webkitgtk.*|firmware-updater)$"

# Получаем список ВСЕХ пакетов
snap_statuses=$(snap list 2>/dev/null | awk 'NR>1 {print $1, $NF}')

# Заполняем ассоциативный массив и готовим данные
while read -r pkg status; do
    if [[ "$status" == *"held"* ]]; then
        initial_status["$pkg"]=1
        checkbox="TRUE"
    else
        initial_status["$pkg"]=0
        checkbox="FALSE"
    fi

    if [[ "$pkg" =~ $system_snaps ]]; then
        display_name="⚠️ $pkg"
    else
        display_name="$pkg"
    fi

    echo "$checkbox" >> "$tmp_args"
    echo "$display_name" >> "$tmp_args"
done <<< "$snap_statuses"

mapfile -t zenity_args < "$tmp_args"
rm -f "$tmp_args"

# --- 1. Дополнительное меню выбора ---
action=$(zenity --list --radiolist \
    --title="Режим работы" \
    --text="Как вы хотите изменить галочки в списке?\n(После этого откроется список приложений)" \
    --column="Выбор" --column="Действие" \
    --width=400 --height=250 \
    TRUE "Оставить как есть (ручной выбор)" \
    FALSE "Выделить ВСЕ приложения" \
    FALSE "Снять ВСЕ выделения" \
    2>/dev/null) || {
    # Если нажали Отмена
    exit 0
}

# --- 2. Отображаем окно и применяем выбранное действие ---
# Создаем копию аргументов для Zenity, чтобы можно было их изменить
zenity_final_args=("${zenity_args[@]}")

if [[ "$action" == "Выделить ВСЕ приложения" ]]; then
    # Меняем все FALSE на TRUE
    for i in "${!zenity_final_args[@]}"; do
        if [[ "${zenity_final_args[$i]}" == "FALSE" ]]; then
            zenity_final_args[$i]="TRUE"
        fi
    done
elif [[ "$action" == "Снять ВСЕ выделения" ]]; then
    # Меняем все TRUE на FALSE
    for i in "${!zenity_final_args[@]}"; do
        if [[ "${zenity_final_args[$i]}" == "TRUE" ]]; then
            zenity_final_args[$i]="FALSE"
        fi
    done
fi

selected=$(zenity --list --checklist \
    --title="Управление обновлениями Snap" \
    --text="Отметьте приложения, которые НЕ должны обновляться автоматически:\n⚠️ — системные компоненты (блокировка опасна!)" \
    --column="Выбор" --column="Приложение" \
    --width=550 --height=700 \
    --separator="|" \
    "${zenity_final_args[@]}" 2>/dev/null) || {
    zenity --info --text="Операция отменена." 2>/dev/null
    exit 0
}

# --- Разбор выбора из Zenity ---
IFS='|' read -ra selected_display <<< "$selected"

for pkg in "${!initial_status[@]}"; do
    current_status["$pkg"]=0
done

for disp_pkg in "${selected_display[@]}"; do
    # Очищаем имя от эмодзи
    clean_pkg=$(echo "$disp_pkg" | sed 's/^⚠️ //')
    if [[ -n "$clean_pkg" ]]; then
        current_status["$clean_pkg"]=1
    fi
done

# --- Применение изменений ---
held_count=0
unheld_count=0
error_msgs=""

for pkg in "${!initial_status[@]}"; do
    init=${initial_status[$pkg]}
    curr=${current_status[$pkg]:-0}

    if [[ "$init" == "0" && "$curr" == "1" ]]; then
        if snap refresh --hold "$pkg" >/dev/null 2>&1; then
            ((held_count++))
        else
            error_msgs+="Ошибка при блокировке $pkg\n"
        fi
    elif [[ "$init" == "1" && "$curr" == "0" ]]; then
        if snap refresh --unhold "$pkg" >/dev/null 2>&1; then
            ((unheld_count++))
        else
            error_msgs+="Ошибка при разблокировке $pkg\n"
        fi
    fi
done

# Выводим отчет
if [[ -n "$error_msgs" ]]; then
    zenity --warning --text="Готово, но были ошибки:\n\n🔒 Заблокировано: $held_count\n🔓 Разблокировано: $unheld_count\n\n$error_msgs" 2>/dev/null
elif [[ $held_count -eq 0 && $unheld_count -eq 0 ]]; then
    zenity --info --text="Изменений нет.\nВсе галочки остались на своих местах." 2>/dev/null
else
    zenity --info --text="Готово!\n\n🔒 Заблокировано: $held_count\n🔓 Разблокировано: $unheld_count" 2>/dev/null
fi