{
  pkgs,
  config,
  lib,
  ...
}: {
  # Enable databending/technical tools features
  myHomeManager.vscode.enable = lib.mkDefault true;
  myHomeManager.git.enable = lib.mkDefault true;
  
  home.packages = with pkgs; [
    # Claude and AI tools
    claude-code
    
    # Git and version control
    gh
    
    # Network analysis and debugging
    wireshark
    nmap
    tcpdump
    
    # Text editors and IDEs
    zed-editor
    
    # Cloud and automation tools
    curl
    
    # System analysis tools would go here
    # (but keeping ripgrep, htop etc. in general bundle for system use)
  ];
}