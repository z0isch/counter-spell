-- Congratulations screen: displayed after completing the gauntlet
local gauntlet = require("gauntlet")

local congrats = {}

local fonts
local switchScreen

local SCREEN_W = 1280
local SCREEN_H = 720

-- Animation state
local timer = 0
local sparkles = {}

local function spawnSparkles()
    sparkles = {}
    for i = 1, 40 do
        sparkles[i] = {
            x = love.math.random() * SCREEN_W,
            y = love.math.random() * SCREEN_H,
            size = love.math.random() * 3 + 1,
            speed = love.math.random() * 20 + 10,
            phase = love.math.random() * math.pi * 2,
        }
    end
end

function congrats.enter(context)
    fonts = context.resources.fonts
    switchScreen = context.switchScreen
    timer = 0
    spawnSparkles()
end

function congrats.update(dt)
    timer = timer + dt
    for _, s in ipairs(sparkles) do
        s.y = s.y - s.speed * dt
        if s.y < -10 then
            s.y = SCREEN_H + 10
            s.x = love.math.random() * SCREEN_W
        end
    end
end

function congrats.draw()
    love.graphics.setBackgroundColor(0.08, 0.08, 0.12)

    -- Sparkles
    for _, s in ipairs(sparkles) do
        local alpha = math.sin(timer * 3 + s.phase) * 0.3 + 0.5
        love.graphics.setColor(1.0, 0.85, 0.2, alpha)
        love.graphics.circle("fill", s.x, s.y, s.size)
    end

    -- Title
    love.graphics.setFont(fonts.title)
    local pulse = math.sin(timer * 2) * 0.1 + 0.9
    love.graphics.setColor(0.3 * pulse, 1.0 * pulse, 0.5 * pulse)
    love.graphics.printf("Congratulations!", 0, SCREEN_H / 2 - 100, SCREEN_W, "center")

    -- Subtitle
    love.graphics.setFont(fonts.subtitle)
    love.graphics.setColor(0.8, 0.8, 0.9)
    love.graphics.printf("You defeated all " .. #gauntlet.bosses .. " bosses!", 0, SCREEN_H / 2 - 40, SCREEN_W, "center")

    -- Boss names list
    love.graphics.setFont(fonts.ui)
    local listY = SCREEN_H / 2 + 10
    for i, entry in ipairs(gauntlet.bosses) do
        love.graphics.setColor(0.3, 1.0, 0.5, 0.7)
        love.graphics.printf(entry.name, 0, listY + (i - 1) * 22, SCREEN_W, "center")
    end

    -- Prompt
    love.graphics.setFont(fonts.subtitle)
    love.graphics.setColor(0.7, 0.7, 0.8)
    love.graphics.printf("Press Enter to return to title", 0, SCREEN_H - 55, SCREEN_W, "center")
end

function congrats.keypressed(key)
    if key == "return" or key == "space" then
        switchScreen("title")
    end
end

return congrats
