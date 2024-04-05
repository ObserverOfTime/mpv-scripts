---@diagnostic disable: lowercase-global

std = 'luajit'

read_globals = {'mp'}

allow_defined_top = false

max_line_length = 100

max_comment_line_length = false

include_files = {
    'clipshot.lua',
    'discord.lua',
    'misc.lua',
    'open-dialog/*.lua'
}
