{
  pkgs,
  lib,
  variantName,
  withModels,
  offlineSource,
  modelFiles,
  modelsDirectory,
  sshKeysFile,
  repositoryRemote,
}:
let
  # Reuse NixOS' Calamares configuration and native view/storage modules.
  # Only replace the generic configuration generator with our flake adapter.
  yaml = name: value: pkgs.writeText name (builtins.toJSON value);
  calamaresConfig = {
    modules-search = [
      "local"
      "@out@/lib/calamares/modules"
    ];
    instances = [
      {
        module = "packagechooser";
        id = "ssh";
        config = "desktop-ssh.conf";
      }
      {
        module = "uefiwelcome";
        id = "uefiwelcome";
        config = "welcome.conf";
      }
      {
        module = "desktop";
        id = "validate";
        config = "desktop-validate.conf";
      }
      {
        module = "desktop";
        id = "install";
        config = "desktop-install.conf";
        weight = 50;
      }
    ]
    ++ lib.optionals withModels [
      {
        module = "packagechooser";
        id = "models";
        config = "desktop-models.conf";
      }
      {
        module = "desktop";
        id = "models";
        config = "desktop-copy-models.conf";
        weight = 50;
      }
    ];
    sequence = [
      {
        show = [
          "uefiwelcome"
          "locale"
          "keyboard"
          "users"
          "partition"
        ]
        ++ lib.optional withModels "packagechooser@models"
        ++ [
          "packagechooser@ssh"
          "summary"
        ];
      }
      {
        exec = [
          "desktop@validate"
          "partition"
          "mount"
          "desktop@install"
        ]
        ++ lib.optional withModels "desktop@models"
        ++ [ "umount" ];
      }
      { show = [ "finished" ]; }
    ];
    branding = "nixos";
    prompt-install = true;
    dont-chroot = false;
    oem-setup = false;
    disable-cancel = false;
    disable-cancel-during-exec = true;
    hide-back-and-next-during-exec = true;
    quit-at-end = false;
  };
  calamaresSettings = yaml "settings.conf" calamaresConfig;
  escapeHTML = lib.replaceStrings [ "&" "<" ">" "\"" ] [ "&amp;" "&lt;" "&gt;" "&quot;" ];
  keyLines = lib.filter (line: builtins.match "[[:space:]]*(#.*)?" line == null) (
    lib.splitString "\n" (builtins.readFile sshKeysFile)
  );
  keyPreview =
    unnamed: line:
    let
      parsed = builtins.match "[[:space:]]*((ssh-|ecdsa-|sk-)[^[:space:]]+)[[:space:]]+([A-Za-z0-9+/=]+)([[:space:]]+(.*))?" line;
    in
    if parsed == null then
      "${unnamed} · (key preview unavailable)"
    else
      let
        key = builtins.elemAt parsed 2;
        comment = builtins.elemAt parsed 4;
        name = if comment == null || comment == "" then unnamed else comment;
        length = builtins.stringLength key;
      in
      "${escapeHTML (builtins.elemAt parsed 0)} …${
        builtins.substring (lib.max 0 (length - 16)) 16 key
      } · ${escapeHTML name}";
  keyList =
    unnamed: empty:
    if keyLines == [ ] then
      "<br/><b>${empty}</b>"
    else
      "<br/><br/><b>Keys:</b><br/>" + lib.concatMapStringsSep "<br/>" (keyPreview unnamed) keyLines;
  sshSettings = yaml "desktop-ssh.conf" {
    mode = "optional";
    method = "legacy";
    labels.step = "SSH Access";
    labels."step[de]" = "SSH-Zugang";
    items = [
      {
        id = "";
        name = "Without SSH server";
        "name[de]" = "Ohne SSH-Server";
        description = "Disable remote SSH access on the installed system.";
        "description[de]" = "SSH-Zugang im installierten System deaktivieren.";
        screenshot = "";
      }
      {
        id = "ssh";
        name = "Enable SSH server";
        "name[de]" = "SSH-Server aktivieren";
        description =
          "Allow login as the installed user with the image's provisioned public keys. Password and root login are disabled. Opens TCP port 22."
          + keyList "Unnamed" "No public keys supplied: no initial key login is configured.";
        "description[de]" =
          "Anmeldung als angelegter Benutzer mit den öffentlichen Schlüsseln des Images. Kein Passwort- oder Root-Login. Öffnet TCP-Port 22."
          + keyList "Ohne Namen" "Keine öffentlichen Schlüssel angegeben: kein anfänglicher Schlüsselzugang eingerichtet.";
        screenshot = "";
      }
    ];
  };
  spice = import ../spice.nix {
    inherit pkgs;
    settings = calamaresConfig;
  };
  modelSettings = yaml "desktop-models.conf" {
    mode = "required";
    method = "legacy";
    default = "qwen";
    labels.step = "Model Weights";
    labels."step[de]" = "Modellgewichte";
    items = [
      {
        id = "qwen";
        name = "Qwen3.8-Flash-Next (GGUF, UD-Q4_K_XL)";
        "name[de]" = "Qwen3.8-Flash-Next (GGUF, UD-Q4_K_XL)";
        description = "Unsloth weights including MTP (Q8_0) and the multimodal projector (BF16): copy all six files to the target system offline. Requires about 107 GiB of additional storage.";
        "description[de]" =
          "Unsloth-Gewichte inklusive MTP (Q8_0) und multimodalem Projektor (BF16): alle sechs Dateien offline auf das Zielsystem kopieren. Benötigt etwa 107 GiB zusätzlichen Speicherplatz.";
        screenshot = "";
      }
      {
        id = "without-models";
        name = "Without model weights";
        "name[de]" = "Ohne Modellgewichte";
        description = "Install the selected system with Gufo without copying weights. To use the model, provide its weights later.";
        "description[de]" =
          "Das gewählte System mit Gufo installieren, ohne Gewichte zu kopieren. Für die Modellnutzung müssen die Gewichte später bereitgestellt werden.";
        screenshot = "";
      }
    ];
  };
  partitionSettings = yaml "partition.conf" {
    efi = {
      mountPoint = "/boot";
      recommendedSize = "1GiB";
      minimumSize = "1GiB";
      label = "EFI";
    };
    userSwapChoices = [ "none" ];
    initialSwapChoice = "none";
    initialPartitioningChoice = "none";
    allowManualPartitioning = false;
    defaultPartitionTableType = "gpt";
    luksGeneration = "luks2";
    defaultFileSystemType = "btrfs";
    availableFileSystemTypes = [ "btrfs" ];
    requiredStorageGiB = if withModels then 256 else 32;
    showNotEncryptedBootMessage = true;
    enableLuksAutomatedPartitioning = true;
    preCheckEncryption = true;
    lvm.enable = false;
    partitionLayout = [
      {
        name = "root";
        filesystem = "btrfs";
        noEncrypt = false;
        mountPoint = "/";
        size = "100%";
      }
    ];
  };
  mountSettings = yaml "mount.conf" {
    extraMounts = [
      {
        device = "proc";
        fs = "proc";
        mountPoint = "/proc";
      }
      {
        device = "sys";
        fs = "sysfs";
        mountPoint = "/sys";
      }
      {
        device = "/dev";
        mountPoint = "/dev";
        options = [ "bind" ];
      }
      {
        device = "tmpfs";
        fs = "tmpfs";
        mountPoint = "/run";
      }
      {
        device = "/run/udev";
        mountPoint = "/run/udev";
        options = [ "bind" ];
      }
      {
        device = "efivarfs";
        fs = "efivarfs";
        mountPoint = "/sys/firmware/efi/efivars";
        efi = true;
      }
    ];
    # An empty list triggers Calamares' @/@home defaults. Explicitly mount
    # the top-level filesystem instead, with no additional subvolumes.
    btrfsSubvolumes = [
      {
        mountPoint = "/";
        subvolume = "";
      }
    ];
    mountOptions = [
      {
        filesystem = "efi";
        options = [
          "fmask=0077"
          "dmask=0077"
        ];
      }
      {
        filesystem = "btrfs";
        options = [
          "compress=zstd"
          "noatime"
        ];
      }
    ];
  };
  userSettings = yaml "users.conf" {
    defaultGroups = [
      "users"
      "networkmanager"
      "wheel"
    ];
    setRootPassword = false;
    doReusePassword = false;
    doAutologin = false;
    passwordRequirements = {
      minLength = 8;
      maxLength = 128;
    };
    allowWeakPasswords = false;
    user = {
      shell = "/run/current-system/sw/bin/bash";
      forbidden_names = [
        "root"
        "gufo"
        "nixos"
        "nobody"
        "daemon"
        "sshd"
      ];
    };
    hostname = {
      location = "EtcFile";
      writeHostsFile = false;
      forbidden_names = [ "localhost" ];
    };
  };
  installSettings = yaml "desktop-install.conf" {
    stage = "install";
    source = "${offlineSource}";
    target = variantName;
    inherit withModels repositoryRemote;
  };
  copyModelSettings = yaml "desktop-copy-models.conf" {
    stage = "models";
    models = "${modelFiles}";
    inherit modelsDirectory;
  };
  validateSettings = yaml "desktop-validate.conf" {
    stage = "validate";
    inherit withModels;
  };
  welcomeModule = pkgs.stdenv.mkDerivation {
    pname = "calamares-uefi-welcome";
    version = "1";
    src = ./calamares/welcome;
    nativeBuildInputs = [
      pkgs.cmake
      pkgs.qt6.wrapQtAppsHook
    ];
    buildInputs = [ pkgs.calamares ] ++ pkgs.calamares.buildInputs;
    dontWrapQtApps = true;
    cmakeFlags = [
      "-DUPSTREAM_WELCOME=${pkgs.calamares}/lib/calamares/modules/welcome/libcalamares_viewmodule_welcome.so"
    ];
  };
  calamaresExtensions = pkgs.calamares-nixos-extensions.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      mkdir -p $out/lib/calamares/modules/desktop
      cp -r ${welcomeModule}/lib/calamares/modules/uefiwelcome $out/lib/calamares/modules/
      cp ${./calamares/main.py} $out/lib/calamares/modules/desktop/main.py
      mkdir -p $out/lib/calamares/modules/desktop/locale/de/LC_MESSAGES
      ${pkgs.gettext}/bin/msgfmt --check ${./calamares/locale/de.po} \
        -o $out/lib/calamares/modules/desktop/locale/de/LC_MESSAGES/desktop-installer.mo
      cp ${./calamares/module.desc} $out/lib/calamares/modules/desktop/module.desc
      cp ${calamaresSettings} $out/etc/calamares/settings.conf
      # Offline installation must not be blocked by upstream's Internet check.
      sed -i '/^[[:space:]]*- internet$/d' $out/etc/calamares/modules/welcome.conf
      substituteInPlace $out/etc/calamares/settings.conf --replace-fail @out@ $out
      ${spice.install}
      cp ${partitionSettings} $out/etc/calamares/modules/partition.conf
      cp ${userSettings} $out/etc/calamares/modules/users.conf
      cp ${sshSettings} $out/etc/calamares/modules/desktop-ssh.conf
      cp ${mountSettings} $out/etc/calamares/modules/mount.conf
      ${lib.optionalString withModels ''
        cp ${modelSettings} $out/etc/calamares/modules/desktop-models.conf
        cp ${copyModelSettings} $out/etc/calamares/modules/desktop-copy-models.conf
      ''}
      cp ${installSettings} $out/etc/calamares/modules/desktop-install.conf
      cp ${validateSettings} $out/etc/calamares/modules/desktop-validate.conf
    '';
  });
in
{
  inherit calamaresExtensions welcomeModule;
  offlinePackages = spice.offlinePackages;
}
