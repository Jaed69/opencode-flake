{
  lib,
  stdenv,
  stdenvNoCC,
  bun,
  fetchFromGitHub,
  makeBinaryWrapper,
  nix-update-script,
  testers,
  writableTmpDirAsHomeHook,
}:

let
  bun-target = {
    "aarch64-darwin" = "bun-darwin-arm64";
    "aarch64-linux" = "bun-linux-arm64";
    "x86_64-darwin" = "bun-darwin-x64";
    "x86_64-linux" = "bun-linux-x64";
  };
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "opencode";
  version = "1.14.28";

  src = fetchFromGitHub {
    owner = "sst";
    repo = "opencode";
    tag = "v${finalAttrs.version}";
    hash = "sha256-lsyjM6rhSv1HzEd2d/+aGHqrYMARj+TrFrLMGY2X59U=";
  };

  postPatch = ''
    if [ -f bunfig.toml ]; then
      substituteInPlace bunfig.toml \
        --replace-quiet 'preload = ["@opentui/solid/preload"]' \
        'preload = []'
    fi
    if [ -f packages/opencode/bunfig.toml ]; then
      substituteInPlace packages/opencode/bunfig.toml \
        --replace-quiet 'preload = ["@opentui/solid/preload"]' \
        'preload = []'
    fi
  '';

  node_modules = stdenvNoCC.mkDerivation {
    pname = "opencode-node_modules";
    inherit (finalAttrs) version src;

    impureEnvVars = lib.fetchers.proxyImpureEnvVars ++ [
      "GIT_PROXY_COMMAND"
      "SOCKS_SERVER"
    ];

    nativeBuildInputs = [
      bun
      writableTmpDirAsHomeHook
    ];

    dontConfigure = true;

    buildPhase = ''
      runHook preBuild

       export BUN_INSTALL_CACHE_DIR=$(mktemp -d)

       bun install \
         --force \
         --ignore-scripts \
         --no-progress

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/node_modules
      cp -R ./node_modules $out

      runHook postInstall
    '';

    dontFixup = true;

    outputHash =
      {
        x86_64-linux = "sha256-uE/XBFopd+yGgWKhs8MMWHmAZAZfrb4vDbdqWYxdHZU=";
        aarch64-linux = lib.fakeHash;
        x86_64-darwin = lib.fakeHash;
        aarch64-darwin = lib.fakeHash;
      }
      .${stdenv.hostPlatform.system};
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
  };

  nativeBuildInputs = [
    bun
    makeBinaryWrapper
  ];

  configurePhase = ''
    runHook preConfigure

    cp -R ${finalAttrs.node_modules}/node_modules .

    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild

    export NODE_ENV=production
    
    cd packages/opencode
 
    bun run ./script/build.ts -- --target=${bun-target.${stdenv.hostPlatform.system}}
  
    cp dist/*/bin/opencode ../../opencode
    cd ../../

    runHook postBuild
  '';

  dontStrip = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 opencode $out/bin/opencode

    runHook postInstall
  '';

  postFixup = ''
    wrapProgram $out/bin/opencode \
      --set LD_LIBRARY_PATH "${lib.makeLibraryPath [ stdenv.cc.cc.lib ]}"
  '';

  passthru = {
    tests.version = testers.testVersion {
      package = finalAttrs.finalPackage;
      command = "HOME=$(mktemp -d) opencode --version";
      inherit (finalAttrs) version;
    };
    updateScript = nix-update-script {
      extraArgs = [
        "--subpackage"
        "node_modules"
      ];
    };
  };

  meta = {
    description = "AI coding agent built for the terminal";
    homepage = "https://github.com/sst/opencode";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "opencode";
  };
})
