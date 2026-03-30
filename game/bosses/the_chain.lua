local waveModule = require("wave")

local boss = {
    faceColor       = {0.5, 0.5, 0.6},
    numLanes        = 7,
    cardSpeed       = 40,
    maxHP           = 30,
    waveIntervalMin = 10.0,
    waveIntervalMax = 15.0,
    waveSizeMin     = 3,
    waveSizeMax     = 7,
    shieldChance    = 0,
    minShield       = 2,
    maxShield       = 3,
    fastChance      = 0,
    startWithChance = 0,
    endWithChance   = 0,
    infixChance     = 0,
    bombChance      = 0,
    chainChance     = 1,
    chainSizeMin    = 2,
    chainSizeMax    = 3,
}

function boss.spawnWave(lanes)
    local count = math.min(
        love.math.random(boss.waveSizeMin, boss.waveSizeMax),
        boss.numLanes
    )
    local chains = {}
    local lane = love.math.random(1, boss.numLanes - count + 1)
    local remaining = count

    while remaining >= boss.chainSizeMin do
        local maxSize = math.min(boss.chainSizeMax, remaining, boss.numLanes - lane + 1)
        if maxSize < boss.chainSizeMin then break end

        local size = love.math.random(boss.chainSizeMin, maxSize)
        local chain = waveModule.spawnChain(size, lane, lanes)
        table.insert(chains, chain)

        lane = lane + size
        remaining = remaining - size
    end

    return chains
end

return boss
