hs.loadSpoon("WinWin")
hs.loadSpoon("WindowGrid")
hs.loadSpoon("WindowHalfsAndThirds")
hs.loadSpoon("KSheet")
hs.loadSpoon("Seal")
hs.loadSpoon("SpoonInstall")

Install=spoon.SpoonInstall

local hyper = {'ctrl', 'cmd'}

local alert = require 'hs.alert'
local application = require 'hs.application'
local geometry = require 'hs.geometry'
local grid = require 'hs.grid'
local hints = require 'hs.hints'
local hotkey = require 'hs.hotkey'
local layout = require 'hs.layout'
local window = require 'hs.window'
local speech = require 'hs.speech'

-- Init speaker.
speaker = speech.new()

-- I don't know how to disable noise global key "Command + Shift +Q" in MacOS.
-- So i redirect "Command + Shift + Q" to "Ctrl + Command + Shift + Q" for Emacs,
-- then i make Emacs response "Ctrl + Command + Shift + Q" to implement key binding "Command + Shift + Q".
local newKeyEvent = require 'hs.eventtap'.event.newKeyEvent
local usleep = require 'hs.timer'.usleep
hs.hotkey.new(
    {"cmd", "shift"}, "q", nil,
    function()
        if window.focusedWindow():application():path() == "/Applications/Emacs.app" then
            local app = window.focusedWindow():application()

            newKeyEvent({"ctrl", "cmd", "shift"}, "q", true):post(app)
            usleep(1000)
            newKeyEvent({"ctrl", "cmd", "shift"}, "q", false):post(app)
        end
end):enable()

-- Init.
hs.window.animationDuration = 0 -- don't waste time on animation when resize window

-- Key to launch application.
local key2App = {
    h = {'/Applications/iTerm.app', 'English', 2},
    j = {'/Applications/Emacs.app', 'English', 2},
    k = {'/Applications/Google Chrome.app', 'English', 1},
    l = {'/System/Library/CoreServices/Finder.app', 'English', 1},
    x = {'/Applications/QQMusic.app', 'Chinese', 1},
    c = {'/Applications/Kindle.app', 'English', 2},
    n = {'/Applications/NeteaseMusic.app', 'Chinese', 1},
    w = {'/Applications/WeChat.app', 'Chinese', 1},
    e = {'/Applications/企业微信.app', 'Chinese', 1},
    s = {'/Applications/System Preferences.app', 'English', 1},
    d = {'/Applications/Dash.app', 'English', 1},
    b = {'/Applications/MindNode.app', 'Chinese', 1},
    p = {'/Applications/Preview.app', 'Chinese', 2},
}

-- Show launch application's keystroke.
local showAppKeystrokeAlertId = ""

local function showAppKeystroke()
    if showAppKeystrokeAlertId == "" then
        -- Show application keystroke if alert id is empty.
        local keystroke = ""
        local keystrokeString = ""
        for key, app in pairs(key2App) do
            keystrokeString = string.format("%-10s%s", key:upper(), app[1]:match("^.+/(.+)$"):gsub(".app", ""))

            if keystroke == "" then
                keystroke = keystrokeString
            else
                keystroke = keystroke .. "\n" .. keystrokeString
            end
        end

        showAppKeystrokeAlertId = hs.alert.show(keystroke, hs.alert.defaultStyle, hs.screen.mainScreen(), 10)
    else
        -- Otherwise hide keystroke alert.
        hs.alert.closeSpecific(showAppKeystrokeAlertId)
        showAppKeystrokeAlertId = ""
    end
end

hs.hotkey.bind(hyper, "z", showAppKeystroke)

-- Maximize window when specify application started.
local maximizeApps = {
    "/Applications/iTerm.app",
    "/Applications/Google Chrome.app",
    "/System/Library/CoreServices/Finder.app",
}

local windowCreateFilter = hs.window.filter.new():setDefaultFilter()
windowCreateFilter:subscribe(
    hs.window.filter.windowCreated,
    function (win, ttl, last)
        for index, value in ipairs(maximizeApps) do
            if win:application():path() == value then
                win:maximize()
                return true
            end
        end
end)

