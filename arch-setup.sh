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

arch-chroot /mnt 



# Setting up Language
echo "Setting up the language"
printf "Enter your language (e.g. en_US.UTF-8, de_DE.UTF-8): "
read language
echo "LANG=$language" > /etc/locale.conf
echo "$language UTF-8" >> /etc/locale.gen
locale-gen
if [ $? -eq 0 ]; then
    echo -e "$SUCESS Language set successfully."
else
    echo -e "$ERROR Failed to set language."
fi

# Setting the hostname
printf "Set your hostname: "
read hostname 
echo "$hostname" > /etc/hostname
if [ $? -eq 0 ]; then
    echo -e "$SUCESS Hostname set successfully."
else
    echo -e "$ERROR Failed to set hostname."
fi

# Setting up the hosts file
echo "127.0.0.1   localhost" >> /etc/hosts
echo "::1         localhost" >> /etc/hosts
echo "127.0.1.1   $hostname.localdomain $hostname" >> /etc/hosts
if [ $? -eq 0 ]; then
    echo -e "$SUCESS Hostname set successfully."
else
    echo -e "$ERROR Failed to set hostname."
fi
# Setting up the network Manager
echo "Installing NetworkManager"
pacman -S networkmanager --noconfirm >> /dev/null
if [ $? -eq 0 ]; then
    echo -e "$SUCESS NetworkManager installed successfully."
else
    echo -e "$ERROR Failed to install NetworkManager."
fi
systemctl enable NetworkManager >> /dev/null
if [ $? -eq 0 ]; then
    printf "%b\n" "$SUCESS NetworkManager enabled successfully."
else
    echo -e "$ERROR Failed to enable NetworkManager."
fi

# Setting up the root password
echo "Setting up the root password"
printf "Enter the root password: "
read -s root_password
passwd root <<< "$root_password" >> /dev/null
if [ $? -eq 0 ]; then
    echo -e "$SUCESS Root password set successfully."
else
    echo -e "$ERROR Failed to set root password."
fi

# Setting up the user
echo "Setting up the user"
printf "Enter the username: "
read username
useradd -m -g users -G wheel -s /bin/bash "$username"
if [ $? -eq 0 ]; then
    echo -e "$SUCESS User '$username' created successfully."
else
    echo -e "$ERROR Failed to create user '$username'."
fi
printf "Enter the password for user '$username': "
read -s user_password
passwd "$username" <<< "$user_password" >> /dev/null
if [ $? -eq 0 ]; then
    echo -e "$SUCESS Password set for user '$username' successfully."
else
    echo -e "$ERROR Failed to set password for user '$username'"
fi

# Setting up GRUB Bootloader for EFI Systems 
pacman -S grub efibootmgr --noconfirm >> /dev/null
if [ $? -eq 0 ]; then
    echo -e "$SUCESS GRUB Bootloader installed successfully."
else
    echo -e "$ERROR Failed to install GRUB Bootloader."
fi
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB >> /dev/null
if [ $? -eq 0 ]; then
    echo -e "$SUCESS GRUB Bootloader installed successfully on the System."
else
    echo -e "$ERROR Failed to install GRUB Bootloader."
fi
grub-mkconfig -o /boot/grub/grub.cfg >> /dev/null
if [ $? -eq 0 ]; then
    echo -e "$SUCESS GRUB Bootloader configured successfully."
else
    echo -e "$ERROR Failed to configure GRUB Bootloader."
fi

sudo pacman -S xorg [xf86-video-your gpu type] --noconfirm
if [ $? -eq 0 ]; then
    echo -e "$SUCESS Xorg installed successfully."
else
    echo -e "$ERROR Failed to install Xorg."
fi

sudo pacman -S sddm
sudo systemctl enable sddm
if [ $? -eq 0 ]; then
    echo -e "$SUCESS SDDM installed successfully."
else
    echo -e "$ERROR Failed to install SDDM."
fi
#Installing KDE Plasma
sudo pacman -S plasma alacritty dolphin ark kwrite kcalc spectacle krunner partitionmanager packagekit-qt5
if [ $? -eq 0 ]; then
    echo -e "$SUCESS KDE Plasma installed successfully."
else
    echo -e "$ERROR Failed to install KDE Plasma."
fi
# Installing Audio and Bluetooth
sudo pacman -S alsa-utils bluez bluez-utils
if [ $? -eq 0 ]; then
    echo -e "$SUCESS Audio and Bluetooth installed successfully."
else
    echo -e "$ERROR Failed to install Audio and Bluetooth."
fi
sudo systemctl enable bluetooth.service
# Installing Optional Programms
sudo pacman -S firefox vlc libreoffice openssh wget git fastfetch docker docker-compose 
if [ $? -eq 0 ]; then
    echo -e "$SUCESS Optional Programms installed successfully."
else
    echo -e "$ERROR Failed to install Optional Programms."
fi
# Enabling OpenSSH daemon and CUPS printer service
sudo systemctl enable sshd.service
sudo systemctl enable --now cups.service
if [ $? -eq 0 ]; then
    echo -e "$SUCESS OpenSSH daemon and CUPS printer service enabled successfully."
else
    echo -e "$ERROR Failed to enable OpenSSH daemon and CUPS printer service."
fi
# Enabling Docker
sudo systemctl enable docker.service
if [ $? -eq 0 ]; then
    echo -e "$SUCESS Docker enabled successfully."
else
    echo -e "$ERROR Failed to enable Docker."
fi
# Installing YAY 
git clone https://aur.archlinux.org/yay.git
cd yay || exit 
makepkg -si
cd .
rm -rf yay 
