-- Gauntlet: manages boss progression through a sequential boss fight
local gauntlet = {}

local BOSS_REGISTRY = {
    {
        id = "white_wizard",
        name = "White Wizard",
        boss = require("bosses.white_wizard"),
        info = {
            demo = true,
            title = "How to Play",
            lines = {
                "Letter cards fall down the lanes toward the bottom.",
                "Type a word that includes some letters on screen, then press Enter.",
                "",
                "If the word is valid and matches card(s) on the board,",
                "those cards are removed and damage is dealt to the boss.",
                "",
                "But watch out! Cards that reach the bottom will damage you.",
                "",
                "Reduce the boss's HP to zero to win.",
            },
            examples = {
                { letter = "c" },
                { letter = "a" },
                { letter = "t" },
            },
        },
    },
    {
        id = "affixer",
        name = "Affixer",
        boss = require("bosses.affixer"),
        info = {
            title = "The Affixer",
            lines = {
                "This boss plays with prefixes, suffixes, and infixes.",
                "",
                "Some cards show a letter with a dash:",
                "",
                "A-  means your word must START with that letter.",
                "-S  means your word must END with that letter.",
                "-E-  means that letter must appear IN THE MIDDLE.",
                "",
                "Plan your words carefully around these constraints!",
            },
            examples = {
                { letter = "a", startWith = true },
                { letter = "s", endWith = true },
                { letter = "e", infix = true },
            },
        },
    },
    {
        id = "blizzard",
        name = "Blizzard",
        boss = require("bosses.blizzard"),
        info = {
            title = "Blizzard",
            lines = {
                "This boss encases cards in shields of ice.",
                "",
                "Shielded cards have glowing rings around them.",
                "Each ring must be broken with a separate word",
                "before the card itself can be cleared.",
                "",
                "Hit shielded cards across multiple words to break through!",
            },
            examples = {
                { letter = "b", shielded = true, shieldHits = 2 },
            },
        },
    },
    {
        id = "bomber",
        name = "Bomber",
        boss = require("bosses.bomber"),
        info = {
            title = "Bomber",
            lines = {
                "This boss fills the board with bombs!",
                "",
                "Bombs are round, black cards with a lit fuse.",
                "If you match a bomb in your word, it damages YOU instead.",
                "But bombs that fall off the bottom do nothing.",
                "",
                "Type words that use normal cards while avoiding bombs.",
            },
            examples = {
                { letter = "e" },
                { letter = "x", bomb = true },
                { letter = "t" },
            },
        },
    },
    {
        id = "rabbit",
        name = "Rabbit",
        boss = require("bosses.rabbit"),
        info = {
            title = "Rabbit",
            lines = {
                "This boss sends cards racing down the lanes!",
                "",
                "Fast cards have speed lines beneath them",
                "and fall much quicker than normal.",
                "",
                "You'll need to think and type fast to keep up!",
            },
            examples = {
                { letter = "r", fast = true },
            },
        },
    },
    {
        id = "the_chain",
        name = "The Chain",
        boss = require("bosses.the_chain"),
        info = {
            title = "The Chain",
            lines = {
                "This boss links cards together in chains.",
                "",
                "Chained cards are connected by orange lines",
                "and must be cleared in order from first to last.",
                "",
                "Find words that match the chain's letter sequence!",
            },
            examples = {
                { letter = "d", chained = true },
                { letter = "o", chained = true },
                { letter = "g", chained = true },
            },
        },
    },
    {
        id = "dragon",
        name = "Dragon",
        boss = require("bosses.dragon"),
    }
}

gauntlet.bosses = {}
gauntlet.currentLevel = 1
gauntlet.hasBeenCompleted = false

function gauntlet.init()
    gauntlet.bosses = {}
    -- White wizard is always first
    gauntlet.bosses[1] = {
        id = BOSS_REGISTRY[1].id,
        name = BOSS_REGISTRY[1].name,
        boss = BOSS_REGISTRY[1].boss,
        info = BOSS_REGISTRY[1].info,
        defeated = false,
    }
    -- Collect middle bosses (exclude first and last) and shuffle (Fisher-Yates)
    local middle = {}
    for i = 2, #BOSS_REGISTRY - 1 do
        middle[#middle + 1] = BOSS_REGISTRY[i]
    end
    for i = #middle, 2, -1 do
        local j = love.math.random(1, i)
        middle[i], middle[j] = middle[j], middle[i]
    end
    for _, entry in ipairs(middle) do
        gauntlet.bosses[#gauntlet.bosses + 1] = {
            id = entry.id,
            name = entry.name,
            boss = entry.boss,
            info = entry.info,
            defeated = false,
        }
    end
    -- Dragon is always last
    local last = BOSS_REGISTRY[#BOSS_REGISTRY]
    gauntlet.bosses[#gauntlet.bosses + 1] = {
        id = last.id,
        name = last.name,
        boss = last.boss,
        info = last.info,
        defeated = false,
    }
    gauntlet.currentLevel = 1
end

function gauntlet.getCurrentBoss()
    return gauntlet.bosses[gauntlet.currentLevel]
end

function gauntlet.advance()
    gauntlet.bosses[gauntlet.currentLevel].defeated = true
    gauntlet.currentLevel = gauntlet.currentLevel + 1
    if gauntlet.isComplete() then
        gauntlet.hasBeenCompleted = true
    end
end

function gauntlet.isComplete()
    return gauntlet.currentLevel > #gauntlet.bosses
end

return gauntlet
