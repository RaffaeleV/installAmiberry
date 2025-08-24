#!/bin/bash

set -e
clear

# Variables
RPI_VERS=4             # Raspberry version (4 or 5)
AMI_VERS=5.8.10        # Amiberry Lite version
USER_N=pi              # Username
USER_PWD=raspberry     # Password

# Let's Start!
echo "========================================================"
echo "Amiberry-Lite installation!"
echo "Access the 'Amiberry Lite' folder from Windows:"
echo "\\\\$(hostname -I | cut -d' ' -f1)\\Amiberry-Lite"
echo "Login credentials -> Username: ${USER_N} | Password: ${USER_PWD}"
echo "========================================================"
read -p "Press any key to start..." -n1 -s
echo

# Step 1: Update system (interactive upgrade)
echo "[*] Updating package list..."
sudo apt update -qq

# echo "[*] Starting interactive upgrade (confirm manually Y/N)..."
# sudo apt upgrade -y
# echo "[*] System upgrade completed."

# Step 2: Install dependencies
echo "[*] Installing dependencies..."
sudo apt install -y -qq \
  mesa-utils mesa-vulkan-drivers \
  samba samba-common-bin

# Step 3: Install Amiberry
echo "[*] Installing Amiberry..."
wget -q https://github.com/BlitterStudio/amiberry-lite/releases/download/v${AMI_VERS}/amiberry-lite-v${AMI_VERS}-debian-bookworm-arm64.zip
unzip -q amiberry-lite-v${AMI_VERS}-debian-bookworm-arm64.zip
sudo apt install -y -qq ./amiberry-lite_${AMI_VERS}_arm64.deb
rm amiberry-lite-v${AMI_VERS}-debian-bookworm-arm64.zip
rm amiberry-lite_${AMI_VERS}_arm64.deb

# Step 4: Remove boot logo and boot messages
echo "[*] Configuring boot options..."
CMDLINE_FILE="/boot/firmware/cmdline.txt"
sudo sed -i 's/$/ logo.nologo quiet/' "$CMDLINE_FILE"
sudo sed -i '/^# disable_splash=1/ s/^#//' /boot/firmware/config.txt
sudo sed -i '/^disable_splash=1/ s/.*//' /boot/firmware/config.txt
echo "disable_splash=1" | sudo tee -a /boot/firmware/config.txt > /dev/null

# Step 5: Configure SAMBA
echo "[*] Configuring Samba..."
cat << EOF | sudo tee /etc/samba/smb.conf > /dev/null
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

sudo systemctl restart smbd
sudo smbpasswd -a ${USER_N} << EOF > /dev/null 2>&1
${USER_PWD}
${USER_PWD}
EOF

# Step 6: Auto-start Amiberry
echo "[*] Enabling autostart..."
cat << 'EOF' > "/home/${USER_N}/start_amiberry.sh"
#!/bin/bash
amiberry-lite
EOF
chmod +x "/home/${USER_N}/start_amiberry.sh"
echo "/home/${USER_N}/start_amiberry.sh" >> "/home/${USER_N}/.bashrc"

# Step 7: Enable autologin
echo "[*] Configuring autologin..."
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
cat << EOF | sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf > /dev/null
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ${USER_N} --noclear %I \$TERM
EOF
sudo systemctl daemon-reload
sudo systemctl restart getty@tty1

# Step 8: Download Kickstarts
echo "[*] Downloading Kickstarts & Stuff..."

# Assicurati che le directory esistano
mkdir -p "/home/${USER_N}/Amiberry-Lite/roms"
mkdir -p "/home/${USER_N}/Amiberry-Lite/conf"
mkdir -p "/home/${USER_N}/Amiberry-Lite/floppies"

# Scarica e installa Kickstart
wget -q https://github.com/RaffaeleV/installAmiberry/raw/refs/heads/main/ks.zip
unzip -q -o ks.zip -d "/home/${USER_N}/Amiberry-Lite/roms"
rm ks.zip

# Scarica e copia la configurazione di default
wget -q https://github.com/RaffaeleV/installAmiberry/raw/refs/heads/main/default.uae
mv -f default.uae "/home/${USER_N}/Amiberry-Lite/conf/default.uae"

# Scarica e copia i Workbench
wget -q https://github.com/RaffaeleV/installAmiberry/raw/refs/heads/main/Workbench.v1.3.3.rev.34.34.Extras.adf
wget -q https://github.com/RaffaeleV/installAmiberry/raw/refs/heads/main/Workbench.v1.3.3.rev.34.34.adf
mv -f Workbench.v1.3.3.rev.34.34.Extras.adf "/home/${USER_N}/Amiberry-Lite/floppies/"
mv -f Workbench.v1.3.3.rev.34.34.adf "/home/${USER_N}/Amiberry-Lite/floppies/"


# Final Message
echo
echo "========================================================"
echo "Amiberry-Lite installation complete!"
echo "========================================================"
read -p "Press any key to reboot..." -n1 -s
echo
sudo reboot

