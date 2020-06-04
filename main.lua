local util = require "util"
local shift_register = require "shift"
local ui = require "ui"
local lua_8080 = require "lua-8080"
local cpu = lua_8080.cpu
local bus = lua_8080.bus
local rom = lua_8080.rom
local ram = lua_8080.ram
local cycles = 0
local interrupts = {1, 2}

function love.load(arg)
    -- Load ROM data into ROM chips and connect them to the bus
    local address = 0
    local rom_files = love.filesystem.getDirectoryItems("assets/m/")
    table.sort(rom_files, function(a, b) return a > b end)
    for i, file in ipairs(rom_files) do
        local rom_part = util.read_file("assets/m/" .. file)

        -- Read high score from save file and write it to ROM
        if file == "invaders.e" then
            local savefile = love.filesystem.newFile("hiscore")
            local ok = savefile:open("r")
            if ok then
                for address = 0x03F4, 0x03F5 do
                    rom_part[address] = string.byte(savefile:read(1))
                end
                savefile:close()
            end
        end

        local r = rom(rom_part)
        bus:connect(address, r)
        address = address + r.size
    end

    -- Connect RAM to the bus
    local wram = ram(0x0400, 0)
    local vram = ram(0x1C00, 0)

    -- Expose mirror RAM
    for address = 0x2000, 0xE000, 0x2000 do
        bus:connect(address, wram)
        bus:connect(address + 0x0400, vram)
    end

    -- Initialize CPU
    cpu:init(bus)

    -- Set up IO ports with constant values
    cpu.ports.internal.input[0] = 0x0E
    cpu.ports.internal.input[1] = 0x08
    cpu.ports.internal.input[2] = 0x00

    -- Set up IO ports connected to the hardware shift register
    cpu.ports.internal.output[2] = shift_register.set_offset
    cpu.ports.internal.input[3] = shift_register.read
    cpu.ports.internal.output[4] = shift_register.shift

    -- Initialize UI
    ui.init(cpu, bus)
end

function love.update(dt)
    local num_interrupts = 0
    -- Cycle the CPU for half a frame
    -- TODO: Should probably do it by cycles
    while num_interrupts ~= 2 do
        cycles = cycles + cpu:cycle()
        -- Twice per frame, the display logic requests an interrupt.
        -- Interrupt 1 (RST 0x08) in the middle of the frame,
        -- and interrupt 2 (RST 0x10) at the end. The 8080 runs at
        -- 2 MHz, so every 1 MHz we request an interrupt, alternating
        -- between 1 and 2.
        if cycles >= 1000000 / 30 and cpu.inte then
            -- Disable interrupts
            cpu.inte = false
            -- Consume cycles
            cycles = cycles - (1000000 / 30)
            -- The display outputs an RST opcode on the data bus
            -- which the CPU fetches and executes
            cycles = cycles + cpu:execute({
                instruction = "RST",
                op1 = interrupts[(num_interrupts % 2) + 1]
            })
            num_interrupts = num_interrupts + 1
        end

    end
end

function love.quit()
    -- Save high score to file
    local file = love.filesystem.newFile("hiscore")
    file:open("w")
    for address = 0x20F4, 0x20F5 do
        file:write(string.char(bus[address]), 1)
    end
    file:close()
end