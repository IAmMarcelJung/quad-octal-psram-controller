# SPDX-License-Identifier: Apache-2.0
{
  nixConfig = {
    extra-substituters = [
      "https://nix-cache.fossi-foundation.org"
    ];
    extra-trusted-public-keys = [
      "nix-cache.fossi-foundation.org:3+K59iFwXqKsL7BNu6Guy0v+uTlwsxYQxjspXzqLYQs="
    ];
  };

  # The exact LibreLane commit is pinned in flake.lock (same as HeiChips/heichips26-tapeout).
  # The dev branch is needed for the current ihp-sg13cmos5l PDK configs (CELL_LIBS, ciel 3.x).
  inputs = {
    librelane.url = "github:librelane/librelane/dev";
  };

  outputs =
    { self, librelane, ... }:
    let
      nix-eda = librelane.inputs.nix-eda;
      devshell = librelane.inputs.devshell;
      nixpkgs = nix-eda.inputs.nixpkgs;
      lib = nixpkgs.lib;
    in
    {
      legacyPackages = nix-eda.forAllSystems (
        system:
        import nixpkgs {
          inherit system;
          overlays = [
            nix-eda.overlays.default
            devshell.overlays.default
            librelane.overlays.default
            (nix-eda.composePythonOverlay (
              pkgs': pkgs: pypkgs': pypkgs:
              let
                callPythonPackage = lib.callPackageWith (pkgs' // pypkgs');
              in
              {
                cocotbext-axi = callPythonPackage ./nix/cocotbext-axi.nix { };
                cocotbext-spi = callPythonPackage ./nix/cocotbext-spi.nix { };
              }
            ))
          ];
        }
      );

      devShells = nix-eda.forAllSystems (
        system:
        let
          pkgs = self.legacyPackages.${system};
        in
        {
          default = pkgs.librelane-shell.override {
            extra-packages = with pkgs; [
              # Simulation
              iverilog
              verilator
              # Formatting (same versions as the CI check)
              verible
            ];
            extra-python-packages =
              ps: with ps; [
                # Verification (test/cocotb)
                cocotb
                cocotbext-axi
                cocotbext-spi
                pytest
                black
              ];
          };
        }
      );
    };
}
