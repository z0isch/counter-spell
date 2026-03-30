-- ngrams.lua: Compute top bigrams and trigrams by frequency from a word list

local ngrams = {}

--- Count all bigrams and trigrams in the word file, return the top N of each.
-- @param filename  Path to the word list (one word per line)
-- @param topN      How many of each to keep (default 250)
-- @return bigrams  Array of top bigram strings, sorted by frequency desc
-- @return trigrams Array of top trigram strings, sorted by frequency desc
function ngrams.compute(filename, topN)
    topN = topN or 250

    local bigramCounts = {}
    local trigramCounts = {}

    for line in love.filesystem.lines(filename) do
        local word = line:lower():match("^%s*(.-)%s*$")
        if word and #word >= 2 then
            for i = 1, #word - 1 do
                local bg = word:sub(i, i + 1)
                bigramCounts[bg] = (bigramCounts[bg] or 0) + 1
            end
            if #word >= 3 then
                for i = 1, #word - 2 do
                    local tg = word:sub(i, i + 2)
                    trigramCounts[tg] = (trigramCounts[tg] or 0) + 1
                end
            end
        end
    end

    local function topEntries(counts, n)
        local entries = {}
        for ngram, count in pairs(counts) do
            table.insert(entries, { ngram = ngram, count = count })
        end
        table.sort(entries, function(a, b) return a.count > b.count end)
        local result = {}
        for i = 1, math.min(n, #entries) do
            table.insert(result, entries[i].ngram)
        end
        return result
    end

    local bigrams = topEntries(bigramCounts, topN)
    local trigrams = topEntries(trigramCounts, topN)

    return bigrams, trigrams
end

return ngrams
