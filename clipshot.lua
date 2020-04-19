NAME = 'mpv-screenshot.jpeg'

if package.config:sub(1, 1) == '\\' then -- Windows
    SHOT = os.getenv('TEMP')..'\\'..NAME
    CMD = {
        'powershell', '-NoProfile', '-Command', ([[& {
            Add-Type -Assembly System.Windows.Forms;
            Add-Type -Assembly System.Drawing;
            $shot = [Drawing.Image]::FromFile(%q);
            [Windows.Forms.Clipboard]::SetImage($shot);
        }]]):format(SHOT)
    }
else -- Unix
    SHOT = '/tmp/'..NAME
    -- os.getenv('OSTYPE') doesn't work
    local ostype = io.popen('printf "$OSTYPE"', 'r'):read()
    if ostype:sub(1, 6) == 'darwin' then -- MacOS
        CMD = {
            'osascript', '-e', ([[¬
                set the clipboard to ( ¬
                    read (POSIX file %q) as JPEG picture ¬
                ) ¬
            ]]):format(SHOT)
        }
    else -- Linux/BSD
        if os.getenv('XDG_SESSION_TYPE') == 'wayland' then -- Wayland
            CMD = {'sh', '-c', ('wl-copy < %q'):format(SHOT)}
        else -- Xorg
            CMD = {'xclip', '-sel', 'c', '-t', 'image/jpeg', '-i', SHOT}
        end
    end
end

function clipshot(arg)
    return function()
        mp.commandv('screenshot-to-file', SHOT, arg)
        mp.command_native_async({'run', unpack(CMD)}, function(suc, _, err)
            mp.osd_message(suc and 'Copied screenshot to clipboard' or err)
        end)
    end
end

mp.add_key_binding('c',     'clipshot-subs',   clipshot('subtitles'))
mp.add_key_binding('C',     'clipshot-video',  clipshot('video'))
mp.add_key_binding('Alt+c', 'clipshot-window', clipshot('window'))
