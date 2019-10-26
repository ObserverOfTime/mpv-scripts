-- luacheck: ignore 131

std = 'lua52c'

read_globals = {'mp'}

allow_defined_top = true

max_line_length = 80

max_comment_line_length = false

include_files = {
    'clipshot.lua',
    'misc.lua',
    'open-dialog/*.lua'
}

files['open-dialog/zenity.lua'] = {
    globals = {'table.merge'}
}

-- vim: ft=lua
