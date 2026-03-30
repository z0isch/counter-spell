-- Title screen: game title and play button
local gauntlet = require("gauntlet")
local endlessConfig = require("bosses.endless")

local title = {}

local fonts
local switchScreen
local titleCardFont

-- Animation timer
local titleTime = 0

-- Title card configuration
local TITLE_CARD_SIZE = 56
local TITLE_CARD_GAP = 8
local ROW_GAP = 28
local LINE1_Y = 180
local LINE2_Y = LINE1_Y + TITLE_CARD_SIZE + ROW_GAP

local titleRow1 = {
    {letter = "C"},
    {letter = "O", shielded = true, shieldHits = 2, chain = true},
    {letter = "U", chain = true},
    {letter = "N", chain = true},
    {letter = "T", bomb = true},
    {letter = "E", shielded = true, shieldHits = 1},
    {letter = "R", fast = true},
}

local titleRow2 = {
    {letter = "S"},
    {letter = "P", bomb = true},
    {letter = "E", shielded = true, shieldHits = 1},
    {letter = "L", fast = true},
    {letter = "L"},
}

local function rowWidth(row)
    return #row * TITLE_CARD_SIZE + (#row - 1) * TITLE_CARD_GAP
end

-- Button dimensions
local BUTTON_W = 200
local BUTTON_H = 50
local BUTTON_R = 8
local BUTTON_X = (love.graphics.getWidth() - BUTTON_W) / 2
local PLAY_Y = LINE2_Y + TITLE_CARD_SIZE + 50
local ENDLESS_Y = PLAY_Y + BUTTON_H + 15

-- Warning popup
local showWarning = false

local POPUP_W = 500
local POPUP_H = 200
local POPUP_X = (love.graphics.getWidth() - POPUP_W) / 2
local POPUP_Y = (love.graphics.getHeight() - POPUP_H) / 2
local POPUP_R = 10

local POPUP_BTN_W = 140
local POPUP_BTN_H = 40
local POPUP_BTN_R = 6
local POPUP_BTN_Y = POPUP_Y + POPUP_H - 55
local PLAY_ANYWAY_X = POPUP_X + POPUP_W / 2 - POPUP_BTN_W - 15
local GO_BACK_X = POPUP_X + POPUP_W / 2 + 15

