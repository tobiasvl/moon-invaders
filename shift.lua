local bit = bit or require "bit32"

local shift_register = {}

local value = 0
local offset = 0

function shift_register.shift(new_value)
    value = bit.rshift(value, 8)
    new_value = bit.lshift(bit.band(new_value, 0xFF), 8)
    value = bit.bor(value, new_value)
end

function shift_register.set_offset(new_offset)
    offset = bit.band(new_offset, 0x07)
end

function shift_register.read()
    return bit.rshift(value, 8 - offset)
end

return shift_register