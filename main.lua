local util = require "util"
local shift_register = require "shift"
local ui = require "ui"
local lua_8080 = require "lua-8080"
local cpu = lua_8080.cpu
local bus = lua_8080.bus
local rom = lua_8080.rom
local ram = lua_8080.ram
local sounds = {previous_state = {0, 0}}
local cycles = 0
local interrupts = {1, 2}

function love.load(arg)
    -- Load ROM data into ROM chips and connect them to the bus
    local address = 0

    local rom_files = {
        "invaders.h",
        "invaders.g",
        "invaders.f",
        "invaders.e"
    }

    local root_dir = ""
    if love.filesystem.isFused() and love.filesystem.mount(love.filesystem.getSourceBaseDirectory(), "fused_dir") then
        root_dir = "fused_dir/"
    end

    local num_files = 0
    for _, file in ipairs(rom_files) do
        local rom_part
        if love.filesystem.getInfo(root_dir .. "assets/" .. file) then
            rom_part = util.read_file(root_dir .. "assets/" .. file)
        end

        if rom_part then
            num_files = num_files + 1
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

    -- Sound
    cpu.ports.internal.output[3] = play_sound(1)
    cpu.ports.internal.output[5] = play_sound(2)

    -- Initialize UI
    ui.init(cpu, bus)

    -- If we didn't load the ROMs correctly, override love.update
    -- and love.draw to just display an error message
    if num_files ~= 4 then
        local font = love.graphics.newFont(20)
        function love.draw()
            love.graphics.setFont(font)
            love.graphics.printf(
                "Couldn't locate Space Invaders ROM files.\n" ..
                    "Please put them in one of the following locations:\n\n" ..
                        string.gsub(love.filesystem.getSourceBaseDirectory(), "/", "\\") ..
                            "\\assets\n" .. string.gsub(love.filesystem.getSaveDirectory(), "/", "\\") .. "\\assets",
                0,
                love.graphics.getHeight() / 3,
                love.graphics.getWidth(),
                "center"
            )
        end
        function love.update(dt)
        end
    end

    -- Alternate sound file names
    local sound_names = {
        "ufo_highpitch",
        "shoot",
        "explosion",
        "invaderkilled",
        "fastinvader1",
        "fastinvader2",
        "fastinvader3",
        "fastinvader4",
        "ufo_lowpitch",
        "extendedplay"
    }

    -- Load sound files
    for i = 0, 9 do
        if love.filesystem.getInfo(root_dir .. "assets/" .. i .. ".wav") then
            sounds[i] = love.audio.newSource(root_dir .. "assets/" .. i .. ".wav", "static")
        elseif love.filesystem.getInfo(root_dir .. "assets/" .. sound_names[i + 1] .. ".wav") then
            sounds[i] = love.audio.newSource(root_dir .. "assets/" .. sound_names[i + 1] .. ".wav", "static")
        end

        if sounds[0] then
            sounds[0]:setLooping(true) -- The UFO sound should loop
        end
    end
end

function play_sound(bank)
    return function(sound_mask)
        for i = 0, 4 do
            -- Should we play the sound?
            local play = bit.band(bit.rshift(sound_mask, i), 1) == 1

            -- Is it a rising edge?
            local playing = bit.band(bit.rshift(sounds.previous_state[bank], i), 1) == 1

            -- Look up sound source
            local sound
            if bank == 1 and i == 4 then
                -- The "extra life" sound file is called 9.wav for some reason
                sound = sounds[9]
            else
                sound = sounds[i + (bank == 2 and 4 or 0)]
            end

            if sound then
                -- Start the sound on a rising edge
                if play and not playing then
                    sound:play()
                end

                -- Stop it on a falling edge (for looping sounds)
                if sound:isLooping() and not play then
                    sound:stop()
                end
            end
        end

        -- Save the last port output for edge checking
        sounds.previous_state[bank] = sound_mask
    end
end

function love.update(dt)
    local num_interrupts = 0
    -- Cycle the CPU
    -- TODO: Should probably do it by cycles
    -- TODO: Use delta time instead of running two frames per frame
    while num_interrupts ~= 2 and not cpu.pause do
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
            cycles =
                cycles +
                cpu:execute(
                    {
                        instruction = "RST",
                        op1 = interrupts[(num_interrupts % 2) + 1]
                    }
                )
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
