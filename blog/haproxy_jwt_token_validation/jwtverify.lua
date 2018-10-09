--
-- jwtverify.lua
--
-- Copyright (c) 2018. Adis Nezirovic <anezirovic@haproxy.com>
-- Copyright (c) 2018. Baptiste Assmann <bassmann@haproxy.com>
-- Copyright (c) 2018. HAProxy Technologies LLC


-- Use HAProxy 'lua-load' to load optional configuration file which
-- should contain config table.

-- Default/fallback config
if not config then
    config = {
	debug = false,
        jwt_keys = {
            sign = nil,
            verify = nil
        }
    }
end

local json   = require 'json'
local base64 = require 'base64'

local openssl = {
    pkey = require 'openssl.pkey',
    digest = require 'openssl.digest'
}


local function log(msg)
    if config.debug then
        core.Debug(tostring(msg))
    end
end


function jwtverify(txn, arg1)
    local mytoken = {}
    local Authorization = ""
    local tmp
    local msg = ""
    local res = false
    local digest
    local vkey


    -- deserialize the Authorization header and store its content
    -- into the mytoken table
    Authorization = txn.sf:req_hdr("Authorization")
    tmp = core.tokenize(Authorization, " .")
    if #tmp ~= 4 then
        msg = "improperly formated Authorization header"
        goto out
    end
    if tmp[1] ~= 'Bearer' then
        msg = "improperly formated Authorization header"
        goto out
    end
    mytoken.header = tmp[2]
    mytoken.headerdecoded = base64.decode(mytoken.header)
    mytoken.payload = tmp[3]
    mytoken.payloaddecoded = base64.decode(mytoken.payload)
    mytoken.signature = tmp[4]
    mytoken.signaturedecoded = base64.decode(mytoken.signature)
    if config.debug then
        print('Authorization header: ' .. Authorization)
        print('Decoded JWT header: ' .. mytoken.headerdecoded)
        print('Decoded JWT payload: ' .. mytoken.payloaddecoded)
    end


    -- deserialize the token header and validate it's encoded
    -- with RS256 algorithm
    tmp = json.decode(base64.decode(mytoken.header))
    if tmp.alg == nil then
        msg = "No alg provided"
        goto out
    elseif tmp.alg ~= 'RS256' then
        msg = "Incorrect alg: " .. tmp.alg
        goto out
    end

 
    -- perform token signature validation
    -- If validation is fine and caller provided a list of fields
    -- to extract, then we do set the relevent HAProxy variables
    digest = openssl.digest.new('SHA256')
    digest:update(mytoken.header .. '.' .. mytoken.payload)
    vkey = openssl.pkey.new(config.jwt_keys.verify)
    res = vkey:verify(base64.decode(mytoken.signature), digest)
    if res == true and #arg1 > 0 then
        local args = core.tokenize(arg1, ",")
        tmp = json.decode(mytoken.payloaddecoded)
	for _, arg in pairs(args) do
            txn.set_var(txn, 'req.jwt' .. arg, tmp[arg])
        end
    end

    -- way out. Display a message when running in debug mode
 ::out::
    if msg ~= "" and config.debug then
        print("JWT: " .. msg)
    end
end
core.register_action('jwtverify', {'http-req'}, jwtverify, 1)
