-- wave.lua: Wave spawning logic for Counter Spell

local ngramsModule = require("ngrams")

local wave = {}

-- Module state (set via wave.init)
local NUM_LANES
local CARD_SIZE
local CARD_SPEED
local WAVE_SIZE_MIN
local WAVE_SIZE_MAX
local CHAIN_CHANCE
local CHAIN_SIZE_MIN
local CHAIN_SIZE_MAX
local SHIELD_CHANCE
local MIN_SHIELD
local MAX_SHIELD
local FAST_CHANCE
local STARTWITH_CHANCE
local ENDWITH_CHANCE
local INFIX_CHANCE
local BOMB_CHANCE
local LETTER_WEIGHTS
local startLetterWeights = {}
local endLetterWeights = {}
local topBigrams = {}
local topTrigrams = {}
local chainWords = {}
local nextChainId = 1

function wave.init(config)
    NUM_LANES        = config.numLanes
    CARD_SIZE        = config.cardSize
    CARD_SPEED       = config.cardSpeed
    WAVE_SIZE_MIN    = config.waveSizeMin
    WAVE_SIZE_MAX    = config.waveSizeMax
    CHAIN_CHANCE     = config.chainChance
    CHAIN_SIZE_MIN   = config.chainSizeMin
    CHAIN_SIZE_MAX   = config.chainSizeMax
    SHIELD_CHANCE    = config.shieldChance
    MIN_SHIELD       = config.minShield
    MAX_SHIELD       = config.maxShield
    FAST_CHANCE      = config.fastChance
    STARTWITH_CHANCE = config.startWithChance
    ENDWITH_CHANCE   = config.endWithChance
    INFIX_CHANCE     = config.infixChance
    BOMB_CHANCE      = config.bombChance
    LETTER_WEIGHTS   = config.letterWeights
end

function wave.loadWordData(wordSet)
    -- Build word index by length for chain generation
    chainWords = {}
    for word, _ in pairs(wordSet) do
        local len = #word
        if not chainWords[len] then
            chainWords[len] = {}
        end
        table.insert(chainWords[len], word)
    end

    -- Build word-boundary letter weights
    startLetterWeights = {}
    endLetterWeights = {}
    for word, _ in pairs(wordSet) do
        local s = word:sub(1, 1)
        local e = word:sub(-1, -1)
        startLetterWeights[s] = (startLetterWeights[s] or 0) + 1
        endLetterWeights[e] = (endLetterWeights[e] or 0) + 1
    end

    -- Compute top bigrams and trigrams
    topBigrams, topTrigrams = ngramsModule.compute("words.txt", 250)
end

function wave.resetChainId()
    nextChainId = 1
end

-- Letter generation helpers

local function weightedRandomLetter(weights)
    local total = 0
    for _, count in pairs(weights) do
        total = total + count
    end
    local roll = love.math.random(1, total)
    for letter, count in pairs(weights) do
        roll = roll - count
        if roll <= 0 then return letter end
    end
end

local function randomLetter()
    return weightedRandomLetter(LETTER_WEIGHTS)
end

local function randomLetterExcluding(weights, excludeSet)
    local filtered = {}
    for letter, count in pairs(weights) do
        if not excludeSet[letter] then filtered[letter] = count end
    end
    if next(filtered) == nil then return weightedRandomLetter(weights) end
    return weightedRandomLetter(filtered)
end

-- Card type rolling

