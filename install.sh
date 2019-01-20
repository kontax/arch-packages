#!/bin/bash
# WARNING: this script will destroy data on the selected disk.
# This script can be run by executing the following:
#   curl -sL https://git.io/coul-install | bash

set -uo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

REPO_URL="https://s3-eu-west-1.amazonaws.com/couldinho-arch-aur/x86_64"
SNAP_PAC_SKIP=y


#####
# Get information from the user
##

hostname=$(dialog --stdout --inputbox "Enter hostname" 0 0) || exit 1
clear
: ${hostname:?"hostname cannot be empty"}

user=$(dialog --stdout --inputbox "Enter admin username" 0 0) || exit 1
clear
: ${user:?"user cannot be empty"}

export password=$(dialog --stdout --passwordbox "Enter admin password" 0 0) || exit 1
clear
: ${password:?"password cannot be empty"}
password2=$(dialog --stdout --passwordbox "Enter admin password again" 0 0) || exit 1
clear
[[ "$password" == "$password2" ]] || ( echo "Passwords did not match"; exit 1; )

passphrase=$(dialog --stdout --passwordbox "Enter passphrase for encrypted volume" 0 0) || exit 1
clear
: ${passphrase:?"passphrase cannot be empty"}
passphrase2=$(dialog --stdout --passwordbox "Enter passphrase for encrypted volume again" 0 0) || exit 1
clear
[[ "$passphrase" == "$passphrase2" ]] || ( echo "Passphrases did not match"; exit 1; )

