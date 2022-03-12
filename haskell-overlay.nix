final: prev:
  let
    inherit (prev.stdenv) mkDerivation;
    inherit (prev.lib.trivial) flip pipe;
    inherit (prev.haskell.lib)
      appendPatch
      appendConfigureFlags
      dontCheck
      doJailbreak;

    withPatch = flip appendPatch;
    withFlags = flip appendConfigureFlags;

    compilerVersion = "921";
    compiler = "ghc" + compilerVersion;
  in {
    myHaskellPackages = prev.haskell.packages.${compiler}.override {
      overrides = hpFinal: hpPrev:
        let
          #hakyll-src = hpPrev.callHackage "hakyll" "4.14.0.0" {};
          pandoc-src = hpPrev.callHackage "pandoc" "2.12" {};
          #hakyll-src = hpPrev.callHackageDirect {
          #  pkg = "hakyll";
          #  ver = "4.15.1.1";
          #  sha256 = "";
          #} {};
        in rec {
          hakyll = pipe hpPrev.hakyll [
            #doJailbreak
            #dontCheck
            (withPatch ./hakyll.patch)
            (withFlags [ "-f" "watchServer" "-f" "previewServer" ])
          ];

          haskell-language-server = prev.haskell-language-server.override {
            supportedGhcVersions = [ compilerVersion ];
          };

          pandoc = pandoc-src;

          #pandoc = pipe pandoc-src [
          #  doJailbreak
          #  dontCheck
          #];

          ssg = hpPrev.callCabal2nix "ssg" ./ssg {};

          website = prev.stdenv.mkDerivation {
            name = "website";
            buildInputs = [ ssg ];
            src = prev.nix-gitignore.gitignoreSourcePure [
              ./.gitignore
              ".git"
              ".github"
            ] ./.;

            # LANG and LOCALE_ARCHIVE are fixes pulled from the community:
            #   https://github.com/jaspervdj/hakyll/issues/614#issuecomment-411520691
            #   https://github.com/NixOS/nix/issues/318#issuecomment-52986702
            #   https://github.com/MaxDaten/brutal-recipes/blob/source/default.nix#L24
            LANG = "en_US.UTF-8";
            LOCALE_ARCHIVE = prev.lib.optionalString
              (prev.buildPlatform.libc == "glibc")
              "${prev.glibcLocales}/lib/locale/locale-archive";

            buildPhase = ''
              hakyll-site build --verbose
            '';

            installPhase = ''
              mkdir -p "$out/dist"
              cp -r dist/* "$out/dist"
            '';
          };
        };
    };
}
