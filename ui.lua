local imgui = require 'imgui'
local moonshine = require 'moonshine'
local lg = love.graphics

local cpu, bus, deferred_port_write

-- Size of the CRT "pixels", before rotating the CRT display.
-- The pixels should be one scanline tall, but the scanlines shader uses some of those
-- pixel on the lines between each scanline. The pixels should be slightly wider than
-- they are tall.
local pixel_height = 3
local pixel_width = pixel_height * 1.333

-- Images and canvases
local gel = lg.newImage("assets/overlay.png")
local moon = lg.newImage("assets/invaders.png")
local display = lg.newCanvas(pixel_width * 256, pixel_height * 224)
local crt_display = lg.newCanvas(pixel_width * 256, pixel_height * 224)
local display_stencil = {display, stencil = true}

-- Shader setup
local shaders = {
    scanlines = true,
    glow = true,
    crt = true
}

-- Scanlines and CRT barrel effect are added first. They're fairly subtle.
local crt = moonshine(pixel_width * 256, pixel_height * 224, moonshine.effects.scanlines)
    .chain(moonshine.effects.crt)
crt.parameters = {
    scanlines = {
        width = pixel_height / 2,
        opacity = 0.5
    },
    crt = {
        distortionFactor = {
            1.02,
            1.065
        }
    }
}

-- The glow is added after the rotation because it preserves transparency, so the
-- height and width switch places here
local glow = moonshine(pixel_height * 224, pixel_width * 256, moonshine.effects.glow)
glow.parameters = {
    glow = {
        strength = 10,
        min_luma = 0.4
    }
}

-- The background gets a vignette so it looks illuminated from within the cabinet
local vignette = moonshine(lg.getWidth(), lg.getHeight(), moonshine.effects.vignette)

-- Toggle a single bit (wire) into an IO port
function toggle_port_bit(port, value)
    cpu.ports.internal.input[port] = bit.bxor(cpu.ports.internal.input[port], value)
end

function love.keypressed(key)
    if key == "left" then
        toggle_port_bit(0, 0x20)
        toggle_port_bit(1, 0x20)
    elseif key == "right" then
        toggle_port_bit(0, 0x40)
        toggle_port_bit(1, 0x40)
    elseif key == "space" then
        toggle_port_bit(0, 0x10)
        toggle_port_bit(1, 0x10)
    elseif key == "1" then
        toggle_port_bit(1, 0x04)
    elseif key == "2" then
        toggle_port_bit(1, 0x02)
    elseif key == "c" then
        toggle_port_bit(1, 0x01)
    elseif key == "t" then
        toggle_port_bit(2, 0x04)
    end
end

-- Since the keys are wired to single IO wires, we can just
-- toggle them again when the key is released.
love.keyreleased = love.keypressed

function love.draw()
    -- If a menu item toggled a port value in the last frame,
    -- we need to toggle it back now.
    if deferred_port_write then
        deferred_port_write()
        deferred_port_write = nil
    end

    imgui.NewFrame()
    if imgui.BeginMainMenuBar() then
        if imgui.BeginMenu("File") then
            if imgui.MenuItem("Open ROM...") then
                --filedialog = Filedialog.new("open", loadChip8File, function() end, love.filesystem.getSaveDirectory())
            end
            if imgui.IsItemHovered() then
                imgui.SetTooltip("Load Space Invaders ROM")
            end
            imgui.EndMenu()
        end
        if imgui.BeginMenu("Control") then
            if imgui.MenuItem("Insert coin", "C") then
                toggle_port_bit(1, 0x01)
                deferred_port_write = function() toggle_port_bit(1, 0x01) end
            end
            if imgui.MenuItem("Tilt", "T") then
                toggle_port_bit(2, 0x04)
                deferred_port_write = function() toggle_port_bit(2, 0x04) end
            end
            if imgui.MenuItem("Reset") then
                cpu.registers.pc = 0
            end
            imgui.EndMenu()
        end
        if imgui.BeginMenu("Settings") then
            if imgui.BeginMenu("Lives") then
                for i = 0, 3 do
                    if imgui.MenuItem(i + 3, nil, bit.band(cpu.ports.internal.input[2], 0x03) == i) then
                        cpu.ports.internal.input[2] = bit.band(cpu.ports.internal.input[2], 0xFC)
                        cpu.ports.internal.input[2] = bit.bor(cpu.ports.internal.input[2], i)
                    end
                end
                imgui.EndMenu()
            end
            if imgui.BeginMenu("Extra life at") then
                for i = 1, 0, -1 do
                    if imgui.MenuItem(i == 0 and 1500 or 1000, nil, bit.band(cpu.ports.internal.input[2], 0x08) == i * 8) then
                        toggle_port_bit(2, 0x08)
                    end
                end
                imgui.EndMenu()
            end
            if imgui.MenuItem("Display coin info on demo screen", nil, bit.band(cpu.ports.internal.input[2], 0x80) == 0x80) then
                toggle_port_bit(2, 0x80)
            end
            if imgui.MenuItem("Reset hi-score") then
                bus[0x20F4] = 0
                bus[0x20F5] = 0
            end
            imgui.EndMenu()
        end
        if imgui.BeginMenu("Display") then
            if imgui.MenuItem("Open ROM...") then
            end
            imgui.EndMenu()
        end
        imgui.EndMainMenuBar()
    end

    if drawflag then
        drawflag = false
        lg.setCanvas(display_stencil)
        lg.clear()
        for y = 0, 223 do
            for x = 0, 31 do
                local address = 0x2400 + (y * 32) + x
                local byte = bus[address]
                for xx = 0, 7 do
                    local pixel = bit.band(byte, 0x01)
                    byte = bit.rshift(byte, 1)
                    if pixel == 1 then
                        lg.stencil(function()
                            lg.rectangle("fill", (x * 8 * pixel_width) + (xx * pixel_width), y * pixel_height, pixel_width, pixel_height)
                        end, "replace", 1, true)
                    end
                end
            end
        end
        lg.setStencilTest("equal", 1)
        lg.draw(gel, 0, 0, 0, pixel_width, pixel_height)
        lg.setCanvas()
    end
    lg.setStencilTest()
    
    -- Draw the CRT screen
    lg.setCanvas(crt_display)
    crt(function()
        lg.draw(display)
    end)
    lg.setCanvas()

    -- Draw the backdrop
    lg.setColor(1,1,1,.7)
    vignette(function()
        lg.draw(moon, 0, 0, 0, lg.getWidth() / moon:getWidth(), lg.getHeight() / moon:getHeight())
    end)
    lg.setColor(1,1,1,1)

    -- Draw the rotated CRT reflection
    lg.setColor(.95,1,1,1)
    glow(function()
        lg.draw(
            crt_display,
            (lg.getWidth() / 2) - ((100 * pixel_width) / 2),
            0,
            math.rad(270),
            .6,
            .6,
            256 * pixel_width
        )
    end)

    imgui.Render()
end

function love.mousemoved(x, y)
    imgui.MouseMoved(x, y, true)
end

function love.mousepressed(_, _, button)
    imgui.MousePressed(button)
end

function love.mousereleased(_, _, button)
    imgui.MouseReleased(button)
end

return {
    init = function(_cpu, _bus)
        cpu, bus = _cpu, _bus
    end
}