---@type string
local TIME_FORMAT = '%H:%M'

mp.add_key_binding('Ctrl+t', 'show-time', function()
    mp.osd_message(os.date(TIME_FORMAT), 2)
end)
