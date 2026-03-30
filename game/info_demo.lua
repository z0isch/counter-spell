-- Animated mini-game demo for the "How to Play" info screen
local cardDraw       = require("card_draw")
local bossFace       = require("boss_face")
local flyingCardsLib = require("flying_cards")
local particlesLib   = require("particles")

local demo = {}

-- Layout constants
local LANE_WIDTH  = 50
local CARD_SIZE   = 44
local NUM_LANES   = 3
local LANE_HEIGHT = 170
local INPUT_H     = 36
local FACE_SIZE   = 80
local BAR_WIDTH   = 24
local BAR_HEIGHT  = 80

-- Timeline durations
local DUR_FALL    = 1.5
local DUR_TYPE_C  = 0.5
local DUR_TYPE_A  = 0.5
local DUR_TYPE_T  = 0.5
local DUR_PAUSE   = 0.3
local DUR_SUBMIT  = 0.55
local DUR_IMPACT  = 0.8
local DUR_HOLD    = 1.0
local DUR_RESET   = 0.3

local PHASES = {
    { name = "falling",  dur = DUR_FALL },
    { name = "type_c",   dur = DUR_TYPE_C },
    { name = "type_a",   dur = DUR_TYPE_A },
    { name = "type_t",   dur = DUR_TYPE_T },
    { name = "pause",    dur = DUR_PAUSE },
    { name = "submit",   dur = DUR_SUBMIT },
    { name = "impact",   dur = DUR_IMPACT },
    { name = "hold",     dur = DUR_HOLD },
    { name = "reset",    dur = DUR_RESET },
}

-- State
local fonts
local faceColor
local phaseIdx
local phaseTimer
local card         -- the single C card object
local cardInLane   -- whether card is still visible in the lane
local inputText
local highlighted
local bossHP
local bossShakeTimer
local bossShakeIntensity

-- Computed layout positions (set in init)
local originX, originY
local lanesX, lanesY
local faceX, faceY
local barX, barY
local inputBoxX, inputBoxY, inputBoxW

local function resetState()
    phaseIdx = 1
    phaseTimer = 0
    card = { letter = "c", y = -CARD_SIZE, speed = 30 }
    cardInLane = true
    inputText = ""
    highlighted = false
    bossHP = 1
    bossShakeTimer = 0
    bossShakeIntensity = 0
    flyingCardsLib.reset()
    particlesLib.reset()
end

function demo.init(f, fc)
    fonts = f
    faceColor = fc or { 0.85, 0.85, 0.95 }
    resetState()
end

local function currentPhase()
    return PHASES[phaseIdx].name
end

local function advancePhase()
    phaseIdx = phaseIdx + 1
    phaseTimer = 0
    if phaseIdx > #PHASES then
        resetState()
    end
end

function demo.update(dt)
    if not fonts then return end

    phaseTimer = phaseTimer + dt
    local phase = currentPhase()

    -- Card falls during falling + typing + pause phases
    if cardInLane then
        card.y = card.y + card.speed * dt
    end

    -- Phase transitions
    if phase == "falling" then
        if phaseTimer >= DUR_FALL then advancePhase() end
    elseif phase == "type_c" then
        inputText = "c"
        highlighted = true
        if phaseTimer >= DUR_TYPE_C then advancePhase() end
    elseif phase == "type_a" then
        inputText = "ca"
        if phaseTimer >= DUR_TYPE_A then advancePhase() end
    elseif phase == "type_t" then
        inputText = "cat"
        if phaseTimer >= DUR_TYPE_T then advancePhase() end
    elseif phase == "pause" then
        if phaseTimer >= DUR_PAUSE then advancePhase() end
    elseif phase == "submit" then
        if phaseTimer < dt + 0.001 then
            -- First frame of submit: launch flying card, clear input
            inputText = ""
            highlighted = false
            cardInLane = false
            local cardScreenX = lanesX + 1 * LANE_WIDTH + (LANE_WIDTH - CARD_SIZE) / 2
            local cardScreenY = originY + lanesY + card.y
            flyingCardsLib.spawn({
                cards = {{
                    startX = cardScreenX,
                    startY = cardScreenY,
                    letter = card.letter,
                }},
                gatherX = lanesX + (NUM_LANES * LANE_WIDTH) / 2,
                gatherY = originY + lanesY + LANE_HEIGHT / 2,
                targetX = faceX,
                targetY = faceY,
            })
        end
        if phaseTimer >= DUR_SUBMIT then advancePhase() end
    elseif phase == "impact" then
        if phaseTimer < dt + 0.001 then
            bossHP = 0
            bossShakeTimer = 0.35
            bossShakeIntensity = 4
        end
        if bossShakeTimer > 0 then
            bossShakeTimer = bossShakeTimer - dt
        end
        if phaseTimer >= DUR_IMPACT then advancePhase() end
    elseif phase == "hold" then
        if phaseTimer >= DUR_HOLD then advancePhase() end
    elseif phase == "reset" then
        if phaseTimer >= DUR_RESET then
            resetState()
        end
    end

    -- Update shared systems
    local completed = flyingCardsLib.update(dt)
    for _, batch in ipairs(completed) do
        bossShakeTimer = 0.35
        bossShakeIntensity = 4
        particlesLib.spawn(batch.targetX, batch.targetY, 8)
    end
    particlesLib.update(dt)
