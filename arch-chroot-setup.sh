#!/bin/bash

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
passwd 
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
echo "Setting up the user password"
passwd "$username" 
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

sudo pacman -S sddm --noconfirm
sudo systemctl enable sddm
if [ $? -eq 0 ]; then
    echo -e "$SUCESS SDDM installed successfully."
else
    echo -e "$ERROR Failed to install SDDM."
fi
#Installing KDE Plasma
sudo pacman -S plasma alacritty dolphin ark kwrite kcalc spectacle krunner partitionmanager packagekit-qt5 --noconfirm
if [ $? -eq 0 ]; then
    echo -e "$SUCESS KDE Plasma installed successfully."
else
    echo -e "$ERROR Failed to install KDE Plasma."
fi
# Installing Audio and Bluetooth
sudo pacman -S alsa-utils bluez bluez-utils -noconfirm
if [ $? -eq 0 ]; then
    echo -e "$SUCESS Audio and Bluetooth installed successfully."
else
    echo -e "$ERROR Failed to install Audio and Bluetooth."
fi
sudo systemctl enable bluetooth.service
# Installing Optional Programms
sudo pacman -S firefox vlc libreoffice openssh wget git fastfetch docker docker-compose --noconfirm
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
# Exiting the Envirmoment 
echo "$SUCESS Exiting the chroot environment."
exit