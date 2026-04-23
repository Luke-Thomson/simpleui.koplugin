local Blitbuffer      = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device          = require("device")
local Font            = require("ui/font")
local FrameContainer  = require("ui/widget/container/framecontainer")
local Geom            = require("ui/geometry")
local InputContainer  = require("ui/widget/container/inputcontainer")
local TextWidget      = require("ui/widget/textwidget")
local TitleBar        = require("ui/widget/titlebar")
local UIManager       = require("ui/uimanager")
local VerticalGroup   = require("ui/widget/verticalgroup")
local VerticalSpan    = require("ui/widget/verticalspan")
local _               = require("gettext")

local Config     = require("sui_config")
local GoalsMod   = require("desktop_modules/module_reading_goals")
local StatsMod   = require("desktop_modules/module_reading_stats")
local StatsProv  = require("desktop_modules/module_stats_provider")
local UI         = require("sui_core")

local Screen = Device.screen
local PFX    = "navbar_statspage_"

local StatsPage = { _instance = nil }

local function buildPlaceholder(text)
    return CenterContainer:new{
        dimen = Geom:new{ w = Screen:getWidth(), h = math.floor(Screen:getHeight() * 0.4) },
        TextWidget:new{
            text    = text,
            face    = Font:getFace("smallinfofont", Screen:scaleBySize(14)),
            fgcolor = Blitbuffer.gray(0.45),
        },
    }
end

local StatsPageWidget = InputContainer:extend{
    name               = "statspage",
    covers_fullscreen  = true,
    is_borderless      = true,
    title_bar_fm_style = true,
}

function StatsPageWidget:init()
    self.title_bar = TitleBar:new{
        show_parent             = self,
        fullscreen              = true,
        title                   = _("Reading Stats"),
        left_icon               = "appbar.close",
        left_icon_tap_callback  = function() self:onClose() end,
        left_icon_hold_callback = false,
    }
    self._content_frame = FrameContainer:new{
        bordersize = 0,
        padding = 0,
        margin = 0,
        background = Blitbuffer.COLOR_WHITE,
        VerticalGroup:new{},
    }
    self[1] = self._content_frame
    self:_rebuild()
end

function StatsPageWidget:_buildCtx()
    pcall(require, "desktop_modules/module_books_shared")
    local conn = Config.openStatsDB()
    local stats = StatsProv.get(conn, os.date("%Y"))
    if conn then pcall(function() conn:close() end) end
    return {
        pfx   = PFX,
        stats = stats,
    }
end

function StatsPageWidget:_rebuild()
    local content_w = Screen:getWidth() - UI.SIDE_PAD * 2
    local ctx       = self:_buildCtx()
    local body      = VerticalGroup:new{ align = "left" }

    body[#body + 1] = VerticalSpan:new{ width = UI.MOD_GAP * 2 }

    local goals = GoalsMod.build(content_w, ctx)
    if goals then
        body[#body + 1] = goals
        body[#body + 1] = VerticalSpan:new{ width = UI.MOD_GAP }
    end

    local stats = StatsMod.build(content_w, ctx)
    if stats then
        body[#body + 1] = stats
    end

    if not goals and not stats then
        body[#body + 1] = buildPlaceholder(_("No reading stats available yet."))
    end

    self._content_frame[1] = body
end

function StatsPageWidget:onShow()
    self:_rebuild()
    UIManager:setDirty(self, "ui")
end

function StatsPageWidget:onClose()
    UIManager:close(self)
    return true
end

function StatsPageWidget:onCloseWidget()
    if StatsPage._instance == self then
        StatsPage._instance = nil
    end
end

function StatsPageWidget:onSetRotationMode(_mode)
    StatsPage._instance = nil
    UIManager:close(self)
    UIManager:scheduleIn(0, function()
        StatsPage.show()
    end)
    return true
end

function StatsPage.show()
    if StatsPage._instance then
        UIManager:close(StatsPage._instance)
        StatsPage._instance = nil
    end
    local w = StatsPageWidget:new{}
    StatsPage._instance = w
    UIManager:show(w)
end

function StatsPage.refresh()
    if StatsPage._instance then
        StatsPage._instance:_rebuild()
        UIManager:setDirty(StatsPage._instance, "ui")
    end
end

return StatsPage
