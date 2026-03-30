-- Totem pole screen: shows boss progression as a vertical tower
local gauntlet      = require("gauntlet")
local bossFace      = require("boss_face")

local totem         = {}

local fonts
local switchScreen

-- Layout constants
local FACE_SIZE     = 90
local FACE_GAP      = 12
local SCREEN_W      = 1280
local SCREEN_H      = 720
local TOTEM_X       = SCREEN_W / 2 -- center of totem column
local TOTEM_TOP     = 20
local PROMPT_HEIGHT = 100          -- space reserved at bottom for fixed prompt text

-- Animation state
local advanceAnim   = nil -- { from = y, to = y, timer = 0, duration = 0.8 }
local indicatorY    = 0
local pulseTimer    = 0
local completeState = false
local scrollOffset  = 0

-- Get the Y center of a boss slot (index 1 = bottom, index N = top)
local function slotCenterY(index)
    local count = #gauntlet.bosses
    local reversed = count - index
    return TOTEM_TOP + reversed * (FACE_SIZE + FACE_GAP) + FACE_SIZE / 2
end

-- Compute scroll offset to keep targetY centered in the visible area
local function computeScroll(targetY)
    local count = #gauntlet.bosses
    local contentBottom = TOTEM_TOP + count * FACE_SIZE + (count - 1) * FACE_GAP + FACE_GAP
    local visibleH = SCREEN_H - PROMPT_HEIGHT

    -- No scrolling needed if everything fits
    if contentBottom <= visibleH then
        return 0
    end

    local offset = targetY - visibleH / 2
    local maxScroll = contentBottom - visibleH
    return math.max(0, math.min(offset, maxScroll))
end

local function drawFace(cx, cy, size, hpFrac, defeated, isCurrent, faceColor)
    local dimFactor = defeated and 0.3 or 1.0
    bossFace.draw(cx, cy, size, hpFrac, faceColor, dimFactor)

    -- Defeated overlay: checkmark
    if defeated then
        love.graphics.setColor(0.3, 1.0, 0.5, 0.8)
        love.graphics.setLineWidth(4)
        local checkX = cx - size * 0.15
        local checkY = cy + size * 0.05
        love.graphics.line(
            checkX - size * 0.12, checkY - size * 0.05,
            checkX, checkY + size * 0.12,
            checkX + size * 0.2, checkY - size * 0.15
        )
        love.graphics.setLineWidth(1)
    end
end

-- Draw the player indicator (arrow pointing at current boss)
local function drawIndicator(y)
    local pulse = math.sin(pulseTimer * 3) * 0.15 + 0.85
    local arrowX = TOTEM_X - FACE_SIZE / 2 - 30
    local arrowSize = 10

    love.graphics.setColor(1.0, 0.85, 0.2, pulse)

    -- Triangle arrow pointing right
    love.graphics.polygon("fill",
        arrowX, y - arrowSize,
        arrowX + arrowSize * 1.5, y,
        arrowX, y + arrowSize
    )

    -- Pulsing border around the current face slot
    love.graphics.setLineWidth(3)
    love.graphics.setColor(1.0, 0.85, 0.2, pulse * 0.6)
    love.graphics.rectangle("line",
        TOTEM_X - FACE_SIZE / 2 - 4,
        y - FACE_SIZE / 2 - 4,
        FACE_SIZE + 8, FACE_SIZE + 8,
        8, 8
    )
    love.graphics.setLineWidth(1)
end

