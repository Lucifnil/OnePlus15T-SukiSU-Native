### AnyKernel3 Ramdisk Mod Script
## OnePlus 15T official-source SukiSU Built-in + SUSFS package.

properties() { '
kernel.string=OnePlus 15T Official 6.12.38 SukiSU Built-in SUSFS
do.devicecheck=0
do.modules=0
do.systemless=0
do.cleanup=1
do.cleanuponabort=0
device.name1=
device.name2=
device.name3=
device.name4=
device.name5=
supported.versions=16
supported.patchlevels=
supported.vendorpatchlevels=
'; }

BLOCK=boot
IS_SLOT_DEVICE=auto
RAMDISK_COMPRESSION=auto
PATCH_VBMETA_FLAG=auto
NO_MAGISK_CHECK=1

. tools/ak3-core.sh

ui_print "OnePlus 15T (PLZ110) / Android 16 only"
ui_print "Official OnePlus 6.12.38 + SukiSU Ultra v4.1.3"
ui_print "BUILT-IN ROOT | SUSFS v2.1.0 | NO KPM"

split_boot
if [ -f split_img/ramdisk.cpio ]; then
  unpack_ramdisk
  write_boot
else
  flash_boot
fi
