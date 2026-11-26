# SPICE provides remote display and guest integration for virtual machines.
{
  pkgs,
  settings ? null,
}:
let
  autostart = pkgs.runCommand "spice-vdagent-autostart.desktop" { } ''
    # Plasma's systemd autostart skips this entry without a replacement user service.
    # https://github.com/NixOS/nixpkgs/issues/239490#issuecomment-1795843923
    # https://github.com/NixOS/nixpkgs/pull/266080
    sed '/^X-systemd-skip=/d' \
      ${pkgs.spice-vdagent}/etc/xdg/autostart/spice-vdagent.desktop > "$out"
    ! grep -q '^X-systemd-skip=' "$out"
    grep -q '^Exec=${pkgs.spice-vdagent}/bin/spice-vdagent$' "$out"
    grep -q '^X-GNOME-Autostart-Phase=WindowManager$' "$out"
  '';
  chooser = pkgs.writeText "desktop-spice.conf" (
    builtins.toJSON {
      mode = "optional";
      method = "legacy";
      labels.step = "SPICE Guest Integration";
      labels."step[de]" = "SPICE-Gastintegration";
      items = [
        {
          id = "";
          name = "Without SPICE guest integration";
          "name[de]" = "Ohne SPICE-Gastintegration";
          description = "Leave SPICE guest integration disabled.";
          "description[de]" = "SPICE-Gastintegration deaktiviert lassen.";
          screenshot = "";
        }
        {
          id = "spice";
          name = "Enable SPICE guest integration";
          "name[de]" = "SPICE-Gastintegration aktivieren";
          description = "Enable the SPICE daemon and install its session agent. Under Plasma/Wayland, clipboard sharing may work only from host to guest; session-agent autostart is not yet confirmed.";
          "description[de]" =
            "SPICE-Dienst aktivieren und Sitzungs-Agent installieren. Unter Plasma/Wayland funktioniert die Zwischenablage möglicherweise nur vom Host zum Gast; der Autostart des Sitzungs-Agenten ist noch nicht bestätigt.";
          screenshot = "";
        }
      ];
    }
  );
  # The launcher selects this configuration only when the SPICE channel exists.
  spiceSettings = pkgs.writeText "spice-settings.conf" (
    builtins.toJSON (
      settings
      // {
        instances = settings.instances ++ [
          {
            module = "packagechooser";
            id = "spice";
            config = "desktop-spice.conf";
          }
        ];
        sequence = builtins.map (
          step:
          if step ? show && builtins.elem "summary" step.show then
            step
            // {
              show = builtins.filter (module: module != "summary") step.show ++ [
                "packagechooser@spice"
                "summary"
              ];
            }
          else
            step
        ) settings.sequence;
      }
    )
  );
in
{
  offlinePackages = [
    pkgs.spice-vdagent
    autostart
  ];
  nixosModule = { config, lib, ... }: {
    environment.etc."xdg/autostart/spice-vdagent.desktop" =
      lib.mkIf config.services.spice-vdagentd.enable
        {
          source = autostart;
        };
  };
  install = ''
    mkdir -p $out/etc-spice/calamares
    ln -s $out/etc/calamares/modules $out/etc-spice/calamares/modules
    cp ${spiceSettings} $out/etc-spice/calamares/settings.conf
    substituteInPlace $out/etc-spice/calamares/settings.conf --replace-fail @out@ $out
    cp ${chooser} $out/etc/calamares/modules/desktop-spice.conf
  '';
}
