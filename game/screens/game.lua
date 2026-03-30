-- Game screen: core gameplay (cards, typing, boss battle)
local waveModule    = require("wave")
local cardMatches   = require("card_matches")
local cardDraw      = require("card_draw")
local bossFace      = require("boss_face")
local particlesLib  = require("particles")
local flyingCardsLib = require("flying_cards")
local gauntlet      = require("gauntlet")

local game          = {}

-- Constants (fixed)
local LANE_WIDTH    = 60
local CARD_SIZE     = 44
local INPUT_HEIGHT  = 50
local PLAYER_MAX_HP = 3


local LETTER_WEIGHTS      = {
    e = 10,
    t = 9,
    a = 8,
    o = 8,
    i = 7,
    n = 7,
    s = 7,
    r = 7,
    h = 6,
    d = 5,
    l = 5,
    c = 3,
    u = 3,
    m = 2,
    w = 2,
    f = 2,
    g = 2,
    y = 2,
    p = 1,
    b = 2,
    v = 1,
    k = 1,
    j = 1,
    x = 1,
    q = 1,
    z = 1,
}

-- State
local fonts
local sounds
local switchScreen
local boss
local endless             = false
local score               = 0
local playerMaxHP

local wordSet             = {}
local lanes               = {}
local playerHP, bossHP
local inputText           = ""
local waveTimer           = 0
local nextWaveTime        = 2
local gameState           = "loading"
local usedWords           = {}
local usedWordsSet        = {}
local highlightCache      = {}
local highlightCacheKey   = ""
local shakeTimer          = 0
local shakeIntensity      = 0
local activeChains        = {}
local bossShakeTimer      = 0
local bossShakeIntensity  = 0
local loaded              = false
local rejectMsg           = nil -- { text = "...", timer = 0 }
local usedLetters         = {}
local usedLetterCount     = 0
local alphabetCompletions = 0

-- Helper functions

local function getLanesStartX()
    return (love.graphics.getWidth() - boss.numLanes * LANE_WIDTH) / 2
end

local function getLaneBottom()
    return love.graphics.getHeight() - INPUT_HEIGHT
end

local function getChainById(chainId)
    for _, chain in ipairs(activeChains) do
        if chain.id == chainId then return chain end
    end
    return nil
end

local function cleanupChain(chainId)
    for i, chain in ipairs(activeChains) do
        if chain.id == chainId then
            local found = false
            for _, lane in ipairs(lanes) do
                for _, card in ipairs(lane) do
                    if card.chainId == chainId then
                        found = true
                        break
                    end
                end
                if found then break end
            end
            if not found then
                table.remove(activeChains, i)
            end
            return
        end
    end
end

local function renumberChain(chainId)
    local remaining = {}
    for laneIdx, lane in ipairs(lanes) do
        for _, card in ipairs(lane) do
            if card.chainId == chainId then
                table.insert(remaining, { card = card, laneIdx = laneIdx })
            end
        end
    end
    table.sort(remaining, function(a, b) return a.card.chainOrder < b.card.chainOrder end)
    for i, entry in ipairs(remaining) do
        entry.card.chainOrder = i
    end
    local chain = getChainById(chainId)
    if chain then
        chain.cards = {}
        for _, entry in ipairs(remaining) do
            table.insert(chain.cards, {
                laneIdx = entry.laneIdx,
                letter = entry.card.letter,
                chainOrder = entry.card.chainOrder,
            })
        end
    end
end

local function boardIsEmpty()
    for _, lane in ipairs(lanes) do
        if #lane > 0 then return false end
    end
    return true
end

local function registerChain(chain)
    table.insert(activeChains, {
        id = chain.id,
        cards = (function()
            local cards = {}
            for order, laneIdx in ipairs(chain.lanes) do
                table.insert(cards, {
                    laneIdx = laneIdx,
                    letter = chain.letters[order],
                    chainOrder = order,
                })
            end
            return cards
        end)(),
    })
end

