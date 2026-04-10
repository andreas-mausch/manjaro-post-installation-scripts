Unified Kernel Image (UKI)

# Motivation

My goals are:

- Strip an unused layer (GRUB), which needs configuration and takes away some boot seconds.
  Also, it is soo old, can't handle HiDPI well and I just don't need it.
- Use the beautiful password input in plymouth for LUKS, instead of the ugly GRUB
- UKI allows Secure Boot with Linux

# Steps

Assuming you use LUKS to encrypt your disk.

- Find disk UUID in `/etc/crypttab`.
- `sudo cp ./cmdline /etc/kernel/`
- replace the UUID
- In case you use btrfs as your file system:
  Add `rootflags=subvol=@` at the beginning.
- Edit `/etc/mkinitcpio.d/linux*.preset`, uncomment the `default_uki=` line and
  set the path to `/boot/efi/EFI/Manjaro/manjaro.efi`
- Edit `/etc/crypttab` and replace the reference to `/crypto_keyfile.bin` by `none`.
- Add a new UEFI boot entry via:
  `sudo efibootmgr --create --disk /dev/nvme0n1 --part 1 --loader '\EFI\Manjaro\manjaro.efi' --label 'Manjaro UKI' --unicode`
  Make sure you use the right disk path and partition number.
- In case you have screen flickering after plymouth, you might try to add `fbcon=nodefer` to your cmdline.