-- Returns cx, cy of the drawn card (after bob) for chain line drawing
local function drawTitleCard(idx, card, x, baseY, font)
    local S = TITLE_CARD_SIZE
    local bob = math.sin(titleTime * 1.5 + idx * 0.5) * 4
    local y = baseY + bob

    local cx = x + S / 2
    local cy = y + S / 2

    -- Shadow at base position (doesn't bob, gives floating feel)
    if card.bomb then
        love.graphics.setColor(0, 0, 0, 0.2)
        love.graphics.circle("fill", x + S / 2 + 2, baseY + S / 2 + 3, S / 2 - 2)
    else
        love.graphics.setColor(0, 0, 0, 0.2)
        love.graphics.rectangle("fill", x + 2, baseY + 3, S, S, 6, 6)
    end

    if card.bomb then
        local radius = S / 2 - 2

        -- Body
        love.graphics.setColor(0.08, 0.08, 0.08)
        love.graphics.circle("fill", cx, cy, radius)
        love.graphics.setColor(0.5, 0.5, 0.55)
        love.graphics.circle("line", cx, cy, radius)

        -- Fuse
        local fuseBaseX = cx + radius * 0.3
        local fuseBaseY = cy - radius + 2
        local fuseTipX = cx + radius * 0.65
        local fuseTipY = cy - radius - 12
        love.graphics.setColor(0.55, 0.4, 0.25)
        love.graphics.setLineWidth(2.5)
        love.graphics.line(fuseBaseX, fuseBaseY, fuseTipX, fuseTipY)
        love.graphics.setLineWidth(1)

        -- Flickering spark
        local sparkR = 3 + math.sin(titleTime * 8 + idx * 2) * 1.5
        love.graphics.setColor(1, 0.6, 0.1)
        love.graphics.circle("fill", fuseTipX, fuseTipY, sparkR)
        love.graphics.setColor(1, 1, 0.4)
        love.graphics.circle("fill", fuseTipX, fuseTipY, sparkR * 0.5)

        -- Letter
        love.graphics.setFont(font)
        love.graphics.setColor(1, 1, 1)
        local tw = font:getWidth(card.letter)
        local th = font:getHeight()
        love.graphics.print(card.letter, x + (S - tw) / 2, y + (S - th) / 2)
    else
        -- Normal card: rounded rectangle
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("fill", x, y, S, S, 6, 6)
        love.graphics.setColor(0.75, 0.75, 0.82)
        love.graphics.rectangle("line", x, y, S, S, 6, 6)

        -- Letter
        love.graphics.setFont(font)
        love.graphics.setColor(0.1, 0.1, 0.15)
        local tw = font:getWidth(card.letter)
        local th = font:getHeight()
        love.graphics.print(card.letter, x + (S - tw) / 2, y + (S - th) / 2)
    end

    -- Shield rings (pulsing)
    if card.shielded and card.shieldHits > 0 then
        love.graphics.setLineWidth(1.5)
        for ring = 1, card.shieldHits do
            local r = S / 2 + 6 + (ring - 1) * 7
            local alpha = 0.7 + math.sin(titleTime * 2 + idx * 0.7 + ring) * 0.15
            love.graphics.setColor(0.55, 0.88, 1.0, alpha)
            love.graphics.circle("line", cx, cy, r)
        end
        love.graphics.setLineWidth(1)
    end

    -- Fast chevrons
    if card.fast then
        love.graphics.setColor(0.55, 0.78, 1.0, 0.7)
        love.graphics.setLineWidth(1.5)
        for j = 0, 1 do
            local vy = y + S + 5 + j * 6
            local hw = S / 2 - j * 4
            love.graphics.line(cx - hw, vy, cx, vy + 4, cx + hw, vy)
        end
        love.graphics.setLineWidth(1)
    end

    return cx, cy
end

local function isHoveringButton(bx, by)
    local mx, my = love.mouse.getPosition()
    return mx >= bx and mx <= bx + BUTTON_W
        and my >= by and my <= by + BUTTON_H
end

local function isHoveringPopupBtn(bx, by)
    local mx, my = love.mouse.getPosition()
    return mx >= bx and mx <= bx + POPUP_BTN_W
        and my >= by and my <= by + POPUP_BTN_H
end

local function startEndless()
    showWarning = false
    switchScreen("game", { boss = endlessConfig, endless = true })
end

function title.enter(context)
    fonts = context.resources.fonts
    switchScreen = context.switchScreen
    showWarning = false
    titleTime = 0
    if not titleCardFont then
        titleCardFont = love.graphics.newFont(30)
    end
end

function title.update(dt)
    titleTime = titleTime + dt
end

function title.draw()
    love.graphics.setBackgroundColor(0.08, 0.08, 0.12)

    -- Row 1: COUNTER
    local screenW = love.graphics.getWidth()
    local row1W = rowWidth(titleRow1)
    local row1X = (screenW - row1W) / 2
    local chainPoints = {}
    local curX = row1X
    for i, card in ipairs(titleRow1) do
        local cx, cy = drawTitleCard(i, card, curX, LINE1_Y, titleCardFont)
        if card.chain then
            table.insert(chainPoints, {x = cx, y = cy})
        end
        curX = curX + TITLE_CARD_SIZE + TITLE_CARD_GAP
    end

    -- Chain lines connecting O-U-N
    if #chainPoints >= 2 then
        love.graphics.setColor(1.0, 0.6, 0.0, 0.5)
        love.graphics.setLineWidth(5)
        for i = 1, #chainPoints - 1 do
            love.graphics.line(chainPoints[i].x, chainPoints[i].y,
                               chainPoints[i + 1].x, chainPoints[i + 1].y)
        end
        love.graphics.setLineWidth(1)
    end

    -- Row 2: SPELL
    local row2W = rowWidth(titleRow2)
    local row2X = (screenW - row2W) / 2
    curX = row2X
    for i, card in ipairs(titleRow2) do
        drawTitleCard(i + #titleRow1, card, curX, LINE2_Y, titleCardFont)
        curX = curX + TITLE_CARD_SIZE + TITLE_CARD_GAP
    end

    -- Play button
    local playHover = isHoveringButton(BUTTON_X, PLAY_Y)
    if playHover then
        love.graphics.setColor(0.35, 0.35, 0.5)
    else
        love.graphics.setColor(0.22, 0.22, 0.32)
    end
    love.graphics.rectangle("fill", BUTTON_X, PLAY_Y, BUTTON_W, BUTTON_H, BUTTON_R, BUTTON_R)

    love.graphics.setColor(0.5, 0.5, 0.65)
    love.graphics.rectangle("line", BUTTON_X, PLAY_Y, BUTTON_W, BUTTON_H, BUTTON_R, BUTTON_R)

    love.graphics.setFont(fonts.subtitle)
    love.graphics.setColor(1, 1, 1)
    local textH = fonts.subtitle:getHeight()
    love.graphics.printf("Play", BUTTON_X, PLAY_Y + (BUTTON_H - textH) / 2, BUTTON_W, "center")

    -- Endless button
    local endlessHover = isHoveringButton(BUTTON_X, ENDLESS_Y)
    if endlessHover then
        love.graphics.setColor(0.35, 0.35, 0.5)
    else
        love.graphics.setColor(0.22, 0.22, 0.32)
    end
    love.graphics.rectangle("fill", BUTTON_X, ENDLESS_Y, BUTTON_W, BUTTON_H, BUTTON_R, BUTTON_R)

    love.graphics.setColor(0.5, 0.5, 0.65)
    love.graphics.rectangle("line", BUTTON_X, ENDLESS_Y, BUTTON_W, BUTTON_H, BUTTON_R, BUTTON_R)

    love.graphics.setFont(fonts.subtitle)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Endless", BUTTON_X, ENDLESS_Y + (BUTTON_H - textH) / 2, BUTTON_W, "center")

    -- Warning popup
    if showWarning then
        -- Overlay
        love.graphics.setColor(0, 0, 0, 0.75)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

        -- Popup box
        love.graphics.setColor(0.15, 0.15, 0.22)
        love.graphics.rectangle("fill", POPUP_X, POPUP_Y, POPUP_W, POPUP_H, POPUP_R, POPUP_R)
        love.graphics.setColor(0.5, 0.5, 0.65)
        love.graphics.rectangle("line", POPUP_X, POPUP_Y, POPUP_W, POPUP_H, POPUP_R, POPUP_R)

        -- Warning title
        love.graphics.setFont(fonts.subtitle)
        love.graphics.setColor(1, 0.85, 0.2)
        love.graphics.printf("Warning", POPUP_X, POPUP_Y + 15, POPUP_W, "center")

        -- Body text
        love.graphics.setFont(fonts.ui)
        love.graphics.setColor(0.8, 0.8, 0.9)
        love.graphics.printf(
            "You haven't completed the gauntlet yet.\nPlaying it first will help you understand all the card types.",
            POPUP_X + 30, POPUP_Y + 50, POPUP_W - 60, "center"
        )

        -- Play Anyway button
        local paHover = isHoveringPopupBtn(PLAY_ANYWAY_X, POPUP_BTN_Y)
        if paHover then
            love.graphics.setColor(0.35, 0.35, 0.5)
        else
            love.graphics.setColor(0.22, 0.22, 0.32)
        end
        love.graphics.rectangle("fill", PLAY_ANYWAY_X, POPUP_BTN_Y, POPUP_BTN_W, POPUP_BTN_H, POPUP_BTN_R, POPUP_BTN_R)
        love.graphics.setColor(0.5, 0.5, 0.65)
        love.graphics.rectangle("line", PLAY_ANYWAY_X, POPUP_BTN_Y, POPUP_BTN_W, POPUP_BTN_H, POPUP_BTN_R, POPUP_BTN_R)
        love.graphics.setFont(fonts.ui)
        love.graphics.setColor(1, 1, 1)
        local btnTextH = fonts.ui:getHeight()
        love.graphics.printf("Play Anyway", PLAY_ANYWAY_X, POPUP_BTN_Y + (POPUP_BTN_H - btnTextH) / 2, POPUP_BTN_W, "center")

        -- Go Back button
        local gbHover = isHoveringPopupBtn(GO_BACK_X, POPUP_BTN_Y)
        if gbHover then
            love.graphics.setColor(0.35, 0.35, 0.5)
        else
            love.graphics.setColor(0.22, 0.22, 0.32)
        end
        love.graphics.rectangle("fill", GO_BACK_X, POPUP_BTN_Y, POPUP_BTN_W, POPUP_BTN_H, POPUP_BTN_R, POPUP_BTN_R)
        love.graphics.setColor(0.5, 0.5, 0.65)
        love.graphics.rectangle("line", GO_BACK_X, POPUP_BTN_Y, POPUP_BTN_W, POPUP_BTN_H, POPUP_BTN_R, POPUP_BTN_R)
        love.graphics.setFont(fonts.ui)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Go Back", GO_BACK_X, POPUP_BTN_Y + (POPUP_BTN_H - btnTextH) / 2, POPUP_BTN_W, "center")
    end
end

function title.mousepressed(x, y, button)
    if button ~= 1 then return end

    if showWarning then
        if isHoveringPopupBtn(PLAY_ANYWAY_X, POPUP_BTN_Y) then
            startEndless()
        elseif isHoveringPopupBtn(GO_BACK_X, POPUP_BTN_Y) then
            showWarning = false
        end
        return
    end

    if isHoveringButton(BUTTON_X, PLAY_Y) then
        gauntlet.init()
        switchScreen("totem")
    elseif isHoveringButton(BUTTON_X, ENDLESS_Y) then
        if gauntlet.hasBeenCompleted then
            startEndless()
        else
            showWarning = true
        end
    end
end

function title.keypressed(key)
    if showWarning then
        if key == "return" or key == "space" then
            startEndless()
        elseif key == "escape" then
            showWarning = false
        end
    end
end

return title