local function spawnWave()
    local result = boss.spawnWave and boss.spawnWave(lanes) or waveModule.spawn(lanes)

    if result then
        if result.id then
            registerChain(result)
        else
            for _, chain in ipairs(result) do
                registerChain(chain)
            end
        end
    end

    nextWaveTime = boss.waveIntervalMin + love.math.random() * (boss.waveIntervalMax - boss.waveIntervalMin)
    highlightCache = {}
    highlightCacheKey = ""
end

local function rejectInput(msg)
    sounds.thunk:stop()
    sounds.thunk:play()
    if msg then
        rejectMsg = { text = msg, timer = 1.5 }
    end
    inputText = ""
end

local function submitWord()
    if #inputText == 0 then return end

    if not wordSet[inputText] then
        rejectInput()
        return
    end

    if usedWordsSet[inputText] then
        rejectInput("You already used that word!")
        return
    end

    local matched, _ = cardMatches.findMatches(inputText, lanes, activeChains)

    if #matched == 0 then
        rejectInput()
        return
    end

    -- Sort highest index first to avoid shifting issues when removing
    table.sort(matched, function(a, b)
        if a.laneIdx == b.laneIdx then
            return a.cardIdx > b.cardIdx
        end
        return a.laneIdx > b.laneIdx
    end)

    -- Process shields: crack or clear
    local removedEntries = {}
    local shieldsCracked = 0
    local bombsCleared = 0
    for _, entry in ipairs(matched) do
        local card = lanes[entry.laneIdx][entry.cardIdx]
        if card.shielded then
            card.shieldHits = card.shieldHits - 1
            if card.shieldHits <= 0 then
                card.shielded = false
            end
            shieldsCracked = shieldsCracked + 1
            card.twistTimer = 0.3
        else
            if card.bomb then bombsCleared = bombsCleared + 1 end
            table.insert(removedEntries, entry)
        end
    end

    -- Collect affected chain IDs before removal
    local affectedChains = {}
    for _, entry in ipairs(removedEntries) do
        local card = lanes[entry.laneIdx][entry.cardIdx]
        if card.chainId then
            affectedChains[card.chainId] = true
        end
    end

    -- Spawn flying card batch: gather to center, then fly to boss bar
    local lanesStartX = getLanesStartX()
    local panelW = lanesStartX
    local targetX = (panelW - 40) / 2 + 20
    local targetY = 30 + (getLaneBottom() - 30 - 55) / 2
    local gatherX = love.graphics.getWidth() / 2
    local gatherY = love.graphics.getHeight() / 2 - 40
    local batchCards = {}
    for _, entry in ipairs(removedEntries) do
        local card = lanes[entry.laneIdx][entry.cardIdx]
        local cardX = lanesStartX + (entry.laneIdx - 1) * LANE_WIDTH + (LANE_WIDTH - CARD_SIZE) / 2
        if card.bomb then
            particlesLib.spawn(cardX + CARD_SIZE / 2, card.y + CARD_SIZE / 2, 15, { color = "red" })
        else
            table.insert(batchCards, {
                startX = cardX,
                startY = card.y,
                letter = card.letter,
            })
        end
    end
    if #batchCards > 0 then
        flyingCardsLib.spawn({
            cards = batchCards,
            gatherX = gatherX,
            gatherY = gatherY,
            targetX = targetX,
            targetY = targetY,
        })
    end

    -- Remove cleared cards
    for _, entry in ipairs(removedEntries) do
        table.remove(lanes[entry.laneIdx], entry.cardIdx)
    end

    -- Renumber and clean up affected chains
    for cid, _ in pairs(affectedChains) do
        renumberChain(cid)
        cleanupChain(cid)
    end

    -- Deal damage
    local bossDamage = #removedEntries - bombsCleared
    local selfDamage = bombsCleared

    if endless then
        score = score + #removedEntries
    else
        bossHP = bossHP - bossDamage
    end

    if selfDamage > 0 then
        playerHP = playerHP - selfDamage
        shakeTimer = 0.3
        shakeIntensity = 4
        if playerHP <= 0 then
            playerHP = 0
            gameState = "lost"
        end
    end

    table.insert(usedWords, inputText)
    usedWordsSet[inputText] = true

    if endless then
        for i = 1, #inputText do
            local ch = inputText:sub(i, i)
            if not usedLetters[ch] then
                usedLetters[ch] = true
                usedLetterCount = usedLetterCount + 1
            end
        end
        if usedLetterCount >= 26 then
            alphabetCompletions = alphabetCompletions + 1
            usedLetters = {}
            usedLetterCount = 0
            playerHP = playerHP + 1
        end
    end

    sounds.bell:stop()
    sounds.bell:play()

    if not endless and bossHP <= 0 then
        bossHP = 0
        gameState = "won"
    end

    inputText = ""
