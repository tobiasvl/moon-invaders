local bit = bit or require "bit32"
local moonshine = require "moonshine"
local lg = love.graphics

-- Load imgui; fail gracefully if it's not found
local ok, imgui = pcall(require, "imgui")
if not ok then
    imgui = nil
else
    function love.mousemoved(x, y)
        imgui.MouseMoved(x, y, true)
    end

    function love.mousepressed(_, _, button)
        imgui.MousePressed(button)
    end

    function love.mousereleased(_, _, button)
        imgui.MouseReleased(button)
    end
end

local cpu, bus, deferred_port_write, fullscreen

-- Images
local root_dir = ""
if love.filesystem.isFused() and love.filesystem.mount(love.filesystem.getSourceBaseDirectory(), "fused_dir") then
    root_dir = "fused_dir/"
end
local overlay
if love.filesystem.getInfo(root_dir .. "assets/overlay.png") then
    overlay = lg.newImage(root_dir .. "assets/overlay.png")
end
local background
if love.filesystem.getInfo(root_dir .. "assets/background.png") then
    background = lg.newImage(root_dir .. "assets/background.png")
end

local pixel_height, pixel_width, display, crt_display, display_stencil, crt, glow, vignette

-- Initialize (or re-initialize, in the case of a resize) the display
local function display_init(w, h)
    w = w or lg.getWidth()
    h = h or lg.getHeight()
    local ratio = 4 / 3
    -- Size of the CRT "pixels", before rotating the CRT display.
    -- The pixels should be one scanline tall, but the scanlines shader uses some of those
    -- pixel on the lines between each scanline. The pixels should be slightly wider than
    -- they are tall.
    if w / h > ratio then
        pixel_height = h / 200
        pixel_width = math.floor(pixel_height * ratio)
    else
        pixel_width = w / 200
        pixel_height = math.floor(pixel_width * 0.75)
    end

    -- Canvases
    display = lg.newCanvas(pixel_width * 256, pixel_height * 224)
    crt_display = lg.newCanvas(pixel_width * 256, pixel_height * 224)
    display_stencil = {display, stencil = true}

    -- Shader setup:

    -- Scanlines and CRT barrel effect are added first. They're fairly subtle.
    -- Note that these operate on the pre-rotated CRT display, because we want the
    -- scanlines to A) be vertical and B) take on the color of the gel overlay.
    crt = moonshine(pixel_width * 256, pixel_height * 224, moonshine.effects.scanlines).chain(moonshine.effects.crt)
    crt.parameters = {
        scanlines = {
            width = pixel_height / 2,
            frequency = pixel_height * 224,
            phase = 3,
            thickness = 1,
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
    glow = moonshine(w, h, moonshine.effects.glow)
    glow.parameters = {
        glow = {
            strength = 7,
            min_luma = 0.4
        }
    }

    -- The background gets a vignette so it looks illuminated from within the cabinet
    vignette = moonshine(w, h, moonshine.effects.vignette)
end

love.resize = display_init

-- Toggle a single bit (wire) into an IO port
local function toggle_port_bit(port, value)
    cpu.ports.internal.input[port] = bit.bxor(cpu.ports.internal.input[port], value)
end

local function toggle_fullscreen()
    fullscreen = not fullscreen
    love.window.setFullscreen(fullscreen, "desktop")
    display_init()
end

function love.mousepressed(_, _, button, istouch, presses)
    if button == 1 and not istouch and presses == 2 then
        toggle_fullscreen()
    end
end

function love.keypressed(key)
    if key == "left" or key == "a" then
        -- Player 1
        toggle_port_bit(1, 0x20)
        -- Player 2
        toggle_port_bit(2, 0x20)
    elseif key == "right" or key == "d" then
        -- Player 1
        toggle_port_bit(1, 0x40)
        -- Player 2
        toggle_port_bit(2, 0x40)
    elseif key == "space" then
        -- Player 1
        toggle_port_bit(1, 0x10)
        -- Player 2
        toggle_port_bit(2, 0x10)
    elseif key == "1" then
        toggle_port_bit(1, 0x04)
    elseif key == "2" then
        toggle_port_bit(1, 0x02)
    elseif key == "c" then
        toggle_port_bit(1, 0x01)
    elseif key == "t" then
        toggle_port_bit(2, 0x04)
    elseif key == "f11" then
        toggle_fullscreen()
    end
end

function love.gamepadpressed(joystick, button)
    local port
    for i, j in ipairs(love.joystick.getJoysticks()) do
        if j == joystick and (i == 1 or i == 2) then
            port = i
        end
    end

    -- Player specific
    if button == "dpleft" or button == "leftshoulder" then
        toggle_port_bit(port, 0x20)
    elseif button == "dpright" or button == "rightshoulder" then
        toggle_port_bit(port, 0x40)
    elseif button == "a" or button == "b" or button == "x" or button == "y" then
        toggle_port_bit(port, 0x10)
    end

    -- Either player
    if button == "start" then
        -- Start 1 or 2 players
        if love.joystick.getJoystickCount() == 1 then
            toggle_port_bit(1, 0x04)
        else
            toggle_port_bit(1, 0x02)
        end
    elseif button == "back" then
        -- Coin
        toggle_port_bit(1, 0x01)
    end
end

-- Since the keys are wired to single IO wires, we can just
-- toggle them again when the key is released.
love.gamepadreleased = love.gamepadpressed
function love.keyreleased(key)
    if key == "f11" then
        return
    else
        love.keypressed(key)
    end
end

local old_value = {0, 0}
function love.joystickaxis(joystick, axis, value)
    -- We're only interested in left/right
    if axis == 2 or axis == 4 then
        return
    end

    -- Find out if it's player 1 or player 2
    local port
    for player, joy in ipairs(love.joystick.getJoysticks()) do
        if joy == joystick and (player == 1 or player == 2) then
            port = player
        end
    end

    -- Use 0.2 as debounce threshold, seems to work OK
    if value > 0 and value < 0.2 then
        value = 0
    elseif value < 0 and value > -0.2 then
        value = 0
    end

    if old_value[port] < 0 and value == 0 or old_value[port] == 0 and value < 0 then
        -- Toggle moving left
        toggle_port_bit(port, 0x20)
    elseif old_value[port] > 0 and value == 0 or old_value[port] == 0 and value > 0 then
        -- Toggle moving right
        toggle_port_bit(port, 0x40)
    elseif old_value[port] < 0 and value > 0 or old_value[port] > 0 and value < 0 then
        -- Turning on a dime, ie. going from left to right or vice versa
        -- without the game registering the neutral position
        toggle_port_bit(port, 0x20)
        toggle_port_bit(port, 0x40)
    end

    old_value[port] = value
end

local function draw_game()
    -- First we stencil the graphics data onto the gel overlay for colors
    lg.setCanvas(display_stencil)
    lg.clear()
    -- Draw the actual graphics data bit by bit
    for y = 0, 223 do
        for x = 0, 31 do
            local address = 0x2400 + (y * 32) + x
            local byte = bus[address]
            for xx = 0, 7 do
                local pixel = bit.band(byte, 0x01)
                byte = bit.rshift(byte, 1)
                -- If the pixel is lit, stencil it
                if pixel == 1 then
                    lg.stencil(
                        function()
                            lg.rectangle(
                                "fill",
                                (x * 8 * pixel_width) + (xx * pixel_width),
                                y * pixel_height,
                                pixel_width,
                                pixel_height
                            )
                        end,
                        "replace",
                        1,
                        true
                    )
                end
            end
        end
    end
    -- Now draw the overlay on only the stenciled pixels
    lg.setStencilTest("equal", 1)
    if overlay then
        lg.draw(overlay, 0, 0, 0, pixel_width, pixel_height)
    else
        lg.rectangle("fill", 0, 0, 256 * pixel_width, 224 * pixel_height)
    end
    lg.setStencilTest()
    lg.setCanvas()

    -- Draw the CRT screen
    lg.setCanvas(crt_display)
    crt(
        function()
            lg.draw(display)
        end
    )
    lg.setCanvas()

    -- Draw the backdrop with a slight dark tinge and vignette
    if background then
        lg.setColor(1, 1, 1, .7)
        vignette(
            function()
                lg.draw(
                    background,
                    0,
                    0,
                    0,
                    -- Resize it to fill the screen
                    lg.getWidth() / background:getWidth(),
                    lg.getHeight() / background:getHeight()
                )
            end
        )
        lg.setColor(1, 1, 1)
    end

    -- Rotate the CRT and draw it with a slight blue tinge
    lg.setColor(0.95, 1, 1)
    glow(
        function()
            lg.draw(
                crt_display,
                (lg.getWidth() / 2) - ((100 * pixel_width) / 2),
                0,
                math.rad(-90), -- Rotate 90 degrees counter-clockwise
                -- Resize it slightly to fit in 800x600 without pixel warping:
                0.6,
                0.6,
                256 * pixel_width
            )
        end
    )
end

local function draw_menu()
    imgui.NewFrame()
    if imgui.BeginMainMenuBar() then
        if imgui.BeginMenu("Control") then
            if imgui.MenuItem("Insert coin", "C") then
                toggle_port_bit(1, 0x01)
                deferred_port_write = function()
                    toggle_port_bit(1, 0x01)
                end
            end
            if imgui.MenuItem("1 player", "1", bus[0x20CE] == 0, bus[0x20EF] == 0 and bus[0x20EB] > 0) then
                toggle_port_bit(1, 0x04)
                deferred_port_write = function()
                    toggle_port_bit(1, 0x04)
                end
            end
            if imgui.MenuItem("2 players", "2", bus[0x20CE] == 1, bus[0x20EF] == 0 and bus[0x20EB] > 1) then
                toggle_port_bit(1, 0x02)
                deferred_port_write = function()
                    toggle_port_bit(1, 0x02)
                end
            end
            if imgui.MenuItem("Tilt", "T") then
                toggle_port_bit(2, 0x04)
                deferred_port_write = function()
                    toggle_port_bit(2, 0x04)
                end
            end
            if imgui.MenuItem("Pause", nil, cpu.pause) then
                cpu.pause = not cpu.pause
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
                    if
                        imgui.MenuItem(
                            i == 0 and 1500 or 1000,
                            nil,
                            bit.band(cpu.ports.internal.input[2], 0x08) == i * 0x08
                        )
                     then
                        toggle_port_bit(2, 0x08)
                    end
                end
                imgui.EndMenu()
            end
            if
                imgui.MenuItem(
                    "Display coin info on demo screen",
                    nil,
                    bit.band(cpu.ports.internal.input[2], 0x80) == 0x00
                )
             then
                toggle_port_bit(2, 0x80)
            end
            if imgui.MenuItem("Reset hi-score") then
                bus[0x20F4] = 0
                bus[0x20F5] = 0
            end
            imgui.EndMenu()
        end
        if imgui.BeginMenu("Display") then
            if imgui.MenuItem("Fullscreen", "F11", fullscreen) then
                toggle_fullscreen()
            end
            imgui.EndMenu()
        end
        imgui.EndMainMenuBar()
    end

    imgui.Render()
end

function love.draw()
    -- If a menu item toggled a port value in the last frame,
    -- we need to toggle it back now.
    if deferred_port_write then
        deferred_port_write()
        deferred_port_write = nil
    end

    draw_game()

    if imgui then
        draw_menu()
    end
end

return {
    init = function(_cpu, _bus)
        cpu, bus = _cpu, _bus
        display_init()
    end
}
