#!/bin/bash

set -e -u

sed -i 's/#\(en_US\.UTF-8\)/\1/' /etc/locale.gen
locale-gen

ln -sf /usr/share/zoneinfo/UTC /etc/localtime

usermod -s /usr/bin/zsh root
cp -aT /etc/skel/ /root/
cp /root/calamares.desktop /root/Desktop/

#make certain that the plasma configuration files are copied properly
cat /etc/skel/.config/plasma-org.kde.plasma.desktop-appletsrc > /root/.config/plasma-org.kde.plasma.desktop-appletsrc
cat /etc/skel/.config/plasmashellrc > /root/.config/plasmashellrc

#root's home cannot be visible to anyone but root
chmod 700 /root

if [ -d /etc/ssh ]; then
  sed -i 's/#\(PermitRootLogin \).\+/\1yes/' /etc/ssh/sshd_config
fi

#Change archiso hostname to resolve branding issues
echo "triggerbox" > /etc/hostname

#Only uncomment American servers (for now)
sed -i "/United States$/{n;s/#Server/Server/;}" /etc/pacman.d/mirrorlist

#work around lack of keys on live media due to installer bug mentioned in line 87
sed -i "s/SigLevel.*/SigLevel = Optional TrustAll/" /etc/pacman.d/mirrorlist

sed -i 's/#\(Storage=\)auto/\1volatile/' /etc/systemd/journald.conf

sed -i 's/#\(HandleSuspendKey=\)suspend/\1ignore/' /etc/systemd/logind.conf
sed -i 's/#\(HandleHibernateKey=\)hibernate/\1ignore/' /etc/systemd/logind.conf
sed -i 's/#\(HandleLidSwitch=\)suspend/\1ignore/' /etc/systemd/logind.conf

#Enable core services
systemctl enable pacman-init.service choose-mirror.service NetworkManager.service

#Boot to GUI by default
systemctl set-default graphical.target

#Make sure plymouth is instantly added to mkinitcpio hooks and Intel graphics are working correctly
sed -i "s/.*MODULES.*/MODULES=(intel_agp i915)/" /etc/mkinitcpio.conf
sed -i "s/.*HOOKS.*/HOOKS=(base udev plymouth autodetect modconf block filesystems keyboard fsck)/" /etc/mkinitcpio.conf

#Create temporary user for installation of AUR packages using AUR helper to avoid dependency problems
if ! id tempuser; then
  useradd -k /etc/skel -md /home/tempuser -g users -G "adm,audio,floppy,log,network,rfkill,scanner,storage,optical,power,wheel" -c "Live System User" tempuser
else
  userdel -rf tempuser
  useradd -k /etc/skel -md /home/tempuser -g users -G "adm,audio,floppy,log,network,rfkill,scanner,storage,optical,power,wheel" -c "Live System User" tempuser
fi
echo "tempuser ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers

#Remove custom repo
sed -i "$ d" /etc/pacman.conf
sed -i "$ d" /etc/pacman.conf
sed -i "$ d" /etc/pacman.conf

#required for yay to work inside the chroot
pacman-key --init
pacman-key --populate archlinux

#work around package signature bug
su tempuser -c "gpg --recv-keys FE0784117FBCE11D F5675605C74E02CF EAAF29B42A678C20 EC94D18F7F05997E"
su tempuser -c "gpg --recv-keys EC94D18F7F05997E"

systemctl enable autoupdate.service autoupdate.timer

#Autologin to root account upon live image boot
echo -e "[Users]\nHideUsers=\nMaximumUid=65000\nMinimumUid=0\nRememberLastUser=true" > /etc/sddm.conf
mkdir /etc/sddm.conf.d
echo -e "[Autologin]\nUser=root\nSession=plasma.desktop" > /etc/sddm.conf.d/autologin.conf

#Configure grub to enable splash boot by default
sed -i "s/.*GRUB_TIMEOUT.*/GRUB_TIMEOUT=0/" /etc/default/grub
sed -i "s/.*GRUB_CMDLINE_LINUX_DEFAULT.*/GRUB_CMDLINE_LINUX_DEFAULT=\"quiet splash loglevel=0 rd.udev.log-priority=3 vt.global_cursor_default=0 sysrq_always_enabled=1\"/" /etc/default/grub

#retarget logo.png symlink before changing theme to work around failure of splash screen to appear
unlink /usr/share/plymouth/themes/triggerbox-breeze/logo.png
ln -s /usr/share/plymouth/themes/triggerbox-breeze/logo_full_blue.png /usr/share/plymouth/themes/triggerbox-breeze/logo.png

#self-explanatory
plymouth-set-default-theme -R triggerbox-breeze

#Delete pacman-key directory to work around bug in which calamares tries to create directory that already exists
rm -rf /etc/pacman.d/gnupg

#Delete temporary user
userdel -rf tempuser

#Create desktop entry for Gab
wget -O /usr/share/icons/breeze/apps/48/gab.svg https://upload.wikimedia.org/wikipedia/commons/6/67/Gab_Logo.svg
echo -e "[Desktop Entry]" >> /usr/share/applications/gab.desktop
echo -e "Icon=gab.svg" >> /usr/share/applications/gab.desktop
echo -e "Name=Gab" >> /usr/share/applications/gab.desktop
echo -e "Type=Link" >> /usr/share/applications/gab.desktop
echo -e "URL[\$e]=https://gab.ai/" >> /usr/share/applications/gab.desktop

#Add Gab by default to pinned apps
sed -i "45s/$/,gab.desktop/" /root/.config/plasma-org.kde.plasma.desktop-appletsrc
sed -i "45s/$/,gab.desktop/" /etc/skel/.config/plasma-org.kde.plasma.desktop-appletsrc
