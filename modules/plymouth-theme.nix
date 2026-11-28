{ pkgs }:
(pkgs.adi1090x-plymouth-themes.override { selected_themes = [ "abstract_ring" ]; }).overrideAttrs
  (old: {
    postInstall = (old.postInstall or "") + ''
      cat ${./plymouth-boot-selection.script} >> "$out/share/plymouth/themes/abstract_ring/abstract_ring.script"
    '';
  })
