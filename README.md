Making Ubuntu more usable for everyone.
Ubuntu-install-pack provides a clean, streamlined system that's ready for work — with nothing unnecessary and everything tailored to your needs.
It’s the perfect setup tool for GNU/Linux users who want efficiency and simplicity.

Делаем GNU/Linux UBUNTU более удобным!

В данный install-pack входят следующие настройки:
-------------------------------------------------

Обновление системы до последней актуальной версии

Решение проблемы запоминания яркости Ubuntu

Выключение компьютера с кнопки

Установка lightdm и настройка окна входа в систему

Переключение раскладки клавиатуры Ctrl+Shift

Поддержка i386 архитектуры

Включаем активный угол меню Обзор

Добавляем Шаблоны

Устанавливаем Шрифты 

Установка тем для GNOME

Обязательные программы (google-chrome gdebi synaptic mc nemo menulibre dconf-editor net-tools tilix catfish gnome-tweaks chrome-gnome-shell grub-customizer timeshift qbittorrent vlc)

Ставим расширения рабочего стола (Extensions, Dash to Panel, ArcMenu, Pomodoro, OpenWeather, User themes, Tiling Shell, Desk Changer)

Установка кодеков для воспроизведения мультимедиа

Установка flash -плейера

QT приложения не будут отличаться от системной темы

Ставим красивые часы и системный монитор на рабочий стол

Установка офисных программ

Установка игрового Zen-ядра на Ubuntu

Установка драйвера видеокарты nvidia GeForce GTX 1650

Установка:
----------


Для Ubuntu 22.04 LTS и 24.04 LTS если используется Wayland, сначала переключитесь на X11:

1. Выйдите из сеанса.
2. На экране входа выберите пользователя и нажмите значок шестерёнки.
3. Выберите Ubuntu on Xorg и войдите в систему.


Для Ubuntu 26.04 LTS штатное использование X11 не предусмотрено, поэтому после установки 
необходимо активировать расширения вручную, см. Примечание.      

Скопируйте установочный скрипт в буфер и запустите его  в командной строке

```bash
sudo apt update && sudo apt install -y git && cd ~ &&
git clone https://github.com/ClimbMunchkin/ubuntu-install-pack.git ubuntu-install-pack &&
bash ~/ubuntu-install-pack/ubuntu-install-pack.sh
```

Выберите необходимые вам пункты для установки. После установки перезагрузите компьютер.


Примечание:
--------
Если расширения все-таки не включились, сделайте это вручную после перезагрузки:
```bash
gnome-extensions enable arcmenu@arcmenu.com
gnome-extensions enable dash-to-panel@jderose9.github.com
gnome-extensions enable tilingshell@ferrarodomenico.com
gnome-extensions enable openweather-extension@jenslody.de
gnome-extensions enable user-theme@gnome-shell-extensions.gcampax.github.com
gnome-extensions enable desk-changer@eric.gach.gmail.com
```

