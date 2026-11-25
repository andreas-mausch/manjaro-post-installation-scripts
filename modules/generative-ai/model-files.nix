{
  pkgs,
  gufo,
  models,
}:
let
  manifest = builtins.fromJSON (builtins.readFile ./models.lock.json);
  upstreamManifest = builtins.fromJSON (
    builtins.readFile (gufo + "/src/models/qwen38_flash_next/models.lock.json")
  );
  relativeDirectory = pkgs.lib.removePrefix "${models.directory}/" models.text-generation.qwen38FlashNext.directory;
in
assert manifest == upstreamManifest;
pkgs.linkFarm "qwen-models" (
  pkgs.lib.concatMap (
    component:
    map (file: {
      name = "${relativeDirectory}/${file.path}";
      path = pkgs.fetchurl {
        url = "https://huggingface.co/${component.source.hf}/resolve/${component.source.revision}/${file.path}";
        sha256 = file.sha256;
      };
    }) component.files
  ) (builtins.attrValues manifest.models.flash-next-q4)
)
