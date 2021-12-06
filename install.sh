#!/bin/bash
# WARNING: this script will destroy data on the selected disk.
# This script can be run by executing the following:
#   bash <(curl -sL https://git.io/coul-install)

set -uo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

exec 1> >(tee "stdout.log")
exec 2> >(tee "stderr.log" >&2)


# The package group to select from
PACKAGE_STAGE_LIST=(
    master      "The live and tested package group"
    dev         "The package group under development"
)

# System options to choose from
SYSTEM_OPTIONS=(
    base        "Base system" off \
    desktop     "Dual monitor desktop with i3wm" off \
    laptop      "HiDPI laptop with i3status options" off \
    dev         "Developer software" off \
    sec         "Reversing & exploitation software" off \
    vmware      "Includes VMWare virtual drivers" off \
)

# This is currently pointing at the prod URL, however a selection can be made
# within this script by the user to point it to the dev repo
export REPO_URL="https://s3-eu-west-1.amazonaws.com/couldinho-arch-aur/x86_64"
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
    desc="$2"
    shift 2
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
echo "# Checking UEFI boot mode"
echo "##"
if [ ! -f /sys/firmware/efi/fw_platform_size ]; then
    echo >&2 "You must boot in UEFI mode to continue"
    exit 2
fi


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

package_stage=$(get_choice "Installation" "Select whether to use the dev or master package list" "${PACKAGE_STAGE_LIST[@]}") || exit 1
clear
: ${package_stage:?"Stage cannot be empty"}

# Ensure we're pointing to the correct repository
if [ "$package_stage" == dev ]; then
    export REPO_URL=$(echo $REPO_URL | sed 's/couldinho-arch-aur/couldinho-arch-aur-dev/g')
fi

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

luks_header_device=$(get_choice "Installation" "Select disk for LUKS header" "${devicelist[@]}") || exit 1


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

# Delete any previous attempts at installation
umount -R /mnt 2>/dev/null || true
cryptsetup luksClose luks 2> /dev/null || true

lsblk -plnx size -o name "${device}" | xargs -n1 wipefs --all
sgdisk --clear "${device}" \
    --new 1::-511MiB "${device}" \
    --new 2::0 --typecode 2:ef00 "${device}"
sgdisk --change-name=1:primary --change-name=2:ESP "${device}"

part_root="$(ls ${device}* | grep -E "^${device}p?1$")"
part_boot="$(ls ${device}* | grep -E "^${device}p?2$")"

if [ "$device" != "$luks_header_device" ]; then
    cryptargs="--header $luks_header_device"
else
    cryptargs=""
    luks_header_device="$part_root"
fi


echo -e "\n  [*] Formatting partitions"

mkfs.vfat -n "EFI" -F 32 "${part_boot}"
echo -n ${passphrase} | cryptsetup luksFormat \
    --type luks2 \
    --pbkdf argon2id \
    --label luks \
    $cryptargs "${part_root}"
echo -n ${passphrase} | cryptsetup luksOpen $cryptargs "${part_root}" luks
mkfs.btrfs -L btrfs /dev/mapper/luks

echo -e "\n  [*] Setting up BTRFS subvolumes"
mount /dev/mapper/luks /mnt
btrfs subvolume create /mnt/root
btrfs subvolume create /mnt/home
btrfs subvolume create /mnt/pkgs
btrfs subvolume create /mnt/docker
btrfs subvolume create /mnt/logs
btrfs subvolume create /mnt/tmp
btrfs subvolume create /mnt/swap
btrfs subvolume create /mnt/snapshots
umount /mnt

