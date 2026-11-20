#!/bin/bash
# snap-manager.sh — продвинутый менеджер блокировок Snap

LOG_DIR="/var/log/snap-update-manager"

ACTIVE_SORT=0  # 0 = быстрый запуск (без меню) - сначала системные пакеты, 1 = спрашивать сортировку


# Разбор аргументов
# sudo ./snap-manager.sh -s (спросит сортировку)
while getopts "s" opt; do
    case $opt in
        s) ACTIVE_SORT=1 ;;
    esac
done


if [[ $EUID -ne 0 ]]; then
    zenity --error --text="Требуются права root. Запустите через sudo." 2>/dev/null
    exit 1
fi


# --- ОЧИСТКА СТАРЫХ ЛОГОВ (старше 30 дней) ---
if [[ -d "$LOG_DIR" ]]; then
    # Тихая очистка: удаляем *.log, которые не изменялись более 30 дней
    find "$LOG_DIR" -maxdepth 1 -name "*.log" -mtime +30 -delete 2>/dev/null || true
fi

# --- 1. Получение версии Snapd ---
SNAPD_VER=$(snap version 2>/dev/null | awk '/^snapd/ {print $2}')
[[ -z "$SNAPD_VER" ]] && SNAPD_VER="unknown"

# После получения SNAPD_VER делаем  проверку
SNAPD_VER_NUM=$(echo "$SNAPD_VER" | grep -oE '^[0-9]+\.[0-9]+' || echo "0.0")
# Используем bc для сравнения версий (если bc не установлен, переходим в резервную ветку)
if [[ $(echo "$SNAPD_VER_NUM < 2.58" | bc 2>/dev/null || echo "1") -eq 1 ]]; then
    zenity --error --title="Версия не поддерживается" \
        --text="Текущая версия snapd ($SNAPD_VER) ниже минимально требуемой 2.58.\n\nФункция --hold недоступна, скрипт не может продолжить работу.\n\nПожалуйста, сначала обновите snapd:\n  sudo snap refresh snapd" \
        2>/dev/null
    exit 1
fi

TITLE="Управление обновлениями Snap (v$SNAPD_VER)"

declare -A initial_status
declare -A current_status
declare -A pkg_display_name
declare -A is_system
tmp_args=$(mktemp)

system_snaps="^(bare|core.*|snapd.*|gnome-.*|mesa-.*|gtk.*|webkitgtk.*|firmware-updater)$"

snap_statuses=$(snap list 2>/dev/null | awk 'NR>1 {print $1, $NF}')

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

# --- 2. Меню ---
# Сначала определяем, есть ли глобальная блокировка
if snap refresh --time 2>/dev/null | grep -qE "^hold: (forever|[0-9])"; then
    GLOBAL_STATE="🔴 ОБНОВЛЕНИЯ ПРИОСТАНОВЛЕНЫ"
    GLOBAL_ACTION_ITEM=("FALSE" "🌐 Глобально: возобновить ВСЕ обновления (--unhold)")
else
    GLOBAL_STATE="🟢 ОБНОВЛЕНИЯ АКТИВНЫ (обновляются в фоне)"
    GLOBAL_ACTION_ITEM=("FALSE" "🌐 Глобально: приостановить ВСЕ обновления (--hold)")
fi

action=$(zenity --list --radiolist \
    --title="$TITLE" --text="Глобальный статус: $GLOBAL_STATE\n\nВыберите режим работы:" \
    --column="Выбор" --column="Действие" --width=650 --height=280 \
    TRUE "Оставить как есть (ручной выбор)" \
    FALSE "Выделить ВСЕ приложения" \
    FALSE "Снять ВСЕ выделения" \
    FALSE "Разово обновить заблокированные snap-пакеты" \
    "${GLOBAL_ACTION_ITEM[@]}" \
    2>/dev/null) || exit 0

# --- Обработка глобальных действий ---
if [[ "$action" == "🌐 Глобально: приостановить ВСЕ обновления (--hold)" ]]; then
    if snap refresh --hold >/dev/null 2>&1; then
        zenity --info --title="$TITLE" --text="✅ Глобальная блокировка ВКЛЮЧЕНА.\n\nВсе Snap-пакеты больше не будут обновляться автоматически." 2>/dev/null
    else
        zenity --error --title="$TITLE" --text="❌ Ошибка при глобальной блокировке." 2>/dev/null
    fi
    exit 0
