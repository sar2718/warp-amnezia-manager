{ pkgs }: {
  deps = [
    pkgs.bash
    pkgs.wireguard-tools
    pkgs.jq
    pkgs.coreutils
    pkgs.curl
    pkgs.util-linux
  ];
}