mount -o noatime,nodiratime,discard,compress=zstd,subvol=root       /dev/mapper/luks /mnt
mkdir -p /mnt/{mnt/btrfs-root,efi,home,var/{cache/pacman,log,tmp,lib/docker},swap,.snapshots}
mount "${part_boot}" /mnt/efi
mount -o noatime,nodiratime,discard,compress=zstd,subvol=/          /dev/mapper/luks /mnt/mnt/btrfs-root
mount -o noatime,nodiratime,discard,compress=zstd,subvol=home       /dev/mapper/luks /mnt/home
mount -o noatime,nodiratime,discard,compress=zstd,subvol=pkgs       /dev/mapper/luks /mnt/var/cache/pacman
mount -o noatime,nodiratime,discard,compress=zstd,subvol=docker     /dev/mapper/luks /mnt/var/lib/docker
mount -o noatime,nodiratime,discard,compress=zstd,subvol=logs       /dev/mapper/luks /mnt/var/log
mount -o noatime,nodiratime,discard,compress=zstd,subvol=tmp        /dev/mapper/luks /mnt/var/tmp
mount -o noatime,nodiratime,discard,compress=zstd,subvol=swap       /dev/mapper/luks /mnt/swap
mount -o noatime,nodiratime,discard,compress=zstd,subvol=snapshots  /dev/mapper/luks /mnt/.snapshots


echo "#####"
echo "# Installing packages and configuring"
echo "# the basic system"
echo "##"

if [[ ! -a /etc/pacman.d/couldinho-arch-aur ]]; then

    echo -e "\n  [*] Configuring remote AUR details"

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

echo -e "\n  [*] Installing packages"
pacstrap /mnt $system


echo -e "\n  [*] Creating an encrypted key for booting"
cryptsetup luksHeaderBackup "${luks_header_device}" --header-backup-file /tmp/header.img
luks_header_size="$(stat -c '%s' /tmp/header.img)"
rm -f /tmp/header.img
echo "cryptdevice=PARTLABEL=primary:luks:allow-discards cryptheader=LABEL=luks:0:$luks_header_size root=LABEL=btrfs rw rootflags=subvol=root quiet mem_sleep_default=deep" > /mnt/etc/kernel/cmdline


echo -e "\n  [*] Generating base config files"
mkdir /mnt/var/cache/pacman/couldinho-arch-aur
genfstab -L /mnt >> /mnt/etc/fstab
echo "${hostname}" > /mnt/etc/hostname
echo "en_US.UTF-8 UTF-8" >> /mnt/etc/locale.gen
echo "en_IE.UTF-8 UTF-8" >> /mnt/etc/locale.gen
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
echo "LC_MONETARY=en_IE.UTF-8" >> /mnt/etc/locale.conf
ln -sf /usr/share/zoneinfo/Europe/Dublin /mnt/etc/localtime
arch-chroot /mnt locale-gen
arch-chroot /mnt arch-secure-boot initial-setup

echo -e "\n  [*] Configuring swap file"
swap_size=$(free --mebi | awk '/Mem:/ {print $2}')
truncate -s 0 /mnt/swap/swapfile
chattr +C /mnt/swap/swapfile
btrfs property set /mnt/swap/swapfile compression none
dd if=/dev/zero of=/mnt/swap/swapfile bs=1M count=${swap_size}
chmod 600 /mnt/swap/swapfile
mkswap /mnt/swap/swapfile
echo "/swap/swapfile none swap defaults 0 0" >> /mnt/etc/fstab


echo "#####"
echo "# Setting up user account and home folder,"
echo "# including the dotfile repo."
echo "##"

echo -e "\n  [*] Creating user and shell"
arch-chroot /mnt useradd -m -s /usr/bin/zsh -g users -G wheel,uucp,video,audio,storage,games,input "$user"
arch-chroot /mnt chsh -s /usr/bin/zsh

echo "$user:$password" | chpasswd --root /mnt
echo "root:$password" | chpasswd --root /mnt

if [ ! -z $CONF_FILE_LOCATION ]; then
    echo -e "\n  [*] Cloning dotfiles to home folder"
    arch-chroot /mnt sudo -E -u $user bash < <( \
        curl -skL $CONF_FILE_LOCATION \
        | openssl aes-256-cbc -salt -d -k "$CONF_FILE_PASS")
fi

# Finish off installing zsh
arch-chroot /mnt sudo -u "$user" zsh -ic true

echo "\n[*] DONE - Install setup from $HOME/dotfiles"

