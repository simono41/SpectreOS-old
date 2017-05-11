#!/bin/bash
#
set -ex

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

iso_name=simon-os
iso_label="SIMON_OS"
iso_version=$(date +%Y.%m.%d)
work_dir=work
out_dir=out
install_dir=arch

arch=$(uname -m)

function minimalinstallation() {
  read -p "Wollen sie eine volle Installation durchführen?: [Y/n] " minimal
  if [ "$minimal" != "n" ]
  then
    echo "Basis"
    pacstrap -c -d -G -i -M ${work_dir}/${arch}/airootfs base base-devel syslinux efibootmgr efitools \
    grub intel-ucode os-prober btrfs-progs dosfstools arch-install-scripts xorriso \
    cdrtools squashfs-tools wget dosfstools btrfs-progs gdisk \
    \
    xorg-server xorg-xinit xorg-drivers acpid ntp dbus avahi cups cronie \
    xf86-input-synaptics ttf-dejavu xscreensaver openssh git netsurf mplayer dialog \
    xorg-twm xorg-xclock xterm alsa-utils pulseaudio pulseaudio-alsa \
    \
    firefox firefox-i18n-de flashplugin vlc brasero libreoffice-fresh libreoffice-fresh-de \
    inkscape audacity atom mumble gimp hplip exfat-utils ntfs-3g \
    kdenlive freeciv minetest teeworlds qemu blender simplescreenrecorder \
    obs-studio ardour hydrogen python python-pip jdk8-openjdk \
    \
    nvidia nvidia-libgl nvidia-settings lib32-nvidia-libgl steam wine wine_gecko wine-mono
  fi
}

read -p "Soll das System neu aufgebaut werden?: [Y/n] " system
if [ "$system" != "n" ]
then
  echo "Scripte werden heruntergeladen!"

  mkdir -p ${work_dir}/${arch}/airootfs

  read -p "Sollen die base Packete neu aufgebaut werden? [Y/n] " pacstrap
  if [ "$pacstrap" != "n" ]
  then
    pacman -Sy arch-install-scripts xorriso cdrtools squashfs-tools wget dosfstools btrfs-progs gdisk qemu
    minimalinstallation
    read -p "Soll ein root passwort festgelegt werden? [Y/n] " root
    if [ "$root" != "n" ]
    then
      arch-chroot ${work_dir}/${arch}/airootfs passwd root
    fi
  fi

  arch-chroot ${work_dir}/${arch}/airootfs pacman-key --init
  arch-chroot ${work_dir}/${arch}/airootfs pacman-key --populate archlinux

  cp install/archiso ${work_dir}/${arch}/airootfs/usr/lib/initcpio/install/archiso
  cp hooks/archiso ${work_dir}/${arch}/airootfs/usr/lib/initcpio/hooks/archiso

  echo "MODULES=\"i915\"" > ${work_dir}/${arch}/airootfs/etc/mkinitcpio.conf
  echo "HOOKS=\"base udev block filesystems keyboard archiso\"" >> ${work_dir}/${arch}/airootfs/etc/mkinitcpio.conf
  echo "COMPRESSION=\"gzip\"" >> ${work_dir}/${arch}/airootfs/etc/mkinitcpio.conf

  echo ${iso_name} > ${work_dir}/${arch}/airootfs/etc/hostname

  cp make_mksquashfs.sh ${work_dir}/${arch}/airootfs/usr/bin/make_mksquashfs
  chmod +x ${work_dir}/${arch}/airootfs/usr/bin/make_mksquashfs

  cp write_cowspace ${work_dir}/${arch}/airootfs/usr/bin/write_cowspace
  chmod +x ${work_dir}/${arch}/airootfs/usr/bin/write_cowspace

  cp pacman.conf ${work_dir}/${arch}/airootfs/etc/

  cp arch-graphical-install ${work_dir}/${arch}/airootfs/usr/bin/
  chmod +x ${work_dir}/${arch}/airootfs/usr/bin/arch-graphical-install

  cp arch-install ${work_dir}/${arch}/airootfs/usr/bin/
  chmod +x ${work_dir}/${arch}/airootfs/usr/bin/arch-install

  cp arch-install-non_root ${work_dir}/${arch}/airootfs/usr/bin/
  chmod +x ${work_dir}/${arch}/airootfs/usr/bin/arch-install-non_root

  mkdir -p ${work_dir}/${arch}/airootfs/usr/share/applications/
  cp arch-install.desktop ${work_dir}/${arch}/airootfs/usr/share/applications/
  chmod +x ${work_dir}/${arch}/airootfs/usr/share/applications/arch-install.desktop

  mkdir -p ${work_dir}/${arch}/airootfs/usr/share/pixmaps/
  cp install.png ${work_dir}/${arch}/airootfs/usr/share/pixmaps/

  cp mirrorlist ${work_dir}/${arch}/airootfs/etc/pacman.d/mirrorlist

  arch-chroot ${work_dir}/${arch}/airootfs pacman -Syu

  arch-chroot ${work_dir}/${arch}/airootfs mkinitcpio -p linux

