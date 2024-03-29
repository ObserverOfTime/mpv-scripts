## mpv scripts

[![LICENSE](https://img.shields.io/badge/license-BSD0-red.svg)](LICENSE.txt "BSD Zero Clause License")

My collection of cross-platform scripts for [mpv][mpv].

Feel free to edit and adapt them however you like
<br>and if you think your changes should be merged,
<br>don't hesitate to submit a pull request.

### [open-dialog](open-dialog)

Scripts that launch a dialog for opening files or URLs.
<br>Follow the link for details.

### [clipshot.lua](clipshot.lua)

#### `clipshot-subs`

Screenshot the video (with subs) and copy it to the clipboard.
<br>Default key binding: <kbd>c</kbd>

#### `clipshot-video`

Screenshot the video (w/o subs) and copy it to the clipboard.
<br>Default key binding: <kbd>C</kbd>

#### `clipshot-window`

Screenshot the full window and copy it to the clipboard.
<br>Default key binding: <kbd>Alt + c</kbd>

### [discord.lua](discord.lua)

Discord rich presence in a single script.
<br>Default key binding: <kbd>D</kbd>

|              |  Windows  |  Linux  |  MacOS  |
|:------------:|:---------:|:-------:|:-------:|
|  **LuaJIT**  |     ✓     |    ✓    |    ✗    |
|   **Lua**    |     ✓     |    ∗    |    ∗    |

∗ Requires [LuaSocket](https://w3.impa.br/~diego/software/luasocket/)

### [misc.lua](misc.lua)

Miscellaneous simple functions.

#### `show-time`

Show the current time (`HH:MM`) on the OSD.
<br>Default key binding: <kbd>Ctrl+t</kbd>

[mpv]: https://github.com/mpv-player/mpv
