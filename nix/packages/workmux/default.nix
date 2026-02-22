{ pkgs, inputs, flake, ... }:

flake.lib.mkRemoteSkills {
  inherit pkgs;
  name = "workmux";
  src = inputs.workmux-src;
  skillsDir = "skills";
}