else
  echo "Wird nicht neu aufgebaut!!!"
  echo "Es muss aber vorhanden sein für ein reibenloser Ablauf!!!"
fi
echo "Jetzt können sie ihr Betriebssystem nach ihren Belieben anpassen:D"
read -p "Wollen sie ihr Betriebssystem nach Belieben anpassen? [Y/n] " packete
if [ "$packete" != "n" ]
then
  arch-chroot ${work_dir}/${arch}/airootfs /usr/bin/arch-graphical-install n
fi

# System-image

read -p "Soll das System-Image neu aufgebaut werden?: [Y/n] " image
mkdir -p ${work_dir}/iso/isolinux
mkdir -p ${work_dir}/iso/${install_dir}/${arch}
mkdir -p ${work_dir}/iso/${install_dir}/boot/${arch}
mkdir -p ${work_dir}/iso/${install_dir}/boot/syslinux
mkdir -p ${work_dir}/iso/EFI/archiso
mkdir -p ${work_dir}/iso/EFI/boot
mkdir -p ${work_dir}/iso/loader/entries

if [ "$image" != "n" ]
then
  arch-chroot ${work_dir}/${arch}/airootfs/ pacman -Q > ${work_dir}/${arch}/airootfs/pkglist.txt
  cp ${work_dir}/${arch}/airootfs/pkglist.txt ${work_dir}/iso/${install_dir}/${arch}/

  arch-chroot ${work_dir}/${arch}/airootfs pacman -Sc
  arch-chroot ${work_dir}/${arch}/airootfs pacman -Scc

  if [ -f ${work_dir}/iso/${install_dir}/${arch}/airootfs.sfs ]
  then
    rm ${work_dir}/iso/${install_dir}/${arch}/airootfs.sfs
  else
    echo "airootfs.sfs nicht vorhanden!"
  fi

  mksquashfs ${work_dir}/${arch}/airootfs ${work_dir}/iso/${install_dir}/${arch}/airootfs.sfs -comp gzip

  md5sum ${work_dir}/iso/${install_dir}/${arch}/airootfs.sfs > ${work_dir}/iso/${install_dir}/${arch}/airootfs.md5

else
  echo "Image wird nicht neu aufgebaut!!!"
fi

# BIOS

