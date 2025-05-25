
# dotfiles

## install Nix
```
curl -fsSL https://install.determinate.systems/nix | sh -s -- install --determinate --diagnostic-endpoint=""
```

## install home-manager
```
nix run home-manager/master -- init --switch
```

## switch home-manager
```
home-manager switch --flake ~/dotfiles#outputs
```

##
