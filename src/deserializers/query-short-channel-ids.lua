local bin = require "plc52.bin"
local Reader = require("lightning-dissector.utils").Reader
local OrderedDict = require("lightning-dissector.utils").OrderedDict
local f = require("lightning-dissector.constants").fields.payload.deserialized
local deserialize_short_ids = require("lightning-dissector.utils").deserialize_short_ids

function deserialize(payload)
  local reader = Reader:new(payload)

  local packed_chain_hash = reader:read(32)
  local packed_len = reader:read(2)
  local len = string.unpack(">I2", packed_len)
  local packed_short_ids = reader:read(len)

  return OrderedDict:new(
    f.chain_hash, bin.stohex(packed_chain_hash),
    "len", OrderedDict:new(
      f.len.raw, bin.stohex(packed_len),
      f.len.deserialized, len
    ),
    "encoded_short_ids", OrderedDict:new(
      f.encoded_short_ids.raw, bin.stohex(packed_short_ids),
      "Deserialized", deserialize_short_ids(packed_short_ids)
    )
  )
end

return {
  number = 261,
  name = "query_short_channel_ids",
  deserialize = deserialize
}
