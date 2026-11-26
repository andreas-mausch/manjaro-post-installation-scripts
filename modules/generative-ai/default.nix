{
  config,
  lib,
  gufoPackage,
  ...
}:
let
  modelDirectoryType = lib.types.addCheck (lib.types.strMatching "/[a-zA-Z0-9/_.-]+") (
    path:
    let
      subpath = lib.removePrefix "/" path;
    in
    lib.path.subpath.isValid subpath && lib.path.subpath.normalise subpath == "./${subpath}"
  );
  modelsDirectory = config.generative-ai.models.directory;
  textGenerationDirectory = config.generative-ai.models.text-generation.directory;
  qwen38FlashNextDirectory = config.generative-ai.models.text-generation.qwen38FlashNext.directory;
in
{
  imports = [ ../base.nix ];
  options.generative-ai.models.directory = lib.mkOption {
    type = modelDirectoryType;
    default = "/var/lib/generative-ai/models";
    description = "Shared absolute directory for AI model weights (without spaces).";
  };
  options.generative-ai.models.text-generation.directory = lib.mkOption {
    type = modelDirectoryType;
    default = "${modelsDirectory}/text-generation";
    description = "Directory for text-generation models.";
  };
  options.generative-ai.models.text-generation.qwen38FlashNext.directory = lib.mkOption {
    type = modelDirectoryType;
    default = "${textGenerationDirectory}/Qwen3.8-Flash-Next";
    description = "Directory for Qwen3.8-Flash-Next weights and sidecars.";
  };
  config = {
    assertions = [
      {
        assertion =
          lib.hasPrefix "${modelsDirectory}/" textGenerationDirectory
          && lib.hasPrefix "${textGenerationDirectory}/" qwen38FlashNextDirectory;
        message = "Text-generation and Qwen3.8-Flash-Next directories must remain below their parent model directories.";
      }
    ];
    hardware.graphics.enable = true;
    nix.settings = import ./cache.nix;
    users.groups.gufo = { };
    users.users.gufo = {
      isSystemUser = true;
      group = "gufo";
      extraGroups = [
        "video"
        "render"
      ];
      home = "/var/lib/gufo";
    };
    security.pam.loginLimits = [
      {
        domain = "@render";
        type = "-";
        item = "memlock";
        value = "unlimited";
      }
    ];
    environment.systemPackages = [ gufoPackage ];
    environment.variables.GUFO_MODELS_DIR = modelsDirectory;
    systemd.tmpfiles.rules = [
      "d /var/lib/gufo 0755 gufo gufo -"
      "d ${modelsDirectory} 0755 gufo gufo -"
      "Z ${modelsDirectory} - gufo gufo -"
    ];
    systemd.services.gufo = {
      description = "Gufo Qwen3.8 Flash-Next (manual start; stop before gaming)";
      # No wantedBy: installed, but not started at boot.
      environment.GUFO_MODELS_DIR = modelsDirectory;
      serviceConfig = {
        User = "gufo";
        Group = "gufo";
        SupplementaryGroups = [
          "video"
          "render"
        ];
        StateDirectory = "gufo";
        LimitMEMLOCK = "infinity";
        TimeoutStopSec = 60;
        ExecStart = lib.concatStringsSep " " [
          "${gufoPackage}/bin/gufo serve --host 127.0.0.1 --port 8080 llm"
          "--model ${qwen38FlashNextDirectory}/UD-Q4_K_XL/Qwen3.8-Flash-Next-UD-Q4_K_XL-00001-of-00004.gguf --served-model-name flash-next"
          "--speculative mtp"
          "--mtp-model ${qwen38FlashNextDirectory}/MTP/mtp-Qwen3.8-Flash-Next-shared-Q8_0.gguf"
          "--sessions 1 --context 32768"
        ];
      };
    };
  };
}
