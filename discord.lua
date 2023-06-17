local utils = require 'mp.utils'
local msg = require 'mp.msg'

---@class DiscordOptions
---@field timeout integer
---@field keybind string
---@field enabled boolean
---@field invidious string
---@field piped string
---@field nitter string
---@field libreddit string
---@field client_id string
local o = {
    timeout = 2,
    keybind = 'D',
    enabled = false,
    invidious = 'yewtu%.be',
    piped = 'piped%.kavin%.rocks',
    nitter = 'nitter%.net',
    libreddit = 'libredd%.it',
    client_id = '700723249889149038'
}
require('mp.options').read_options(o, 'discord')

---@return string
local function uuid()
    math.randomseed(mp.get_time() * 1e4)
    local tpl = 'XXXXXXXX-XXXX-4XXX-%xXXX-XXXXXXXXXXXX'
    return tpl:format(math.random(8, 0xb)):gsub('X', function(_)
        return ('%x'):format(math.random(0, 0xf))
    end)
end

---@param str string
---@return string
local function tohex(str)
    return str:gsub('.', function(c)
        return ('\\x%02x'):format(c:byte())
    end)
end

---@type string
local VERSION = mp.get_property('mpv-version')

---@enum OP
local OP = {AUTHENTICATE = 0, FRAME = 1, CLOSE = 2}

---@class unixstream
---@field connect fun()
---@field receive fun()
---@field send fun()

---@class RPC
---@field socket integer|file*|unixstream?
---@field pid integer
---@field unix boolean
---@field path string
---@field _last string?
local RPC = {
    socket = nil,
    pid = utils.getpid(),
    unix = package.config:sub(1, 1) == '/'
}

if RPC.unix then
    local temp = os.getenv('XDG_RUNTIME_DIR')
              or os.getenv('TMPDIR')
              or os.getenv('TMP')
              or os.getenv('TEMP')
              or '/tmp'
    RPC.path = temp..'/discord-ipc-0'
    if _G.jit then
        msg.verbose('using', _G.jit.version)
        local ffi = require 'ffi'
        ffi.cdef[[
            struct sockaddr {
                unsigned short int sa_family;
                char sa_data[14];
            };
            struct sockaddr_un {
                unsigned short int sun_family;
                char sun_path[108];
            };
            int socket(int domain, int type, int protocol);
            int connect(int fd, const struct sockaddr *addr, unsigned int len);
            int recv(int fd, void *buf, unsigned int len, int flags);
            int send(int fd, const void *buf, unsigned int n, int flags);
            int close(int fd);
            char *strerror(int errnum);
        ]]
        ---@return string
        function RPC._strerror()
            return ffi.string(ffi.C.strerror(ffi.errno()))
        end
        ---@param fd integer
        ---@param addr ffi.cdata*
        ---@return integer
        function RPC._connect(fd, addr)
            local cast = ffi.cast('const struct sockaddr *', addr)
            return ffi.C.connect(fd, cast, ffi.sizeof(addr[0]))
        end
        ---@param fd integer
        ---@param len integer
        ---@return boolean, string
        function RPC._recv(fd, len)
            local buff = ffi.new('unsigned char[?]', len)
            local status = ffi.C.recv(fd, buff, len, 0) ~= -1
            return status, status and ffi.string(buff, len) or RPC._strerror()
        end
    else
        local socket = assert(require 'socket')
        msg.verbose('using', socket._VERSION)
    end
else
    RPC.path = [[\\.\pipe\discord-ipc-0]]
end

---@class Assets
---@field large_image string
---@field large_text string?
---@field small_image string?
---@field small_text string?

---@class Timestamps
---@field start integer
---@field end integer?

---@class Button
---@field label string
---@field url string

---@class Activity
---@field details string
---@field state string?
---@field timestamps Timestamps?
---@field buttons Button[]?
---@field assets Assets
RPC.activity = {
    details = 'No file',
    state = nil,
    timestamps = nil,
    buttons = nil,
    assets = {
        large_image = 'mpv',
        large_text = VERSION,
        small_image = 'stop',
        small_text = 'Idle'
    }
}

---@return integer
function RPC.get_time()
    local pos = mp.get_property_number('time-pos', 0)
    return math.floor(os.time() - pos)
end

---@param op OP
---@param body string?
---@return string
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

---@param body string?
---@return number, number
function RPC.unpack(body)
    local byte
    local op = 0
    local len = 0
    local iter = 1
    assert(body, 'empty body')
    for j = 1, 4 do
        byte = body:sub(iter, iter):byte()
        op = op + byte * (2 ^ ((j - 1) * 8))
        iter = iter + 1
    end
    for j = 1, 4 do
        byte = body:sub(iter, iter):byte()
        len = len + byte * (2 ^ ((j - 1) * 8))
        iter = iter + 1
    end
    return math.floor(op), math.floor(len)
end

---@return boolean
function RPC:connect()
    local status, data
    if _G.jit then
        local ffi = package.loaded.ffi
        local addr = ffi.new('struct sockaddr_un[1]', {{
            sun_family = 1, -- AF_UNIX
            sun_path = self.path
        }})
        self.socket = ffi.C.socket(1, 1, 0) -- AF_UNIX, SOCK_STREAM, 0
        if self.socket ~= -1 then
            status = self._connect(self.socket, addr)
            if status ~= -1 then return true end
        end
        data = self._strerror()
    elseif self.unix then
        self.socket = require 'socket.unix' ()
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

