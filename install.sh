#!/bin/bash
# WARNING: this script will destroy data on the selected disk.
# This script can be run by executing the following:
#   curl -sL https://git.io/coul-install | bash

set -uo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

exec 1> >(tee "stdout.log")
exec 2> >(tee "stderr.log")

# System options to choose from
SYSTEM_OPTIONS=(
    base        "Base system" off \
    desktop     "Dual monitor desktop with i3wm" off \
    laptop      "HiDPI laptop with i3status options" off \
    dev         "Developer software" off \
    sec         "Reversing & exploitation software" off \
    vmware      "Includes VMWare virtual drivers" off \
)

REPO_URL="https://s3-eu-west-1.amazonaws.com/couldinho-arch-aur/x86_64"
export SNAP_PAC_SKIP=y

# Dialog options
HEIGHT=0
WIDTH=0
CHOICE_HEIGHT=0
BACKTITLE="Arch Linux install script"


# Dialog Functions
function get_input {
    title="$1"
    desc="$2"

    input=$(
        dialog --clear \
               --stdout \
               --backtitle "$BACKTITLE" \
               --title "$title" \
               --inputbox "$desc" \
               $HEIGHT $WIDTH
    )
    echo "$input"
}

function get_password {
    title="$1"
    desc="$2"

    init_pass=$(
        dialog --clear \
               --stdout \
               --backtitle "$BACKTITLE" \
               --title "$title" \
               --passwordbox "$desc" \
               $HEIGHT $WIDTH
    )
    : ${init_pass:?"password cannot be empty"}
    echo $init_pass
}

function get_new_password {
    title="$1"
    desc="$2"

    init_pass=$(
        dialog --clear \
               --stdout \
               --backtitle "$BACKTITLE" \
               --title "$title" \
               --passwordbox "$desc" \
               $HEIGHT $WIDTH
    )
    : ${init_pass:?"password cannot be empty"}

    test_pass=$(
        dialog --clear \
               --stdout \
               --backtitle "$BACKTITLE" \
               --title "$title" \
               --passwordbox "$desc again" \
               $HEIGHT $WIDTH
    )
    if [[ "$init_pass" != "$test_pass" ]]; then
        echo "Passwords did not match" >&2
        exit 1
    fi
    echo $init_pass
}

function get_multi_choice {
    title="$1"
    shift
    desc="$2"
    shift
    options=("$@")
    dialog --clear \
        --stdout \
         --backtitle "$BACKTITLE" \
         --title "$title" \
         --checklist "$desc" \
         $HEIGHT $WIDTH $CHOICE_HEIGHT \
         "${options[@]}"
 }

function get_choice {
    title="$1"
    shift
    desc="$2"
    shift
    options=("$@")
    dialog --clear \
        --stdout \
         --backtitle "$BACKTITLE" \
         --title "$title" \
         --menu "$desc" \
         $HEIGHT $WIDTH $CHOICE_HEIGHT \
         "${options[@]}"
 }


echo ""
echo "#####"
echo "# Downloading necessary packages"
echo "# and set up fastest mirrors"
echo "##"

pacman -Sy --noconfirm --needed git reflector dialog
reflector -f 5 -c GB -c IE --sort rate --age 12 --save /etc/pacman.d/mirrorlist
timedatectl set-ntp true


#####
# Get information from the user
##
hostname=$(get_input "Hostname" "Enter hostname") || exit 1
clear
: ${hostname:?"hostname cannot be empty"}

user=$(get_input "User" "Enter admin username") || exit 1
clear
: ${user:?"user cannot be empty"}

password=$(get_new_password "User" "Enter admin password") || exit 1
clear

passphrase=$(get_new_password "User" "Enter passphrase for encrypted volume") || exit 1
clear

devicelist=$(lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop" | tac | tr '\n' ' ')
read -r -a devicelist <<< $devicelist
device=$(get_choice "Installation" "Select installation disk" "${devicelist[@]}") || exit 1
clear


config=$(get_input "Config" "Enter location of config files (leave blank if required)") || exit 1
clear

if [ ! -z $config ]; then
    conf_pass=$(get_password "Config" "Enter passphrase to decrypt config files") || exit 1
    clear
fi

user_system=$(get_multi_choice "System" "Choose a system" "${SYSTEM_OPTIONS[@]}") || exit 1
clear
: ${user_system:?"system cannot be empty"}

# Extracting packages to install for selected systems
system=""
for s in ${user_system[@]}; do
    system+="couldinho-$s "
done


echo ""
echo "====="
echo "* INSTALLING $system "
echo "==="
echo ""

# Environment variables for personal config files
# The IP needs to be pulled for now due to pacstrap not having DNS lookup
if [ ! -z $config ]; then
    conf_url=${config#*//}
    export CONF_FILE_LOCATION=$config
    export CONF_FILE_PASS=$conf_pass
fi


echo ""
echo "#####"
echo "# Setting up partitions"
echo "##"

swap_size=$(free --mebi | awk '/Mem:/ {print $2}')
swap_end=$(( $swap_size + 129 + 1 ))MiB
bios=$(if [ -f /sys/firmware/efi/fw_platform_size ]; then echo "gpt"; else echo "msdos"; fi)
part=$(if [[ $bios == "gpt" ]]; then echo "ESP"; else echo "primary"; fi)

parted --script "${device}" -- mklabel ${bios} \
  mkpart ${part} fat32 1Mib 129MiB \
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
echo -n ${passphrase} | cryptsetup luksFormat --type luks1 "${part_root}"
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
pacstrap /mnt $system


echo "  [*] Generating base config files"
mkdir /mnt/var/cache/pacman/couldinho-arch-aur
genfstab -t PARTUUID /mnt >> /mnt/etc/fstab
echo "${hostname}" > /mnt/etc/hostname
echo "en_US.UTF-8 UTF-8" >> /mnt/etc/locale.gen
echo "en_IE.UTF-8 UTF-8" >> /mnt/etc/locale.gen
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
echo "LC_MONETARY=en_IE.UTF-8" >> /mnt/etc/locale.conf
ln -sf /usr/share/zoneinfo/Europe/Dublin /mnt/etc/localtime
chmod 600 /mnt/boot/initramfs-linux*
sed -i "s|#PART_ROOT#|${part_root}|g" /mnt/etc/default/grub

arch-chroot /mnt locale-gen

echo "  [*] Installing grub"
arch-chroot /mnt grub-install ${device}
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg


echo "#####"
echo "# Setting up user account and home folder,"
echo "# including the dotfile repo."
echo "##"

echo "  [*] Creating user and shell"
arch-chroot /mnt useradd -m -s /usr/bin/zsh -g users -G wheel,uucp,video,audio,storage,games,input "$user"
arch-chroot /mnt chsh -s /usr/bin/zsh

echo "$user:$password" | chpasswd --root /mnt
echo "root:$password" | chpasswd --root /mnt

if [ ! -z $CONF_FILE_LOCATION ]; then
    echo "  [*] Cloning dotfiles to home folder"
    arch-chroot /mnt sudo -u $user bash < <( \
        curl -skL $CONF_FILE_LOCATION \
        | openssl aes-256-cbc -salt -d -k "$CONF_FILE_PASS")
fi

# Finish off installing zsh
arch-chroot /mnt sudo -u "$user" zsh -ic true

echo "[*] DONE - Install setup from $HOME/dotfiles"

