function love.conf(t)
    t.identity = "Moon Invaders"
    t.window.title = t.identity
    t.window.resizable = false

    t.version = "11.4"

    -- Disable stuff we don't use
    t.accelerometerjoystick = false
    t.modules.data = false
    t.modules.physics = false
    t.modules.touch = false
    t.modules.video = false
    t.audio.mic = false
end
