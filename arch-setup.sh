#!/bin/sh
# This script is for setting up Arch Linux
echo "############################################################"
echo "#                                                          #"
echo "#                Arch Linux Setup Script                   #"
echo "#                                                          #"
echo "# This script will guide you through the setup of Arch     #"
echo "# Linux, including partitioning, formatting, and           #"
echo "# installing the base system.                              #"
echo "#                                                          #"
echo "############################################################"
echo ""

SUCCESS="\e[1;32m[SUCCESS]\e[0m"
ERROR="\e[1;31m[ERROR]\e[0m"
WARNING="\e[1;33m[WARNING]\e[0m"

echo "Which keylayout do you want? (Type 'A' to print all options):"
read keylayout

if [[ "$keylayout" == "A" || "$keylayout" == "a" ]]; then
    localectl list-keymaps
    echo "Which keylayout do you want: "
    read keylayout
fi

if [ -z "$keylayout" ]; then
    echo "$WARNING Keylayout not provided! Continuing with the currently selected keylayout."
    current_keylayout=$(localectl status | awk -F: '/VC Keymap/{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')
    echo "Current keylayout is: $current_keylayout"
else
    if loadkeys "$keylayout" 2>/dev/null; then
        echo "$SUCESS Keylayout '$keylayout' loaded successfully."
    else
        echo "$WARNING Failed to load keylayout '$keylayout'! Continuing with the currently selected keylayout."
        current_keylayout=$(localectl status | awk -F: '/VC Keymap/{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')
        echo "Current keylayout is: $current_keylayout"
    fi
fi
if [ "$(pwd)" != "/root" ]; then
    cd || exit
    echo "$SUCESS Changed directory to /root"
fi
printf "Do you want to update the time Y/N : "
read time
if [ -z "$time" ]; then
    echo "$WARNING No input provided. Defaulting to 'N'."
    time="n"

else  
time=$(echo "$time" | tr '[:upper:]' '[:lower:]')
fi 
if [ $time = "y" ]; then
    timedatectl set-ntp true
    if [ $? -eq 0 ]; then
        echo -e "$SUCESS Time updated successfully."
    else
        echo "$ERROR Failed to update time."
    fi
fi

echo "Starting partionioning of the disk"
echo -e "$WARNING This will delete all data on the disk\e[0m"
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
        break
    else
        echo "Disk '$disk' not found. Please try again."
    fi
done

echo "You have selected disk: $disk"
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
    if ! [[ "$root" =~ ^[0-9]+$ ]] || [ "$root" -lt 10 ]; then
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
echo -e " $WARNING \e[1mDo you want to remove all the partitions on $disk. This is not necessary if you are installing Arch Linux on a new disk.\e[0m"
echo "Do you want to remove all the parations parts on $disk? Y/N"
read remove
remove=$(echo "$remove" | tr '[:upper:]' '[:lower:')
if [ "$remove" = "y" ]; then
    echo "Removing all partitions on $disk"
    umount -R "/dev/$disk"* 2>/dev/null
    wipefs -a "/dev/$disk"
    if [ $? -eq 0 ]; then
        echo -e "$SUCESS All partitions removed successfully."
    else
        echo -e "$ERROR Failed to remove all partitions."
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
} | fdisk "/dev/$disk" > /dev/null
if [ $? -eq 0 ]; then
    echo -e "$SUCESS Partitions created successfully."
else
    echo -e "$ERROR Failed to create partitions."
fi

echo "Formatting partitions"


root_partition=''
root_partition=$(sudo fdisk -l | grep "Linux filesystem" | awk '{print $1}')
line_count=$(sudo fdisk -l | grep "Linux filesystem" | wc -l)
if [ "$line_count" != 1 ]; then 
    echo "Multiple Linux filesystem partitions found. Please select the root partition."
    sudo fdisk -l | grep "Linux filesystem"
    echo "Enter the root partition: "
    read root_partition
fi

boot_partition=''
boot_partition=$(sudo fdisk -l | grep "EFI System" | awk '{print $1}')
line_count=$(sudo fdisk -l | grep "EFI System" | wc -l)
if [ "$line_count" != 1 ]; then 
    echo "Multiple EFI System partitions found. Please select the boot partition."
    sudo fdisk -l | grep "EFI System"
    echo "Enter the boot partition: "
    read boot_partition
fi

swap_partition=''
swap_partition=$(sudo fdisk -l | grep "Linux swap" | awk '{print $1}')
line_count=$(sudo fdisk -l | grep "Linux swap" | wc -l)
if [ "$line_count" != 1 ]; then 
    echo "Multiple Linux swap partitions found. Please select the swap partition."
    sudo fdisk -l | grep "Linux swap"
    echo "Enter the swap partition: "
    read swap_partition
fi

echo "Formatting boot partition"
mkfs.fat -F 32 "$boot_partition"
if [ $? -eq 0 ]; then
    echo -e "$SUCESS Boot partition formatted successfully."
else
    echo -e "$ERROR Failed to format boot partition."
fi
mkfs.ext4 "$root_partition"
if [ $? -eq 0 ]; then
    echo -e "$SUCESS Root partition formatted successfully."
else
    echo -e "$ERROR Failed to format root partition."
fi
mkswap "$swap_partition"
if [ $? -eq 0 ]; then
    echo -e "$SUCESS Swap partition formatted successfully."
else
    echo -e "$ERROR Failed to format swap partition."
fi


echo "Mounting partitions to /mnt"

mount "$root_partition" /mnt
if [ $? -eq 0 ]; then
    echo -e "$SUCESS Root partition mounted successfully."
else
    echo -e "$ERROR Failed to mount root partition."
fi
mount --mkdir "$boot_partition" /mnt/boot
if [ $? -eq 0 ]; then
    echo -e "$SUCESS Boot partition mounted successfully."
else
    echo -e "$ERROR Failed to mount boot partition."
fi
swapon "$swap_partition"
if [ $? -eq 0 ]; then
    echo -e "$SUCESS Swap partition mounted successfully."
else
    echo -e "$ERROR Failed to mount swap partition."
fi



echo "Installing the base system"
pacstrap /mnt base base-devel linux linux-firmware linux-headers nano intel-ucode reflector mtools dosfstools --noconfirm >> /dev/null
if [ $? -eq 0 ]; then
    echo -e "$SUCESS Base system installed successfully."
else
    echo -e "$ERROR Failed to install base system."
fi
genfstab -U /mnt >> /mnt/etc/fstab

# Setup in the arch chroot environment
echo "Setting up the system in chroot"
cd arch-install-script || exit
cp arch-chroot-setup.sh /mnt
chmod +x /mnt/arch-chroot-setup.sh
arch-chroot /mnt ./arch-chroot-setup.sh
if [ $? -eq 0 ]; then
    echo -e "$SUCESS System setup in chroot completed successfully."
else
    echo -e "$ERROR Failed to setup system in chroot."
fi
printf "Do you want to remove the installation script? Y/N: "
read remove_script
remove_script=$(echo "$remove_script" | tr '[:upper:]' '[:lower:]')
if [ "$remove_script" = "y" ]; then
    rm /mnt/arch-chroot-setup.sh
    if [ $? -eq 0 ]; then
        echo -e "$SUCESS Installation script removed successfully."
    else
        echo -e "$ERROR Failed to remove installation script."
    fi
fi


echo "Installation complete. Should the system get rebooting now"
reboot
