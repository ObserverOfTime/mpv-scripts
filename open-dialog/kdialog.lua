---Launch a dialog for opening files or URLs (KDialog)
---@author ObserverOfTime
---@license 0BSD

local utils = require 'mp.utils'

local xorg = os.getenv('XDG_SESSION_TYPE') == 'x11'

local MULTIMEDIA = table.concat({
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

local SUBTITLES = table.concat({
    '*.ass',
    '*.srt',
    '*.ssa',
    '*.sub',
    '*.txt',
}, ' ')

local ICON = 'mpv'

---@class KDOpts
---@field title string
---@field text string
---@field default? string
---@field type? string
---@field args string[]

---@param opts KDOpts
---@return fun()
local function KDialog(opts)
    return function()
        local path = mp.get_property('path')
        path = path == nil and '' or utils.split_path(
            utils.join_path(utils.getcwd(), path)
        )
        local args = {
            'kdialog', opts.default or path,
            '--title', opts.title,
            '--icon', ICON,
            '--multiple', '--separate-output',
            opts.type or '--getopenfilename', opts.text,
        }
        local ontop = mp.get_property_native('ontop')
        if xorg then
            local focus = utils.subprocess {
                args = {'xdotool', 'getwindowfocus'}
            }.stdout:gsub('\n$', '')
            table.insert(args, 5, '--attach')
            table.insert(args, 6, focus)
        end
        mp.set_property_native('ontop', false)
        local kdialog = utils.subprocess {
            args = args, cancellable = false
        }
        mp.set_property_native('ontop', ontop)
        if kdialog.status ~= 0 then return end
        for file in kdialog.stdout:gmatch('[^\n]+') do
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
