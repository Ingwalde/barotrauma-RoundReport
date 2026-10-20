-- shared mock helpers: in-memory net message
function NewMsg()
  local q, i = {}, 0
  local m = {}
  function m.WriteString(v) q[#q+1] = tostring(v) end
  function m.WriteBoolean(v) q[#q+1] = v and true or false end
  function m.WriteSingle(v) q[#q+1] = v + 0.0 end
  function m.WriteUInt16(v) q[#q+1] = v end
  local function rd() i = i + 1; return q[i] end
  m.ReadString, m.ReadBoolean, m.ReadSingle, m.ReadUInt16 = rd, rd, rd, rd
  return m
end
