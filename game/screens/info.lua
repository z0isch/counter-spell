-- Info screen: shows informational content before a boss fight
local cardDraw  = require("card_draw")
local infoDemoModule = require("info_demo")

local info = {}

local fonts
local switchScreen
local boss
local infoData
local hasDemo

local SCREEN_W = 1280
local SCREEN_H = 720
local CARD_SIZE = 44

function info.enter(context)
    fonts = context.resources.fonts
    switchScreen = context.switchScreen
    boss = context.boss
    infoData = context.infoData
    hasDemo = infoData.demo
    if hasDemo then
        infoDemoModule.init(fonts, boss.faceColor)
    end
end

function info.update(dt)
    if hasDemo then
        infoDemoModule.update(dt)
    end
end

function info.draw()
    love.graphics.setBackgroundColor(0.08, 0.08, 0.12)

    -- Title
    love.graphics.setFont(fonts.title)
    love.graphics.setColor(1.0, 0.85, 0.2)
    love.graphics.printf(infoData.title, 0, 80, SCREEN_W, "center")

    -- Body lines
    love.graphics.setFont(fonts.subtitle)
    local y = 160
    local lineSpacing = 32
    for _, line in ipairs(infoData.lines) do
        if line == "" then
            y = y + lineSpacing * 0.5
        else
            love.graphics.setColor(0.85, 0.85, 0.92)
            love.graphics.printf(line, 140, y, SCREEN_W - 280, "center")
            y = y + lineSpacing
        end
    end

    if hasDemo then
        -- Animated demo below text
        infoDemoModule.draw(SCREEN_W / 2, y + 30)
    elseif infoData.examples then
        -- Static example cards
        local examplesY = y + 24
        local gap = 20
        local totalW = #infoData.examples * CARD_SIZE + (#infoData.examples - 1) * gap
        local startX = (SCREEN_W - totalW) / 2

        -- Draw chain lines behind cards
        for i, ex in ipairs(infoData.examples) do
            if ex.chained and i < #infoData.examples and infoData.examples[i + 1].chained then
                local ax = startX + (i - 1) * (CARD_SIZE + gap) + CARD_SIZE / 2
                local bx = startX + i * (CARD_SIZE + gap) + CARD_SIZE / 2
                love.graphics.setColor(1.0, 0.6, 0.0, 0.5)
                love.graphics.setLineWidth(5)
                love.graphics.line(ax, examplesY + CARD_SIZE / 2, bx, examplesY + CARD_SIZE / 2)
                love.graphics.setLineWidth(1)
            end
        end

        -- Draw cards
        for i, ex in ipairs(infoData.examples) do
            local cardX = startX + (i - 1) * (CARD_SIZE + gap)
            cardDraw.draw(cardX, examplesY, ex, fonts.card)
        end
    end

    -- Prompt
    love.graphics.setFont(fonts.subtitle)
    love.graphics.setColor(0.7, 0.7, 0.8)
    love.graphics.printf("Press Enter to begin", 0, SCREEN_H - 55, SCREEN_W, "center")
end

function info.keypressed(key)
    if key == "return" or key == "space" then
        switchScreen("game", { boss = boss })
    elseif key == "escape" then
        switchScreen("totem")
    end
end

return info