function totem.enter(context)
    fonts = context.resources.fonts
    switchScreen = context.switchScreen
    pulseTimer = 0

    if gauntlet.isComplete() then
        switchScreen("congrats")
        return
    end

    completeState = false

    if context.justDefeated then
        -- Animate from previous position (one below current) to current
        local prevLevel = gauntlet.currentLevel - 1
        if prevLevel >= 1 then
            local fromY = slotCenterY(prevLevel)
            local toY = slotCenterY(gauntlet.currentLevel)
            indicatorY = fromY
            advanceAnim = { from = fromY, to = toY, timer = 0, duration = 0.8 }
        else
            indicatorY = slotCenterY(gauntlet.currentLevel)
            advanceAnim = nil
        end
    elseif gauntlet.currentLevel == 1 and not gauntlet.bosses[1].defeated then
        -- First time entering: animate arrow from top down to first boss
        local fromY = slotCenterY(#gauntlet.bosses)
        local toY = slotCenterY(1)
        indicatorY = fromY
        advanceAnim = { from = fromY, to = toY, timer = 0, duration = 5.0 }
    else
        indicatorY = slotCenterY(gauntlet.currentLevel)
        advanceAnim = nil
    end

    scrollOffset = computeScroll(indicatorY)
end

function totem.update(dt)
    pulseTimer = pulseTimer + dt

    if advanceAnim then
        advanceAnim.timer = advanceAnim.timer + dt
        local t = math.min(advanceAnim.timer / advanceAnim.duration, 1)
        -- Ease out quad
        local eased = 1 - (1 - t) * (1 - t)
        indicatorY = advanceAnim.from + (advanceAnim.to - advanceAnim.from) * eased
        if t >= 1 then
            indicatorY = advanceAnim.to
            advanceAnim = nil
        end
    end

    -- Scroll to keep indicator centered
    local target = completeState and slotCenterY(#gauntlet.bosses) or indicatorY
    scrollOffset = computeScroll(target)
end

function totem.draw()
    love.graphics.setBackgroundColor(0.08, 0.08, 0.12)

    -- Scrollable content
    love.graphics.push()
    love.graphics.translate(0, -scrollOffset)

    -- Draw totem pole structure (subtle vertical line behind faces)
    local count = #gauntlet.bosses
    local totemHeight = count * FACE_SIZE + (count - 1) * FACE_GAP
    love.graphics.setColor(0.18, 0.18, 0.25)
    love.graphics.setLineWidth(6)
    love.graphics.line(TOTEM_X, TOTEM_TOP, TOTEM_X, TOTEM_TOP + totemHeight)
    love.graphics.setLineWidth(1)

    -- Draw each boss face
    for i, entry in ipairs(gauntlet.bosses) do
        local cy = slotCenterY(i)
        local isCurrent = (i == gauntlet.currentLevel) and not completeState
        local hpFrac = entry.defeated and 0 or 1
        drawFace(TOTEM_X, cy, FACE_SIZE, hpFrac, entry.defeated, isCurrent, entry.boss.faceColor)

        -- Boss name label to the right
        love.graphics.setFont(fonts.subtitle)
        if entry.defeated then
            love.graphics.setColor(0.4, 0.4, 0.45)
        elseif isCurrent then
            love.graphics.setColor(1.0, 0.85, 0.2)
        else
            love.graphics.setColor(0.6, 0.6, 0.7)
        end
        love.graphics.print(entry.name, TOTEM_X + FACE_SIZE / 2 + 20, cy - 7)
    end

    -- Player indicator
    if not completeState then
        drawIndicator(indicatorY)
    end

    love.graphics.pop()
    if advanceAnim == nil then
        -- Prompt at bottom (fixed on screen, not scrolled)
        love.graphics.setFont(fonts.subtitle)
        if completeState then
            love.graphics.setColor(0.3, 1.0, 0.5)
            love.graphics.printf("GAUNTLET COMPLETE!", 0, SCREEN_H - 90, SCREEN_W, "center")
            love.graphics.setColor(0.7, 0.7, 0.8)
            love.graphics.printf("Press Enter to return to title", 0, SCREEN_H - 55, SCREEN_W, "center")
        else
            love.graphics.setColor(0.7, 0.7, 0.8)
            love.graphics.printf("Press Enter to fight", 0, SCREEN_H - 55, SCREEN_W, "center")
        end
    end
end

function totem.keypressed(key)
    if completeState then
        if key == "return" or key == "space" then
            switchScreen("title")
        end
        return
    end

    if key == "return" or key == "space" then
        local entry = gauntlet.getCurrentBoss()
        if entry.info then
            switchScreen("info", { boss = entry.boss, infoData = entry.info })
        else
            switchScreen("game", { boss = entry.boss })
        end
    elseif key == "escape" then
        switchScreen("title")
    end
end

return totem
