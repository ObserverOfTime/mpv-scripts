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

[xdotool][xdotool] is required for both scripts.

### Windows

You just have to download [powershell.lua](powershell.lua).

### MacOS

You can install Zenity from [MacPorts][ports]
or [Homebrew][brew] and download [zenity_nox.lua][zenity-nox].

**TODO**: Write an AppleScript version.

[kdialog]: https://github.com/KDE/kdialog
[zenity]: https://github.com/GNOME/zenity
[xdotool]: https://github.com/jordansissel/xdotool
[zenity-nox]: https://git.io/JeZZL
[brew]: https://formulae.brew.sh/formula/zenity
[ports]: https://ports.macports.org/port/zenity/summary
