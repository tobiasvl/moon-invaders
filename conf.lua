function love.conf(t)
    -- Debug mode
    t.console = true

    t.identity = "Moon Invaders"
    t.window.title = t.identity
    t.window.resizable = false
    t.window.height = 600

    t.version = "11.3"

    -- Disable stuff we don't use
    t.accelerometerjoystick = false
    t.modules.joystick = false
    t.modules.data = false
    t.modules.physics = false
    t.modules.touch = false
    t.modules.video = false
end