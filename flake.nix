{
  description = "Simple Python Communications";

  inputs.nixpkgs.url = github:NixOS/nixpkgs/nixos-23.05;

  outputs = { self, nixpkgs }:
    let
      pkgs = import nixpkgs { system = "x86_64-linux"; };
      sipyco = pkgs.python3Packages.buildPythonPackage {
        pname = "sipyco";
        version = "1.5";
        src = self;
        propagatedBuildInputs = with pkgs.python3Packages; [ pybase64 numpy ];
      };
      sipyco-aarch64 = (with nixpkgs.legacyPackages.aarch64-linux; python3Packages.buildPythonPackage {
        inherit (sipyco) pname version src;
        propagatedBuildInputs = with python3Packages; [ pybase64 numpy ];
      });
      sphinxcontrib-wavedrom = pkgs.python3Packages.buildPythonPackage rec {
        pname = "sphinxcontrib-wavedrom";
        version = "3.0.2";
        src = pkgs.python3Packages.fetchPypi {
          inherit pname version;
          sha256 = "sha256-ukZd3ajt0Sx3LByof4R80S31F5t1yo+L8QUADrMMm2A=";
        };
        buildInputs = [ pkgs.python3Packages.setuptools_scm ];
        propagatedBuildInputs = [ pkgs.nodejs pkgs.nodePackages.wavedrom-cli ] ++ (with pkgs.python3Packages; [ wavedrom sphinx xcffib cairosvg ]);
      };
      latex-sipyco-manual = pkgs.texlive.combine {
        inherit (pkgs.texlive)
          scheme-basic latexmk cmap collection-fontsrecommended fncychap
          titlesec tabulary varwidth framed fancyvrb float wrapfig parskip
          upquote capt-of needspace etoolbox;
      };
    in rec {
      packages.x86_64-linux = {
        inherit sipyco sphinxcontrib-wavedrom latex-sipyco-manual;
        default = sipyco;
        sipyco-manual-html = pkgs.stdenvNoCC.mkDerivation rec {
          name = "sipyco-manual-html-${version}";
          version = sipyco.version;
          src = self;
          buildInputs = [
            sipyco
            pkgs.python3Packages.sphinx pkgs.python3Packages.sphinx_rtd_theme
            pkgs.python3Packages.sphinx-argparse sphinxcontrib-wavedrom
          ];
          buildPhase = ''
            export SOURCE_DATE_EPOCH=${builtins.toString self.sourceInfo.lastModified}
            cd doc
            make html
          '';
          installPhase = ''
            cp -r _build/html $out
            mkdir $out/nix-support
            echo doc manual $out index.html >> $out/nix-support/hydra-build-products
          '';
        };
        sipyco-manual-pdf = pkgs.stdenvNoCC.mkDerivation rec {
          name = "sipyco-manual-pdf-${version}";
          version = sipyco.version;
          src = self;
          buildInputs = [
            sipyco
            pkgs.python3Packages.sphinx pkgs.python3Packages.sphinx_rtd_theme
            pkgs.python3Packages.sphinx-argparse sphinxcontrib-wavedrom
            latex-sipyco-manual
          ];
          buildPhase = ''
            export SOURCE_DATE_EPOCH=${builtins.toString self.sourceInfo.lastModified}
            cd doc
            make latexpdf
          '';
          installPhase = ''
            mkdir $out
            cp _build/latex/SiPyCo.pdf $out
            mkdir $out/nix-support
            echo doc-pdf manual $out SiPyCo.pdf >> $out/nix-support/hydra-build-products
          '';
        };
      };

      devShells.x86_64-linux.default = pkgs.mkShell {
        name = "sipyco-dev-shell";
        buildInputs = [
          (pkgs.python3.withPackages(ps: with ps; [ pybase64 numpy ]))
          pkgs.python3Packages.sphinx pkgs.python3Packages.sphinx_rtd_theme
          pkgs.python3Packages.sphinx-argparse sphinxcontrib-wavedrom latex-sipyco-manual
        ];
      };

      packages.aarch64-linux = {
        sipyco = sipyco-aarch64;
        default = sipyco-aarch64;
      };

      hydraJobs = {
        inherit (packages.x86_64-linux) sipyco sipyco-manual-html sipyco-manual-pdf;
      }; 
    };
}
