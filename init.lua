hs.loadSpoon("WinWin")
hs.loadSpoon("WindowGrid")
hs.loadSpoon("WindowHalfsAndThirds")
hs.loadSpoon("KSheet")
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
hs.hotkey.new({"cmd", "shift"}, "q", nil, function()
    if window.focusedWindow():application():path() == "/Applications/Emacs.app" then
       local app = window.focusedWindow():application()

       newKeyEvent({"ctrl", "cmd", "shift"}, "q", true):post(app)
       usleep(1000)
       newKeyEvent({"ctrl", "cmd", "shift"}, "q", false):post(app)
    end
end):enable()

-- Init.
hs.window.animationDuration = 0	-- don't waste time on animation when resize window

-- Key to launch application.
local key2App = {
    h = '/Applications/iTerm.app',
    j = '/Applications/Emacs.app',
    k = '/Applications/Google Chrome.app',
    l = '/System/Library/CoreServices/Finder.app',
    x = '/Applications/QQMusic.app',
    n = '/Applications/NeteaseMusic.app',
    s = '/Applications/System Preferences.app',
    w = '/Applications/WeChat.app',
    e = '/Applications/企业微信.app',
    d = '/Applications/Dash.app',
    z = '/Applications/Kindle.app',
}

-- Manage application's inputmethod status.
local function Chinese()
  hs.keycodes.currentSourceID("com.sogou.inputmethod.sogou.pinyin")
end

local function English()
  hs.keycodes.currentSourceID("com.apple.keylayout.ABC")
end

local function set_app_input_method(app_name, set_input_method_function, event)
  event = event or hs.window.filter.windowFocused

  hs.window.filter.new(app_name)
    :subscribe(event, function()
                 set_input_method_function()
              end)
end

set_app_input_method('Hammerspoon', English, hs.window.filter.windowCreated)
set_app_input_method('Spotlight', English, hs.window.filter.windowCreated)
set_app_input_method('Alfred', English, hs.window.filter.windowCreated)
set_app_input_method('Emacs', English)
set_app_input_method('iTerm2', English)
set_app_input_method('Google Chrome', English)
set_app_input_method('WeChat', Chinese)

-- Build better app switcher.
switcher = hs.window.switcher.new(
   hs.window.filter.new()
      :setAppFilter('Emacs', {allowRoles = '*', allowTitles = 1}), -- make emacs window show in switcher list
   {
      showTitles = false,		-- don't show window title
      thumbnailSize = 200,		-- window thumbnail size
      showSelectedThumbnail = false,	-- don't show bigger thumbnail
      backgroundColor = {0, 0, 0, 0.8}, -- background color
      highlightColor = {0.3, 0.3, 0.3, 0.8}, -- selected color
   }
)

hs.hotkey.bind("alt", "tab", function() switcher:next() end)
hs.hotkey.bind("alt-shift", "tab", function() switcher:previous() end)

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

-- Toggle an application between being the frontmost app, and being hidden
function toggleApplication(appPath)
    -- Tag app path use for `applicationWatcher'.
    startAppPath = appPath

    local app = findApplication(appPath)

    if not app then
        -- Application not running, launch app
        application.launchOrFocus(appPath)
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
    	end
    else
        -- Start application if application is hide.
        if true == app:hide() then
            application.launchOrFocus(appPath)
    	end
    end
end

moveToScreen = function(win, n)
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

caffeinateTrayIcon = hs.menubar.new()

local function caffeinateSetIcon(state)
  caffeinateTrayIcon:setIcon(state and caffeinateOnIcon or caffeinateOffIcon)
end

local function toggleCaffeinate()
    local sleepStatus = hs.caffeinate.toggle("displayIdle")
    if sleepStatus then
       hs.notify.new({title="System Sleep", informativeText="System never sleep"}):send()
    else
       hs.notify.new({title="System Sleep", informativeText="System will sleep when idle"}):send()
    end

    caffeinateSetIcon(sleepStatus)
end

hs.hotkey.bind(hyper, "[", toggleCaffeinate)
caffeinateTrayIcon:setClickCallback(toggleCaffeinate)
caffeinateSetIcon(sleepStatus)

-- Window operations.
hs.hotkey.bind(hyper, 'U', resizeToCenter)

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
    -- Kill current focused window.
    window.focusedWindow():close()

    -- Then focus next window.
    hs.window.frontmostWindow():focus()
end)

hs.hotkey.bind(hyper, "-", function()
    hs.application.frontmostApplication():kill()
end)

hs.hotkey.bind(hyper, ".", function()
		  hs.alert.show("App path:        "
				..window.focusedWindow():application():path()
				.."\n"
				.."App name:      "
				..window.focusedWindow():application():name()
				.."\n"
				.."IM source id:  "
				..hs.keycodes.currentSourceID())
end)

hotkey.bind(hyper, '/', function()
    hints.windowHints()
end)

-- Start or focus application.
for key, app in pairs(key2App) do
    hotkey.bind(hyper, key, function()
        toggleApplication(app)
    end)
end

-- Move application to screen.
hs.hotkey.bind(hyper, "1", function()
    moveToScreen(hs.window.focusedWindow(), 1)
end)

hs.hotkey.bind(hyper, "2", function()
    moveToScreen(hs.window.focusedWindow(), 2)
end)

-- Binding key to start plugin.
Install:andUse("WindowHalfsAndThirds",
               {
                 config = {
                   use_frame_correctness = true
                 },
                 hotkeys = {max_toggle = {hyper, "I"}}
               })

Install:andUse("WindowGrid",
               {
                 config = { gridGeometries = { { "6x4" } } },
                 hotkeys = {show_grid = {hyper, ","}},
                 start = true
               })

local ksheetIsShow = false
local ksheetAppPath = ""

hs.hotkey.bind(hyper, "M", function ()
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

-- Reload config.
hs.hotkey.bind(hyper, "'", function ()
		  speaker:speak("Offline to reloading...")
		  hs.reload()
end)

-- We put reload notify at end of config, notify popup mean no error in config.
hs.notify.new({title="Manatee", informativeText="Andy, I am online!"}):send()

-- Speak something after configuration success.
speaker:speak("Andy, I am online!")
