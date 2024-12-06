#!/bin/sh
# This script is for setting up Arch Linux
echo "Which keylayout do you want? (Type 'A' to print all options):"
read keylayout

if [[ "$keylayout" == "A" || "$keylayout" == "a" ]]; then
    localectl list-keymaps
    echo "Which keylayout do you want: "
    read keylayout
fi

if [ -z "$keylayout" ]; then
    echo "Keylayout not provided! Continuing with the currently selected keylayout."
    current_keylayout=$(localectl status | awk -F: '/VC Keymap/{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')
    echo "Current keylayout is: $current_keylayout"
else
    if loadkeys "$keylayout" 2>/dev/null; then
        echo "Keylayout '$keylayout' loaded successfully."
    else
        echo "Failed to load keylayout '$keylayout'! Continuing with the currently selected keylayout."
        current_keylayout=$(localectl status | awk -F: '/VC Keymap/{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')
        echo "Current keylayout is: $current_keylayout"
    fi
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
echo -e "\e[31mWarning: This will delete all data on the disk\e[0m"
while true; do
    printf "Which disk do you want to partition? (Type 'A' to list all disks): "
    read -r disk
    if [[ "$disk" == "A" || "$disk" == "a" ]]; then
        echo "Available disks:"
        lsblk -d -o NAME,SIZE,TYPE | grep -E "disk"
        continue
    fi
    if [ -z "$disk" ]; then
        echo "No disk provided. Please enter a disk name."
        continue
    fi
    if lsblk -d -n -o NAME | grep -qw "$disk"; then
        echo "Disk '$disk' found."
        break
    else
        echo "Disk '$disk' not found. Please try again."
    fi
done

echo "You have selected disk: $disk"
echo "Info Starting partitioning of $disk"
disk_size=$(lsblk -bno SIZE /dev/$disk | grep -m 1 -E "^.*$")

while true; do
    printf "How much GB for Linux Swap (Min: 1G): "
    read swap
    swap=${swap:-0}
    if ! [[ "$swap" =~ ^[0-9]+$ ]] || [ "$swap" -lt 1 ]; then
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

    printf "How much GB for Linux Root (Min: 5GB): "
    read root
    root=${root:-0}
    if ! [[ "$root" =~ ^[0-9]+$ ]] || [ "$root" -lt 5 ]; then
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
echo -e "\e[31mRemoving all partitions on $disk will remove all data on the disk and can cause serious data loss.\e[0m"
echo "Do you want to remove all the parations parts on $disk? Y/N"
read remove
remove=$(echo "$remove" | tr '[:upper:]' '[:lower:')
if [ "$remove" = "y" ]; then
    echo "Removing all partitions on $disk"
    wipefs -a "/dev/$disk"
    if [ $? -eq 0 ]; then
        echo "All partitions removed successfully."
    else
        echo "Failed to remove all partitions."
    fi
fi
{
    echo "g"       # Create a new DOS partition table
    echo "n"       # Add a new partition (Boot)
    echo "1"       # Partition number 1
    echo           # Default - start at beginning of disk
    echo "+$boot"G # Boot partition size
    echo "t"       # Change partition type
    echo "1"       # Select partition 1 (boot)
    echo "n"       # Add a new partition (Swap)
    echo "2"       # Partition number 2
    echo           # Default - start immediately after boot
    echo "+$swap"G # Swap partition size
    echo "n"       # Add a new partition (Root)
    echo "3"       # Partition number 3
    echo           # Default - start immediately after swap
    echo "+$root"G  # Root partition size
    echo "t"       # Change partition type
    echo "2"       # Select partition 2 (swap)
    echo "19"      # Set type to Linux swap
    echo "w"       # Write the changes and exit
} | fdisk "/dev/$disk"
