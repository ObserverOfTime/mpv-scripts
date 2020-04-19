utils = require 'mp.utils'
msg = require 'mp.msg'

local o = {
    timeout = 2,
    keybind = 'D',
    enabled = false,
    client_id = '700723249889149038'
}
require('mp.options').read_options(o, 'discord')

function string.uuid()
    math.randomseed(mp.get_time() * 1e4)
    local tpl = 'XXXXXXXX-XXXX-4XXX-%xXXX-XXXXXXXXXXXX'
    return tpl:format(math.random(8, 0xb)):gsub('X', function(c)
        return ('%x'):format(math.random(0, 0xf))
    end)
end

function string:tohex()
    return self:gsub('.', function(c)
        return ('\\x%02x'):format(string.byte(c))
    end)
end

MPV = mp.get_property('mpv-version')

OP = {AUTHENTICATE = 0, FRAME = 1, CLOSE = 2}

RPC = {
    socket = nil,
    pid = utils.getpid(),
    unix = package.config:sub(1, 1) == '/'
}

if RPC.unix then
    local temp = os.getenv('XDG_RUNTIME_DIR')
        or os.getenv('TMPDIR')
        or os.getenv('TEMP')
        or os.getenv('TMP')
        or '/tmp'
    RPC.path = temp..'/discord-ipc-0'
else
    RPC.path = [[\\?\pipe\discord-ipc-0]]
end

RPC.activity = {
    details = 'No file',
    state = nil,
    timestamps = {},
    assets = {
        large_image = 'mpv',
        large_text = MPV,
        small_image = 'stop',
        small_text = 'Idle'
    }
}

function RPC.pack(op, body)
    local bytes = {}
    assert(body, 'empty body')
    local len = body:len()
    for _ = 1, 4 do
        table.insert(bytes, string.char(op % (2 ^ 8)))
        op = math.floor(op / (2 ^ 8))
    end
    for _ = 1, 4 do
        table.insert(bytes, string.char(len % (2 ^ 8)))
        len = math.floor(len / (2 ^ 8))
    end
    return table.concat(bytes, '')..body
end

function RPC.unpack(body)
    local op = 0
    local len = 0
    local iter = 1
    local byte = nil
    assert(body, 'empty body')
    for j = 1, 4 do
        byte = string.byte(body:sub(iter, iter))
        op = op + byte * (2 ^ ((j - 1) * 8))
        iter = iter + 1
    end
    for j = 1, 4 do
        byte = string.byte(body:sub(iter, iter))
        len = len + byte * (2 ^ ((j - 1) * 8))
        iter = iter + 1
    end
    return math.floor(op), math.floor(len)
end

function RPC:connect()
    local status, data
    if self.unix then
        self.socket = assert(require 'socket.unix' ())
        status, data = pcall(function()
            assert(self.socket:connect(self.path))
        end)
        if status then return true end
    else
        status, data = pcall(function()
            return assert(io.open(self.path, 'r+b'))
        end)
        self.socket = data
        if status then return true end
    end
    self.socket = nil
    msg.fatal(data, '('..self.path..')')
    return false
end

function RPC:recv(len)
    if not self.socket then
        assert(self:connect(), 'failed to connect')
    end
    local status, data
    if self.unix then
        status, data = pcall(function()
            return assert(self.socket:receive(len))
        end)
    else
        status, data = pcall(function()
            return assert(self.socket:read(len))
        end)
    end
    if not status then
        msg.error(data)
        return nil
    end
    assert(string.len(data) == len, 'incorrect data length')
    msg.debug('received', data:tohex())
    return data
end

function RPC:send(op, body)
    if not self.socket then
        assert(self:connect(), 'failed to connect')
    end
    local data = self.pack(op, body)
    msg.debug('sending', data:tohex())
    if self.unix then
        assert(self.socket:send(data))
    else
        assert(self.socket:write(data))
        self.socket:flush()
    end
end

function RPC:handshake(version)
    local body = utils.format_json {
        v = version or 1,
        client_id = o.client_id
    }
    self:send(OP.AUTHENTICATE, body)
    local op, len = self.unpack(self:recv(8))
    local res = utils.parse_json(self:recv(len))
    assert(op == OP.FRAME, res.message)
    assert(res.evt == 'READY', res.message)
    msg.verbose('performed handshake')
end

function RPC:set_activity()
    if self.activity.details:len() > 127 then
        self.activity.details = self.activity.details:sub(1, 126)..'…'
    end
    local nonce = string.uuid()
    local body = utils.format_json {
        cmd = 'SET_ACTIVITY', nonce = nonce,
        args = {activity = self.activity, pid = self.pid}
    }:gsub('%[]', '{}')
    self:send(OP.FRAME, body)
    local res = self:recv(8)
    if not res then
        msg.info('reattempting to set activity')
        return self:set_activity()
    end
    local _, len = self.unpack(res)
    res = utils.parse_json(self:recv(len))
    if not res then
        msg.info('reattempting to set activity')
        return self:set_activity()
    end
    assert(res.cmd == 'SET_ACTIVITY', 'incorrect cmd')
    assert(res.nonce == nonce, 'incorrect nonce')
    if res.evt == 'ERROR' then
        msg.error(res.data.message)
        return nil
    end
    return body
