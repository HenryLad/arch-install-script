#!/bin/sh
# This script is for setting up Arch Linux
echo "Which keylayout do you want (A to print all options)":
read keylayout
if [ $keylayout == "A" ]; then
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
    cd || exit
    echo "Changed directory to /root"
fi
printf "Do you want to update the time Y/N : "
read time
time=$(echo "$time" | tr '[:upper:]' '[:lower:]')
if [ $time = "y" ]; then
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
if [ $disk == "A" ]; then
    lsblk | grep -E "disk|part" | grep -vE "loop|zram"
fi
while true; do
    printf "Which disk do you want to partition: "
    read disk
    if [ -z "$disk" ]; then
        echo "Disk not provided"
    elif lsblk | grep -q "$disk"; then
        break
    else
        echo "Disk not found"
    fi
done
echo "Info Starting partitioning of $disk"
disk_size=$(lsblk -bno SIZE /dev/$disk | grep -m 1 -E "^.*$")


while true; do
    printf "How much GB for Linux Swap (Min: 4G): "
    read swap
    swap=${swap:-0}
    if ! [[ "$swap" =~ ^[0-9]+$ ]] || [ "$swap" -lt 4 ]; then
        echo "Invalid input. Swap must be a number and at least 4GB."
        continue
    fi

    printf "How much GB for Linux Boot (Min: 1GB): "
    read boot
    boot=${boot:-0}
    if ! [[ "$boot" =~ ^[0-9]+$ ]] || [ "$boot" -lt 1 ]; then
        echo "Invalid input. Boot must be a number and at least 1GB."
        continue
    fi

    printf "How much GB for Linux Root (Min: 20GB): "
    read root
    root=${root:-0}
    if ! [[ "$root" =~ ^[0-9]+$ ]] || [ "$root" -lt 20 ]; then
        echo "Invalid input. Root must be a number and at least 20GB."
        continue
    fi

    total=$((swap + boot + root))
    if [ "$total" -gt $((disk_size / 1024 / 1024 / 1024)) ]; then
        echo "Total size exceeds disk size. Please enter valid sizes."
        continue
    fi

    break
done
{
  echo "g"                        # Create a new DOS partition table
  echo "n"                        # Add a new partition (Boot)
  echo "p"                        # Primary partition
  echo "1"                        # Partition number 1
  echo                           # Default - start at beginning of disk
  echo "+$boot"              # Boot partition size
  echo "n"                        # Add a new partition (Swap)
  echo "p"                        # Primary partition
  echo "2"                        # Partition number 2
  echo                           # Default - start immediately after boot
  echo "+$swap"              # Swap partition size
  echo "n"                        # Add a new partition (Root)
  echo "p"                        # Primary partition
  echo "3"                        # Partition number 3
  echo                           # Default - start immediately after swap
  echo "$root"               # Root partition size
  echo "t"                        # Change partition type
  echo "2"                        # Select partition 2 (swap)
  echo "82"                       # Set type to Linux swap
  echo "w"                        # Write the changes and exit
} | fdisk "$disk"