-- Manage application's inputmethod status.
local function Chinese()
    hs.keycodes.currentSourceID("com.sogou.inputmethod.sogou.pinyin")
end

local function English()
    hs.keycodes.currentSourceID("com.apple.keylayout.ABC")
end

-- Build better app switcher.
switcher = hs.window.switcher.new(
    hs.window.filter.new()
        :setAppFilter('Emacs', {allowRoles = '*', allowTitles = 1}), -- make emacs window show in switcher list
    {
        showTitles = false,               -- don't show window title
        thumbnailSize = 200,              -- window thumbnail size
        showSelectedThumbnail = false,    -- don't show bigger thumbnail
        backgroundColor = {0, 0, 0, 0.8}, -- background color
        highlightColor = {0.3, 0.3, 0.3, 0.8}, -- selected color
    }
)

hs.hotkey.bind("alt", "tab", function()
                   switcher:next()
                   updateFocusAppInputMethod()
end)
hs.hotkey.bind("alt-shift", "tab", function()
                   switcher:previous()
                   updateFocusAppInputMethod()
end)

function updateFocusAppInputMethod()
    for key, app in pairs(key2App) do
        local appPath = app[1]
        local inputmethod = app[2]

        if window.focusedWindow():application():path() == appPath then
            if inputmethod == 'English' then
                English()
            else
                Chinese()
            end

            break
        end
    end
end

-- Handle cursor focus and application's screen manage.
startAppPath = ""
function applicationWatcher(appName, eventType, appObject)
    -- Move cursor to center of application when application activated.
    -- Then don't need move cursor between screens.
    if (eventType == hs.application.watcher.activated) then
        -- Just adjust cursor postion if app open by user keyboard.
        if appObject:path() == startAppPath then
            spoon.WinWin:centerCursor()
            startAppPath = ""
        end
    end
end

appWatcher = hs.application.watcher.new(applicationWatcher)
appWatcher:start()

function findApplication(appPath)
    local apps = application.runningApplications()
    for i = 1, #apps do
        local app = apps[i]
        if app:path() == appPath then
            return app
        end
    end

    return nil
end

function launchApp(appPath)
    -- We need use Chrome's remote debug protocol that debug JavaScript code in Emacs.
    -- So we need launch chrome with --remote-debugging-port argument instead application.launchOrFocus.
    if appPath == "/Applications/Google Chrome.app" then
        hs.execute("open -a 'Google Chrome' --args '--remote-debugging-port=9222'")
    else
        application.launchOrFocus(appPath)
    end

    -- Move the application's window to the specified screen.
    for key, app in pairs(key2App) do
        local path = app[1]
        local screenNumber = app[3]

        if appPath == path then
            hs.timer.doAfter(
                1,
                function()
                    local app = findApplication(appPath)
                    local appWindow = app:mainWindow()

		    moveToScreen(appWindow, screenNumber, false)
            end)
            break
        end
    end
end

