{ ... }: {
  programs.wlogout = {
    enable = true;

    layout = [
      { label = "lock";     action = "hyprlock";              text = "Lock";     keybind = "l"; }
      { label = "logout";   action = "hyprctl dispatch exit"; text = "Logout";   keybind = "e"; }
      { label = "suspend";  action = "systemctl suspend";     text = "Suspend";  keybind = "u"; }
      { label = "reboot";   action = "systemctl reboot";      text = "Reboot";   keybind = "r"; }
      { label = "shutdown"; action = "systemctl poweroff";     text = "Shutdown"; keybind = "s"; }
    ];

    style = ''
      * {
        background-image: none;
        font-family: "JetBrainsMono Nerd Font", "Noto Sans CJK JP";
      }

      window {
        background-color: rgba(46, 52, 64, 0.9);
      }

      button {
        color: #d8dee9;
        background-color: #3b4252;
        border: 2px solid #4c566a;
        border-radius: 12px;
        margin: 8px;
        background-repeat: no-repeat;
        background-position: center;
        background-size: 25%;
      }

      button:hover {
        background-color: #434c5e;
        border-color: #88c0d0;
      }

      button:focus {
        background-color: #434c5e;
        border-color: #81a1c1;
      }
    '';
  };
}
