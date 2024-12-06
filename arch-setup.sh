#!/bin/sh
# This script is for setting up Arch Linux
echo "Which keylayout do you want (A to print all options)": 
read keylayout
if [ $keylayout == "A" ]
then
    localectl list-keymaps
    echo "Which keylayout do you want: "
    read keylayout
fi
loadkeys "$keylayout"
if [ $? -eq 0 ]; then
    echo "Keylayout loaded successfully."
else
    echo "Failed to load keylayout."
fi
if [ "$(pwd)" != "/root" ]; then
    cd '/root'
fi
printf"Do you want to update the time : (Y/N)"
read time
if [ $time = "Y" ]
then
    timedatectl set-ntp true
    if [ $? -eq 0 ]; then
        echo "Time updated successfully."
    else
        echo "Failed to update time."
    fi
fi 

echo "Starting partionioning of the disk"
echo "Warning: This will delete all data on the disk"
printf "Which disk do you want to partition (A to print all options): "
read disk
if [ $disk == "A" ]
then
    lsblk
    printf "Which disk do you want to partition: "
    read disk
fi
echo "Info Starting partitioning of $disk"
printf "How much GB for Linux Swap(Min: 4G) : "
read swap
printf "How much GB for Linux Boot(Min :  1GB) : "
read boot
printf "How much GB for Linux Root(Min: 20GB) : "
read root
sudo fdisk /dev/$disk 
g 