read -p "Soll das BIOS installiert werden?: [Y/n] " bios
if [ "$bios" != "n" ]
then
  cp -R ${work_dir}/${arch}/airootfs/usr/lib/syslinux/bios/* ${work_dir}/iso/${install_dir}/boot/syslinux/
  cp ${work_dir}/${arch}/airootfs/boot/initramfs-linux.img ${work_dir}/iso/${install_dir}/boot/${arch}/archiso.img
  cp ${work_dir}/${arch}/airootfs/boot/vmlinuz-linux ${work_dir}/iso/${install_dir}/boot/${arch}/vmlinuz
  cp ${work_dir}/${arch}/airootfs/usr/lib/syslinux/bios/isolinux.bin ${work_dir}/iso/isolinux/
  cp ${work_dir}/${arch}/airootfs/usr/lib/syslinux/bios/isohdpfx.bin ${work_dir}/iso/isolinux/
  cp ${work_dir}/${arch}/airootfs/usr/lib/syslinux/bios/ldlinux.c32 ${work_dir}/iso/isolinux/

  echo "DEFAULT menu.c32" > ${work_dir}/iso/${install_dir}/boot/syslinux/syslinux.cfg
  echo "PROMPT 0" >> ${work_dir}/iso/${install_dir}/boot/syslinux/syslinux.cfg
  echo "MENU TITLE ${iso_label}" >> ${work_dir}/iso/${install_dir}/boot/syslinux/syslinux.cfg
  echo "TIMEOUT 300" >> ${work_dir}/iso/${install_dir}/boot/syslinux/syslinux.cfg
  echo "" >> ${work_dir}/iso/${install_dir}/boot/syslinux/syslinux.cfg

  sed "s|%ISO_LABEL%|${iso_label}|g;
  s|%arch%|${arch}|g;
  s|%INSTALL_DIR%|${install_dir}|g" syslinux.cfg >> ${work_dir}/iso/${install_dir}/boot/syslinux/syslinux.cfg

  echo "" >> ${work_dir}/iso/${install_dir}/boot/syslinux/syslinux.cfg
  echo "ONTIMEOUT arch" >> ${work_dir}/iso/${install_dir}/boot/syslinux/syslinux.cfg

  echo "DEFAULT loadconfig" > ${work_dir}/iso/isolinux/isolinux.cfg
  echo "" >> ${work_dir}/iso/isolinux/isolinux.cfg
  echo "LABEL loadconfig" >> ${work_dir}/iso/isolinux/isolinux.cfg
  echo "  CONFIG /arch/boot/syslinux/syslinux.cfg" >> ${work_dir}/iso/isolinux/isolinux.cfg
  echo "  APPEND /arch/boot/syslinux/" >> ${work_dir}/iso/isolinux/isolinux.cfg

fi

# EFI

read -p "Soll das EFI installiert werden?: [Y/n] " efi
if [ "$efi" != "n" ]
then

  mkdir -p ${work_dir}/efiboot

  if [ -f ${work_dir}/iso/EFI/archiso/efiboot.img ]
  then
    rm ${work_dir}/iso/EFI/archiso/efiboot.img
  else
    echo "efiboot.img nicht vorhanden!"
  fi
  truncate -s 128M ${work_dir}/iso/EFI/archiso/efiboot.img
  mkfs.fat -n ${iso_label}_EFI ${work_dir}/iso/EFI/archiso/efiboot.img

  mount -t vfat -o loop ${work_dir}/iso/EFI/archiso/efiboot.img ${work_dir}/efiboot

  mkdir -p ${work_dir}/efiboot/EFI/boot
  mkdir -p ${work_dir}/efiboot/EFI/archiso
  mkdir -p ${work_dir}/efiboot/loader/entries

  cp ${work_dir}/iso/${install_dir}/boot/${arch}/vmlinuz ${work_dir}/efiboot/EFI/archiso/vmlinuz.efi
  cp ${work_dir}/iso/${install_dir}/boot/${arch}/archiso.img ${work_dir}/efiboot/EFI/archiso/archiso.img

  cp ${work_dir}/${arch}/airootfs/boot/intel-ucode.img ${work_dir}/iso/${install_dir}/boot/intel_ucode.img
  cp ${work_dir}/iso/${install_dir}/boot/intel_ucode.img ${work_dir}/efiboot/EFI/archiso/intel_ucode.img

  cp ${work_dir}/${arch}/airootfs/usr/share/efitools/efi/PreLoader.efi ${work_dir}/efiboot/EFI/boot/bootx64.efi

  cp ${work_dir}/${arch}/airootfs/usr/share/efitools/efi/HashTool.efi ${work_dir}/efiboot/EFI/boot/

  cp ${work_dir}/${arch}/airootfs/usr/lib/systemd/boot/efi/systemd-bootx64.efi ${work_dir}/efiboot/EFI/boot/loader.efi

  cp uefi-shell-v2-${arch}.conf ${work_dir}/efiboot/loader/entries/
  cp uefi-shell-v1-${arch}.conf ${work_dir}/efiboot/loader/entries/
  cp uefi-shell-v1-${arch}.conf ${work_dir}/iso/loader/entries/uefi-shell-v1-${arch}.conf
  cp uefi-shell-v2-${arch}.conf ${work_dir}/iso/loader/entries/uefi-shell-v2-${arch}.conf

  # EFI Shell 2.0 for UEFI 2.3+
  if [ -f ${work_dir}/iso/EFI/shellx64_v2.efi ]
  then
    echo "Bereits Vorhanden!"
    sleep 1
  else
    curl -o ${work_dir}/iso/EFI/shellx64_v2.efi https://raw.githubusercontent.com/tianocore/edk2/master/ShellBinPkg/UefiShell/X64/Shell.efi
  fi
  # EFI Shell 1.0 for non UEFI 2.3+
  if [ -f ${work_dir}/iso/EFI/shellx64_v1.efi ]
  then
    echo "Bereits Vorhanden!"
    sleep 1
  else
    curl -o ${work_dir}/iso/EFI/shellx64_v1.efi https://raw.githubusercontent.com/tianocore/edk2/master/EdkShellBinPkg/FullShell/X64/Shell_Full.efi
  fi

  cp ${work_dir}/iso/EFI/shellx64_v2.efi ${work_dir}/efiboot/EFI/
  cp ${work_dir}/iso/EFI/shellx64_v1.efi ${work_dir}/efiboot/EFI/

  cp ${work_dir}/${arch}/airootfs/usr/share/efitools/efi/PreLoader.efi ${work_dir}/iso/EFI/boot/bootx64.efi
  cp ${work_dir}/${arch}/airootfs/usr/share/efitools/efi/HashTool.efi ${work_dir}/iso/EFI/boot/

  cp ${work_dir}/${arch}/airootfs/usr/lib/systemd/boot/efi/systemd-bootx64.efi ${work_dir}/iso/EFI/boot/loader.efi

  echo "timeout 3" > ${work_dir}/iso/loader/loader.conf
  echo "default archiso-${arch}-usb-default" >> ${work_dir}/iso/loader/loader.conf
  echo "timeout 3" > ${work_dir}/efiboot/loader/loader.conf
  echo "default archiso-${arch}-cd-default" >> ${work_dir}/efiboot/loader/loader.conf

  sed "s|%ISO_LABEL%|${iso_label}|g;
  s|%arch%|${arch}|g;
  s|%INSTALL_DIR%|${install_dir}|g" releng/archiso-${arch}-usb-default.conf >> ${work_dir}/iso/loader/entries/archiso-${arch}-usb-default.conf

  ###

  sed "s|%ISO_LABEL%|${iso_label}|g;
  s|%arch%|${arch}|g;
  s|%INSTALL_DIR%|${install_dir}|g" releng/archiso-${arch}-cd-default.conf >> ${work_dir}/efiboot/loader/entries/archiso-${arch}-cd-default.conf

  read -p "efiboot jetzt trennen? [Y/n] "
  if [ "$trennen" != "n" ]
  then
    umount -d ${work_dir}/efiboot
  fi
fi

read -p "Soll das Image jetzt gemacht werden? [Y/n] " image
if [ "$image" != "n" ]
then

  imagename=arch-${iso_name}-$(date "+%y.%m.%d")-${arch}.iso

  read -p "Soll das Image jetzt gemacht werden? [Y/n] " run
  if [ "$run" != "n" ]
  then
    if [ -f ${out_dir}/${imagename} ]
    then
      rm ${out_dir}/${imagename}
    fi
    mkdir -p ${out_dir}
    xorriso -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "${iso_label}" \
    -eltorito-boot isolinux/isolinux.bin \
    -eltorito\-catalog isolinux/boot.cat \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    -isohybrid-mbr $(pwd)/${work_dir}/iso/isolinux/isohdpfx.bin \
    -eltorito-alt-boot \
    -e EFI/archiso/efiboot.img \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    -output ${out_dir}/${imagename} ${work_dir}/iso/
  fi


  read -p "Soll das Image jetzt ausgeführt werden? [Y/n] " run
  if [ "$run" != "n" ]
  then
    if [ -f arch.img ]
    then
      echo "arch.img vorhanden!"
    else
      echo "arch.img nicht vorhanden!"
      qemu-img create -f qcow2 arch.img 64G
    fi
    qemu-system-${arch} -enable-kvm -cdrom out/${imagename} -hda arch.img -boot d -m 8092
  fi


  read -p "Soll das Image jetzt geschrieben werden? [Y/n] " write
  if [ "$write" != "n" ]
  then
    fdisk -l
    read -p "Wo das Image jetzt geschrieben werden? [sda/sdb/sdc/sdd] " device

    #
    if cat /proc/mounts | grep /dev/${device}1 > /dev/null; then
      echo "gemountet"
      umount /dev/${device}1
    else
      echo "nicht gemountet"
    fi
    #
    if cat /proc/mounts | grep /dev/${device}2 > /dev/null; then
      echo "gemountet"
      umount /dev/${device}2
    else
      echo "nicht gemountet"
    fi
    #
    if cat /proc/mounts | grep /dev/${device}3 > /dev/null; then
      echo "gemountet"
      umount /dev/${device}3
    else
      echo "nicht gemountet"
    fi
    #

    dd bs=4M if=out/${imagename} of=/dev/${device} status=progress && sync
  fi


  read -p "Soll das Image jetzt eine Partition zum Offline-Schreiben erhalten? [Y/n] " btrfs
  if [ "$btrfs" != "n" ]
  then
    if [ "$device" == "" ]
    then
      fdisk -l
      read -p "Wo das Image jetzt geschrieben werden? [sda/sdb/sdc/sdd] " device
    fi

fdisk -W always /dev/${device} <<EOT
p
n




p
w
y
EOT

    echo "mit j bestätigen"
    mkfs.ext4 -L cow_device /dev/${device}3

    sync

  fi
fi
echo "Fertig!!!"
