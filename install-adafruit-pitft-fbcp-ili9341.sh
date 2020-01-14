#!/bin/bash

# Modified to use fbcp-ili9341 instead of fbcp.
# Original: https://raw.githubusercontent.com/adafruit/Raspberry-Pi-Installer-Scripts/master/adafruit-pitft.sh
# This script is still in the process of being cleaned up.

# No touchscreen.
# Hardcoded to HDMI mirror.
# Hardcoded the HDMI resolution (pitft will scale).
# Assumes no login screen.
# Assumes Systemd.
# Assumes the 2.8 resistive touch screen.
# Assumes landscape.

# TODO(eriq): Review all packages.

if [ $(id -u) -ne 0 ]; then
    echo "Installer must be run as root."
    echo "Try 'sudo bash $0'"
    exit 1
fi

set -e
trap exit SIGINT

# Given a filename, a regex pattern to match and a replacement string,
# perform replacement if found, else append replacement to end of file.
# (# $1 = filename, $2 = pattern to match, $3 = replacement)
reconfig() {
    grep $2 $1 >/dev/null
    if [ $? -eq 0 ]; then
        # Pattern found; replace in file
        sed -i "s/$2/$3/g" $1 >/dev/null
    else
        # Not found; append (silently)
        echo $3 | sudo tee -a $1 >/dev/null
    fi
}


############################ Sub-Scripts ############################

function softwareinstall() {
    echo "Installing Pre-requisite Software...This may take a few minutes!"

    sudo apt-get update
    apt-get install -y bc cmake python-dev python-pip python-smbus python-spidev evtest libts-bin device-tree-compiler
    pip install evdev
}

# update /boot/config.txt with appropriate values
function update_configtxt() {
    if grep -q "adafruit-pitft-helper" "/boot/config.txt"; then
        echo "Already have an adafruit-pitft-helper section in /boot/config.txt."
        echo "Removing old section..."
        cp /boot/config.txt /boot/config.txt.bak
        sed -i -e "/^# --- added by adafruit-pitft-helper/,/^# --- end adafruit-pitft-helper/d" /boot/config.txt
    fi

    if [ "${pitfttype}" == "28r" ]; then
        overlay="dtoverlay=pitft28-resistive,rotate=${pitftrot},speed=64000000,fps=30"
    fi

    date=`date`

    cat >> /boot/config.txt <<EOF
# --- added by adafruit-pitft-helper $date ---
dtparam=spi=on
dtparam=i2c1=on
dtparam=i2c_arm=on
$overlay
hdmi_cvt=1280 960 60 1 0 0 0
# --- end adafruit-pitft-helper $date ---
EOF
}

function uninstall_console() {
    echo "Removing console fbcon map from /boot/cmdline.txt"
    sed -i 's/rootwait fbcon=map:10 fbcon=font:VGA8x8/rootwait/g' "/boot/cmdline.txt"
    echo "Screen blanking time reset to 10 minutes"
    if [ -e "/etc/kbd/config" ]; then
      sed -i 's/BLANK_TIME=0/BLANK_TIME=10/g' "/etc/kbd/config"
    fi
    sed -i -e '/^# disable console blanking.*/d' /etc/rc.local
    sed -i -e '/^sudo sh -c "TERM=linux.*/d' /etc/rc.local
}

function install_fbcp() {
    echo "Downloading rpi-fbcp..."
    cd /tmp
    curl -sLO https://github.com/juj/fbcp-ili9341/archive/master.zip
    echo "Uncompressing rpi-fbcp..."
    rm -rf /tmp/fbcp-ili9341-master
    unzip master.zip
    cd fbcp-ili9341-master
    mkdir build
    cd build
    echo "Building rpi-fbcp..."
    cmake -DADAFRUIT_ILI9341_PITFT=ON -DSPI_BUS_CLOCK_DIVISOR=30 ..
    make -j
    echo "Installing rpi-fbcp..."
    install fbcp-ili9341 /usr/local/bin/fbcp
    cd ~
    rm -rf /tmp/fbcp-ili9341-master

    # Install fbcp systemd unit, first making sure it's not in rc.local:
    echo "We have systemd, so install fbcp systemd unit..."
    install_fbcp_unit

    # Disable overscan compensation (use full screen):
    raspi-config nonint do_overscan 1

    # Set up HDMI parameters:
    echo "Configuring boot/config.txt for forced HDMI"
    reconfig /boot/config.txt "^.*hdmi_force_hotplug.*$" "hdmi_force_hotplug=1"
    reconfig /boot/config.txt "^.*hdmi_group.*$" "hdmi_group=2"
    reconfig /boot/config.txt "^.*hdmi_mode.*$" "hdmi_mode=87"

    if [ "${pitftrot}" == "90" ] || [ "${pitftrot}" == "270" ]; then
        # dont rotate HDMI on 90 or 270
        reconfig /boot/config.txt "^.*display_hdmi_rotate.*$" ""
    fi
}

function install_fbcp_unit() {
    sudo cp systemd-units/fbcp.service /etc/systemd/system/fbcp.service
    sudo systemctl enable fbcp.service
}

echo "This script downloads and installs"
echo "PiTFT Support using userspace touch"
echo "controls and a DTO for display drawing."
echo "one of several configuration files."
echo "Run time of up to 5 minutes. Reboot required!"
echo

PITFT_ROTATIONS=("90" "180" "270" "0")
PITFT_TYPES=("28r" "22" "28c" "35r" "st7789_240x240" "st7789_240x135")
WIDTH_VALUES=(320 320 320 480 240)
HEIGHT_VALUES=(240 240 240 320 240)

PITFT_SELECT=1
PITFT_ROTATE=3

SYSTEMD=1

pitfttype=${PITFT_TYPES[$PITFT_SELECT-1]}
pitftrot=${PITFT_ROTATIONS[$PITFT_ROTATE-1]}

echo "Installing Python libraries & Software..."
softwareinstall

echo "Updating /boot/config.txt..."
update_configtxt

echo "Making sure console doesn't use PiTFT"
uninstall_console

echo "Adding FBCP support..."
install_fbcp

echo "Success!"
echo
echo "Settings take effect on next boot."
echo
echo -n "REBOOT NOW? [y/N] "
read
if [[ ! "$REPLY" =~ ^(yes|y|Y)$ ]]; then
        echo "Exiting without reboot."
        exit 0
fi
echo "Reboot started..."
reboot
exit 0
