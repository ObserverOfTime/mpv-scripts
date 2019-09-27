utils = require 'mp.utils'

NAME = 'mpv-screenshot.png'

if package.config:sub(1, 1) ~= '/' then -- Windows
    SHOT = os.getenv('TEMP')..'\\'..NAME
    CMD = {
        'powershell', '-NoProfile', '-Command', string.format([[& {
            Add-Type -Assembly System.Windows.Forms;
            Add-Type -Assembly System.Drawing;
            $shot = [Drawing.Image]::FromFile(%q);
            [Windows.Forms.Clipboard]::SetImage($shot);
        }]], SHOT)
    }
else -- Unix
    SHOT = '/tmp/'..NAME
    -- os.getenv('OSTYPE') doesn't work
    local ostype = io.popen('printf "$OSTYPE"', 'r'):read()
    if ostype:sub(1, 6) == 'darwin' then -- MacOS
        CMD = {
            'osascript', '-e', string.format([[¬
                set the clipboard to ( ¬
                    read (POSIX file %q) as «class PNG» ¬
                ) ¬
            ]], SHOT)
        }
    else -- Linux/BSD
        CMD = {'xclip', '-sel', 'c', '-t', 'image/png', '-i', SHOT}
    end
end

function clipshot(arg)
    return function()
        mp.commandv('screenshot-to-file', SHOT, arg)
        utils.subprocess_detached({args = CMD})
        mp.osd_message('Copied screenshot to clipboard')
        -- TODO: switch to new API when it's in stable
        -- mp.command_native_async({'run', unpack(CMD)}, function(suc, res, err)
        --    mp.osd_message(suc and 'Copied screenshot to clipboard' or err)
        -- end)
    end
end

mp.add_key_binding('c',     'clipshot-subs',   clipshot('subtitles'))
mp.add_key_binding('C',     'clipshot-video',  clipshot('video'))
mp.add_key_binding('Alt+c', 'clipshot-window', clipshot('window'))
