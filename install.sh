#!/bin/bash
# WARNING: this script will destroy data on the selected disk.
# This script can be run by executing the following:
#   bash <(curl -sL https://git.io/coul-install)

set -uo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

exec &> >(tee "install.log")


# The package group to select from
PACKAGE_STAGE_LIST=(
    master      "The live and tested package group"
    dev         "The package group under development"
)

# System options to choose from
SYSTEM_OPTIONS=(
    base            "Base system" off \
    desktop         "Dual monitor desktop with i3wm" off \
    laptop          "HiDPI laptop with i3status options" off \
    dev             "Developer software" off \
    sec             "Reversing & exploitation software" off \
    vmware          "Includes VMWare virtual drivers" off \
    xcp-ng          "Guest tools for XCP-NG" off \
)

# This is currently pointing at the prod URL, however a selection can be made
# within this script by the user to point it to the dev repo
export REPO_URL="https://s3-eu-west-1.amazonaws.com/couldinho-arch-aur/x86_64"

# This repository is cloned into the user home folder
export PKG_REPO_URL="https://github.com/kontax/arch-packages.git"

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

function display_message {
    title="$1"
    desc="$2"

    dialog --clear \
           --stdout \
           --backtitle "$BACKTITLE" \
           --title "$title" \
           --msgbox "$desc" \
           $HEIGHT $WIDTH
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

# Fix persistent certificate issues
pacman-key --init
pacman-key --populate
pacman -Sy --noconfirm archlinux-keyring

# Install required packages
pacman -Sy --noconfirm --needed git reflector dialog
reflector -f 5 -c GB -c IE --sort rate --age 12 --save /etc/pacman.d/mirrorlist
timedatectl set-ntp true
hwclock --systohc --utc


#####
# Get information from the user
##

if [[ -z ${hidpi:-} ]]; then
    noyes=("Yes" "The font is too small" "No" "The font size is just fine")
    hidpi=$(get_choice "Font size" "Is your screen HiDPI?" "${noyes[@]}") || exit 1
    clear
fi
[[ "$hidpi" == "Yes" ]] && font="ter-132n" || font="ter-716n"
setfont "$font"

if [[ -z ${package_stage:-} ]]; then
    package_stage=$(get_choice "Installation" "Select whether to use the dev or master package list" "${PACKAGE_STAGE_LIST[@]}") || exit 1
    clear
    : ${package_stage:?"Stage cannot be empty"}
fi

# Ensure we're pointing to the correct repository
if [ "$package_stage" == dev ]; then
    export REPO_URL=$(echo $REPO_URL | sed 's/couldinho-arch-aur/couldinho-arch-aur-dev/g')
fi

if [[ -z ${hostname:-} ]]; then
    hostname=$(get_input "Hostname" "Enter hostname") || exit 1
    clear
    : ${hostname:?"hostname cannot be empty"}
fi

if [[ -z ${user:-} ]]; then
    user=$(get_input "User" "Enter admin username") || exit 1
    clear
    : ${user:?"user cannot be empty"}
fi

if [[ -z ${password:-} ]]; then
    password=$(get_new_password "User" "Enter admin password") || exit 1
    clear
fi

if [[ -z ${encrypt:-} ]]; then
    noyes=("Yes" "Encrypt the root drive" "No" "Do not encrypt the root drive")
    encrypt=$(get_choice "Encrypt Drive" "Encrypt the root drive?" "${noyes[@]}") || exit 1
    clear
fi

if [[ -z ${yubikey:-} && ${encrypt} == "Yes" ]]; then
    noyes=("Yes" "Use a YubiKey for LUKS (must be v5+)" "No" "Use a password for LUKS")
    yubikey=$(get_choice "YubiKey Encryption" "Use a YubiKey for LUKS encryption/decryption?" "${noyes[@]}") || exit 1
    clear
else
    yubikey="No"
fi

if [[ -z ${passphrase:-} && ${encrypt} == "Yes" && ${yubikey} == "No" ]]; then
    passphrase=$(get_new_password "User" "Enter passphrase for encrypted volume")
    clear
elif [[ -z ${passphrase:-} && ${encrypt} == "Yes" && ${yubikey} == "Yes" ]]; then
    passphrase=${password}
    display_message "YubiKey Encryption" \
        "Ensure the YubiKey is inserted now. When prompted use the admin \
         password for LUKS decryption. When the YubiKey starts to flash, press \
         the hardware button, and press it again when prompted."
    clear
fi

if [[ -z ${device:-} ]]; then
    devicelist=$(lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop" | tac | tr '\n' ' ')
    read -r -a devicelist <<< $devicelist
    device=$(get_choice "Installation" "Select installation disk" "${devicelist[@]}") || exit 1
    clear
fi

if [[ -z ${luks_header_device:-} && ${encrypt} == "Yes" ]]; then
    luks_header_device=$(get_choice "Installation" "Select disk for LUKS header" "${devicelist[@]}") || exit 1
fi


if [[ -z ${config:-} ]]; then
    config=$(get_input "Config" "Enter location of config files (leave blank if required)") || exit 1
    clear
fi

if [[ ! -z $config && -z ${conf_pass:-} ]]; then
    conf_pass=$(get_password "Config" "Enter passphrase to decrypt config files") || exit 1
    clear
fi

if [[ -z ${user_system:-} ]]; then
    user_system=$(get_multi_choice "System" "Choose a system" "${SYSTEM_OPTIONS[@]}") || exit 1
    clear
    : ${user_system:?"system cannot be empty"}
fi

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

if [[ ${encrypt} == "Yes" ]]; then
    part_install="/dev/mapper/luks"
    if [ "$device" != "$luks_header_device" ]; then
        cryptargs="--header $luks_header_device"
    else
        cryptargs=""
        luks_header_device="$part_root"
    fi
else
    part_install="${part_root}"
fi


echo -e "\n  [*] Formatting partitions"

mkfs.vfat -n "EFI" -F 32 "${part_boot}"
if [[ ${encrypt} == "Yes" ]]; then
    echo -n ${passphrase} | cryptsetup luksFormat \
        --type luks2 \
        --pbkdf argon2id \
        --label luks \
        $cryptargs "${part_root}"
    echo -n ${passphrase} | cryptsetup luksOpen $cryptargs "${part_root}" luks
fi

# YUBIKEY CHANGES
#TODO: Can we echo password in here
#TODO: Need to ask about whether a yubikey is present
#TODO: Can the passphrase from above be removed
#TODO: Can multiple yubikeys be used?
[[ "$yubikey" == "Yes" ]] && \
    systemd-cryptenroll \
    --fido2-device=auto ${part_root} \
    --fido2-with-client-pin=false \
    --wipe-slot=password
# END YUBIKEY CHANGES
mkfs.btrfs -L btrfs ${part_install}

echo -e "\n  [*] Setting up BTRFS subvolumes"
mount ${part_install} /mnt
btrfs subvolume create /mnt/root
btrfs subvolume create /mnt/home
btrfs subvolume create /mnt/pkgs
btrfs subvolume create /mnt/docker
btrfs subvolume create /mnt/logs
btrfs subvolume create /mnt/tmp
btrfs subvolume create /mnt/swap
btrfs subvolume create /mnt/snapshots
umount /mnt

mount -o noatime,nodiratime,discard,compress=zstd,subvol=root       ${part_install} /mnt
mkdir -p /mnt/{mnt/btrfs-root,efi,home,var/{cache/pacman,log,tmp,lib/docker},swap,.snapshots}
mount "${part_boot}" /mnt/efi
mount -o noatime,nodiratime,discard,compress=zstd,subvol=/          ${part_install} /mnt/mnt/btrfs-root
mount -o noatime,nodiratime,discard,compress=zstd,subvol=home       ${part_install} /mnt/home
mount -o noatime,nodiratime,discard,compress=zstd,subvol=pkgs       ${part_install} /mnt/var/cache/pacman
mount -o noatime,nodiratime,discard,compress=zstd,subvol=docker     ${part_install} /mnt/var/lib/docker
mount -o noatime,nodiratime,discard,compress=zstd,subvol=logs       ${part_install} /mnt/var/log
mount -o noatime,nodiratime,discard,compress=zstd,subvol=tmp        ${part_install} /mnt/var/tmp
mount -o noatime,nodiratime,discard,compress=zstd,subvol=swap       ${part_install} /mnt/swap
mount -o noatime,nodiratime,discard,compress=zstd,subvol=snapshots  ${part_install} /mnt/.snapshots


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
ParallelDownloads = 32
EOF
fi

echo -e "\n  [*] Installing packages"
pacstrap /mnt $system


if [[ ${encrypt} == "Yes" ]]; then
    echo -e "\n  [*] Creating an encrypted key for booting"
    cryptsetup luksHeaderBackup "${luks_header_device}" --header-backup-file /tmp/header.img
    luks_header_size="$(stat -c '%s' /tmp/header.img)"
    rm -f /tmp/header.img
fi

if [[ ${encrypt} == "Yes" ]]; then
    if [[ ${yubikey:-} == "Yes" ]]; then
        yk_kernel_options="rd.luks.options=fido2-device=auto"
        yk_modules="systemd sd-encrypt"
    else
        yk_kernel_options=""
        yk_modules=""
    fi

    encrypt_modules="${yk_modules} encrypt-dh"
    boot_args="cryptdevice=PARTLABEL=primary:luks:allow-discards cryptheader=LABEL=luks:0:$luks_header_size $yk_kernel_options"
else
    encrypt_modules=""
    boot_args=""
fi

echo "$boot_args root=LABEL=btrfs rw rootflags=subvol=root quiet mem_sleep_default=deep" > /mnt/etc/kernel/cmdline
# END YUBIKEY CHANGES


echo -e "\n  [*] Generating base config files"
ln -sfT dash /mnt/usr/bin/sh
echo "FONT=$font" > /mnt/etc/vconsole.conf
mkdir /mnt/var/cache/pacman/couldinho-arch-aur
genfstab -L /mnt >> /mnt/etc/fstab
echo "${hostname}" > /mnt/etc/hostname
echo "en_US.UTF-8 UTF-8" >> /mnt/etc/locale.gen
echo "en_IE.UTF-8 UTF-8" >> /mnt/etc/locale.gen
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
echo "LC_MONETARY=en_IE.UTF-8" >> /mnt/etc/locale.conf
ln -sf /usr/share/zoneinfo/Europe/Dublin /mnt/etc/localtime
arch-chroot /mnt locale-gen

# YUBIKEY CHANGES
if [[ "$yubikey" == "Yes" ]]; then
    echo "root ${part_root} - fido2-device=auto" > /mnt/etc/crypttab.initramfs
fi
modules="base consolefont udev autodetect modconf block $encrypt_modules filesystems keyboard"
cat << EOF > /mnt/etc/mkinitcpio.conf
MODULES=()
BINARIES=()
FILES=()
HOOKS=(${modules})
EOF

# END YUBIKEY CHANGES
arch-chroot /mnt mkinitcpio -p linux
arch-chroot /mnt arch-secure-boot initial-setup

echo -e "\n  [*] Configuring swap file"
swap_size=$(free --mebi | awk '/Mem:/ {print $2}')
btrfs filesystem mkswapfile --size ${swap_size}M /mnt/swap/swapfile
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

if [ ! -z ${CONF_FILE_LOCATION:-} ]; then
    echo -e "\n  [*] Cloning dotfiles to home folder"
    arch-chroot /mnt sudo SUDO_PASSWORD="$password" -u $user bash < <( \
        curl -skL $CONF_FILE_LOCATION \
        | openssl aes-256-cbc -pbkdf2 -salt -d -k "$CONF_FILE_PASS")
fi

# Set up the repostiory
repo_path="/home/$user/dev/arch-packages"
arch-chroot /mnt sudo -u "$user" \
    mkdir "/home/$user/dev"
arch-chroot /mnt sudo -u "$user" \
    git clone "$PKG_REPO_URL" "$repo_path"
arch-chroot /mnt sudo -u "$user" \
    cp "$repo_path/pre-commit" "$repo_path/.git/hooks"

# Finish off installing zsh
arch-chroot /mnt sudo -u "$user" zsh -ic true

echo -e "\n[*] DONE - Install setup from $HOME/dotfiles"

