hs.loadSpoon("WinWin")

local hyper = {'ctrl', 'cmd'}

local alert = require 'hs.alert'
local application = require 'hs.application'
local geometry = require 'hs.geometry'
local grid = require 'hs.grid'
local hints = require 'hs.hints'
local hotkey = require 'hs.hotkey'
local layout = require 'hs.layout'
local window = require 'hs.window'

local key2App = {
    h = 'iterm',
    j = 'Emacs',
    k = 'Google Chrome',
    l = 'Finder',
    n = '网易云音乐',
    s = '系统偏好设置',
    w = '微信（会话）',
    e = '企业微信',
    d = 'Dash',
}

-- Toggle an application between being the frontmost app, and being hidden
function toggle_application(_app)
    -- Finds a running applications
    local app = application.find(_app)

    if not app then
        -- Application not running, launch app
        application.launchOrFocus(_app)

	-- It's handy move cursor after focus
	spoon.WinWin:centerCursor()
        return
    end

    -- Application running, toggle hide/unhide
    local mainwin = app:mainWindow()
    if mainwin then
        if true == app:isFrontmost() then
            mainwin:application():hide()
        else
            mainwin:application():activate(true)
            mainwin:application():unhide()
            mainwin:focus()

	    -- It's handy move cursor after focus
	    spoon.WinWin:centerCursor()
        end
    else
        -- No windows, maybe hide
        if true == app:hide() then
            -- Focus app
            application.launchOrFocus(_app)

	    -- It's handy move cursor after focus
	    spoon.WinWin:centerCursor()
        else
            -- Nothing to do
        end
    end
end

moveto = function(win, n)
  local screens = hs.screen.allScreens()
  if n > #screens then
    hs.alert.show("No enough screens " .. #screens)
  else
    local toWin = hs.screen.allScreens()[n]:name()
    hs.alert.show("Move " .. win:application():name() .. " to " .. toWin)
    hs.layout.apply({{nil, win:title(), toWin, hs.layout.maximized, nil, nil}})
  end
end

function resizeToCenter()
   local win = hs.window.focusedWindow()
   local f = win:frame()
   local screen = win:screen()
   local max = screen:frame()
   local winScale = 0.7

   f.x = max.x + (max.w * (1 - winScale) / 2)
   f.y = max.y + (max.h * (1 - winScale) / 2)
   f.w = max.w * winScale
   f.h = max.h * winScale
   win:setFrame(f)
end

-- Window operations.
hs.hotkey.bind(hyper, 'U', resizeToCenter)

hs.hotkey.bind(hyper, 'I', function()
    hs.grid.maximizeWindow()
end)

hs.hotkey.bind(hyper, "Y", function()
    window.focusedWindow():moveToUnit(layout.left50)
end)

hs.hotkey.bind(hyper, "O", function()
    window.focusedWindow():moveToUnit(layout.right50)
end)

hs.hotkey.bind(hyper, "P", function()
    window.focusedWindow():toggleFullScreen()
end)

hs.hotkey.bind(hyper, ";", function()
    window.focusedWindow():close()
end)

hs.hotkey.bind(hyper, ",", grid.show)

hs.hotkey.bind(hyper, ".", function()
    hs.alert.show(window.focusedWindow():title())
end)

hotkey.bind(hyper, '/', function()
    hints.windowHints()
end)

-- Start or focus application.
for key, app in pairs(key2App) do
    hotkey.bind(hyper, key, function()
        toggle_application(app)
    end)
end

-- Move application to screen.
hs.hotkey.bind(hyper, "1", function()
    local win = hs.window.focusedWindow()
    moveto(win, 1)
end)

hs.hotkey.bind(hyper, "2", function()
    local win = hs.window.focusedWindow()
    moveto(win, 2)
end)

hs.hotkey.bind(hyper, "3", function()
    local win = hs.window.focusedWindow()
    moveto(win, 3)
end)

-- Binding key to start plugin.

-- Reload config.
hs.hotkey.bind(hyper, "'", function ()
    hs.reload()
end)

-- We put reload notify at end of config, notify popup mean no error in config.
hs.notify.new({title="Hammerspoon", informativeText="Config reload successful!"}):send()
