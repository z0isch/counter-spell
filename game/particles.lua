-- Shared particle burst system
local particles = {}

local active = {}

function particles.spawn(x, y, count, opts)
    opts = opts or {}
    local color = opts.color
    local speedMin = opts.speedMin or 40
    local speedMax = opts.speedMax or 120
    local lifeMin = opts.lifeMin or 0.3
    local lifeMax = opts.lifeMax or 0.3
    local sizeMin = opts.sizeMin or 2
    local sizeMax = opts.sizeMax or 3
    local vyBias = opts.vyBias or 0

    for _ = 1, count do
        local angle = love.math.random() * math.pi * 2
        local speed = speedMin + love.math.random() * (speedMax - speedMin)
        local life = lifeMin + love.math.random() * lifeMax
        active[#active + 1] = {
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed + vyBias,
            life = life,
            maxLife = life,
            size = sizeMin + love.math.random() * (sizeMax - sizeMin),
            color = color,
        }
    end
end

function particles.update(dt)
    for i = #active, 1, -1 do
        local p = active[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.vx = p.vx * 0.96
        p.vy = p.vy * 0.96
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(active, i)
        end
    end
end

function particles.draw()
    for _, p in ipairs(active) do
        local t = p.life / p.maxLife
        local alpha = t
        local size = p.size * t
        local r, g, b
        if p.color == "smoke" then
            local grey = 0.3 + 0.3 * t
            r, g, b = grey, grey, grey
        elseif p.color == "red" then
            r = 1
            g = 0.15 + 0.2 * t
            b = 0.05 * t
        else
            r = 1
            g = 0.4 + 0.5 * t
            b = 0.1 * t
        end
        love.graphics.setColor(r, g, b, alpha)
        love.graphics.circle("fill", p.x, p.y, size)
    end
end

function particles.reset()
    active = {}
end

return particles
