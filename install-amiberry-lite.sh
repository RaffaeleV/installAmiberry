#!/bin/bash

set -e
clear

# Set some variables
RPI_VERS=4             # Raspberry version (4 or 5)
AMI_VERS=5.8.10        # Amiberry Lite version
USER_N=pi              # Username
USER_PWD=raspberry     # Password

error_exit() {
    echo "Error on line $1. Exiting script."
    exit 1
}
trap 'error_exit $LINENO' ERR

# Step 0: Message Before Start
echo "========================================================"
echo "Amiberry-Lite installation!"
echo "To copy stuff, access the 'Amiberry Lite' folder"
echo "from your Windows machine using this address: \\\\$(hostname -I | cut -d' ' -f1)\\Amiberry-Lite"
echo "Login credentials: Username: ${USER_N} | Password: ${USER_PWD}"
echo "========================================================"
read -p "Press any key to start..." -n1 -s

echo

# Step 1: Update system (interactive)
echo "Updating system (interactive)..."
sudo apt update || error_exit $LINENO
sudo apt upgrade || error_exit $LINENO

# Step 2: Install dependencies
echo "Installing dependencies..."
sudo apt install -y \
  cmake \
  libsdl2-2.0-0 libsdl2-ttf-2.0-0 libsdl2-image-2.0-0 \
  flac mpg123 libmpeg2-4 libserialport0 libportmidi0 \
  mesa-utils mesa-vulkan-drivers \
  libegl-mesa0 raspi-gpio libgl1-mesa-dri libgl1-mesa-glx libgles2-mesa alsa-utils \
  libasound2 libasound2-dev libportaudio2 libasound2-plugins alsa-oss \
  samba samba-common-bin || error_exit $LINENO

# Step 3: Install Amiga Emulator (Amiberry-Lite)
echo "Installing Amiberry..."

wget -q https://github.com/BlitterStudio/amiberry-lite/releases/download/v${AMI_VERS}/amiberry-lite-v${AMI_VERS}-debian-bookworm-arm64.zip || error_exit $LINENO

unzip -q amiberry-lite-v${AMI_VERS}-debian-bookworm-arm64.zip || error_exit $LINENO

sudo apt install -y ./amiberry-lite_${AMI_VERS}_arm64.deb || error_exit $LINENO
 
rm amiberry-lite-v${AMI_VERS}-debian-bookworm-arm64.zip || error_exit $LINENO
rm amiberry-lite_${AMI_VERS}_arm64.deb || error_exit $LINENO

# Step 4: Remove boot logo, bootscreen and initial messages
echo "Removing boot logo and boot messages..."
CMDLINE_FILE="/boot/firmware/cmdline.txt"
sudo sed -i 's/$/ logo.nologo quiet/' "$CMDLINE_FILE" || error_exit $LINENO
sudo sed -i '/^# disable_splash=1/ s/^#//' /boot/firmware/config.txt || error_exit $LINENO
sudo sed -i '/^disable_splash=1/ s/.*//' /boot/firmware/config.txt || error_exit $LINENO
echo "disable_splash=1" | sudo tee -a /boot/firmware/config.txt || error_exit $LINENO

# Step 5: Configure SAMBA for Amiberry directory access
echo "Configuring SAMBA for Amiberry directory..."
cat << EOF | sudo tee /etc/samba/smb.conf || error_exit $LINENO
[global]
   workgroup = WORKGROUP
   security = user
   guest account = nobody
   map to guest = bad user

[Amiberry]
   path = /home/${USER_N}/Amiberry-Lite
   browseable = yes
   read only = no
   guest ok = yes
   create mask = 0755
EOF
sudo systemctl restart smbd || error_exit $LINENO
sudo smbpasswd -a ${USER_N} << EOF > /dev/null 2>&1
${USER_PWD}
${USER_PWD}
EOF

# Step 6: Auto-start Amiberry-Lite on boot
echo "Configuring Amiberry-Lite to start on boot..."
cat << 'EOF' > "$HOME/start_amiberry.sh"
#!/bin/bash
amiberry-lite
EOF
chmod +x "$HOME/start_amiberry.sh" || error_exit $LINENO
echo "~/start_amiberry.sh" >> "$HOME/.bashrc" || error_exit $LINENO

# Step 7: Enable autologin for pi user
echo "Enabling autologin for user ${USER_N}..."
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d || error_exit $LINENO
cat << EOF | sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf || error_exit $LINENO
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ${USER_N} --noclear %I \$TERM
EOF
sudo systemctl daemon-reload || error_exit $LINENO
sudo systemctl restart getty@tty1 || error_exit $LINENO

# Step 8: Create a script to download Kickstarts and stuff

echo "========================================================"
echo "Creating a script to download Kickstarts and stuff..."
echo "========================================================"

SCRIPT_PATH="$HOME/sw-download.sh"

cat > "$SCRIPT_PATH" << 'EOF'
#!/bin/bash

echo "========================================================"
echo "Downloading Kickstart and Workbench files..."
echo "========================================================"

wget -q https://github.com/RaffaeleV/installAmiberry/raw/refs/heads/main/ks.zip
unzip -q -o ks.zip -d "$HOME/Amiberry-Lite/roms"
rm ks.zip

wget -q https://github.com/RaffaeleV/installAmiberry/raw/refs/heads/main/default.uae
mv -f default.uae "$HOME/Amiberry-Lite/conf/default.uae"

wget -q https://github.com/RaffaeleV/installAmiberry/raw/refs/heads/main/Workbench.v1.3.3.rev.34.34.Extras.adf
wget -q https://github.com/RaffaeleV/installAmiberry/raw/refs/heads/main/Workbench.v1.3.3.rev.34.34.adf
mv -f Workbench.v1.3.3.rev.34.34.Extras.adf "$HOME/Amiberry-Lite/floppies/"
mv -f Workbench.v1.3.3.rev.34.34.adf "$HOME/Amiberry-Lite/floppies/"

echo "Kickstart and Workbench files downloaded successfully."
EOF

chmod +x "$SCRIPT_PATH"
echo 
echo "========================================================"
echo "Script created in: $SCRIPT_PATH"
echo "========================================================"
echo


# Step 8: Final Message and reboot
echo "========================================================"
echo "Amiberry-Lite installation complete!"
echo "========================================================"
read -p "Press any key to reboot..." -n1 -s


sudo reboot

