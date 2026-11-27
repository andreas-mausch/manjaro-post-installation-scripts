{
  config,
  lib,
  pkgs,
  ...
}:
let
  builder = pkgs.writeShellApplication {
    name = "prepare-system-uki";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.util-linux
    ];
    text = ''
      system=$(readlink -e "$1")
      esp=$2
      findmnt --mountpoint "$esp" >/dev/null
      spec="$system/boot.json"
      jq -e --arg system "$system" '
        .["org.nixos.bootspec.v1"] |
        .toplevel == $system and .init == ($system + "/init") and
        (.kernel | type == "string") and (.initrd | type == "string") and
        (.kernelParams | type == "array")
      ' "$spec" >/dev/null
      kernel=$(jq -r '.["org.nixos.bootspec.v1"].kernel' "$spec")
      initrd=$(jq -r '.["org.nixos.bootspec.v1"].initrd' "$spec")
      cmdline=$(jq -r '.["org.nixos.bootspec.v1"] | (["init=" + .init] + .kernelParams) | join(" ")' "$spec")
      directory="$esp/EFI/my-os-setup"
      mkdir -p "$directory"
      # Serialize preparation; never touch systemd-boot's own EFI files.
      exec 9>"$directory/.prepare.lock"
      flock 9
      output="$directory/$(basename "$system").efi"
      if [ ! -f "$output" ]; then
        temporary=$(mktemp "$directory/.uki-XXXXXX")
        trap 'rm -f "$temporary"' EXIT
        ${pkgs.systemdUkify}/lib/systemd/ukify build \
          --linux="$kernel" --initrd="$initrd" --cmdline="$cmdline" \
          --os-release="@$system/etc/os-release" \
          --stub=${config.systemd.package}/lib/systemd/boot/efi/linux${pkgs.stdenv.hostPlatform.efiArch}.efi.stub \
          --output="$temporary"
        chmod 0644 "$temporary"
        sync -f "$temporary"
        mv "$temporary" "$output"
        sync -f "$directory"
        trap - EXIT
      fi
      echo "Prepared direct-boot UKI: $output"
    '';
  };
in
{
  config = {
    # Temporary integration: keep systemd-boot as the default while validating
    # direct boot. Registration is idempotent and appends to BootOrder so that
    # firmware menus can discover the UKI without changing the existing default.
    boot.loader.systemd-boot.extraInstallCommands = lib.mkAfter ''
      system=$(${pkgs.coreutils}/bin/readlink -e "$1")
      ${lib.getExe builder} "$system" ${lib.escapeShellArg config.boot.loader.efi.efiSysMountPoint}
      image=${lib.escapeShellArg config.boot.loader.efi.efiSysMountPoint}/EFI/my-os-setup/"$(${pkgs.coreutils}/bin/basename "$system")".efi
      PATH=${config.systemd.package}/bin:$PATH \
        ${pkgs.python3Packages.virt-firmware}/bin/kernel-bootcfg \
        --add-uki "$image" --title "NixOS UKI $(${pkgs.coreutils}/bin/date -r "$image" '+%Y-%m-%d %H:%M')" \
        --boot-order last
    '';
    # Retain the CLI for inspection and explicit selection during VM validation.
    environment.systemPackages = [ pkgs.python3Packages.virt-firmware ];
  };
}
