{
  description = "Container image with Nix installed";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        user = {
          name = "opencode";
          uid = "1000";
          gid = "1000";
          home = "/home/opencode";
        };
      in
      {
        packages.default = pkgs.dockerTools.streamLayeredImage {
          name = "opencode-container";
          tag = "latest";
          fromImage = pkgs.dockerTools.pullImage {
            imageName = "ghcr.io/nixos/nix";
            imageDigest = "sha256:7a007c766426c1877758ddc5cb87a965ac131fc78c582ce0083d922d5";
            sha256 = "sha256-dvT5FsEiH6VtSYKPtEkl8EyBiKtkrrJhG3dqsF/wFxc=";
          };
          contents = pkgs.buildEnv {
            name = "opencode-container-env";
            paths = with pkgs; [
              opencode
              git
              bash
              coreutils
              opencode
            ];
          };
          config = {
            EntryPoint = [ "/bin/opencode" ];
            WorkingDir = user.home;
            User = "${user.uid}:${user.gid}";
            Env = [
              "PATH=/nix/var/nix/profiles/default/sbin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin"
            ];
          };
          enableFakechroot = true;
          fakeRootCommands = ''
            mkdir -p /etc/nix
            cat <<HERE >> /etc/nix/nix.conf
            experimental-features = nix-command flakes
            use-xdg-base-directories = true
            HERE

            ${pkgs.dockerTools.shadowSetup}

            groupadd --system --gid ${user.gid} opencode
            useradd --system --uid ${user.uid} --gid ${user.uid} --create-home opencode

            mkdir -p ${user.home}/.local/share/opencode \
                     ${user.home}/.local/state/opencode \
                     ${user.home}/.cache/opencode

            chown -R ${user.uid}:${user.gid} ${user.home}
          '';
        };
      }
    );
}
