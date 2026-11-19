#!/bin/bash
# snap-hold-selector.sh — продвинутый менеджер блокировок Snap

if [[ $EUID -ne 0 ]]; then
    zenity --error --text="Требуются права root. Запустите через sudo." 2>/dev/null
    exit 1
fi

# --- 1. Получение версии Snapd ---
SNAPD_VER=$(snap version 2>/dev/null | awk '/^snapd/ {print $2}' || echo "unknown")
TITLE="Управление обновлениями Snap (v$SNAPD_VER)"

declare -A initial_status
declare -A current_status
declare -A pkg_display_name
declare -A is_system
tmp_args=$(mktemp)

# Регулярное выражение для системных пакетов
system_snaps="^(bare|core.*|snapd.*|gnome-.*|mesa-.*|gtk.*|webkitgtk.*|firmware-updater)$"

# Получаем список всех пакетов
snap_statuses=$(snap list 2>/dev/null | awk 'NR>1 {print $1, $NF}')

# Заполняем массивы
while read -r pkg status; do
    if [[ "$status" == *"held"* ]]; then
        initial_status["$pkg"]=1
    else
        initial_status["$pkg"]=0
    fi

    if [[ "$pkg" =~ $system_snaps ]]; then
        pkg_display_name["$pkg"]="⚠️ $pkg"
        is_system["$pkg"]=1
    else
        pkg_display_name["$pkg"]="$pkg"
        is_system["$pkg"]=0
    fi
done <<< "$snap_statuses"

# --- 2. Меню сортировки и режима ---
action=$(zenity --list --radiolist \
    --title="$TITLE" \
    --text="Выберите режим работы и сортировку:" \
    --column="Выбор" --column="Действие" \
    --width=450 --height=350 \
    TRUE "Оставить как есть (ручной выбор)" \
    FALSE "Выделить ВСЕ приложения" \
    FALSE "Снять ВСЕ выделения" \
    FALSE "Разово обновить выбранные (снять блокировку, обновить, вернуть)" \
    2>/dev/null) || exit 0

sort_action=$(zenity --list --radiolist \
    --title="$TITLE" \
    --text="Выберите сортировку списка:" \
    --column="Выбор" --column="Сортировка" \
    --width=400 --height=250 \
    TRUE "По имени (А-Я)" \
    FALSE "Сначала заблокированные" \
    FALSE "Сначала системные" \
    2>/dev/null) || exit 0

# --- 3. Подготовка списка для Zenity ---
# Создаем временный массив для сортировки
declare -a sorted_pkgs
for pkg in "${!initial_status[@]}"; do
    sorted_pkgs+=("$pkg")
done

# Применяем сортировку
if [[ "$sort_action" == "По имени (А-Я)" ]]; then
    IFS=$'\n' sorted_pkgs=($(sort <<<"${sorted_pkgs[*]}"))
elif [[ "$sort_action" == "Сначала заблокированные" ]]; then
    IFS=$'\n' sorted_pkgs=($(for p in "${sorted_pkgs[@]}"; do echo "${initial_status[$p]} $p"; done | sort -rn | awk '{print $2}'))
elif [[ "$sort_action" == "Сначала системные" ]]; then
    IFS=$'\n' sorted_pkgs=($(for p in "${sorted_pkgs[@]}"; do echo "${is_system[$p]} $p"; done | sort -rn | awk '{print $2}'))
fi

# Формируем аргументы для Zenity с учетом режима "Выделить всё" / "Снять всё"
for pkg in "${sorted_pkgs[@]}"; do
    if [[ "$action" == "Выделить ВСЕ приложения" ]]; then
        checkbox="TRUE"
    elif [[ "$action" == "Снять ВСЕ выделения" ]]; then
        checkbox="FALSE"
    else
        if [[ "${initial_status[$pkg]}" == "1" ]]; then
            checkbox="TRUE"
        else
            checkbox="FALSE"
        fi
    fi
    echo "$checkbox" >> "$tmp_args"
    echo "${pkg_display_name[$pkg]}" >> "$tmp_args"
done

mapfile -t zenity_args < "$tmp_args"
rm -f "$tmp_args"

# --- 4. Отображение списка ---
selected=$(zenity --list --checklist \
    --title="$TITLE" \
    --text="Отметьте приложения, которые НЕ должны обновляться автоматически:\n⚠️ — системные компоненты" \
    --column="Выбор" --column="Приложение" \
    --width=550 --height=700 \
    --separator="|" \
    "${zenity_args[@]}" 2>/dev/null) || exit 0

# --- 5. Обработка выбора ---
IFS='|' read -ra selected_display <<< "$selected"

for pkg in "${!initial_status[@]}"; do
    current_status["$pkg"]=0
done

for disp_pkg in "${selected_display[@]}"; do
    clean_pkg=$(echo "$disp_pkg" | sed 's/^⚠️ //')
    if [[ -n "$clean_pkg" ]]; then
        current_status["$clean_pkg"]=1
    fi
done

# --- 6. Применение изменений ---
held_count=0
unheld_count=0
updated_count=0
error_msgs=""

if [[ "$action" == "Разово обновить выбранные (снять блокировку, обновить, вернуть)" ]]; then
    # Логика разового обновления
    for pkg in "${!current_status[@]}"; do
        if [[ "${current_status[$pkg]}" == "1" ]]; then
            # Снимаем блокировку, обновляем, возвращаем блокировку
            if snap refresh --unhold "$pkg"  && \
               snap refresh "$pkg"  && \
               snap refresh --hold "$pkg" ; then
                ((updated_count++))
            else
                error_msgs+="Ошибка обновления $pkg\n"
            fi
        fi
    done
    zenity --info --text="Разово обновлено пакетов: $updated_count\n\n$error_msgs" 2>/dev/null
    exit 0
fi

# Логика обычной блокировки/разблокировки
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

# --- 7. Итоговый отчет ---
if [[ -n "$error_msgs" ]]; then
    zenity --warning --text="Готово, но были ошибки:\n\n🔒 Заблокировано: $held_count\n🔓 Разблокировано: $unheld_count\n\n$error_msgs" 2>/dev/null
elif [[ $held_count -eq 0 && $unheld_count -eq 0 ]]; then
    zenity --info --text="Изменений нет.\nВсе галочки остались на своих местах." 2>/dev/null
else
    zenity --info --text="Готово!\n\n🔒 Заблокировано: $held_count\n🔓 Разблокировано: $unheld_count" 2>/dev/null
fi