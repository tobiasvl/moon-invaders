-- Overrides for the LÖVE callback functions if no ROM is loaded

local path_separator = "/"
if love.system.getOS() == "Windows" then
    path_separator = "\\"
end

local root_dir = ""
local local_assets
if love.filesystem.isFused() and love.filesystem.mount(love.filesystem.getSourceBaseDirectory(), "fused_dir") then
    root_dir = "fused_dir/"
    local_assets =
        string.gsub(love.filesystem.getSourceBaseDirectory(), "/", path_separator) .. path_separator .. "assets"
else
    local_assets = string.gsub(love.filesystem.getSource(), "/", path_separator) .. path_separator .. "assets"
end

local font = love.graphics.newFont(20)

local dot = "• "
local dot_width = font:getWidth(dot)

local local_assets_width = font:getWidth(local_assets)
local local_assets_height = font:getHeight(local_assets)

local save_assets = string.gsub(love.filesystem.getSaveDirectory(), "/", path_separator) .. path_separator .. "assets"
local save_assets_width = font:getWidth(save_assets)
local save_assets_height = font:getHeight(save_assets)

function love.draw()
    if love.filesystem.getInfo(root_dir .. "assets/background.png") then
        local background = love.graphics.newImage(root_dir .. "assets/background.png")
        if background then
            love.graphics.setColor(1, 1, 1, .5)
            love.graphics.draw(
                background,
                0,
                0,
                0,
                -- Resize it to fill the screen
                love.graphics.getWidth() / background:getWidth(),
                love.graphics.getHeight() / background:getHeight()
            )
            love.graphics.setColor(1, 1, 1)
        end
    end

    love.graphics.setFont(font)
    love.graphics.printf(
        "Unable to locate Space Invaders ROM files\n" .. "Please put them in one of the following locations:",
        20,
        150,
        love.graphics.getWidth(),
        "left"
    )

    love.graphics.printf("• " .. local_assets, 40, 220, love.graphics.getWidth(), "left")
    love.graphics.line(
        40 + dot_width,
        220 + local_assets_height,
        40 + dot_width + local_assets_width,
        222 + local_assets_height
    )
    love.graphics.printf("• " .. save_assets, 40, 250, love.graphics.getWidth(), "left")
    love.graphics.line(
        40 + dot_width,
        250 + save_assets_height,
        40 + dot_width + save_assets_width,
        252 + save_assets_height
    )
end

function love.mousepressed(x, y)
    local link_local_assets = root_dir .. "assets"

    if x >= 45 and x <= 45 + local_assets_width and y >= 220 and y <= 220 + local_assets_height then
        love.system.openURL(link_local_assets)
    end

    if x >= 45 and y >= 250 and y <= 250 + save_assets_height then
        if not love.filesystem.getInfo(love.filesystem.getSaveDirectory() .. "/assets") then
            love.filesystem.createDirectory(love.filesystem.getSaveDirectory() .. "/assets")
        end
        love.system.openURL(love.filesystem.getSaveDirectory() .. "/assets")
    end
end

function love.mousemoved(x, y)
    local hand = love.mouse.getSystemCursor("hand")

    if x >= 40 + dot_width and x <= 40 + dot_width + local_assets_width and y >= 220 and y <= 220 + local_assets_height then
        love.mouse.setCursor(hand)
    elseif
        x >= 40 + dot_width and x <= 40 + dot_width + save_assets_width and y >= 250 and y <= 250 + local_assets_height
     then
        love.mouse.setCursor(hand)
    else
        love.mouse.setCursor()
    end
end

-- Stub out love.update
function love.update()
end

function love.quit()
    return false
end
