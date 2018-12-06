--
-- authorize.lua
--
-- Connection / request authorization when HAProxy is used as a "proxy" in
-- a service mesh managed by consul connect
--
--
-- Copyright (c) 2017-2018. Baptiste Assmann <bassmann@haproxy.com>
-- Copyright (c) 2017-2018. HAProxy Technologies, LLC.
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, version 2 of the License

--package.path = package.path .. ';/opt/hapee-1.8/usr/lib/lua/?.lua'

local http = require("socket.http")
local ltn12 = require("ltn12")
local json = require("cjson")
local x509 = require("openssl.x509")

cache = {}

-- return true if the key is in the cache, return false otherwise
local function checkCache(key)
  if cache[key] == nil then
    return false
  end
  return true
end

-- return true if the key in the cache has expired
local function hasExpired(key)
  if not checkCache(key) then
    return true
  end

  local now = core.now()["sec"]

  if now - cache[key]["timestamp"] < 1 then
    return false
  end

  return true
end

local function setCache(spiffie_url, auth_status, reason)
  cache[spiffie_url] = {}
  cache[spiffie_url]["authorized"] = auth_status
  cache[spiffie_url]["reason"] = reason
  cache[spiffie_url]["timestamp"] = core.now()["sec"]
end

core.register_action("authorize", { "http-req", "tcp-req" }, function(txn)
  local serial = txn.f:ssl_c_serial()
  local der = txn.sf:ssl_c_der()
  local client_cert_url = ''
  local headers = {}
  local request_body = ''
  local response_body = {}
  local target = txn.sf:fe_name()

  -- this is due to a 'second' call, need to troubleshoot why
  -- this function is called twice in TCP mode
  if type(der) == 'nil' then
    txn.set_var(txn, "txn.SpiffeUrl", "-")
    txn.set_var(txn, "txn.Authorized", "false")
    txn.set_var(txn, "txn.Reason", "Error parsing client certificate")
    return
  end

  -- collecting client cert spiffe URL and client certificate serial

  local mycert = x509.new(der, "DER")
  if mycert ~= nil then
    local myext = mycert:getExtension('X509v3 Subject Alternative Name')
    client_cert_url = string.gsub(myext:text(), 'URI:', '')
    txn.set_var(txn, "txn.SpiffeUrl", client_cert_url)
  end

  serial = txn.c:hex(serial)

  if not hasExpired(client_cert_url) then
    txn.set_var(txn, "txn.Authorized", cache[client_cert_url]["authorized"])
    txn.set_var(txn, "txn.Reason", cache[client_cert_url]["reason"])
    return
  end

  -- prepate and run the HTTP request to consul connect
  -- update the target to remove the 'f_' prefix
  target = string.sub(target, 3)
  request_body = json.encode({ Target = target, ClientCertURI = client_cert_url, ClientCertSerial = serial })
  print("DEBUG: " .. request_body)
  headers['Content-Type'] = 'application/json'
  headers['Content-Length'] = #request_body

  local b, c, h = http.request {
    url = "http://127.0.0.1:8500/v1/agent/connect/authorize",
    --create = core.tcp,
    method = "POST",
    headers = headers,
    source = ltn12.source.string(request_body),
    sink = ltn12.sink.table(response_body)
  }

  -- analyze the feedback from consul connect
  if c == nil or c ~= 200 then
    setCache(client_cert_url, "false", "Not authorized by consul")
    txn.set_var(txn, "txn.Authorized", "false")
    txn.set_var(txn, "txn.Reason", 'Not authorized by consul')
    return
  end

  local myjson = json.decode(table.concat(response_body))
  if myjson['Authorized'] == nil or myjson['Authorized'] ~= true then
    txn.set_var(txn, "txn.Authorized", "false")
    if myjson['Reason'] ~= nil then
      setCache(client_cert_url, "false", myjson['Reason'])
      txn.set_var(txn, "txn.Reason", myjson['Reason'])
    else
      setCache(client_cert_url, "false", 'Not authorized by consul')
      txn.set_var(txn, "txn.Reason", 'Not authorized by consul')
    end
    return
  end

  setCache(client_cert_url, "true", myjson['Reason'])

  txn.set_var(txn, "txn.Authorized", "true")
  txn.set_var(txn, "txn.Reason", myjson['Reason'])
end)
