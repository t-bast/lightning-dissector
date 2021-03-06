local bin = require "plc52.bin"
local basexx = require "basexx"
local Reader = require("lightning-dissector.utils").Reader
local convert_signature_der = require("lightning-dissector.utils").convert_signature_der
local OrderedDict = require("lightning-dissector.utils").OrderedDict
local f = require("lightning-dissector.constants").fields.payload.deserialized

function deserialize(payload)
  local reader = Reader:new(payload)

  local packed_signature = reader:read(64)
  local packed_flen = reader:read(2)
  local flen = string.unpack(">I2", packed_flen)
  local packed_features = reader:read(flen)
  local packed_timestamp = reader:read(4)
  local packed_node_id = reader:read(33)
  local packed_rgb_color = reader:read(3)
  local packed_alias = reader:read(32)
  local packed_addrlen = reader:read(2)
  local addrlen = string.unpack(">I2", packed_addrlen)
  local packed_addresses = reader:read(addrlen)

  local timestamp = string.unpack(">I4", packed_timestamp)

  local addresses = {}
  local addresses_reader = Reader:new(packed_addresses)
  while addresses_reader:has_next() do
    local packed_address_type = addresses_reader:read(1)
    local address_type = string.unpack(">I1", packed_address_type)

    if address_type == 1 then
      local packed_ipv4_addr = addresses_reader:read(4)
      local packed_port = addresses_reader:read(2)

      local building_ipv4_addr = {}
      for i = 1, 4 do
        local one_byte = string.unpack(">I1", packed_ipv4_addr:sub(i, i))
        table.insert(building_ipv4_addr, one_byte)
      end

      local ipv4_addr = table.concat(building_ipv4_addr, ".")
      local port = string.unpack(">I2", packed_port)

      table.insert(addresses, OrderedDict:new(
        f.addresses.deserialized.type, "IPv4",
        f.addresses.deserialized.addr, ipv4_addr,
        f.addresses.deserialized.port, port
      ))

    elseif address_type == 2 then
      local packed_ipv6_addr = addresses_reader:read(16)
      local packed_port = addresses_reader:read(2)

      local building_ipv6_addr = {}
      for i = 1, 16, 2 do
        local two_byte = bin.stohex(packed_ipv6_addr:sub(i, i + 1))
        table.insert(building_ipv6_addr, two_byte)
      end

      local ipv6_addr = table.concat(building_ipv6_addr, ":")
      local port = string.unpack(">I2", packed_port)

      table.insert(addresses, OrderedDict:new(
        f.addresses.deserialized.type, "IPv6",
        f.addresses.deserialized.addr, ipv6_addr,
        f.addresses.deserialized.port, port
      ))
    elseif address_type == 3 then
      local packed_v2_onion_addr = addresses_reader:read(10)
      local v2_onion_addr = basexx.to_base32(packed_v2_onion_addr)
      local packed_port = addresses_reader:read(2)

      table.insert(addresses, OrderedDict:new(
        f.addresses.deserialized.type, "Tor v2 onion service",
        f.addresses.deserialized.addr, v2_onion_addr .. ".onion",
        f.addresses.deserialized.port, string.unpack(">I2", packed_port)
      ))
    elseif address_type == 4 then
      local packed_v3_onion_addr = addresses_reader:read(32)
      local v3_onion_addr = basexx.to_base32(packed_v3_onion_addr)
      addresses_reader:read(3)  -- skip checksum
      local packed_port = addresses_reader:read(2)

      table.insert(addresses, OrderedDict:new(
        f.addresses.deserialized.type, "Tor v2 onion service",
        f.addresses.deserialized.addr, v3_onion_addr .. ".onion",
        f.addresses.deserialized.port, string.unpack(">I2", packed_port)
      ))
    end
  end

  return OrderedDict:new(
    "signature", OrderedDict:new(
      f.signature.raw, bin.stohex(packed_signature),
      f.signature.der, bin.stohex(convert_signature_der(packed_signature))
    ),
    "flen", OrderedDict:new(
      f.flen.raw, bin.stohex(packed_flen),
      f.flen.deserialized, flen
    ),
    f.features, bin.stohex(packed_features),
    "timestamp", OrderedDict:new(
      f.timestamp.raw, bin.stohex(packed_timestamp),
      f.timestamp.deserialized, timestamp
    ),
    f.node_id, bin.stohex(packed_node_id),
    f.rgb_color, "#" .. bin.stohex(packed_rgb_color),
    "alias", OrderedDict:new(
      f.alias.raw, bin.stohex(packed_alias),
      f.alias.deserialized, packed_alias
    ),
    "addrlen", OrderedDict:new(
      f.addrlen.raw, bin.stohex(packed_addrlen),
      f.addrlen.deserialized, addrlen
    ),
    "addresses", OrderedDict:new(
      f.addresses.raw, bin.stohex(packed_addresses),
      "Deserialized", addresses
    )
  )
end

return {
  number = 257,
  name = "node_announcement",
  deserialize = deserialize
}
