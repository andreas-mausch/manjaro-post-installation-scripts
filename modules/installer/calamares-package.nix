{
  symlinkJoin,
  makeWrapper,
  calamares,
  calamaresExtensions,
}:
symlinkJoin {
  name = "calamares-nixos-${calamares.version}";
  paths = [ calamares ];
  nativeBuildInputs = [ makeWrapper ];
  # Keep the compiled Qt application independent of variant-specific settings.
  postBuild = ''
    rm "$out/bin/calamares"
    makeWrapper ${calamares}/bin/calamares "$out/bin/calamares" \
      --prefix XDG_DATA_DIRS : ${calamaresExtensions}/share \
      --prefix XDG_CONFIG_DIRS : ${calamaresExtensions}/etc \
      --run 'if [ -e /dev/virtio-ports/com.redhat.spice.0 ]; then export XDG_CONFIG_DIRS="${calamaresExtensions}/etc-spice:$XDG_CONFIG_DIRS"; fi' \
      --add-flags --xdg-config

    policy=share/polkit-1/actions/io.calamares.calamares.policy
    rm "$out/$policy"
    cp ${calamares}/$policy "$out/$policy"
    substituteInPlace "$out/$policy" \
      --replace-fail '${calamares}/bin/calamares' "$out/bin/calamares"

    desktop=share/applications/calamares.desktop
    rm "$out/$desktop"
    cp ${calamares}/$desktop "$out/$desktop"
    substituteInPlace "$out/$desktop" \
      --replace-fail 'TryExec=calamares' "TryExec=$out/bin/calamares" \
      --replace-fail 'pkexec calamares' "pkexec $out/bin/calamares"
  '';
  passthru.unwrapped = calamares;
  meta = calamares.meta // {
    mainProgram = "calamares";
  };
}
