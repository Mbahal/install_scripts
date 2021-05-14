# default creds

mbahal:temp
root:temp

Maybe change the username and passwords if you use them, they have been put so that the installation works but it basically kills the security of the installation if they are not changed


# Installation disk

By default it does not really check what the disks are, it only checks if /dev/sda or /dev/vda are there, if one or the other is present, it continues and format them.
The reason behind it is that proxmox only shows /dev/sda by default when we put only one disk, and those were proxmox installtion files.
So either know what you're doing or change the disks

Keyboard layout is in french, but might not work with Xorg, see https://wiki.archlinux.org/title/Keyboard_configuration_in_Xorg#Using_X_configuration_filesa
So this maybe should be added on some distributions

# Packages

Only core packages or installed (with i3 as a wm). 
You could delete some (like spice or qemu-guest-agent) but as i said, those were proxmox install scripts and i needed spice. But it should not come as a bloated distribution with 999999 packages pre-installed



