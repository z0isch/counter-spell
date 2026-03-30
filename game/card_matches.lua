-- card_matches.lua: Card matching logic for Counter Spell

local card_matches = {}

-- Try to match an entire chain against the text (all-or-nothing).
-- Returns list of {entry, wordPos} or nil.
local function tryMatchChain(chain, allCards, text, usedPositions)
    local chainCards = {}
    for _, entry in ipairs(allCards) do
        if entry.card.chainId == chain.id then
            table.insert(chainCards, entry)
        end
    end
    table.sort(chainCards, function(a, b) return a.card.chainOrder < b.card.chainOrder end)

    local chainLen = #chainCards
    if chainLen == 0 then return nil end

    local minStart = 1
    local maxStart = #text - chainLen + 1
    if maxStart < 1 then return nil end

    -- Constrain start position based on startWith/endWith on chain endpoints
    if chainCards[1].card.startWith then
        maxStart = 1
    end
    if chainCards[chainLen].card.endWith then
        local required = #text - chainLen + 1
        minStart = math.max(minStart, required)
        maxStart = math.min(maxStart, required)
    end
    if minStart > maxStart then return nil end

    for start = minStart, maxStart do
        local valid = true
        -- Check infix constraints: infix cards must not be at first or last position
        for j = 1, chainLen do
            if chainCards[j].card.infix then
                local wordPos = start + j - 1
                if wordPos == 1 or wordPos == #text then
                    valid = false
                    break
                end
            end
        end
        if valid then
        for j = 1, chainLen do
            if usedPositions[start + j - 1] then
                valid = false
                break
            end
        end
        end
        if valid then
            for j = 1, chainLen do
                if text:sub(start + j - 1, start + j - 1) ~= chainCards[j].card.letter then
                    valid = false
                    break
                end
            end
        end
        if valid then
            local result = {}
            for j = 1, chainLen do
                table.insert(result, { entry = chainCards[j], wordPos = start + j - 1 })
            end
            return result
        end
    end

    return nil
end

--- Find all cards matching the given word text.
-- @param text          string  The typed word
-- @param lanes         table   Array of lane arrays containing card objects
-- @param activeChains  table   Array of active chain descriptors
-- @return matches      table   Array of {laneIdx, cardIdx, card} for matched cards
-- @return matchSet     table   {[card]=true} set for O(1) lookup
function card_matches.findMatches(text, lanes, activeChains)
    if #text == 0 then return {}, {} end

    -- Collect all cards sorted by Y descending (closest to bottom first)
    -- Skip bombs that haven't started moving yet (still paused)
    local allCards = {}
    for laneIdx, lane in ipairs(lanes) do
        for cardIdx, card in ipairs(lane) do
            if not (card.bomb and card.pauseTimer and card.pauseTimer > 0) then
                table.insert(allCards, { laneIdx = laneIdx, cardIdx = cardIdx, card = card })
            end
        end
    end
    table.sort(allCards, function(a, b) return a.card.y > b.card.y end)

    local matchedEntries = {}
    local matchSet       = {}
    local usedPositions  = {}
    local usedCards      = {}

    -- Pass 1: chain matching (all-or-nothing per chain)
    for _, chain in ipairs(activeChains) do
        local result = tryMatchChain(chain, allCards, text, usedPositions)
        if result then
            for _, match in ipairs(result) do
                matchSet[match.entry.card] = true
                usedCards[match.entry.card] = true
                usedPositions[match.wordPos] = true
                table.insert(matchedEntries, match.entry)
            end
        end
    end

    -- Pass 2: greedy single-card matching (closest to bottom first)
    for i = 1, #text do
        if not usedPositions[i] then
            local ch = text:sub(i, i)
            for _, entry in ipairs(allCards) do
                if not usedCards[entry.card] and not entry.card.chainId and entry.card.letter == ch then
                    local posOk = true
                    if entry.card.startWith and i ~= 1 then posOk = false end
                    if entry.card.endWith and i ~= #text then posOk = false end
                    if entry.card.infix and (i == 1 or i == #text) then posOk = false end
                    if posOk then
                        usedCards[entry.card] = true
                        matchSet[entry.card] = true
                        table.insert(matchedEntries, entry)
                        break
                    end
                end
            end
        end
    end

    return matchedEntries, matchSet
end

return card_matches
