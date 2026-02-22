{
  description = "skills.nix - A Nix-packaged collection of agent skills";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-unstable";
    blueprint.url = "github:numtide/blueprint";
    blueprint.inputs.nixpkgs.follows = "nixpkgs";
    workmux-src = {
      url = "github:raine/workmux/v0.1.118";
      flake = false;
    };
  };

  outputs = inputs: inputs.blueprint { inherit inputs; prefix = "nix"; };
}
