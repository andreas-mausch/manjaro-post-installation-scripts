{ ... }:
{
  # Keep eSpeak and screen readers, without the large optional MBROLA voice sets.
  nixpkgs.overlays = [
    (_: prev: {
      espeak-ng = prev.espeak-ng.override { mbrolaSupport = false; };
    })
  ];
}
