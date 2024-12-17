#!/bin/bash

set -e
clear

# Set some variables
RPI_VERS=4             # Raspberry version (4 or 5)
AMI_VERS=5.7.4         # Amiberry version
USER_N=pi              # Username
USER_PWD=raspberry     # Password

error_exit() {
    echo "Error on line $1. Exiting script."
    exit 1
}
trap 'error_exit $LINENO' ERR

# Step 0: Message Before Start
echo "========================================================"
echo "Amiberry installation!"
echo "To copy kickstarts and software, access the 'amiberry' folder"
echo "from your Windows machine using this address: \\\\$(hostname -I | cut -d' ' -f1)\\amiberry"
echo "Login credentials: Username: ${USER_N} | Password: ${USER_PWD}"
echo "========================================================"
read -p "Press any key to start..." -n1 -s

echo

# Step 1: Update system
echo "Updating system..."
sudo apt update -y > /dev/null 2>&1 || error_exit $LINENO
sudo apt upgrade -y > /dev/null 2>&1 || error_exit $LINENO

# Step 2: Install dependencies
echo "Installing dependencies..."
sudo apt install -y \
  cmake \
  libsdl2-2.0-0 libsdl2-ttf-2.0-0 libsdl2-image-2.0-0 \
  flac mpg123 libmpeg2-4 libserialport0 libportmidi0 \
  mesa-utils mesa-vulkan-drivers \
  libegl-mesa0 raspi-gpio libgl1-mesa-dri libgl1-mesa-glx libgles2-mesa alsa-utils \
  libasound2 libasound2-dev libportaudio2 libasound2-plugins alsa-oss \
  samba samba-common-bin > /dev/null 2>&1 || error_exit $LINENO
sudo apt update -y > /dev/null 2>&1 || error_exit $LINENO
sudo apt install pulseaudio pavucontrol pulseaudio-utils -y > /dev/null 2>&1 || error_exit $LINENO
systemctl --user enable pulseaudio > /dev/null 2>&1 || error_exit $LINENO
systemctl --user start pulseaudio > /dev/null 2>&1 || error_exit $LINENO

# Step 3: Install Amiga Emulator (Amiberry)
echo "Installing Amiberry..."
wget -q https://github.com/BlitterStudio/amiberry/releases/download/v${AMI_VERS}/amiberry-v${AMI_VERS}-debian-bookworm-aarch64-rpi${RPI_VERS}.zip > /dev/null 2>&1 || error_exit $LINENO
unzip -q amiberry-v${AMI_VERS}-debian-bookworm-aarch64-rpi${RPI_VERS}.zip -d ~/amiberry > /dev/null 2>&1 || error_exit $LINENO
chmod +x ~/amiberry/amiberry > /dev/null 2>&1 || error_exit $LINENO
rm amiberry-v${AMI_VERS}-debian-bookworm-aarch64-rpi${RPI_VERS}.zip > /dev/null 2>&1 || error_exit $LINENO

# Download KSs
wget -q https://github.com/RaffaeleV/installAmiberry/raw/refs/heads/main/ks.zip > /dev/null 2>&1 || error_exit $LINENO
unzip -q -o ks.zip -d ~/amiberry/kickstarts > /dev/null 2>&1 || error_exit $LINENO

wget -q https://github.com/RaffaeleV/installAmiberry/raw/refs/heads/main/default.uae > /dev/null 2>&1 || error_exit $LINENO
sudo mv default.uae ~/amiberry/conf/default.uae > /dev/null 2>&1 || error_exit $LINENO

wget -q https://github.com/RaffaeleV/installAmiberry/raw/refs/heads/main/Workbench.v1.3.3.rev.34.34.Extras.adf > /dev/null 2>&1 || error_exit $LINENO
wget -q https://github.com/RaffaeleV/installAmiberry/raw/refs/heads/main/Workbench.v1.3.3.rev.34.34.adf > /dev/null 2>&1 || error_exit $LINENO
sudo mv Workbench.v1.3.3.rev.34.34.Extras.adf ~/amiberry/floppies/ > /dev/null 2>&1 || error_exit $LINENO
sudo mv Workbench.v1.3.3.rev.34.34.adf ~/amiberry/floppies/ > /dev/null 2>&1 || error_exit $LINENO

rm ks.zip > /dev/null 2>&1 || error_exit $LINENO
rm default.uae > /dev/null 2>&1 || error_exit $LINENO
rm *.adf > /dev/null 2>&1 || error_exit $LINENO

# Step 4: Remove boot logo, bootscreen and initial messages
echo "Removing boot logo and boot messages..."
CMDLINE_FILE="/boot/firmware/cmdline.txt"
sudo sed -i 's/$/ logo.nologo quiet/' "$CMDLINE_FILE" > /dev/null 2>&1 || error_exit $LINENO
sudo sed -i '/^# disable_splash=1/ s/^#//' /boot/firmware/config.txt > /dev/null 2>&1 || error_exit $LINENO
sudo sed -i '/^disable_splash=1/ s/.*//' /boot/firmware/config.txt > /dev/null 2>&1 || error_exit $LINENO
echo "disable_splash=1" | sudo tee -a /boot/firmware/config.txt > /dev/null 2>&1 || error_exit $LINENO

# Insert custom splash-screen (Requires Plymouth)
# curl -O https://raw.githubusercontent.com/RaffaeleV/installAmiberry/refs/heads/main/splash.png > /dev/null 2>&1 || error_exit $LINENO
# sudo mv splash.png /usr/share/plymouth/themes/pix/splash.png > /dev/null 2>&1 || error_exit $LINENO
# sudo plymouth-set-default-theme -R pix > /dev/null 2>&1 || error_exit $LINENO


# Step 5: Enable autologin for pi user
echo "Enabling autologin for user ${USER_N}..."
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d || error_exit $LINENO
cat << EOF | sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf > /dev/null 2>&1
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ${USER_N} --noclear %I \$TERM
EOF
sudo systemctl daemon-reload > /dev/null 2>&1 || error_exit $LINENO
sudo systemctl restart getty@tty1 > /dev/null 2>&1 || error_exit $LINENO

# Step 6: Configure SAMBA for Amiberry directory access
echo "Configuring SAMBA for Amiberry directory..."
cat << 'EOF' | sudo tee /etc/samba/smb.conf > /dev/null 2>&1 || error_exit $LINENO
[global]
   workgroup = WORKGROUP
   security = user
   guest account = nobody
   map to guest = bad user

[Amiberry]
   path = /home/pi/amiberry
   browseable = yes
   read only = no
   guest ok = yes
   create mask = 0755
EOF
sudo systemctl restart smbd > /dev/null 2>&1 || error_exit $LINENO
sudo smbpasswd -a ${USER_N} << EOF > /dev/null 2>&1
${USER_PWD}
${USER_PWD}
EOF

# Step 7: Auto-start Amiberry on boot
echo "Configuring Amiberry to start on boot..."
cat << 'EOF' > ~/start_amiberry.sh
#!/bin/bash
cd ~/amiberry && ./amiberry
EOF
chmod +x ~/start_amiberry.sh > /dev/null 2>&1 || error_exit $LINENO
echo "~/start_amiberry.sh" >> ~/.bashrc || error_exit $LINENO

# Step 8: Final Message Before Reboot
echo "========================================================"
echo "Amiberry installation complete!"
echo "========================================================"
read -p "Press any key to reboot..." -n1 -s

# Step 9: Reboot
sudo reboot
