-- Shared flying card gather+fly animation
local flyingCards = {}

local CARD_SIZE = 44
local batches = {}

function flyingCards.spawn(batch)
    batch.timer = 0
    batch.gatherDuration = batch.gatherDuration or 0.25
    batch.flyDuration = batch.flyDuration or 0.3
    batches[#batches + 1] = batch
end

function flyingCards.update(dt)
    local completed = {}
    for i = #batches, 1, -1 do
        local batch = batches[i]
        batch.timer = batch.timer + dt
        local totalDuration = batch.gatherDuration + batch.flyDuration
        if batch.timer >= totalDuration then
            table.remove(batches, i)
            completed[#completed + 1] = batch
        end
    end
    return completed
end

function flyingCards.draw(font)
    love.graphics.setFont(font)
    for _, batch in ipairs(batches) do
        local gathering = batch.timer < batch.gatherDuration
        for _, fc in ipairs(batch.cards) do
            local x, y, scale, alpha
            if gathering then
                local t = batch.timer / batch.gatherDuration
                local ease = t * t
                x = fc.startX + (batch.gatherX - CARD_SIZE / 2 - fc.startX) * ease
                y = fc.startY + (batch.gatherY - CARD_SIZE / 2 - fc.startY) * ease
                scale = 1 - 0.2 * t
                alpha = 0.7
            else
                local t = (batch.timer - batch.gatherDuration) / batch.flyDuration
                local ease = t * t
                local gx = batch.gatherX - CARD_SIZE / 2
                local gy = batch.gatherY - CARD_SIZE / 2
                x = gx + (batch.targetX - CARD_SIZE / 2 - gx) * ease
                y = gy + (batch.targetY - CARD_SIZE / 2 - gy) * ease
                scale = 0.8 - 0.4 * t
                alpha = 0.7 * (1 - t)
            end

            love.graphics.setColor(1, 1, 1, alpha)
            love.graphics.rectangle("fill",
                x + CARD_SIZE * (1 - scale) / 2,
                y + CARD_SIZE * (1 - scale) / 2,
                CARD_SIZE * scale, CARD_SIZE * scale, 6, 6)

            love.graphics.setColor(0.85, 0.85, 0.9, alpha)
            love.graphics.rectangle("line",
                x + CARD_SIZE * (1 - scale) / 2,
                y + CARD_SIZE * (1 - scale) / 2,
                CARD_SIZE * scale, CARD_SIZE * scale, 6, 6)

            love.graphics.setColor(0, 0, 0, alpha)
            local label = fc.letter:upper()
            local tw = font:getWidth(label) * scale
            local th = font:getHeight() * scale
            love.graphics.print(label, x + (CARD_SIZE - tw) / 2, y + (CARD_SIZE - th) / 2, 0, scale, scale)
        end
    end
end

function flyingCards.reset()
    batches = {}
end

return flyingCards
