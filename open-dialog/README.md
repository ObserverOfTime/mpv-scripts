## Open Dialog

Rather than write a single cross-platform script, which would be
too complicated, I opted for separate scripts for each platform.

All scripts provide the following functions:

#### `open-files`

Open one or more media files in mpv.
<br>Default key binding: <kbd>Ctrl + f</kbd>

#### `open-url`

Open a URL in mpv.
<br>Default key binding: <kbd>Ctrl + F</kbd>

#### `open-subs`

Open one or more subtitle files in mpv.
<br>Default key binding: <kbd>Alt + f</kbd>

---

### Linux

If you're on KDE, you should download
[kdialog.lua](kdialog.lua) which uses [KDialog][kdialog].

If not, you should download
[zenity.lua](zenity.lua) which uses [Zenity][zenity].

### Windows

Download [powershell.lua](powershell.lua).

### MacOS

Download [osascript.lua](osascript.lua).

[kdialog]: https://github.com/KDE/kdialog
[zenity]: https://github.com/GNOME/zenity
