#!/bin/bash

set -e
set -x
if [ -e /dev/vda ]; then
  device=/dev/vda
elif [ -e /dev/sda ]; then
  device=/dev/sda
else
  echo "ERROR: There is no disk available for installation" >&2
  exit 1
fi
export device
ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime

#maybe change the hostname?
echo 'mbahal-archlinux' > /etc/hostname

sed -i -e 's/^#\(fr_FR.UTF-8\)/\1/' /etc/locale.gen
locale-gen
echo 'LANG=fr_FR.UTF-8' > /etc/locale.conf
echo "KEYMAP=fr-latin1" > /etc/vconsole.conf
echo "FONT=eurlatgr" >> /etc/vconsole.conf

systemctl enable NetworkManager

export HOME_DIR=mbahal
useradd -m  -U mbahal
echo -e 'temp\ntemp' | passwd mbahal
#allow mbahal to use sudo
cat <<EOF > /etc/sudoers.d/mbahal
Defaults:mbahal !requiretty
mbahal ALL=(ALL:ALL) ALL
EOF
chmod 440 /etc/sudoers.d/mbahal
mkdir -p /etc/systemd/network
ln -sf /dev/null /etc/systemd/network/99-default.link

echo "Section \"InputClass\"
        Identifier \"Keyboard Layout\"
        MatchIsKeyboard \"on\"
        Option \"XkbLayout\" \"fr\"
        Option \"XkbLayout\" \"latin9\"
EndSection " > /etc/X11/xorg.conf.d/00-keyboard.conf

#enable sshd to have ssh access
systemctl enable sshd
#enable qemu-guest-agent
systemctl enable qemu-guest-agent
sed -i -e 's/^#Color/Color/' /etc/pacman.conf
sed -i -e 's/^#Include = \/etc\/pacman.d\/mirrorlist/Include = \/etc\/pacman.d\/mirrorlist/' /etc/pacman.conf
sed -i -e 's/filesystems keyboard/filesystems keyboard keymap lvm2 encrypt udev/' /etc/mkinitcpio.conf
mkinitcpio -p linux-lts
sed -i '/GRUB_CMDLINE_LINUX=/d' /etc/default/grub
sed -i 's/#GRUB_ENABLE_CRYPTODISK=y/GRUB_ENABLE_CRYPTODISK=y/' /etc/default/grub
echo GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=$(blkid -s UUID -o value /dev/mapper/archlvm-root):root root=/dev/mapper/root\" >> /etc/default/grub
grub-install --target=i386-pc --bootloader-id=arch_grub --recheck "${device}"
sed -i -e 's/^GRUB_TIMEOUT=.*$/GRUB_TIMEOUT=1/' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

#now let's configure the /home
mkdir -m 700 /etc/luks-keys

#génération du fichier de clé
dd if=/dev/urandom of=/etc/luks-keys/home bs=1 count=256 status=progress

# Chiffrement du home via la clé crée

echo "YES" | cryptsetup luksFormat -v -c aes-xts-plain64 -s 512 -h sha512 -i 4000 /dev/archlvm/home /etc/luks-keys/home
cryptsetup -d /etc/luks-keys/home open /dev/archlvm/home home
mkfs.xfs /dev/mapper/home
mount /dev/mapper/home /home


# change fstab & crypttab, but need to see if it works not tested

echo "home /dev/mapper/archlvm-home  /etc/luks-keys/home
swap /dev/mapper/archlvm-swap  /dev/urandom  swap,cipher=aes-xts-plain64,size=256
tmp  /dev/mapper/archlvm-tmp   /dev/urandom  tmp,cipher=aes-xts-plain64,size=256" >> /etc/crypttab

echo "/dev/mapper/tmp   /tmp   tmpfs  defaults  0  0
/dev/mapper/swap  none   swap   sw  0  0
/dev/mapper/home  /home  xfs    defaults  0  2" >> /etc/fstab

echo -e 'temp\ntemp' | passwd

