-- Shared boss face drawing
local bossFace = {}

function bossFace.draw(cx, cy, size, hpFrac, faceColor, dimFactor)
    dimFactor = dimFactor or 1.0
    local scale = size / 200
    local ox = cx - size / 2
    local oy = cy - size / 2

    love.graphics.push()
    love.graphics.translate(ox, oy)
    love.graphics.scale(scale, scale)

    -- Face box
    local fc = faceColor or {0.5, 0.5, 0.5}
    love.graphics.setColor(fc[1] * dimFactor, fc[2] * dimFactor, fc[3] * dimFactor)
    love.graphics.rectangle("fill", 0, 0, 200, 200, 10, 10)
    love.graphics.setColor(fc[1] * 0.5, fc[2] * 0.5, fc[3] * 0.5)
    love.graphics.rectangle("line", 0, 0, 200, 200, 10, 10)

    local fcx, fcy = 100, 100
    local alpha = dimFactor < 1.0 and 0.35 or 1.0

    -- Feature color: black on light backgrounds, white on dark
    local lum = fc[1] * 0.299 + fc[2] * 0.587 + fc[3] * 0.114
    local feat = (lum > 0.5 and dimFactor >= 1.0) and 0 or 1

    -- Eyes
    local eyeY = fcy - 20
    local leftEyeX = fcx - 40
    local rightEyeX = fcx + 40
    love.graphics.setColor(feat, feat, feat, alpha)
    love.graphics.circle("fill", leftEyeX, eyeY, 12)
    love.graphics.circle("fill", rightEyeX, eyeY, 12)

    -- Eyebrows: angle inward (angry) as HP depletes
    local browAngle = (1 - hpFrac) * 0.5
    love.graphics.setLineWidth(4)
    love.graphics.line(
        leftEyeX - 24, eyeY - 28 - browAngle * 24,
        leftEyeX + 24, eyeY - 28 + browAngle * 24
    )
    love.graphics.line(
        rightEyeX - 24, eyeY - 28 + browAngle * 24,
        rightEyeX + 24, eyeY - 28 - browAngle * 24
    )
    love.graphics.setLineWidth(1)

    -- Mouth: smile at full HP, frown at 0 HP
    local mouthY = fcy + 40
    local mouthWidth = 40
    local smileCurve = (0.5 - hpFrac) * 64

    love.graphics.setLineWidth(4)
    local segments = 10
    local points = {}
    for i = 0, segments do
        local t = i / segments
        local px = fcx - mouthWidth + t * mouthWidth * 2
        local py = mouthY - smileCurve * 4 * t * (1 - t)
        points[#points + 1] = px
        points[#points + 1] = py
    end
    love.graphics.line(points)
    love.graphics.setLineWidth(1)

    love.graphics.pop()
end

return bossFace