end

local function resetGame()
    lanes = {}
    for i = 1, boss.numLanes do
        lanes[i] = {}
    end
    playerHP = playerMaxHP
    bossHP = endless and 0 or boss.maxHP
    score = 0
    inputText = ""
    waveTimer = 0
    nextWaveTime = 2
    usedWords = {}
    usedWordsSet = {}
    gameState = "playing"
    shakeTimer = 0
    activeChains = {}
    flyingCardsLib.reset()
    bossShakeTimer = 0
    bossShakeIntensity = 0
    particlesLib.reset()
    rejectMsg = nil
    usedLetters = {}
    usedLetterCount = 0
    alphabetCompletions = 0
    waveModule.resetChainId()
end

local function loadWords()
    local startTime = love.timer.getTime()
    for line in love.filesystem.lines("words.txt") do
        local word = line:lower():match("^%s*(.-)%s*$")
        if word and #word > 0 then
            wordSet[word] = true
        end
    end

    waveModule.loadWordData(wordSet)

    local elapsed = love.timer.getTime() - startTime
    print(string.format("Loaded word list in %.2fs", elapsed))
end

-- Draw helpers

local function drawCard(x, y, card, highlighted)
    cardDraw.draw(x, y, card, fonts.card, highlighted)
end

local function drawFlyingCards()
    flyingCardsLib.draw(fonts.card)
end

local function drawParticles()
    particlesLib.draw()
end

local function drawBossFace(panelW, hpFrac)
    local cx = panelW / 2
    local cy = 5 + 100
    bossFace.draw(cx, cy, 200, hpFrac, boss.faceColor)
end

local function drawScore()
    local panelW = getLanesStartX()

    love.graphics.setFont(fonts.subtitle)
    love.graphics.setColor(0.7, 0.7, 0.8)
    love.graphics.printf("Score", 0, 50, panelW, "center")

    love.graphics.setFont(fonts.title)
    love.graphics.setColor(1, 0.85, 0.2)
    love.graphics.printf(tostring(score), 0, 80, panelW, "center")
end

local function drawBossBar()
    local panelW = getLanesStartX()
    local barWidth = 40
    local barX = (panelW - barWidth) / 2
    local barY = 215
    local barHeight = getLaneBottom() - barY - 55

    local bsX, bsY = 0, 0
    if bossShakeTimer > 0 then
        bsX = (love.math.random() * 2 - 1) * bossShakeIntensity
        bsY = (love.math.random() * 2 - 1) * bossShakeIntensity
    end
    love.graphics.push()
    love.graphics.translate(bsX, bsY)

    local hpFrac = math.max(0, bossHP / boss.maxHP)

    -- Face above the bar
    drawBossFace(panelW, hpFrac)

    -- Bar background
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", barX, barY, barWidth, barHeight, 4, 4)

    local fillH = barHeight * hpFrac
    love.graphics.setColor(0.8, 0.15, 0.15)
    love.graphics.rectangle("fill", barX, barY + barHeight - fillH, barWidth, fillH, 4, 4)

    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.rectangle("line", barX, barY, barWidth, barHeight, 4, 4)

    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(bossHP .. "/" .. boss.maxHP, 0, barY + barHeight + 5, panelW, "center")

    love.graphics.pop()
end

