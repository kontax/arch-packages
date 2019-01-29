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
    base        "Base system" \
    desktop     "Dual monitor desktop with i3wm" \
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


#####
# Get information from the user
##
hostname=$(get_input "Hostname" "Enter hostname") || exit 1
clear
: ${hostname:?"hostname cannot be empty"}

user=$(get_input "User" "Enter admin username") || exit 1
clear
: ${user:?"user cannot be empty"}

password=$(get_password "User" "Enter admin password") || exit 1
clear

passphrase=$(get_password "User" "Enter passphrase for encrypted volume") || exit 1
clear

devicelist=$(lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop" | tac | tr '\n' ' ')
read -r -a devicelist <<< $devicelist
device=$(get_choice "Installation" "Select installation disk" "${devicelist[@]}") || exit 1
clear


config=$(get_input "Config" "Enter location of config files (leave blank if required)") || exit 1
clear

if [[ -v config ]]; then
    conf_pass=$(get_password "Config" "Enter passphrase to decrypt config files") || exit 1
    clear
fi

system=$(get_choice "System" "Choose a system" "${SYSTEM_OPTIONS[@]}") || exit 1
clear
: ${system:?"system cannot be empty"}


echo "hostname: $hostname"
echo "user: $user"
echo "password: $password"
echo "passphrase: $passphrase"
echo "device: $device"
echo "config: $config"
echo "conf_pass: $conf_pass"
echo "system: $system"

exit 0
