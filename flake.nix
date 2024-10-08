{
  description = "Bachitter's Nix Config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
   
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
  };

  outputs = inputs@{ self, nix-darwin, nix-homebrew, nixpkgs }:
  let
    configuration = { pkgs, config, ... }: {

      # Allow packages to be installed that are closed source.
      nixpkgs.config.allowUnfree = true;

      # List packages installed in system profile.
      environment.systemPackages =
        [ pkgs.cloudflared
          pkgs.eza
          pkgs.fzf
          pkgs.htop
          pkgs.git
          pkgs.go
          pkgs.libgcc
          pkgs.mkalias
          pkgs.mkcert
          pkgs.neofetch
          pkgs.neovim
          pkgs.ripgrep
          pkgs.starship
          pkgs.unzip
          pkgs.wezterm
          pkgs.wget
        ];

      # Installs JetBrains Mono Nerd Font
      fonts.packages = [
          (pkgs.nerdfonts.override { fonts = [ "JetBrainsMono"]; })
        ]

      # Enable homebrew and install packages
      homebrew = {
        enable = true;
        taps = [
          "homebrew/services"
          "make"
          "nvm"
        ];
        casks = [
          "1password"
          "discord"
          "raycast"
        ];
        onActivation.autoUpdate = true;
        onActivation.cleanup = "zap";
        onActivation.upgrade = true;
      }

      # Setup system defaults
      system.defaults = {
        loginwindow.GuestEnabled = false;
        NSGlobalDomain.AppleInterfaceStyle = "Dark";
        NSGlobalDomain.KeyRepeat = "2";
      };
      
      # Enable keyboard mapping and remap caps lock to escape
      system.keyboard.enableKeyMapping = true;
      system.keyboard.remapCapsLockToEscape = true;

      # Add ability to used TouchID for sudo authentication
      security.pam.enableSudoTouchIdAuth = true;

      # Create aliases to apps to be indexed by spotlight
      system.activationScripts.applications.text = let
        env = pkgs.buildEnv {
          name = "system-applications";
          paths = config.environment.systemPackages;
          pathsToLink = "/Applications";
        };
      in
        pkgs.lib.mkForce ''
        # Set up applications.
        echo "setting up /Applications..." >&2
        rm -rf /Applications/Nix\ Apps
        mkdir -p /Applications/Nix\ Apps
        find ${env}/Applications -maxdepth 1 -type l -exec readlink '{}' + |
        while read src; do
          app_name=$(basename "$src")
          echo "copying $src" >&2
          ${pkgs.mkalias}/bin/mkalias "$src" "/Applications/Nix Apps/$app_name"
        done
      '';

      # Auto upgrade nix package and the daemon service.
      services.nix-daemon.enable = true;
      # nix.package = pkgs.nix;

      # Necessary for using flakes on this system.
      nix.settings.experimental-features = "nix-command flakes";
      
      nix.settings.trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];

      # Create /etc/zshrc that loads the nix-darwin environment.
      programs.zsh.enable = true;  # default shell on catalina

      # Set Git commit hash for darwin-version.
      system.configurationRevision = self.rev or self.dirtyRev or null;

      # Used for backwards compatibility, please read the changelog before changing.
      # $ darwin-rebuild changelog
      system.stateVersion = 5;

      # The platform the configuration will be used on.
      nixpkgs.hostPlatform = "aarch64-darwin";
    };
  in
  {
    # Build darwin flake using:
    # $ darwin-rebuild build --flake .#simple
    darwinConfigurations."blackbox" = nix-darwin.lib.darwinSystem {
      modules = [ 
        configuration
        nix-homebrew.darwinModules.nix-homebrew
        {
          nix-homebrew = {
            # Install Homebrew under the default prefix
            enable = true;
            # Apple Silicon Only: Also install Homebrew under the default Intel prefix for Rosetta 2
            enableRosetta = true;
            # User owning the Homebrew prefix
            user = "bachitter";
            # Automatically migrate existing Homebrew installations
            autoMigrate = true;
          };
        }
      ];
    };

    # Expose the package set, including overlays, for convenience.
    darwinPackages = self.darwinConfigurations."blackbox".pkgs;
  };
}
