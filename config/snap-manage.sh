#!/bin/bash
ENTER=$(echo -e "\n")
ESC=$(echo -e "\x1B")

echo -n "SNAP start ['Enter'] | stop ['Esc']: "
read key
if [[ $key == $ENTER ]];then
    echo "Starting snap..."
    sudo systemctl unmask snapd.service
    sudo systemctl start snapd.service

else
    echo "Stopping snap..."
    sudo systemctl stop snapd.service
    sudo systemctl mask snapd.service
fi
