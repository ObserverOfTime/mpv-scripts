utils = require 'mp.utils'

MULTIMEDIA = table.concat({
    '*.aac',
    '*.avi',
    '*.flac',
    '*.flv',
    '*.m3u',
    '*.m3u8',
    '*.m4v',
    '*.mkv',
    '*.mov',
    '*.mp3',
    '*.mp4',
    '*.mpeg',
    '*.mpg',
    '*.oga',
    '*.ogg',
    '*.ogv',
    '*.opus',
    '*.wav',
    '*.webm',
    '*.wmv',
}, ' ')

SUBTITLES = table.concat({
    '*.ass',
    '*.srt',
    '*.ssa',
    '*.sub',
    '*.txt',
}, ' ')

ICON = 'mpv'

function KDialog(opts)
    return function()
        local path = mp.get_property('path')
        path = path == nil and '' or utils.split_path(
            utils.join_path(mp.getcwd(), path)
        )
        local ontop = mp.get_property_native('ontop')
        local focus = utils.subprocess {
            args = {'xdotool', 'getwindowfocus'}
        }.stdout:gsub('\n$', '')
        mp.set_property_native('ontop', false)
        local kdialog = utils.subprocess {
            args = {
                'kdialog', opts.default or path,
                '--title', opts.title,
                '--attach', focus,
                '--icon', ICON,
                '--multiple', '--separate-output',
                opts.type or '--getopenfilename', opts.text,
            }, cancellable = false,
        }
        mp.set_property_native('ontop', ontop)
        if kdialog.status ~= 0 then return end
        for file in string.gmatch(kdialog.stdout, '[^\n]+') do
            mp.commandv(opts.args[1], file, opts.args[2])
        end
    end
end

mp.add_key_binding('Ctrl+f', 'open-files', KDialog {
        title = 'Select Files',
        text = 'Multimedia Files ('..MULTIMEDIA..')',
        args = {'loadfile', 'append-play'},
})
mp.add_key_binding('Ctrl+F', 'open-url', KDialog {
        title = 'Open URL',
        text = 'Enter the URL to open:',
        default = '',
        type = '--inputbox',
        args = {'loadfile', 'replace'},
})
mp.add_key_binding('Alt+f', 'open-subs', KDialog {
        title = 'Select Subs',
        text = 'Subtitle Files ('..SUBTITLES..')',
        args = {'sub-add', 'select'},
})
