local Blitbuffer     = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device         = require("device")
local Font           = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom           = require("ui/geometry")
local GestureRange   = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local TextBoxWidget  = require("ui/widget/textboxwidget")
local TextWidget     = require("ui/widget/textwidget")
local TitleBar       = require("ui/widget/titlebar")
local UIManager      = require("ui/uimanager")
local VerticalGroup  = require("ui/widget/verticalgroup")
local VerticalSpan   = require("ui/widget/verticalspan")
local _              = require("gettext")

local UI = require("sui_core")

local Screen = Device.screen

local OPDSPage = { _instance = nil }

local OPDSPageWidget = InputContainer:extend{
    name               = "opdspage",
    covers_fullscreen  = true,
    is_borderless      = true,
    title_bar_fm_style = true,
}

function OPDSPageWidget:init()
    self.title_bar = TitleBar:new{
        show_parent             = self,
        fullscreen              = true,
        title                   = _("OPDS"),
        left_icon               = "appbar.close",
        left_icon_tap_callback  = function() self:onClose() end,
        left_icon_hold_callback = false,
    }

    local inner_w = Screen:getWidth() - UI.SIDE_PAD * 2
    local card_w  = math.floor(inner_w * 0.92)
    local card_h  = Screen:scaleBySize(112)

    local card = FrameContainer:new{
        bordersize = 1,
        color      = Blitbuffer.gray(0.75),
        background = Blitbuffer.gray(0.06),
        radius     = Screen:scaleBySize(14),
        padding    = Screen:scaleBySize(16),
        dimen      = Geom:new{ w = card_w, h = card_h },
        VerticalGroup:new{
            align = "left",
            TextWidget:new{
                text  = _("Open Catalog"),
                face  = Font:getFace("smallinfofont", Screen:scaleBySize(18)),
                bold  = true,
            },
            VerticalSpan:new{ width = Screen:scaleBySize(8) },
            TextBoxWidget:new{
                text  = _("Jump straight into your OPDS sources with one tap."),
                face  = Font:getFace("smallinfofont", Screen:scaleBySize(12)),
                width = card_w - Screen:scaleBySize(32),
            },
        },
    }

    local launch = InputContainer:new{
        dimen = Geom:new{ w = card_w, h = card_h },
        [1]   = card,
    }
    launch.ges_events = {
        TapOpenOPDS = {
            GestureRange:new{ ges = "tap", range = function() return launch.dimen end },
        },
    }
    function launch:onTapOpenOPDS()
        local Bottombar = require("sui_bottombar")
        if not Bottombar.launchOPDSCatalog or not Bottombar.launchOPDSCatalog() then
            local InfoMessage = require("ui/widget/infomessage")
            UIManager:show(InfoMessage:new{
                text = _("OPDS catalog not available."),
                timeout = 3,
            })
        end
        return true
    end

    self[1] = FrameContainer:new{
        bordersize = 0,
        padding = 0,
        margin = 0,
        background = Blitbuffer.COLOR_WHITE,
        VerticalGroup:new{
            align = "center",
            VerticalSpan:new{ width = UI.MOD_GAP * 2 },
            CenterContainer:new{
                dimen = Geom:new{ w = inner_w, h = Screen:scaleBySize(40) },
                TextWidget:new{
                    text = _("Your OPDS Library"),
                    face = Font:getFace("smallinfofont", Screen:scaleBySize(20)),
                    bold = true,
                },
            },
            VerticalSpan:new{ width = Screen:scaleBySize(6) },
            CenterContainer:new{
                dimen = Geom:new{ w = inner_w, h = Screen:scaleBySize(44) },
                TextBoxWidget:new{
                    text  = _("A cleaner launch point for browsing your catalogs."),
                    face  = Font:getFace("smallinfofont", Screen:scaleBySize(12)),
                    width = math.floor(inner_w * 0.86),
                    alignment = "center",
                },
            },
            VerticalSpan:new{ width = Screen:scaleBySize(18) },
            CenterContainer:new{
                dimen = Geom:new{ w = inner_w, h = card_h },
                launch,
            },
        },
    }
end

function OPDSPageWidget:onClose()
    UIManager:close(self)
    return true
end

function OPDSPageWidget:onCloseWidget()
    if OPDSPage._instance == self then
        OPDSPage._instance = nil
    end
end

function OPDSPage.show()
    if OPDSPage._instance then
        UIManager:close(OPDSPage._instance)
        OPDSPage._instance = nil
    end
    local w = OPDSPageWidget:new{}
    OPDSPage._instance = w
    UIManager:show(w)
end

return OPDSPage
