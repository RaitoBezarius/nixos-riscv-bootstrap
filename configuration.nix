{ lib, pkgs, config, ... }:
let resize = pkgs.runCommandCC "resize" {} ''
      mkdir -p $out/bin
      ${pkgs.stdenv.cc.targetPrefix}cc ${./resize.c} -O3 -o $out/bin/resize-disk
      fixupPhase
    '';

    ugh = pkgs.writeShellScriptBin "retain-deps" ''
      echo "The extra-utils are at ${config.system.build.extraUtils}" >&2
    '';
in
{ nixpkgs.crossSystem = lib.systems.examples.riscv32;
  nixpkgs.config.allowUnsupportedSystem = true;

  boot.loader.grub.enable = false;
  boot.kernelPackages = pkgs.linuxPackagesFor pkgs.linux;
  boot.initrd.extraUtilsCommands = ''
    cp -a ${resize}/bin/resize-disk $out/bin
  '';
  boot.initrd.postMountCommands = ''
    if [ -f /mnt-root/needs-resize ]; then
      PATH=$systemConfig/sw/bin:$PATH resize-disk
    fi
  '';

  environment.noXlibs = true;
  environment.systemPackages = [ pkgs.gptfdisk ugh ];
  # gobject-introspection apparently can't cross-compile without running host code: http://nicola.entidi.com/post/cross-compiling-gobject-introspection/
  # polkit brings in gobject-introspection
  security.polkit.enable = false;
  # udisks2 brings in polkit
  services.udisks2.enable = false;
  fileSystems."/" =
    { label = "root";
      fsType = "btrfs";
    };

  # texinfo fails to cross-build at the moment.
  documentation.info.enable = false;

  nix.package = pkgs.nixUnstable;
  nix.sshServe =
    { enable = true;
      keys = [ "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDcEkYM1r8QVNM/G5CxJInEdoBCWjEHHDdHlzDYNSUIdHHsn04QY+XI67AdMCm8w30GZnLUIj5RiJEWXREUApby0GrfxGGcy8otforygfgtmuUKAUEHdU2MMwrQI7RtTZ8oQ0USRGuqvmegxz3l5caVU7qGvBllJ4NUHXrkZSja2/51vq80RF4MKkDGiz7xUTixI2UcBwQBCA/kQedKV9G28EH+1XfvePqmMivZjl+7VyHsgUVj9eRGA1XWFw59UPZG8a7VkxO/Eb3K9NF297HUAcFMcbY6cPFi9AaBgu3VC4eetDnoN/+xT1owiHi7BReQhGAy/6cdf7C/my5ehZwD raito@RaitoBezarius-Laptop-OverDrive" ];
      protocol = "ssh-ng";
    };
  nix.trustedUsers = [ "nix-ssh" ];

  system.boot.loader.kernelFile = "vmlinux";

  users.extraUsers.root.initialHashedPassword = "";
}
