#!/bin/bash
if [ "$EUID" = 0 ]; then
  echo "Please don't run this script as root!"
  exit
fi
basedistroversion="$(date +%Y.%m.%d)"
distroversion=""
distrocodename=""
echo "Welcome to the generation script for TriggerLinux"
echo "==========="
if [ "$1" != "" ]; then
  distroversion="$1"
  distrocodename="$2"
else
  distroversion="${basedistroversion:2:5}"
  distrocodename="monthly-stable-$(uname -m)"
fi

cleanup_failure() {
  if [ -d workingdir ]; then
    cat config/pacman.conf | sudo tee /etc/pacman.conf > /dev/null
    sudo rm -rf {workingdir,customrepo}
  fi
}

createdir() {
  yes | sudo pacman -Scc #prevent AUR package signature errors
  sudo mkdir workingdir
  sudo cp -r config/* workingdir
  sudo mkdir -p workingdir/airootfs/usr/share/plymouth/themes/
  sudo mkdir -p workingdir/airootfs/usr/share/applications
}
copypackages() {
  sudo cp -f ./packages ./workingdir/packages.x86_64
}
copyskel() {
  sudo mkdir -p ./workingdir/airootfs/etc/fonts
  if [ ! -d skeldata/Desktop ]; then
    mkdir -p skeldata/{Desktop,Documents,Downloads,Pictures,Videos}
  fi
  sudo cp -r skeldata ./workingdir/airootfs/etc/skel
  sudo bash -c 'echo -e "PROMPT=\"%n@%m:%~%# \"" >> ./workingdir/airootfs/etc/skel/.zshrc'
  sudo cp fonts.conf workingdir/airootfs/etc/skel/.config/fontconfig
  sudo cp fonts.conf workingdir/airootfs/etc/fonts/local.conf
  sudo cp -f ./customize_airootfs.sh ./workingdir/airootfs/root/customize_airootfs.sh
  if [ ! -d workingdir/airootfs/usr/lib/systemd/system ]; then
    sudo mkdir -p workingdir/airootfs/usr/lib/systemd/system
  fi
  sudo cp autoupdate.{service,timer} ./workingdir/airootfs/usr/lib/systemd/system/
  sudo mkdir ./workingdir/airootfs/usr/bin
}
createlsbrelease() {
  echo "lsb-release" | sudo tee --append ./workingdir/packages.x86_64 > /dev/null
  echo "DISTRIB_ID=TriggerLinux" | sudo tee ./workingdir/airootfs/etc/lsb-release > /dev/null
  echo 'DISTRIB_DESCRIPTION="Break the grip of censorship"' | sudo tee --append ./workingdir/airootfs/etc/lsb-release > /dev/null
  echo "DISTRIB_RELEASE=$distroversion" | sudo tee --append ./workingdir/airootfs/etc/lsb-release > /dev/null
  echo "DISTRIB_CODENAME=$distrocodename" | sudo tee --append ./workingdir/airootfs/etc/lsb-release > /dev/null
}

buildtheiso() {
  sudo rm -rf ./workingdir/airootfs/etc/systemd/system/getty*
  cd workingdir
  sudo ./build.sh -v || exit 1
  cd ../
}
cleanup() {
  echo "Cleaning up..."
  cat ./config/pacman.conf | sudo tee /etc/pacman.conf > /dev/null
  sudo pacman --noconfirm -Syyuu
  rm ./pacman.backup
  sudo rm -rf /var/cache/pacman/pkg/triggerlinux-calamares*
  sudo rm -rf /var/cache/pacman/pkg/qt5-styleplugins-git*
  finalfiles=""
  while IFS='' read -r currentpkg || [[ -n "$currentpkg" ]]; do
  finalfiles="$finalfiles /var/cache/pacman/pkg/$(cut -d'.' -f1 <<<"${currentpkg##*/}")*"
  done < "aurpackages"
  echo "Deleting files $finalfiles..."
  sudo rm -rf $finalfiles
  rm -rf ./customrepo
  echo "Saving iso file..."
  cp ./workingdir/out/*.iso ./triggerlinux-$distroversion-$(uname -m).iso
  echo "Exporting iso file to hosting node"
  cat ./triggerlinux-$distroversion-$(uname -m).iso | sudo tee /opt/lampp/htdocs/triggerlinux-latest-$(uname -m).iso > /dev/null
  echo "Removing archiso directory..."
  sudo rm -rf workingdir
}
cleanup_failure
createdir
copypackages
copyskel
createlsbrelease
buildtheiso
cleanup
