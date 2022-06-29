{
  description = "Example for presentation";
  inputs = {
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    naersk = {
      url = "github:nmattia/naersk";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, rust-overlay, naersk, ... }:
    let
      pkgs = import nixpkgs {
        localSystem = "${system}";
        overlays = [ rust-overlay.overlay ];
      };
      system = "x86_64-linux";
      riscvPkgs = import nixpkgs {
        localSystem = "${system}";
        crossSystem = {
          config = "riscv64-unknown-linux-gnu";
          abi = "lp64";
        };
      };
      rust_build = pkgs.rust-bin.nightly."2022-06-28".default.override {
        targets = [ "riscv64imac-unknown-none-elf" ];
        extensions = [ "rust-src" "clippy" "cargo" "rustfmt-preview" ];
      };
      naersk_lib = naersk.lib."${system}".override {
        rustc = rust_build;
        cargo = rust_build;
      };
      sample_package = naersk_lib.buildPackage {
        pname = "example_kernel";
        root = ./.;
        cargoBuild = _orig:
          ''
            CARGO_BUILD_TARGET_DIR=$out cargo rustc --release --target="riscv64imac-unknown-none-elf" -- -Clink-arg=-Tlinker.ld'';
      };
      sample_usage = pkgs.writeScript "run_toy_kernel" ''
        #!/usr/bin/env bash
        echo ""
        echo '~~~ `C-a x` to kill qemu; `C-a h` for other options. ~~~'
        ${pkgs.qemu}/bin/qemu-system-riscv64 -kernel ${sample_package}/riscv64imac-unknown-none-elf/release/nix_example_kernel -nographic -machine sifive_u
      '';
    in {
      devShell.x86_64-linux = pkgs.mkShell {
        nativeBuildInputs = [
          pkgs.qemu
          rust_build
          riscvPkgs.buildPackages.gcc
          riscvPkgs.buildPackages.gdb
        ];
      };
      packages.riscv64-linux.kernel = sample_package;
      packages.riscv64-linux.default = sample_package;
      apps.x86_64-linux.toy_kernel = {
        type = "app";
        program = "${sample_usage}";
      };
      apps.x86_64-linux.default = self.apps.x86_64-linux.toy_kernel;
    };
}