---@param len integer
---@return string?
function RPC:recv(len)
    if not self.socket then
        assert(self:connect(), 'failed to connect')
    end
    local status, data
    if _G.jit then
        status, data = self._recv(self.socket, len)
    elseif self.unix then
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
    msg.debug('received', tohex(data))
    assert(data:len() == len, 'incorrect data length')
    return data
end

---@param op OP
---@param body string?
function RPC:send(op, body)
    if not self.socket then
        assert(self:connect(), 'failed to connect')
    end
    local data = self.pack(op, body)
    msg.debug('sending', tohex(data))
    if _G.jit then
        local status = package.loaded.ffi.C
            .send(self.socket, data, #data, 0)
        assert(status ~= -1, self._strerror())
    elseif self.unix then
        assert(self.socket:send(data))
    else
        assert(self.socket:write(data))
        self.socket:flush()
    end
end

---@param version? integer
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

---@return string?
function RPC:set_activity()
    if self.activity.details:len() > 127 then
        self.activity.details = self.activity.details:sub(1, 126)..'…'
    end
    local nonce = uuid()
    local body = utils.format_json {
        cmd = 'SET_ACTIVITY', nonce = nonce,
        args = {activity = self.activity, pid = self.pid}
    }
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
        if _G.jit then
            local status = package.loaded.ffi.C.close(self.socket)
            assert(status ~= -1, self._strerror())
        else
            self.socket:close()
        end
        self.socket = nil
    end
end

mp.register_event('idle-active', function()
    RPC.activity = {
        details = 'No file',
        state = nil,
        buttons = nil,
        timestamps = nil,
        assets = {
            small_image = 'stop',
            small_text = 'Idle',
            large_image = 'mpv',
            large_text = VERSION
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
        local item = mp.get_property('playlist-pos')
        plist = (' [%d/%d]'):format(item + 1, plist)
        item = mp.get_property(('playlist/%d/title'):format(item))
        if item then title = item end
    else
        plist = ''
    end
    local path = mp.get_property('path')
    if path and path:find('^https?://') then
        if path:find('youtube%.com') or
           path:find('youtu%.be') then
            RPC.activity.assets.large_image = 'youtube'
        elseif path:find('twitch%.tv') then
            RPC.activity.assets.large_image = 'twitch'
        elseif path:find('cdn%.discordapp%.com') or
               path:find('media%.discordapp%.net') then
            RPC.activity.assets.large_image = 'discord'
        elseif path:find('drive%.google%.') then
            RPC.activity.assets.large_image = 'drive'
        elseif path:find('twitter%.com') then
            RPC.activity.assets.large_image = 'twitter'
        elseif path:find('reddit%.com') or
               path:find('redd%.it') then
            RPC.activity.assets.large_image = 'reddit'
        elseif path:find(o.invidious) then
            RPC.activity.assets.large_image = 'invidious'
        elseif path:find(o.piped) then
            RPC.activity.assets.large_image = 'piped'
        elseif path:find(o.nitter) then
            RPC.activity.assets.large_image = 'nitter'
        elseif path:find(o.libreddit) then
            RPC.activity.assets.large_image = 'libreddit'
        else
            RPC.activity.assets.large_image = 'stream'
        end
        RPC.activity.buttons = {
            {label = 'Open URL', url = path}
        }
    else
        RPC.activity.buttons = nil
        RPC.activity.assets.large_image = 'mpv'
    end
    RPC.activity.details = title
    RPC.activity.state = time..plist
    RPC.activity.assets.small_image = 'pause'
    RPC.activity.assets.small_text = 'Paused'
    RPC.activity.timestamps = nil
end)

mp.register_event('shutdown', function()
    RPC:disconnect()
end)

mp.register_event('seek', function()
    if not mp.get_property_bool('pause') then
        RPC.activity.timestamps = {start = RPC.get_time()}
    end
end)

mp.observe_property('paused-for-cache', 'bool', function(_, value)
    if value then
        RPC.activity.timestamps = nil
        RPC.activity.assets.small_image = 'play'
        RPC.activity.assets.small_text = 'Playing'
    else
        RPC.activity.timestamps = {start = RPC.get_time()}
        RPC.activity.assets.small_image = 'play'
        RPC.activity.assets.small_text = 'Playing'
    end
end)

mp.observe_property('core-idle', 'bool', function(_, value)
    if value then
        RPC.activity.timestamps = nil
        RPC.activity.assets.small_image = 'pause'
        RPC.activity.assets.small_text = 'Loading'
    else
        RPC.activity.timestamps = {start = RPC.get_time()}
        RPC.activity.assets.small_image = 'play'
        RPC.activity.assets.small_text = 'Playing'
    end
end)

mp.observe_property('pause', 'bool', function(_, value)
    if value then
        RPC.activity.timestamps = nil
        RPC.activity.assets.small_image = 'pause'
        RPC.activity.assets.small_text = 'Paused'
    else
        RPC.activity.timestamps = {start = RPC.get_time()}
        RPC.activity.assets.small_image = 'play'
        RPC.activity.assets.small_text = 'Playing'
    end
end)

mp.observe_property('eof-reached', 'bool', function(_, value)
    if value then
        RPC.activity.timestamps = nil
        RPC.activity.assets.small_image = 'stop'
        RPC.activity.assets.small_text = 'Idle'
    end
end)

local timer = mp.add_periodic_timer(o.timeout, function()
    local curr = utils.format_json(RPC.activity)
    if RPC._last ~= curr then
        RPC:set_activity()
        RPC._last = curr
    end
end)

mp.add_key_binding(o.keybind, 'toggle-discord-rpc', function()
    o.enabled = not o.enabled
    if o.enabled then
        RPC:handshake()
        timer:resume()
    else
        RPC._last = nil
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