local function drawPlayerHP()
    local panelX = getLanesStartX() + boss.numLanes * LANE_WIDTH
    local panelW = love.graphics.getWidth() - panelX
    local inputY = love.graphics.getHeight() - INPUT_HEIGHT
    local pipSize = 36
    local pipSpacing = 44
    local displayHP = math.max(playerHP, playerMaxHP)
    local totalW = (displayHP - 1) * pipSpacing + pipSize
    local pipStartX = panelX + (panelW - totalW) / 2
    local y = inputY + (INPUT_HEIGHT - pipSize) / 2

    love.graphics.setFont(fonts.ui)
    love.graphics.setColor(0.7, 0.7, 0.8)
    love.graphics.printf("HP", panelX, y - 14, panelW, "center")

    for i = 1, displayHP do
        if i > playerHP then
            love.graphics.setColor(0.25, 0.25, 0.3)
        elseif i > playerMaxHP then
            love.graphics.setColor(0.3, 0.9, 0.4)
        else
            love.graphics.setColor(0.9, 0.2, 0.3)
        end
        love.graphics.rectangle("fill", pipStartX + (i - 1) * pipSpacing, y, pipSize, pipSize, 3, 3)
    end
end

local function drawInput()
    local inputY = love.graphics.getHeight() - INPUT_HEIGHT
    local lanesStartX = getLanesStartX()
    local lanesW = boss.numLanes * LANE_WIDTH

    love.graphics.setColor(0.12, 0.12, 0.18)
    love.graphics.rectangle("fill", lanesStartX, inputY, lanesW, INPUT_HEIGHT)

    local boxMargin = 8
    local boxH = INPUT_HEIGHT - 14
    local boxY = inputY + 7
    local boxX = lanesStartX + boxMargin
    local boxW = lanesW - boxMargin * 2
    love.graphics.setColor(0.18, 0.18, 0.25)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 5, 5)
    love.graphics.setColor(0.35, 0.35, 0.45)
    love.graphics.rectangle("line", boxX, boxY, boxW, boxH, 5, 5)

    love.graphics.setFont(fonts.input)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(inputText, boxX + 10, boxY + (boxH - fonts.input:getHeight()) / 2)

    local cursorX = boxX + 10 + fonts.input:getWidth(inputText)
    if math.floor(love.timer.getTime() * 2) % 2 == 0 then
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.rectangle("fill", cursorX, boxY + 5, 2, boxH - 10)
    end

    if #inputText == 0 then
        love.graphics.setColor(0.4, 0.4, 0.5)
        love.graphics.setFont(fonts.inputPlaceholder)
        love.graphics.print("Type a word and press Enter", boxX + 10,
            boxY + (boxH - fonts.inputPlaceholder:getHeight()) / 2)
    end
end