devicelist=$(lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop" | tac)
device=$(dialog --stdout --menu "Select installation disk" 0 0 0 ${devicelist}) || exit 1
clear

config=$(dialog --stdout --inputbox "Enter location of config files (leave blank if required)" 0 0)
clear

if [ -n $config ]; then

    conf_pass=$(dialog --stdout --passwordbox "Enter passphrase to decrypt config files" 0 0) || exit 1
    clear
    : ${conf_pass:?"passphrase cannot be empty"}
    conf_pass2=$(dialog --stdout --passwordbox "Enter passphrase to decrypt config files again" 0 0) || exit 1
    clear
    [[ "$conf_pass" == "$conf_pass2" ]] || ( echo "Passphrases did not match"; exit 1; )

fi

# Environment variables for personal config files
# The IP needs to be pulled for now due to pacstrap not having DNS lookup
conf_url=${config#*//}
export CONF_FILE_LOCATION=$config
export CONF_FILE_IP=$(host -t a $conf_url 8.8.8.8 2>/dev/null | egrep "^$conf_url" | awk '{ print $4 }')
export CONF_FILE_PASS=$conf_pass

#####
# Set up logging
##

exec 1> >(tee "stdout.log")
exec 2> >(tee "stderr.log")


echo ""
echo "#####"
echo "# Downloading necessary packages"
echo "# and set up fastest mirrors"
echo "##"

pacman -Sy --noconfirm --needed git reflector
reflector -f 5 -c GB -c IE --sort rate --age 12 --save /etc/pacman.d/mirrorlist
timedatectl set-ntp true


echo ""
echo "#####"
echo "# Setting up partitions"
echo "##"

swap_size=$(free --mebi | awk '/Mem:/ {print $2}')
swap_end=$(( $swap_size + 129 + 1 ))MiB

parted --script "${device}" -- mklabel gpt \
  mkpart ESP fat32 1Mib 129MiB \
  set 1 boot on \
  mkpart primary linux-swap 129MiB ${swap_end} \
  mkpart primary ${swap_end} 100%

# Simple globbing was not enough as on one device I needed to match /dev/mmcblk0p1
# but not /dev/mmcblk0boot1 while being able to match /dev/sda1 on other devices.
part_boot="$(ls ${device}* | grep -E "^${device}p?1$")"
part_swap="$(ls ${device}* | grep -E "^${device}p?2$")"
part_root="$(ls ${device}* | grep -E "^${device}p?3$")"

wipefs "${part_boot}"
wipefs "${part_swap}"
wipefs "${part_root}"

mkfs.vfat -n "EFI" -F32 "${part_boot}"
mkswap "${part_swap}"
echo -n ${passphrase} | cryptsetup luksFormat "${part_root}"
echo -n ${passphrase} | cryptsetup luksOpen "${part_root}" luks
mkfs.btrfs -L btrfs /dev/mapper/luks

swapon "${part_swap}"

echo "  [*] Setting up BTRFS subvolumes"
mount /dev/mapper/luks /mnt
btrfs subvolume create /mnt/root
btrfs subvolume create /mnt/home
btrfs subvolume create /mnt/pkgs
btrfs subvolume create /mnt/logs
btrfs subvolume create /mnt/tmp
btrfs subvolume create /mnt/snapshots
umount /mnt

mount -o noatime,nodiratime,discard,compress=lzo,subvol=root /dev/mapper/luks /mnt
mkdir -p /mnt/{mnt/btrfs-root,boot/efi,home,var/{cache/pacman,log,tmp},.snapshots}
mount "${part_boot}" /mnt/boot/efi
mount -o noatime,nodiratime,discard,compress=lzo,subvol=/ /dev/mapper/luks /mnt/mnt/btrfs-root
mount -o noatime,nodiratime,discard,compress=lzo,subvol=home /dev/mapper/luks /mnt/home
mount -o noatime,nodiratime,discard,compress=lzo,subvol=pkgs /dev/mapper/luks /mnt/var/cache/pacman
mount -o noatime,nodiratime,discard,compress=lzo,subvol=logs /dev/mapper/luks /mnt/var/log
mount -o noatime,nodiratime,discard,compress=lzo,subvol=tmp /dev/mapper/luks /mnt/var/tmp
mount -o noatime,nodiratime,discard,compress=lzo,subvol=snapshots /dev/mapper/luks /mnt/.snapshots


echo "  [*] Creating an encrypted key for booting"
dd bs=512 count=4 if=/dev/urandom of=/mnt/crypto_keyfile.bin
chmod 000 /mnt/crypto_keyfile.bin
echo -n ${passphrase} | cryptsetup luksAddKey ${part_root} /mnt/crypto_keyfile.bin


echo "#####"
echo "# Installing packages and configuring"
echo "# the basic system"
echo "##"

if [[ ! -a /etc/pacman.d/couldinho-arch-aur ]]; then
    
    echo ""
    echo "  [*] Configuring remote AUR details"

    cat >>/etc/pacman.d/couldinho-arch-aur <<EOF
[options]
CacheDir = /var/cache/pacman/pkg
CacheDir = /var/cache/pacman/couldinho-arch-aur

[couldinho-arch-aur]
Server = $REPO_URL
SigLevel = Optional TrustAll
EOF

    cat >>/etc/pacman.conf <<EOF
Include = /etc/pacman.d/couldinho-arch-aur
EOF
fi

echo "  [*] Installing packages"
pacstrap /mnt couldinho-desktop


echo "  [*] Generating base config files"
mkdir /mnt/var/cache/pacman/couldinho-arch-aur
genfstab -t PARTUUID /mnt >> /mnt/etc/fstab
echo "${hostname}" > /mnt/etc/hostname
echo "FONT=ter-112n" > /mnt/etc/vconsole.conf
echo "en_US.UTF-8 UTF-8" >> /mnt/etc/locale.gen
echo "en_IE.UTF-8 UTF-8" >> /mnt/etc/locale.gen
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
echo "LC_MONETARY=en_IE.UTF-8" >> /mnt/etc/locale.conf
ln -sf /usr/share/zoneinfo/Europe/Dublin /mnt/etc/localtime
chmod 600 /mnt/boot/initramfs-linux*
sed -i "s|#PART_ROOT#|${part_root}|g" /mnt/etc/default/grub

if ! arch-chroot /mnt id -u $user 2>/dev/null; then
    echo "  [*] Creating user and shell"
    arch-chroot /mnt useradd -mU -s /usr/bin/zsh -G wheel,uucp,video,audio,storage,games,input "$user"
    arch-chroot /mnt chsh -s /usr/bin/zsh
fi
arch-chroot /mnt locale-gen

echo "  [*] Installing grub"
arch-chroot /mnt grub-install
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

echo "  [*] Cloning dotfiles to home folder"
git clone https://github.com/kontax/dotfiles.git /mnt/home/$user/dotfiles
arch-chroot /mnt chown -R $user:users /home/$user/dotfiles

echo "  [*] Installing certificates"
curl -skL www.coulson.ie/Coulson_Root_CA.pem -o /mnt/etc/ca-certificates/trust-source/anchors/Coulson_Root_CA.crt
curl -skL www.coulson.ie/Coulson_TLS_CA.pem -o /mnt/etc/ca-certificates/trust-source/anchors/Coulson_TLS_CA.crt
arch-chroot /mnt trust extract-compat

echo "$user:$password" | chpasswd --root /mnt
echo "root:$password" | chpasswd --root /mnt
echo "[*] DONE - Install setup from HOME/dotfiles"