end

function RPC:disconnect()
    if self.socket then
        self:send(OP.CLOSE, '')
        self.socket:close()
        self.socket = nil
    end
end

mp.register_event('idle', function()
    RPC.activity = {
        details = 'No file',
        state = nil,
        timestamps = {},
        assets = {
            small_image = 'stop',
            small_text = 'Idle',
            large_image = 'mpv',
            large_text = MPV
        }
    }
end)

mp.register_event('file-loaded', function()
    local title = mp.get_property('media-title') or 'Untitled'
    local artist = mp.get_property('metadata/by-key/Artist')
    title = artist and title..' - '..artist or title
    local time = mp.get_property_number('duration')
    time = time and 'Duration: '..os.date('!%T', time) or ''
    local plist = mp.get_property_number('playlist-count')
    if plist > 1 then
        local pos = mp.get_property('playlist-pos-1')
        plist = (' [%d/%d]'):format(pos, plist)
    else
        plist = ''
    end
    local path = mp.get_property('path')
    if path and path:find('^https?://') then
        if path:find('youtube%.com') or path:find('youtu%.be') then
            RPC.activity.assets.large_image = 'youtube'
        elseif path:find('invidio%.us') or path:find('yewtu%.be') then
            RPC.activity.assets.large_image = 'invidious'
        elseif path:find('twitch%.tv') then
            RPC.activity.assets.large_image = 'twitch'
        elseif path:find('twitter%.com') then
            RPC.activity.assets.large_image = 'twitter'
        elseif path:find('discordapp%.com') then
            RPC.activity.assets.large_image = 'discord'
        else
            RPC.activity.assets.large_image = 'stream'
        end
        RPC.activity.assets.large_text = path
    else
        RPC.activity.assets.large_image = 'mpv'
        RPC.activity.assets.large_text = MPV
    end
    RPC.activity.details = title
    RPC.activity.state = time..plist
    RPC.activity.assets.small_image = 'pause'
    RPC.activity.assets.small_text = 'Paused'
    RPC.activity.timestamps = {}
end)

mp.register_event('shutdown', function()
    RPC:disconnect()
end)

mp.register_event('seek', function()
    local pos = mp.get_property_number('time-pos')
    RPC.activity.timestamps = {
        start = math.floor(os.time() - (pos or 0))
    }
end)

mp.observe_property('paused-for-cache', 'bool', function(_, value)
    if value then
        RPC.activity.timestamps = {}
        RPC.activity.assets.small_image = 'play'
        RPC.activity.assets.small_text = 'Playing'
    else
        local pos = mp.get_property_number('time-pos')
        RPC.activity.timestamps = {
            start = math.floor(os.time() - (pos or 0))
        }
        RPC.activity.assets.small_image = 'play'
        RPC.activity.assets.small_text = 'Playing'
    end
end)

mp.observe_property('core-idle', 'bool', function(_, value)
    if value then
        RPC.activity.timestamps = {}
        RPC.activity.assets.small_image = 'pause'
        RPC.activity.assets.small_text = 'Loading'
    else
        local pos = mp.get_property_number('time-pos')
        RPC.activity.timestamps = {
            start = math.floor(os.time() - (pos or 0))
        }
        RPC.activity.assets.small_image = 'play'
        RPC.activity.assets.small_text = 'Playing'
    end
end)

mp.observe_property('pause', 'bool', function(_, value)
    if value then
        RPC.activity.timestamps = {}
        RPC.activity.assets.small_image = 'pause'
        RPC.activity.assets.small_text = 'Paused'
    else
        local pos = mp.get_property_number('time-pos')
        RPC.activity.timestamps = {
            start = math.floor(os.time() - (pos or 0))
        }
        RPC.activity.assets.small_image = 'play'
        RPC.activity.assets.small_text = 'Playing'
    end
end)

mp.observe_property('eof-reached', 'bool', function(_, value)
    if value then
        RPC.activity.timestamps = {}
        RPC.activity.assets.small_image = 'stop'
        RPC.activity.assets.small_text = 'Idle'
    end
end)

timer = mp.add_periodic_timer(o.timeout, function()
    local curr = utils.format_json(RPC.activity)
    if timer._last ~= curr then
        RPC:set_activity()
        timer._last = curr
    end
end)

mp.add_key_binding(o.keybind, 'toggle-discord-rpc', function()
    o.enabled = not o.enabled
    if o.enabled then
        RPC:handshake()
        timer:resume()
    else
        timer._last = nil
        RPC:disconnect()
        timer:kill()
    end
end)

if o.enabled then
    RPC:handshake()
    RPC:set_activity()
else
    timer:kill()
end
