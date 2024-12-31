{pkgs, ...}: {
  hardware.uinput.enable = true;
  users.groups.uinput.members = ["emet"];
  users.groups.input.members = ["emet"];
}