end

function demo.draw(centerX, topY)
    if not fonts then return end

    -- Compute layout origin
    local lanesW = NUM_LANES * LANE_WIDTH
    local totalW = FACE_SIZE + 20 + lanesW
    originX = centerX - totalW / 2
    originY = topY

    -- Boss face panel (left side)
    local facePanelX = originX
    faceX = facePanelX + FACE_SIZE / 2
    faceY = originY + FACE_SIZE / 2

    -- HP bar below face
    barX = facePanelX + (FACE_SIZE - BAR_WIDTH) / 2
    barY = originY + FACE_SIZE + 10

    -- Lanes (right of face)
    lanesX = facePanelX + FACE_SIZE + 20
    lanesY = 0  -- relative to originY

    -- Input box below lanes
    inputBoxX = lanesX + 6
    inputBoxY = originY + LANE_HEIGHT + 6
    inputBoxW = lanesW - 12

    -- Draw boss face with shake
    love.graphics.push()
    if bossShakeTimer > 0 then
        local sx = (love.math.random() * 2 - 1) * bossShakeIntensity
        local sy = (love.math.random() * 2 - 1) * bossShakeIntensity
        love.graphics.translate(sx, sy)
    end

    local hpFrac = bossHP / 1
    bossFace.draw(faceX, faceY, FACE_SIZE, hpFrac, faceColor)

    -- HP bar
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", barX, barY, BAR_WIDTH, BAR_HEIGHT, 3, 3)
    local fillH = BAR_HEIGHT * hpFrac
    love.graphics.setColor(0.8, 0.15, 0.15)
    love.graphics.rectangle("fill", barX, barY + BAR_HEIGHT - fillH, BAR_WIDTH, fillH, 3, 3)
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.rectangle("line", barX, barY, BAR_WIDTH, BAR_HEIGHT, 3, 3)

    love.graphics.setFont(fonts.sidebar)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(bossHP .. "/1", facePanelX, barY + BAR_HEIGHT + 4, FACE_SIZE, "center")

    love.graphics.pop()

    -- Lane backgrounds
    love.graphics.setColor(0.06, 0.06, 0.1)
    love.graphics.rectangle("fill", lanesX, originY, lanesW, LANE_HEIGHT)

    for i = 1, NUM_LANES do
        local lx = lanesX + (i - 1) * LANE_WIDTH
        love.graphics.setColor(0.18, 0.18, 0.25)
        love.graphics.rectangle("line", lx, originY, LANE_WIDTH, LANE_HEIGHT)
    end

    -- Danger line
    love.graphics.setColor(0.8, 0.2, 0.2, 0.4)
    love.graphics.setLineWidth(2)
    love.graphics.line(lanesX, originY + LANE_HEIGHT - 2, lanesX + lanesW, originY + LANE_HEIGHT - 2)
    love.graphics.setLineWidth(1)

    -- Draw card in middle lane (lane index 1, 0-based)
    if cardInLane then
        local cx = lanesX + 1 * LANE_WIDTH + (LANE_WIDTH - CARD_SIZE) / 2
        local cy = originY + card.y
        -- Clip to lane area
        if cy + CARD_SIZE > originY and cy < originY + LANE_HEIGHT then
            cardDraw.draw(cx, cy, card, fonts.card, highlighted)
        end
    end

    -- Input box
    love.graphics.setColor(0.12, 0.12, 0.18)
    love.graphics.rectangle("fill", lanesX, originY + LANE_HEIGHT, lanesW, INPUT_H)

    love.graphics.setColor(0.18, 0.18, 0.25)
    love.graphics.rectangle("fill", inputBoxX, inputBoxY, inputBoxW, INPUT_H - 12, 4, 4)
    love.graphics.setColor(0.35, 0.35, 0.45)
    love.graphics.rectangle("line", inputBoxX, inputBoxY, inputBoxW, INPUT_H - 12, 4, 4)

    if #inputText > 0 then
        love.graphics.setFont(fonts.input)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(inputText, inputBoxX + 8, inputBoxY + (INPUT_H - 12 - fonts.input:getHeight()) / 2)
    else
        love.graphics.setFont(fonts.inputPlaceholder)
        love.graphics.setColor(0.4, 0.4, 0.5)
        love.graphics.print("Type a word...", inputBoxX + 8,
            inputBoxY + (INPUT_H - 12 - fonts.inputPlaceholder:getHeight()) / 2)
    end

    -- Flying cards and particles (drawn in screen space)
    flyingCardsLib.draw(fonts.card)
    particlesLib.draw()
end

return demo
