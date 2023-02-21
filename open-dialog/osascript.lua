local utils = require 'mp.utils'

local MULTIMEDIA = utils.format_json({
    'AAC',
    'AVI',
    'FLAC',
    'FLV',
    'M3U',
    'M3U8',
    'M4V',
    'MKV',
    'MOV',
    'MP3',
    'MP4',
    'MPEG',
    'MPG',
    'OGA',
    'OGG',
    'OGV',
    'OPUS',
    'WAV',
    'WEBM',
    'WMV',
})

local SUBTITLES = utils.format_json({
    'ASS',
    'SRT',
    'SSA',
    'SUB',
    'TXT',
})

---@class OSAOpts
---@field title string
---@field text string|nil
---@field args string[]
---@field language? string
---@field template? string

---@param opts OSAOpts
---@return fun()
local function OSAScript(opts)
    return function()
        local template = opts.template or [[
            var app = Application.currentApplication()
            app.includeStandardAdditions = true
            app.chooseFile({
                ofType: %s,
                withPrompt: %q,
                defaultLocation: %q,
                multipleSelectionsAllowed: true
            }).join("\n\r")
        ]]
        local language = opts.language or 'AppleScript'
        local path = mp.get_property('path')
        path = path == nil and '.' or utils.split_path(
            utils.join_path(utils.getcwd(), path)
        )
        local ontop = mp.get_property_native('ontop')
        mp.set_property_native('ontop', false)
        local osascript = utils.subprocess {
            args = {
                'osascript', '-l', language, '-e',
                template:format(opts.text, opts.title, path)
            }, cancellable = false
        }
        mp.set_property_native('ontop', ontop)
        if osascript.status ~= 0 then return end
        for file in osascript.stdout:gmatch('[^\r\n]+') do
            mp.commandv(opts.args[1], file, opts.args[2])
        end
    end
end

mp.add_key_binding('Ctrl+f', 'open-files', OSAScript {
    title = 'Select Media Files',
    text = MULTIMEDIA,
    args = {'loadfile', 'append-play'},
    language = 'JavaScript'
})
mp.add_key_binding('Ctrl+F', 'open-url', OSAScript {
    title = 'Open URL',
    text = 'Enter the URL to open:',
    args = {'loadfile', 'replace'},
    template = [[
        try
            return text returned of ( ¬
                display dialog "Enter the URL to open:" ¬
                    with title "Open URL" default answer "" ¬
                    buttons {"Cancel", "OK"} default button 2)
        on error number -128
            return ""
        end try
    ]],
})
mp.add_key_binding('Alt+f', 'open-subs', OSAScript {
    title = 'Select Subtitles',
    text = SUBTITLES,
    args = {'sub-add', 'select'},
    language = 'JavaScript'
})
