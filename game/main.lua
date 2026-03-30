https = nil
local overlayStats = require("lib.overlayStats")
local runtimeLoader = require("runtime.loader")

-- Counter Spell: A typing game where you defeat a boss by spelling words
local screens = {
    title    = require("screens.title"),
    game     = require("screens.game"),
    totem    = require("screens.totem"),
    info     = require("screens.info"),
    congrats = require("screens.congrats"),
}

local currentScreen = nil
local resources = {}

local function switchScreen(name, data)
    if currentScreen and currentScreen.leave then
        currentScreen.leave()
    end
    currentScreen = screens[name]
    if currentScreen.enter then
        local context = { resources = resources, switchScreen = switchScreen }
        if data then
            for k, v in pairs(data) do
                context[k] = v
            end
        end
        currentScreen.enter(context)
    end
end

function love.load()
  https = runtimeLoader.loadHTTPS()
  love.keyboard.setKeyRepeat(true)

    resources.fonts = {
        card             = love.graphics.newFont(24),
        input            = love.graphics.newFont(20),
        inputPlaceholder = love.graphics.newFont(12),
        ui               = love.graphics.newFont(14),
        title            = love.graphics.newFont(36),
        subtitle         = love.graphics.newFont(18),
        sidebar          = love.graphics.newFont(16),
    }

    resources.sounds = {
        typewriter = {},
        bell       = love.audio.newSource("sounds/bell.ogg", "static"),
        thunk      = love.audio.newSource("sounds/thunk.ogg", "static"),
    }
    for i = 1, 4 do
        resources.sounds.typewriter[i] = love.audio.newSource("sounds/typewriter" .. i .. ".ogg", "static")
    end

    switchScreen("title")
  overlayStats.load() -- Should always be called last
end

function love.draw()
  if currentScreen and currentScreen.draw then
        currentScreen.draw()
    end
  overlayStats.draw() -- Should always be called last
end

function love.update(dt)
   if currentScreen and currentScreen.update then
        currentScreen.update(dt)
    end
  overlayStats.update(dt) -- Should always be called last
end

function love.keypressed(key)
  if key == "escape" and love.system.getOS() ~= "Web" then
    love.event.quit()
  else
    if currentScreen and currentScreen.keypressed then
        currentScreen.keypressed(key)
    end
    overlayStats.handleKeyboard(key) -- Should always be called last
  end
end

function love.textinput(text)
    if currentScreen and currentScreen.textinput then
        currentScreen.textinput(text)
    end
end

function love.mousepressed(x, y, button)
    if currentScreen and currentScreen.mousepressed then
        currentScreen.mousepressed(x, y, button)
    end
end

function love.touchpressed(id, x, y, dx, dy, pressure)
  overlayStats.handleTouch(id, x, y, dx, dy, pressure) -- Should always be called last
end
