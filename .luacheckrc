-- luacheck: ignore 131

std = 'lua52'

globals = {'mp'}

allow_defined_top = true

max_line_length = 80

max_comment_line_length = false

files['open-dialog/zenity.lua'] = {
    globals = {'table.merge'}
}

-- vim: ft=lua