-- Toggle an application between being the frontmost app, and being hidden
function toggleApplication(app)
    local appPath = app[1]
    local inputMethod = app[2]

    -- Tag app path use for `applicationWatcher'.
    startAppPath = appPath

    local app = findApplication(appPath)
    local setInputMethod = true

    if not app then
        -- Application not running, launch app
        launchApp(appPath)
    else
        -- Application running, toggle hide/unhide
        local mainwin = app:mainWindow()
        if mainwin then
            if app:isFrontmost() then
                -- Show mouse circle if has focus on target application.
                drawMouseCircle()

                setInputMethod = false
            else
                -- Focus target application if it not at frontmost.
                mainwin:application():activate(true)
                mainwin:application():unhide()
                mainwin:focus()
            end
        else
            -- Start application if application is hide.
            if app:hide() then
                launchApp(appPath)
            end
        end
    end

    if setInputMethod then
        if inputMethod == 'English' then
            English()
        else
            Chinese()
        end
    end
end

local mouseCircle = nil
local mouseCircleTimer = nil

function drawMouseCircle()
    -- Kill previous circle if it still live.
    circle = mouseCircle
    timer = mouseCircleTimer

    if circle then
        circle:delete()
        if timer then
            timer:stop()
        end
    end

    -- Get mouse point.
    mousepoint = hs.mouse.getAbsolutePosition()

    -- Init circle color and raius.
    local color = {
        ["red"]= 92.0 / 255.0,
        ["blue"]= 245.0 / 255.0,
        ["green"]= 201.0 / 255.0,
        ["alpha"]= 0.8}

    raius = 30

    -- Draw mouse circle.
    circle = hs.drawing.circle(hs.geometry.rect(mousepoint.x - raius / 2, mousepoint.y - raius / 2, raius, raius))
    circle:setStroke(false)
    circle:setFillColor(color)
    circle:bringToFront(true)
    circle:show()

    -- Save circle in local variable.
    mouseCircle = circle

    -- Hide mouse circle after 0.5 second.
    mouseCircleTimer = hs.timer.doAfter(
        0.5,
        function()
            circle:hide(0.5)
            hs.timer.doAfter(0.6, function() circle:delete() end)
    end)
end

moveToScreen = function(win, n, showNotify)
    local screens = hs.screen.allScreens()
    if n > #screens then
	if showNotify then
	    hs.alert.show("No enough screens " .. #screens)
	end
    else
        local toScreen = hs.screen.allScreens()[n]:name()
	if showNotify then
	    hs.alert.show("Move " .. win:application():name() .. " to " .. toScreen)
	end
        hs.layout.apply({{nil, win:title(), toScreen, hs.layout.maximized, nil, nil}})
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

-- Power operation.
caffeinateOnIcon = [[ASCII:
.....1a..........AC..........E
..............................
......4.......................
1..........aA..........CE.....
e.2......4.3...........h......
..............................
..............................
.......................h......
e.2......6.3..........t..q....
5..........c..........s.......
......6..................q....
......................s..t....
.....5c.......................
]]

    caffeinateOffIcon = [[ASCII:
.....1a.....x....AC.y.......zE
..............................
......4.......................
1..........aA..........CE.....
e.2......4.3...........h......
..............................
..............................
.......................h......
e.2......6.3..........t..q....
5..........c..........s.......
......6..................q....
......................s..t....
...x.5c....y.......z..........
]]

local caffeinateTrayIcon = hs.menubar.new()

local function caffeinateSetIcon(state)
    caffeinateTrayIcon:setIcon(state and caffeinateOnIcon or caffeinateOffIcon)

    if state then
        caffeinateTrayIcon:setTooltip("Sleep never sleep")
    else
        caffeinateTrayIcon:setTooltip("System will sleep when idle")
    end
end

local function toggleCaffeinate()
    local sleepStatus = hs.caffeinate.toggle("displayIdle")
    if sleepStatus then
        hs.notify.new({title="HammerSpoon", informativeText="System never sleep"}):send()
    else
        hs.notify.new({title="HammerSpoon", informativeText="System will sleep when idle"}):send()
    end

    caffeinateSetIcon(sleepStatus)
end

hs.hotkey.bind(hyper, "[", toggleCaffeinate)
caffeinateTrayIcon:setClickCallback(toggleCaffeinate)
caffeinateSetIcon(sleepStatus)

-- Window operations.
hs.hotkey.bind(hyper, 'U', resizeToCenter)

hs.hotkey.bind(
    hyper, "Y",
    function()
        window.focusedWindow():moveToUnit(layout.left50)
end)

hs.hotkey.bind(
    hyper, "O",
    function()
        window.focusedWindow():moveToUnit(layout.right50)
end)

hs.hotkey.bind(
    hyper, "P",
    function()
        window.focusedWindow():toggleFullScreen()
end)

hs.hotkey.bind(
    hyper, ";",
    function()
        -- Kill current focused window.
        window.focusedWindow():close()

        -- Then focus next window.
        hs.window.frontmostWindow():focus()
end)

hs.hotkey.bind(
    hyper, "-",
    function()
        hs.application.frontmostApplication():kill()
end)

hs.hotkey.bind(
    hyper, ".",
    function()
        hs.alert.show(string.format("App path:        %s\nApp name:      %s\nIM source id:  %s",
                                    window.focusedWindow():application():path(),
                                    window.focusedWindow():application():name(),
                                    hs.keycodes.currentSourceID()))
end)

hotkey.bind(
    hyper, '/',
    function()
        hints.windowHints()
end)

-- Start or focus application.
for key, app in pairs(key2App) do
    hotkey.bind(
        hyper, key,
        function()
            toggleApplication(app)
    end)
end

-- Move application to screen.
hs.hotkey.bind(
    hyper, "1",
    function()
        moveToScreen(hs.window.focusedWindow(), 1, true)
end)

hs.hotkey.bind(
    hyper, "2",
    function()
        moveToScreen(hs.window.focusedWindow(), 2, true)
end)

-- Binding key to start plugin.
Install:andUse(
    "WindowHalfsAndThirds",
    {
        config = {use_frame_correctness = true},
        hotkeys = {max_toggle = {hyper, "I"}}
})

Install:andUse(
    "WindowGrid",
    {
        config = {gridGeometries = {{"6x4"}}},
        hotkeys = {show_grid = {hyper, ","}},
        start = true
})

-- Show application keystroke window.
local ksheetIsShow = false
local ksheetAppPath = ""

hs.hotkey.bind(
    hyper, "M",
    function ()
        local currentAppPath = window.focusedWindow():application():path()

        -- Toggle ksheet window if cache path equal current app path.
        if ksheetAppPath == currentAppPath then
            if ksheetIsShow then
                spoon.KSheet:hide()
                ksheetIsShow = false
            else
                spoon.KSheet:show()
                ksheetIsShow = true
            end
            -- Show app's keystroke if cache path not equal current app path.
        else
            spoon.KSheet:show()
            ksheetIsShow = true

            ksheetAppPath = currentAppPath
        end
end)

-- hs.hotkey.new({}, "escape", nil,
--     function()
--         spoon.KSheet:hide()
--         ksheetIsShow = false
--         ksheetAppPath = ""
-- end):enable()

-- Execute v2ray default, fuck GFW.
local v2rayPath = "/Users/andy/v2ray/v2ray"
local v2rayTask = nil

local function stopV2ray()
    if v2rayTask and v2rayTask:isRunning() then
        v2rayTask:terminate()
    end
end

local function startV2ray()
    v2rayTask = hs.task.new(v2rayPath, nil)
    v2rayTask:start()
end

local function reloadV2ray()
    stopV2ray()
    startV2ray()

    hs.notify.new({title="Manatee", informativeText="Reload v2ray"}):send()
end
startV2ray()

local v2rayTrayIcon = hs.menubar.new()
v2rayTrayIcon:setTitle("V2ray")
v2rayTrayIcon:setTooltip("Click to reload V2ray")
v2rayTrayIcon:setClickCallback(reloadV2ray)

hs.hotkey.bind(hyper, "]", reloadV2ray)

-- Force system sleep.
hs.hotkey.bind(hyper, "delete", hs.caffeinate.systemSleep)

-- Reload config.
hs.hotkey.bind(
    hyper, "'", function ()
        speaker:speak("Offline to reloading...")
        hs.reload()
end)

-- Use seal instead Alfred.
spoon.Seal:loadPlugins({"apps"})
spoon.Seal:bindHotkeys({show={{"alt"}, "Space"}})
spoon.Seal:start()

-- We put reload notify at end of config, notify popup mean no error in config.
hs.notify.new({title="Manatee", informativeText="Andy, I am online!"}):send()

-- Speak something after configuration success.
speaker:speak("Andy, I am online!")