elif [[ "$action" == "🌐 Глобально: возобновить ВСЕ обновления (--unhold)" ]]; then
    if snap refresh --unhold >/dev/null 2>&1; then
        zenity --info --title="$TITLE" --text="✅ Глобальная блокировка СНЯТА.\n\nАвтоматические обновления всех Snap-пакетов снова активны." 2>/dev/null
    else
        zenity --error --title="$TITLE" --text="❌ Ошибка при снятии глобальной блокировки." 2>/dev/null
    fi
    exit 0
fi


if [[ "$ACTIVE_SORT" == 1 ]]; then
# --- Дальнейшая логика (сортировка и список) ---
    sort_action=$(zenity --list --radiolist \
    --title="$TITLE" --text="Выберите сортировку списка:" \
    --column="Выбор" --column="Сортировка" --width=400 --height=250 \
    TRUE "По имени (А-Я)" \
    FALSE "Сначала заблокированные" \
    FALSE "Сначала системные" \
    2>/dev/null) || exit 0

else
    sort_action="Сначала системные"
fi

# --- 3. Подготовка списка ---
declare -a sorted_pkgs
for pkg in "${!initial_status[@]}"; do sorted_pkgs+=("$pkg"); done

if [[ "$sort_action" == "По имени (А-Я)" ]]; then
    IFS=$'\n' sorted_pkgs=($(sort <<<"${sorted_pkgs[*]}"))
elif [[ "$sort_action" == "Сначала заблокированные" ]]; then
    IFS=$'\n' sorted_pkgs=($(for p in "${sorted_pkgs[@]}"; do echo "${initial_status[$p]} $p"; done | sort -rn | awk '{print $2}'))
elif [[ "$sort_action" == "Сначала системные" ]]; then
    IFS=$'\n' sorted_pkgs=($(for p in "${sorted_pkgs[@]}"; do echo "${is_system[$p]} $p"; done | sort -rn | awk '{print $2}'))
fi

for pkg in "${sorted_pkgs[@]}"; do
    if [[ "$action" == "Выделить ВСЕ приложения" ]]; then
        checkbox="TRUE"
    elif [[ "$action" == "Снять ВСЕ выделения" ]]; then
        checkbox="FALSE"
    else
        if [[ "${initial_status[$pkg]}" == "1" ]]; then checkbox="TRUE"; else checkbox="FALSE"; fi
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
    --column="Выбор" --column="Приложение" --width=550 --height=700 \
    --separator="|" "${zenity_args[@]}" 2>/dev/null) || exit 0

# --- 5. Обработка выбора ---
IFS='|' read -ra selected_display <<< "$selected"
for pkg in "${!initial_status[@]}"; do current_status["$pkg"]=0; done
for disp_pkg in "${selected_display[@]}"; do
    clean_pkg=$(echo "$disp_pkg" | sed 's/^⚠️ //')
    if [[ -n "$clean_pkg" ]]; then current_status["$clean_pkg"]=1; fi
done

# --- 6. Применение изменений ---
held_count=0
unheld_count=0
updated_count=0
error_msgs=""

