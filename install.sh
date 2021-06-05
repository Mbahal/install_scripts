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
#initialize device with two partitions, one that will receive the esp (efi system partition) flag and boot file
#the other that will hold the logical volumes a
#let 1 MiB so that the 34 first sectors are let alone since a disk need them i can't remember why but fails otherwise
parted --script "${device}" \
	mklabel msdos \
	mkpart primary ext4 1MiB 100MiB \
	set 1 boot on \
	mkpart primary ext4 100MiB 100% \
	q
#create the physical volume
pvcreate "${device}2"

#create group volume on the vg
vgcreate archlvm "${device}2"


#logical volumes creation
lvcreate -L 35%FREE -n root archlvm
lvcreate -L 2G -n swap archlvm
lvcreate -L 1G -n tmp archlvm
lvcreate -l 100%FREE -n home archlvm


#creation of the encrypted root volume, -c = cipher algorithm -s size of the key, -h hashing function -i iteration_time between two unlocks (2000 by defaults)
echo -e "YES" | cryptsetup luksFormat -c aes-xts-plain64 -s 512 -h sha512 -i 4000 /dev/archlvm/root luks_password

#open encrypted volume and mount it
cryptsetup open -d luks_password /dev/archlvm/root root
mkfs.xfs /dev/mapper/root
mount /dev/mapper/root /mnt

# format and mount boot/esp partition
mkfs.ext4 "${device}1"
mkdir /mnt/boot
mount "${device}1"  /mnt/boot

# Get the four best  mirrors, will help with the download speed
# by speed before intalling the rest of the packages

echo 'Yes' | pacman -Sy pacman-contrib
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
sleep 5 #apparently needs to finish something when pulling pacman-contrib that makes rankmirrors fails sometimes
sync
#rankmirrors -n 4 /etc/pacman.d/mirrorlist.backup > /etc/pacman.d/mirrorlist
sync
# Install base packages not all aare mandatory but none are not usefull imo

echo 'all' | pacstrap /mnt base base-devel lvm2 cryptsetup xfsprogs linux-lts linux-lts-headers linux-firmware zip unzip p7zip vim alsa-utils dosfstools lsb-release exfat-utils bash-completion git grub efibootmgr openssh sudo qemu-guest-agent networkmanager i3-gaps i3lock i3blocks i3status rofi lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings xorg-{server,xinit,apps} xdg-user-dirs xf86-video-nouveau mesa intel-ucode xorg-fonts-type1 freetype2 gsfonts sdl_ttf ttf-{dejavu,bitstream-vera,liberation} noto-fonts-{cjk,emoji,extra} tmux xterm xf86-video-vesa xf86-video-fbdev xf86-video-qxl

mkdir -p /etc/X11/xorg.conf.d/



genfstab -Up /mnt >> /mnt/etc/fstab
arch-chroot /mnt /bin/bash
