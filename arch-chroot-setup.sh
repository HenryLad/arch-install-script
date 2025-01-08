#!/bin/bash

SUCCESS="\e[1;32m[SUCCESS]\e[0m"
ERROR="\e[1;31m[ERROR]\e[0m"
WARNING="\e[1;33m[WARNING]\e[0m"

display_message() {
    # $1: Exit Code of last prozess
    # $2: Message for Sucess
    # $3: Message for Error
    if [ $1 -eq 0 ] || [ $1 == "y" ] || [ $1 == "Y" ]; then
        echo -e "$SUCCESS $2"
    else
        echo -e "$ERROR $3"
    fi
}
# Setting up the keylayout
echo "Setting up the keylayout"
printf "Enter your keylayout (e.g. de-latin1): "
read -r keylayout
loadkeys $keylayout
display_message $? "Keylayout set successfully." "Failed to set keylayout."

# Setting up time 
# Setting up Language
echo "Setting up the language"
printf "Enter your language (e.g. en_US.UTF-8, de_DE.UTF-8): "
read -r language
echo "LANG=$language" >/etc/locale.conf
echo "$language UTF-8" >>/etc/locale.gen
locale-gen
display_message $? "Language set successfully." "Failed to set language."

# Setting the hostname
printf "Set your hostname: "
read -r hostname
echo "$hostname" >/etc/hostname
display_message $? "Hostname set successfully." "Failed to set hostname."
# Setting up the hosts file
echo "127.0.0.1   localhost" >/etc/hosts
echo "::1         localhost" >>/etc/hosts
echo "127.0.1.1   $hostname.localdomain $hostname" >>/etc/hosts
display_message $? "Hosts file set successfully." "Failed to set hosts file."
# Setting up the network Manager
echo "Installing NetworkManager"
pacman -S networkmanager --noconfirm >>/dev/null
display_message $? "NetworkManager installed successfully." "Failed to install NetworkManager."
systemctl enable NetworkManager >>/dev/null
display_message $? "NetworkManager enabled successfully." "Failed to enable NetworkManager."
# Setting up the root password
echo "Setting up the root password"
passwd
display_message $? "Password set for root successfully." "Failed to set password for root."
# Setting up the user
echo "Setting up the user"
printf "Enter the username: "
read -r username
useradd -m -g users -G wheel -s /bin/bash "$username"
if [ $? -eq 0 ]; then
    echo -e "$SUCCESS User '$username' created successfully."
else
    echo -e "$ERROR Failed to create user '$username'."
fi
echo "Setting up the user password"
passwd "$username"
if [ $? -eq 0 ]; then
    echo -e "$SUCCESS Password set for user '$username' successfully."
else
    echo -e "$ERROR Failed to set password for user '$username'"
fi

echo "Setting up the time"
timedatectl set-ntp true
display_message $? "Time updated successfully." "Failed to update time."
# Updating the mirrorlist
echo "Updating the mirrorlist"
pacman -S reflector --noconfirm >>/dev/null
display_message $? "Reflector installed successfully." "Failed to install reflector."
reflector --latest 200 --sort rate --save /etc/pacman.d/mirrorlist
display_message $? "Mirrorlist updated successfully." "Failed to update mirrorlist."
# Starting System upgrade and update
echo -e "$WARNING Starting full System upgrade and update."
pacman -Sy --noconfirm >> /dev/null
display_message $? "System updated successfully." "Failed to update system."
pacamn -Syu --noconfirm >> /dev/null
display_message $? "System upgraded successfully." "Failed to update system."
# Updating Keyring
echo "Updating Pacman Keyring"
pacman -S archlinux-keyring --noconfirm >>/dev/null
display_message $? "Pacman Keyring updated successfully." "Failed to update Pacman Keyring."
# Setting up GRUB Bootloader for EFI Systems
pacman -S grub efibootmgr --noconfirm >>/dev/null
display_message $? "GRUB Bootloader package installed successfully." "Failed to install GRUB Bootloader package."
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB >>/dev/null
display_message $? "GRUB Bootloader installed successfully." "Failed to install GRUB Bootloader."
grub-mkconfig -o /boot/grub/grub.cfg >>/dev/null
display_message $? "GRUB Bootloader configured successfully." "Failed to configure GRUB Bootloader."
# Getting Grapic Card Informations 
intel=$(lspci -v -nn -d ::03xx | grep Intel > /dev/null)
amd=$(lspci -v -nn -d ::03xx | grep AMD > /dev/null)
nvidia=$(lspci -v -nn -d ::03xx | grep NVIDIA > /dev/null)

if [ -n "$intel" ]; then
    sudo pacman -S xf86-video-intel --noconfirm
    display_message $? "Intel video driver installed successfully." "Failed to install Intel video driver."
elif [ -n "$amd" ]; then
    sudo pacman -S xf86-video-amdgpu --noconfirm
    display_message $? "AMD video driver installed successfully." "Failed to install AMD video driver."
elif [ -n "$nvidia" ]; then
    sudo pacman -S nvidia nvidia-utils --noconfirm
    display_message $? "NVIDIA video driver installed successfully." "Failed to install NVIDIA video driver."
else
    echo -e "$WARNING No supported GPU found. Skipping GPU driver installation."
fi
sudo pacman -S xorg  --noconfirm
display_message $? "Xorg installed successfully." "Failed to install Xorg."
sudo pacman -S sddm --noconfirm
sudo systemctl enable sddm
display_message $? "SDDM installed and enabled successfully." "Failed to install SDDM."
#Installing KDE Plasma
sudo pacman -S plasma alacritty dolphin ark kwrite kcalc spectacle krunner partitionmanager packagekit-qt5 --noconfirm >>/dev/null
display_message $? "KDE Plasma & Base System for KDE installed successfully." "Failed to install KDE."
# Installing Audio and Bluetooth
sudo pacman -S alsa-utils bluez bluez-utils -noconfirm
display_message $? "Audio and Bluetooth installed successfully." "Failed to install Audio and Bluetooth."
sudo systemctl enable bluetooth.service
display_message $? "Bluetooth enabled successfully." "Failed to enable Bluetooth."
# Installing Optional Programms
echo "Do you want to install optional programms? (y/n)"
read optional_programms
if [ $optional_programms = "n" ]; then
    sudo pacman -S firefox vlc libreoffice openssh wget git fastfetch docker docker-compose gcc --noconfirm
    display_message $? "Optional programms installed successfully." "Failed to install optional programms."
else
    echo "Optional programms installation skipped."
fi

# Enabling OpenSSH daemon and CUPS printer service
sudo systemctl enable sshd.service
sudo systemctl enable --now cups.service
display_message $? "OpenSSH and CUPS enabled successfully." "Failed to enable OpenSSH and CUPS."
# Enabling Docker
sudo systemctl enable docker.service
display_message $? "Docker enabled successfully." "Failed to enable Docker."


# Exiting the Envirmoment
echo "$SUCESS Exiting the chroot environment."
exit