local function drawUsedWords()
    local lanesEndX = getLanesStartX() + boss.numLanes * LANE_WIDTH
    local x = lanesEndX + 20
    local y = 10
    local lineH = fonts.sidebar:getHeight() + 2

    love.graphics.setFont(fonts.sidebar)
    love.graphics.setColor(0.5, 0.5, 0.6)
    love.graphics.print("Used Words", x, y)
    y = y + lineH + 4

    local maxVisible = math.floor((getLaneBottom() - 55 - y) / lineH)
    local start = math.max(1, #usedWords - maxVisible + 1)
    for i = start, #usedWords do
        love.graphics.setColor(0.35, 0.35, 0.45)
        love.graphics.print(usedWords[i], x, y)
        y = y + lineH
    end
end

local function drawGameOver()
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    love.graphics.setFont(fonts.title)
    if endless then
        love.graphics.setColor(1, 0.85, 0.2)
        love.graphics.printf("GAME OVER", 0, love.graphics.getHeight() / 2 - 60, love.graphics.getWidth(), "center")
        love.graphics.setFont(fonts.subtitle)
        love.graphics.setColor(0.7, 0.7, 0.8)
        love.graphics.printf("Score: " .. score, 0, love.graphics.getHeight() / 2, love.graphics.getWidth(), "center")
        love.graphics.printf("Press Enter to return to title", 0, love.graphics.getHeight() / 2 + 40,
            love.graphics.getWidth(), "center")
    elseif gameState == "won" then
        love.graphics.setColor(0.3, 1, 0.5)
        love.graphics.printf("VICTORY!", 0, love.graphics.getHeight() / 2 - 30, love.graphics.getWidth(), "center")
        love.graphics.setFont(fonts.subtitle)
        love.graphics.setColor(0.7, 0.7, 0.8)
        love.graphics.printf("Press Enter to continue", 0, love.graphics.getHeight() / 2 + 20, love.graphics.getWidth(),
            "center")
    else
        love.graphics.setColor(1, 0.3, 0.3)
        love.graphics.printf("DEFEATED!", 0, love.graphics.getHeight() / 2 - 30, love.graphics.getWidth(), "center")
        love.graphics.setFont(fonts.subtitle)
        love.graphics.setColor(0.7, 0.7, 0.8)
        love.graphics.printf("Enter to retry / Escape for gauntlet", 0, love.graphics.getHeight() / 2 + 20,
            love.graphics.getWidth(), "center")
    end
end

local function drawAlphabetGrid()
    if not endless then return end

    local panelX = getLanesStartX() + boss.numLanes * LANE_WIDTH
    local panelW = love.graphics.getWidth() - panelX
    local cellSize = 38
    local cellGap = 3
    local cols = 2
    local rows = 13
    local gridW = cols * cellSize + (cols - 1) * cellGap
    local gridH = rows * (cellSize + cellGap) - cellGap

    local gridX = panelX + (panelW - gridW) / 2
    local gridY = 40

    love.graphics.setFont(fonts.ui)
    love.graphics.setColor(0.5, 0.5, 0.6)

    local alphabet = "abcdefghijklmnopqrstuvwxyz"
    for i = 1, 26 do
        local letter = alphabet:sub(i, i)
        local col = math.ceil(i / 13) - 1
        local row = (i - 1) % 13

        local x = gridX + col * (cellSize + cellGap)
        local y = gridY + row * (cellSize + cellGap)

        local used = usedLetters[letter]

        if used then
            love.graphics.setColor(0.2, 0.6, 0.3, 0.6)
        else
            love.graphics.setColor(0.15, 0.15, 0.2, 0.4)
        end
        love.graphics.rectangle("fill", x, y, cellSize, cellSize, 4, 4)

        love.graphics.setFont(fonts.card)
        if used then
            love.graphics.setColor(1, 1, 1, 1.0)
        else
            love.graphics.setColor(0.4, 0.4, 0.5, 0.35)
        end
        local tw = fonts.card:getWidth(letter:upper())
        local th = fonts.card:getHeight()
        love.graphics.print(letter:upper(), x + (cellSize - tw) / 2, y + (cellSize - th) / 2)
    end
end

local function drawLoading()
    love.graphics.setFont(fonts.title)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Counter Spell", 0, love.graphics.getHeight() / 2 - 40, love.graphics.getWidth(), "center")
    love.graphics.setFont(fonts.subtitle)
    love.graphics.setColor(0.6, 0.6, 0.7)
    love.graphics.printf("Loading words...", 0, love.graphics.getHeight() / 2 + 10, love.graphics.getWidth(), "center")
end

local function drawGame()
    local lanesStartX = getLanesStartX()
    local laneBottom = getLaneBottom()

    love.graphics.setColor(0.06, 0.06, 0.1)
    love.graphics.rectangle("fill", lanesStartX, 0, boss.numLanes * LANE_WIDTH, laneBottom)

    if inputText ~= highlightCacheKey then
        highlightCacheKey = inputText
        if #inputText > 0 then
            local _, matchSet = cardMatches.findMatches(inputText, lanes, activeChains)
            highlightCache = matchSet
        else
            highlightCache = {}
        end
    end

    for i = 1, boss.numLanes do
        local x = lanesStartX + (i - 1) * LANE_WIDTH

        love.graphics.setColor(0.18, 0.18, 0.25)
        love.graphics.rectangle("line", x, 0, LANE_WIDTH, laneBottom)

        for _, card in ipairs(lanes[i]) do
            local highlighted = highlightCache[card] or false
            drawCard(x + (LANE_WIDTH - CARD_SIZE) / 2, card.y, card, highlighted)
        end
    end

    for _, chain in ipairs(activeChains) do
        local points = {}
        for _, member in ipairs(chain.cards) do
            for _, card in ipairs(lanes[member.laneIdx]) do
                if card.chainId == chain.id and card.chainOrder == member.chainOrder then
                    local px = lanesStartX + (member.laneIdx - 1) * LANE_WIDTH + LANE_WIDTH / 2
                    local py = card.y + CARD_SIZE / 2
                    table.insert(points, { x = px, y = py })
                    break
                end
            end
        end
        if #points >= 2 then
            love.graphics.setColor(1.0, 0.6, 0.0, 0.5)
            love.graphics.setLineWidth(5)
            for i = 1, #points - 1 do
                love.graphics.line(points[i].x, points[i].y, points[i + 1].x, points[i + 1].y)
            end
            love.graphics.setLineWidth(1)
        end
    end

    love.graphics.setColor(0.8, 0.2, 0.2, 0.4)
    love.graphics.setLineWidth(2)
    love.graphics.line(lanesStartX, laneBottom - 2, lanesStartX + boss.numLanes * LANE_WIDTH, laneBottom - 2)
    love.graphics.setLineWidth(1)

    if endless then
        drawScore()
    else
        drawBossBar()
    end
    drawPlayerHP()
    drawInput()

    -- Reject message above input bar
    if rejectMsg then
        local alpha = math.min(rejectMsg.timer / 0.3, 1)
        love.graphics.setFont(fonts.ui)
        local msgW = fonts.ui:getWidth(rejectMsg.text)
        local msgX = (love.graphics.getWidth() - msgW) / 2
        local msgY = love.graphics.getHeight() - INPUT_HEIGHT - 30
        love.graphics.setColor(1, 0.35, 0.35, alpha)
        love.graphics.print(rejectMsg.text, msgX, msgY)
    end

    drawUsedWords()
    drawAlphabetGrid()
    drawFlyingCards()
    drawParticles()

    if gameState == "won" or gameState == "lost" then
        drawGameOver()
    end
end

-- Screen interface

function game.enter(context)
    fonts = context.resources.fonts
    sounds = context.resources.sounds
    switchScreen = context.switchScreen
    boss = context.boss
    endless = context.endless or false
    playerMaxHP = endless and 5 or PLAYER_MAX_HP

    if not loaded then
        loadWords()
        loaded = true
    end

    waveModule.init({
        numLanes        = boss.numLanes,
        cardSize        = CARD_SIZE,
        cardSpeed       = boss.cardSpeed,
        waveSizeMin     = boss.waveSizeMin,
        waveSizeMax     = boss.waveSizeMax,
        chainChance     = boss.chainChance,
        chainSizeMin    = boss.chainSizeMin,
        chainSizeMax    = boss.chainSizeMax,
        shieldChance    = boss.shieldChance,
        minShield       = boss.minShield,
        maxShield       = boss.maxShield,
        fastChance      = boss.fastChance,
        startWithChance = boss.startWithChance,
        endWithChance   = boss.endWithChance,
        infixChance     = boss.infixChance,
        bombChance      = boss.bombChance,
        letterWeights   = LETTER_WEIGHTS,
    })
    resetGame()
end

function game.update(dt)
    if rejectMsg then
        rejectMsg.timer = rejectMsg.timer - dt
        if rejectMsg.timer <= 0 then
            rejectMsg = nil
        end
    end

    if shakeTimer > 0 then
        shakeTimer = shakeTimer - dt
    end
    if bossShakeTimer > 0 then
        bossShakeTimer = bossShakeTimer - dt
    end

    local completed = flyingCardsLib.update(dt)
    for _, batch in ipairs(completed) do
        bossShakeTimer = 0.35
        bossShakeIntensity = 5
        particlesLib.spawn(batch.targetX, batch.targetY, 12 + #batch.cards * 3)
    end

    particlesLib.update(dt)

    if gameState ~= "playing" then return end

    if boardIsEmpty() then
        waveTimer = 0
        spawnWave()
    else
        waveTimer = waveTimer + dt
        if waveTimer >= nextWaveTime then
            waveTimer = 0
            spawnWave()
        end
    end

    local laneBottom = getLaneBottom()
    for laneIdx, lane in ipairs(lanes) do
        for i = #lane, 1, -1 do
            local card = lane[i]
            if card.pauseTimer and card.pauseTimer > 0 then
                card.pauseTimer = card.pauseTimer - dt
            else
                card.y = card.y + card.speed * dt
            end
            if card.twistTimer and card.twistTimer > 0 then
                card.twistTimer = card.twistTimer - dt
            end

            if card.y + CARD_SIZE >= laneBottom then
                if card.chainId then
                    local fallenOrder = card.chainOrder
                    local cid = card.chainId
                    for _, ln in ipairs(lanes) do
                        for _, c in ipairs(ln) do
                            if c.chainId == cid and c.chainOrder > fallenOrder then
                                c.chainId = nil
                                c.chainOrder = nil
                            end
                        end
                    end
                end

                local cardCX = getLanesStartX() + (laneIdx - 1) * LANE_WIDTH + LANE_WIDTH / 2
                local cardCY = laneBottom - CARD_SIZE / 2
                if card.bomb then
                    particlesLib.spawn(cardCX, cardCY, 10, {
                        color = "smoke", speedMin = 20, speedMax = 50,
                        lifeMin = 0.4, sizeMin = 3, sizeMax = 4, vyBias = -20,
                    })
                else
                    particlesLib.spawn(cardCX, cardCY, 12, {
                        color = "red", speedMax = 100,
                        lifeMin = 0.25, lifeMax = 0.25,
                    })
                end

                table.remove(lane, i)
                highlightCacheKey = ""

                if card.chainId then
                    cleanupChain(card.chainId)
                end

                if not card.bomb then
                    playerHP = playerHP - 1
                    shakeTimer = 0.3
                    shakeIntensity = 4
                end

                if playerHP <= 0 then
                    playerHP = 0
                    gameState = "lost"
                end
            end
        end
    end
end

function game.draw()
    local shakeX, shakeY = 0, 0
    if shakeTimer > 0 then
        shakeX = (love.math.random() * 2 - 1) * shakeIntensity
        shakeY = (love.math.random() * 2 - 1) * shakeIntensity
    end
    love.graphics.push()
    love.graphics.translate(shakeX, shakeY)

    love.graphics.setBackgroundColor(0.08, 0.08, 0.12)

    if gameState == "loading" then
        drawLoading()
    else
        drawGame()
    end

    love.graphics.pop()
end

function game.keypressed(key)
    if gameState == "won" and not endless then
        if key == "return" or key == "space" or key == "escape" then
            gauntlet.advance()
            switchScreen("totem", { justDefeated = true })
        end
        return
    end
    if gameState == "lost" then
        if endless then
            if key == "return" or key == "space" or key == "escape" then
                switchScreen("title")
            end
        else
            if key == "return" or key == "space" then
                resetGame()
            elseif key == "escape" then
                switchScreen("totem")
            end
        end
        return
    end

    if gameState ~= "playing" then return end

    if key == "backspace" then
        if #inputText > 0 then
            sounds.thunk:stop()
            sounds.thunk:play()
        end
        inputText = inputText:sub(1, -2)
    elseif key == "return" then
        submitWord()
    elseif key == "escape" then
        inputText = ""
    end
end

function game.textinput(text)
    if gameState ~= "playing" then return end
    local ch = text:lower()
    if ch:match("^[a-z]$") then
        inputText = inputText .. ch
        local snd = sounds.typewriter[love.math.random(1, 4)]
        snd:stop()
        snd:play()
    end
end

return game
