
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
通常の場合

```
home-manager switch --flake ~/dotfiles#output
```

dev 環境の場合

```
home-manger switch --flake ~/dotfiles#dev
```

##