# === БЛОК РАЗОВОГО ОБНОВЛЕНИЯ С ЛОГАМИ И ПРОВЕРКОЙ ПРОЦЕССОВ ===
if [[ "$action" == "Разово обновить заблокированные snap-пакеты" ]]; then
    to_update=()
    for pkg in "${!current_status[@]}"; do
        if [[ "${current_status[$pkg]}" == "1" ]]; then to_update+=("$pkg"); fi
    done

    total=${#to_update[@]}
    if [[ $total -eq 0 ]]; then
        zenity --info --text="Не выбрано ни одного пакета для обновления." 2>/dev/null
        exit 0
    fi

    # --- Создаем папку для логов ---
    mkdir -p "$LOG_DIR"
    MASTER_LOG="$LOG_DIR/update-$(date +%Y%m%d_%H%M%S).log"
    
    echo "=== Начало обновления: $(date) ===" >> "$MASTER_LOG"
    echo "Выбранные пакеты: ${to_update[*]}" >> "$MASTER_LOG"
    echo "----------------------------------------" >> "$MASTER_LOG"

    pipe=$(mktemp -u)
    mkfifo "$pipe"
    
    # Запускаем прогресс БЕЗ --auto-close, чтобы он не закрылся раньше времени
    zenity --progress --title="$TITLE" --text="Подготовка..." --percentage=0  --width=600 --height=100 < "$pipe" &
    zenity_pid=$!
    exec 3> "$pipe"

    current=0
    error_msgs=""
    updated_count=0

    for pkg in "${to_update[@]}"; do
        ((current++))
        percent=$(( current * 100 / total ))
        echo "# Проверка $pkg ($current из $total)..." >&3
        echo "$percent" >&3

        # --- ПРОВЕРКА НА ЗАПУЩЕННЫЕ ПРОЦЕССЫ ---
        # Используем || true, чтобы pgrep не ломал скрипт, если процессов нет
        if pgrep -f "$pkg" >/dev/null 2>&1; then
            if zenity --question --title="Приложение запущено" \
                --text="Обнаружен запущенный процесс, связанный с '$pkg'.\nОн может помешать обновлению.\n\nЗакрыть все связанные процессы принудительно?" 2>/dev/null; then
                pkill -f "$pkg" 2>/dev/null || true
                sleep 1
            else
                error_msgs+="[Пропущено] $pkg: приложение запущено.\n"
                echo "[Пропущено] $pkg: приложение запущено." >> "$MASTER_LOG"
                continue
            fi
        fi

        echo "# Обновление $pkg..." >&3
        log_file=$(mktemp)
        
        # Выполняем обновление
        if snap refresh "$pkg" > "$log_file" 2>&1; then
            ((updated_count++))
            echo "[УСПЕХ] $pkg обновлен." >> "$MASTER_LOG"
            cat "$log_file" >> "$MASTER_LOG"
            echo "" >> "$MASTER_LOG"
        else
            err_detail=$(tail -n 5 "$log_file" | tr '\n' ' ')
            error_msgs+="[Ошибка] $pkg: $err_detail\n"
            echo "[ОШИБКА] $pkg не обновлен." >> "$MASTER_LOG"
            cat "$log_file" >> "$MASTER_LOG"
            echo "----------------------------------------" >> "$MASTER_LOG"
        fi
        rm -f "$log_file"
    done

    # --- ЗАВЕРШАЕМ ПРОГРЕСС ---
    # Отправляем 100%, чтобы прогресс-бар заполнился до конца
    echo "100" >&3
    echo "# Готово!" >&3
    exec 3>&-
    
    # Ждем закрытия Zenity (так как --auto-close убран, он закроется только после закрытия пайпа)
    wait $zenity_pid 2>/dev/null
    rm -f "$pipe"

    # Завершаем мастер-лог
    echo "=== Завершено: $(date) ===" >> "$MASTER_LOG"
    echo "Успешно обновлено: $updated_count из $total" >> "$MASTER_LOG"

    # --- ИТОГОВОЕ ОКНО (теперь оно точно появится) ---
    if [[ -n "$error_msgs" ]]; then
        echo -e "Готово!\n\nУспешно обновлено: $updated_count\n\nОшибки:\n$error_msgs\n\nПолный лог сохранен в: $MASTER_LOG" | zenity --text-info --title="Результат обновления" --width=600 --height=400 2>/dev/null
    else
        zenity --info --text="Успешно обновлено пакетов: $updated_count\n\nПолный лог сохранен в:\n$MASTER_LOG" 2>/dev/null
    fi
    exit 0
fi
# === КОНЕЦ БЛОКА РАЗОВОГО ОБНОВЛЕНИЯ ===

# Логика обычной блокировки/разблокировки
for pkg in "${!initial_status[@]}"; do
    init=${initial_status[$pkg]}
    curr=${current_status[$pkg]:-0}

    if [[ "$init" == "0" && "$curr" == "1" ]]; then
        if snap refresh --hold "$pkg" >/dev/null 2>&1; then ((held_count++)); else error_msgs+="Ошибка при блокировке $pkg\n"; fi
    elif [[ "$init" == "1" && "$curr" == "0" ]]; then
        if snap refresh --unhold "$pkg" >/dev/null 2>&1; then ((unheld_count++)); else error_msgs+="Ошибка при разблокировке $pkg\n"; fi
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