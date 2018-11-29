--
-- base64.lua
--
-- URL safe base64 encoder/decoder
--

-- https://github.com/diegonehab/luasocket
local mime = require 'mime'
local _M = {}

--- base64 encoder
--
-- @param s String to encode (can be binary data)
-- @return Encoded string
function _M.encode(s)
    local u
    local padding_len = 2 - ((#s-1) % 3)

    if padding_len > 0 then
        u = mime.b64(s):sub(1, - padding_len - 1)
    else
        u = mime.b64(s)
    end

    if u then
        return u:gsub('[+]', '-'):gsub('[/]', '_')
    else
        return nil
    end
end

--- base64 decoder
--
-- @param s String to decode
-- @return Decoded string (can be binary data)
function _M.decode(s)
    local e = s:gsub('[-]', '+'):gsub('[_]', '/')
    local u, _ = mime.unb64(e .. string.rep('=', 3 - ((#s - 1) % 4)))

    return u
end

return _M
