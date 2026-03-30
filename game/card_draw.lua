-- Shared card drawing
local cardDraw = {}

local CARD_SIZE = 44

function cardDraw.draw(x, y, card, font, highlighted)
    local twisting = card.twistTimer and card.twistTimer > 0
    if twisting then
        local t = card.twistTimer / 0.3
        local angle = math.sin(t * math.pi * 3) * 0.25 * t
        love.graphics.push()
        love.graphics.translate(x + CARD_SIZE / 2, y + CARD_SIZE / 2)
        love.graphics.rotate(angle)
        love.graphics.translate(-(x + CARD_SIZE / 2), -(y + CARD_SIZE / 2))
    end

    local cx = x + CARD_SIZE / 2
    local cy = y + CARD_SIZE / 2

    local bodyColor
    local textColor
    if card.bomb then
        bodyColor = { 0, 0, 0 }
        textColor = { 1, 1, 1 }
    else
        bodyColor = { 1, 1, 1 }
        textColor = { 0, 0, 0 }
    end

    if card.bomb then
        -- Draw bomb: circle body + fuse
        local radius = CARD_SIZE / 2 - 2
        local fuseBaseX = cx + radius * 0.3
        local fuseBaseY = cy - radius + 2
        local fuseTipX = cx + radius * 0.65
        local fuseTipY = cy - radius - 12

        -- Body
        if highlighted then
            love.graphics.setColor(100 / 255, 0, 0)
        else
            love.graphics.setColor(bodyColor)
        end
        love.graphics.circle("fill", cx, cy, radius)

        -- Outline
        if highlighted then
            love.graphics.setColor(1, 0.9, 0.4)
        else
            love.graphics.setColor(0.85, 0.85, 0.9)
        end
        love.graphics.circle("line", cx, cy, radius)

        -- Fuse stem
        love.graphics.setColor(0.55, 0.4, 0.25)
        love.graphics.setLineWidth(2.5)
        love.graphics.line(fuseBaseX, fuseBaseY, fuseTipX, fuseTipY)
        love.graphics.setLineWidth(1)

        -- Spark at fuse tip
        love.graphics.setColor(1, 0.6, 0.1)
        love.graphics.circle("fill", fuseTipX, fuseTipY, 4)
        love.graphics.setColor(1, 1, 0.4)
        love.graphics.circle("fill", fuseTipX, fuseTipY, 2)
    else
        -- Normal card: rounded rectangle
        if highlighted then
            love.graphics.setColor(0.9, 0.7, 0.15)
        else
            love.graphics.setColor(bodyColor)
        end
        love.graphics.rectangle("fill", x, y, CARD_SIZE, CARD_SIZE, 6, 6)

        if highlighted then
            love.graphics.setColor(1, 0.9, 0.4)
        else
            love.graphics.setColor(0.85, 0.85, 0.9)
        end
        love.graphics.rectangle("line", x, y, CARD_SIZE, CARD_SIZE, 6, 6)
    end

    love.graphics.setFont(font)
    love.graphics.setColor(textColor)
    local label
    if card.startWith then
        label = card.letter:upper() .. "-"
    elseif card.endWith then
        label = "-" .. card.letter:upper()
    elseif card.infix then
        label = "-" .. card.letter:upper() .. "-"
    else
        label = card.letter:upper()
    end
    local tw = font:getWidth(label)
    local th = font:getHeight()
    love.graphics.print(label, x + (CARD_SIZE - tw) / 2, y + (CARD_SIZE - th) / 2)

    if card.shielded and card.shieldHits > 0 then
        love.graphics.setLineWidth(1.5)
        for ring = 1, card.shieldHits do
            local r = 28 + (ring - 1) * 7
            love.graphics.setColor(0.55, 0.88, 1.0, 0.85)
            love.graphics.circle("line", cx, cy, r)
        end
        love.graphics.setLineWidth(1)
    end

    if card.fast then
        love.graphics.setColor(0.55, 0.78, 1.0, 0.7)
        love.graphics.setLineWidth(1.5)
        for j = 0, 1 do
            local vy = y + CARD_SIZE + 5 + j * 6
            local hw = CARD_SIZE / 2 - j * 4
            love.graphics.line(cx - hw, vy, cx, vy + 4, cx + hw, vy)
        end
        love.graphics.setLineWidth(1)
    end

    if twisting then
        love.graphics.pop()
    end
end

return cardDraw
