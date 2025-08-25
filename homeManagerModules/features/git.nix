{inputs,...}: {
  programs.git = {
    enable = true;
    userEmail = "119401366+Bakan0@users.noreply.github.com";
    userName = "bakan0";
    extraConfig = {
      url."git@github.com:".insteadOf = "https://github.com/";
    };
  };
}