local function applyCardTypeRoll(card, opts)
    opts = opts or {}
    -- Bomb is exclusive of all other modifiers
    if not opts.noBomb and love.math.random() < BOMB_CHANCE then
        card.bomb = true
        return
    end
    if love.math.random() < SHIELD_CHANCE then
        card.shielded = true
        card.shieldHits = love.math.random(MIN_SHIELD, MAX_SHIELD)
        card.maxShieldHits = card.shieldHits
    end
    if love.math.random() < FAST_CHANCE then
        card.fast = true
        local mult = 1.5 + love.math.random() * 1.0 -- 1.5x–2.5x speed
        card.speedMultiplier = mult
        card.speed = CARD_SPEED * mult
    end
    if not opts.noPosition then
        local posRoll = love.math.random()
        if posRoll < STARTWITH_CHANCE then
            card.startWith = true
        elseif posRoll < STARTWITH_CHANCE + ENDWITH_CHANCE then
            card.endWith = true
        elseif posRoll < STARTWITH_CHANCE + ENDWITH_CHANCE + INFIX_CHANCE then
            card.infix = true
        end
    end
end

-- Chain letter generation

local function generateChainLetters(chainSize, needStartWith, needEndWith)
    -- For startWith/endWith constraints, use word-substring approach
    if needStartWith or needEndWith then
        for _ = 1, 20 do
            local minLen = chainSize
            local maxLen = math.min(chainSize + 5, 10)
            if needStartWith and needEndWith then
                maxLen = chainSize
            end
            local targetLen = love.math.random(minLen, maxLen)
            local wordList = chainWords[targetLen]
            if wordList and #wordList > 0 then
                local word = wordList[love.math.random(1, #wordList)]
                local startPos
                if needStartWith then
                    startPos = 1
                elseif needEndWith then
                    startPos = #word - chainSize + 1
                end
                if startPos and startPos >= 1 then
                    local letters = {}
                    for i = startPos, startPos + chainSize - 1 do
                        table.insert(letters, word:sub(i, i))
                    end
                    return letters
                end
            end
        end
    end

    -- Pick from top bigrams/trigrams by frequency
    local pool = chainSize == 2 and topBigrams or topTrigrams
    if #pool > 0 then
        local ngram = pool[love.math.random(1, #pool)]
        local letters = {}
        for i = 1, #ngram do
            table.insert(letters, ngram:sub(i, i))
        end
        return letters
    end

    -- Fallback: random letters
    local letters = {}
    for _ = 1, chainSize do
        table.insert(letters, randomLetter())
    end
    return letters
end

-- Wave spawning helpers

local function rollChain(count)
    if love.math.random() >= CHAIN_CHANCE or count < CHAIN_SIZE_MIN then
        return nil
    end

    local size = love.math.random(CHAIN_SIZE_MIN, math.min(CHAIN_SIZE_MAX, count))
    local startWith = love.math.random() < STARTWITH_CHANCE
    local endWith = love.math.random() < ENDWITH_CHANCE
    local start = love.math.random(1, NUM_LANES - size + 1)

    local lanes = {}
    for i = start, start + size - 1 do
        table.insert(lanes, i)
    end

    local id = nextChainId
    nextChainId = nextChainId + 1

    return {
        id = id,
        size = size,
        lanes = lanes,
        letters = generateChainLetters(size, startWith, endWith),
        startWith = startWith,
        endWith = endWith,
    }
end

local function pickNonChainLanes(chainLanes, totalCount)
    local chainLaneSet = {}
    for _, laneIdx in ipairs(chainLanes) do
        chainLaneSet[laneIdx] = true
    end

    local available = {}
    for i = 1, NUM_LANES do
        if not chainLaneSet[i] then
            table.insert(available, i)
        end
    end

    -- Shuffle
    for i = #available, 2, -1 do
        local j = love.math.random(1, i)
        available[i], available[j] = available[j], available[i]
    end

    local count = math.min(totalCount - #chainLanes, #available)
    local result = {}
    for i = 1, count do
        table.insert(result, available[i])
    end
    return result
end

local function spawnChainCards(chain, gameLanes)
    for order, laneIdx in ipairs(chain.lanes) do
        local card = {
            letter = chain.letters[order],
            y = 0,
            speed = CARD_SPEED,
            chainId = chain.id,
            chainOrder = order,
        }
        applyCardTypeRoll(card, { noBomb = true, noPosition = true })
        card.pauseTimer = CARD_SIZE / card.speed
        if order == 1 and chain.startWith then
            card.startWith = true
        elseif order == chain.size and chain.endWith then
            card.endWith = true
        elseif love.math.random() < INFIX_CHANCE then
            card.infix = true
        end
        table.insert(gameLanes[laneIdx], card)
    end
end

local function spawnNonChainCards(laneList, gameLanes)
    local cards = {}
    for _, laneIdx in ipairs(laneList) do
        local card = {
            letter = randomLetter(),
            y = 0,
            speed = CARD_SPEED,
        }
        applyCardTypeRoll(card)
        card.pauseTimer = CARD_SIZE / card.speed
        if not card.bomb then
            if card.startWith then
                card.letter = weightedRandomLetter(startLetterWeights)
            elseif card.endWith then
                card.letter = weightedRandomLetter(endLetterWeights)
            end
        end
        table.insert(gameLanes[laneIdx], card)
        table.insert(cards, card)
    end

    -- Ensure at least one non-bomb card so the wave is playable
    local allBombs = true
    for _, card in ipairs(cards) do
        if not card.bomb then
            allBombs = false; break
        end
    end
    if allBombs and #cards > 0 then
        local pick = cards[love.math.random(1, #cards)]
        pick.bomb = nil
        applyCardTypeRoll(pick, { noBomb = true })
        if pick.startWith then
            pick.letter = weightedRandomLetter(startLetterWeights)
        elseif pick.endWith then
            pick.letter = weightedRandomLetter(endLetterWeights)
        end
    end

    return cards
end

local function deconflictBombs(cards)
    local bombLetterSet = {}
    for _, card in ipairs(cards) do
        if card.bomb then bombLetterSet[card.letter] = true end
    end
    if next(bombLetterSet) == nil then return end

    for _, card in ipairs(cards) do
        if not card.bomb and bombLetterSet[card.letter] then
            if card.startWith then
                card.letter = randomLetterExcluding(startLetterWeights, bombLetterSet)
            elseif card.endWith then
                card.letter = randomLetterExcluding(endLetterWeights, bombLetterSet)
            else
                card.letter = randomLetterExcluding(LETTER_WEIGHTS, bombLetterSet)
            end
        end
    end
end

--- Create a chain descriptor and spawn its cards into the given lanes.
-- @param size       Number of cards in the chain
-- @param startLane  First lane index for the chain
-- @param gameLanes  The game's lanes array (mutated: new cards inserted)
-- @return chain     Chain descriptor
function wave.spawnChain(size, startLane, gameLanes)
    local startWith = love.math.random() < STARTWITH_CHANCE
    local endWith = love.math.random() < ENDWITH_CHANCE

    local chainLanes = {}
    for i = startLane, startLane + size - 1 do
        table.insert(chainLanes, i)
    end

    local id = nextChainId
    nextChainId = nextChainId + 1

    local chain = {
        id = id,
        size = size,
        lanes = chainLanes,
        letters = generateChainLetters(size, startWith, endWith),
        startWith = startWith,
        endWith = endWith,
    }

    spawnChainCards(chain, gameLanes)
    return chain
end

--- Spawn a wave of cards into the given lanes.
-- @param gameLanes  The game's lanes array (mutated: new cards inserted)
-- @return chain     Chain descriptor to register, or nil
function wave.spawn(gameLanes)
    local count = math.min(love.math.random(WAVE_SIZE_MIN, WAVE_SIZE_MAX), NUM_LANES)

    local chain = rollChain(count)
    local nonChainLanes = pickNonChainLanes(chain and chain.lanes or {}, count)

    if chain then spawnChainCards(chain, gameLanes) end
    local waveCards = spawnNonChainCards(nonChainLanes, gameLanes)
    deconflictBombs(waveCards)

    return chain
end

return wave
