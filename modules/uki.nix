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
      # Serialize preparation on the EFI partition.
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
  entryManager = pkgs.writeShellApplication {
    name = "manage-uki-entries";
    runtimeInputs = [
      builder
      config.systemd.package
    ];
    text = ''
      exec ${pkgs.python3.withPackages (packages: [ packages.virt-firmware ])}/bin/python3 \
        ${./uki/entries.py} "$1" ${lib.escapeShellArg config.boot.loader.efi.efiSysMountPoint} \
        /var/lib/my-os-setup/uki/generations.json /nix/var/nix/gcroots/nixos-install /run/current-system
    '';
  };
in
{
  config = {
    boot.loader.external = {
      enable = true;
      installHook = lib.getExe entryManager;
    };
    # Retain the CLI for inspection and explicit selection during VM validation.
    environment.systemPackages = [
      pkgs.python3Packages.virt-firmware
      entryManager
    ];
  };
}
