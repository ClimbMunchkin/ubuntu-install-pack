#!/bin/bash
#Меняем владельца текущей папки с подпапками

cd ~/ubuntu-install-pack

password=$(zenity --forms \
	--title="НАСТРОЙКА UBUNTU" \
  	--text="Введите пароль Администратора" \
    --add-password="Пароль"\
    --width=320)
echo $password | sudo -S chown -R $USER:$USER .
#sudo chown -R $USER:$USER .
#Даем права на запуск скриптов в каталоге install-pack/
sudo chmod +x install-pack/*

#read -sn1 -p "Press any key to continue...";echo
progs=$(zenity --width=800 --height=500 --list  --text "НАСТРОЙКА UBUNTU" --checklist --separator=" " \
			  --column "Выбрать" --column "Компоненты" --column "Описание" \
			   TRUE '0-upgrade' 'Обновление системы до последней актуальной версии'\
			   FALSE '1-brightness' 'Решение проблемы запоминания яркости Ubuntu '\
			   FALSE '1.1-lightdm' 'Установка lightdm и настройка окна входа в систему'\
			   TRUE '2-poweroff-button' 'Выключение компьютера с кнопки' \
			   TRUE '2.1-switchkey' 'Переключение раскладки клавиатуры Ctrl+Shift'\
			   TRUE '2.2-i386' 'Поддержка i386 архитектуры'\
			   TRUE '2.3-hot-corner' 'Включаем активный угол меню Обзор'\
			   TRUE '2.4-templates' 'Шаблоны'\
			   TRUE '2.5-fonts' 'Шрифты'\
			   TRUE '2.6-extensions' 'Ставим расширения рабочего стола'\
			   TRUE '2.7-conky-clock' 'Ставим красивые часы и системный монитор на рабочий стол'\
			   TRUE '2.8-themes' 'Темы для GNOME'\
			   TRUE '2.9-qt' 'QT приложения не будут отличаться от системной темы'\
			   TRUE '3-programs' 'Обязательные программы, в том числе Chrome'\
			   TRUE '3.1-zsh-terminal' 'Установка красивого и удобного терминала ZSH'\
			   TRUE '3.2-snap-manager' 'Управление блокировками snap-пакетов'\
			   TRUE '3.3-cleanup' 'Программа для удаление старых пакетов и очистка кэша'\
			   TRUE '3.4-rkhunter' 'Антивирусник rkHunter GUI'\
			   FALSE '3.5-codec' 'Установка кодеков для воспроизведения мультимедиа'\
			   FALSE '3.6-office' 'Установка офисных программ'\
			   FALSE '4-zen-kernel' 'Установка игрового Zen-ядра на Ubuntu'\
			   FALSE '5-nvidia-driver' 'Установка драйвера видеокарты nvidia GeForce GTX 1650'\
			   )
cd install-pack

count=$(echo $progs |wc -w)
clear
echo "ЧИСЛО УСТАНАВЛИВАЕМЫХ КОМПОНЕНТ: $count"


for prog in $progs; do
	echo "Установка $prog ..."

	
	echo "===================================================================================================="
	./$prog 
 
done


#Перезагружаемся в конце установки
echo "===================================================================================================="
zenity --question --title="Перезагрузка системы" \
        --text="Установка успешно завершена. Для того чтоб изменения вступили в силу, необходимо перезагрузить компьютер. Перезагрузить компьютер сейчас?" \
        --timeout=20 --width=600 --height=100 
 if [ $? -eq "0" ]
 then
 	echo "ПЕРЕЗАГРУЗКА СИСТЕМЫ..."
	sudo reboot
 fi
