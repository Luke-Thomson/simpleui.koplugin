local Blitbuffer     = require("ffi/blitbuffer")
local Device         = require("device")
local Font           = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom           = require("ui/geometry")
local GestureRange   = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
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
local CLR_TEXT_SUB = UI.CLR_TEXT_SUB
local CLR_BORDER   = UI.CLR_BORDER
local CLR_SURFACE  = UI.CLR_SURFACE

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
    local card_w  = inner_w
    local card_h  = Screen:scaleBySize(92)

    local card = FrameContainer:new{
        bordersize = 1,
        color      = CLR_BORDER,
        background = Blitbuffer.COLOR_WHITE,
        radius     = Screen:scaleBySize(10),
        padding    = Screen:scaleBySize(16),
        dimen      = Geom:new{ w = card_w, h = card_h },
        HorizontalGroup:new{
            align = "center",
            FrameContainer:new{
                bordersize = 0,
                padding = 0,
                dimen = Geom:new{ w = math.floor(card_w * 0.72), h = card_h - Screen:scaleBySize(32) },
                VerticalGroup:new{
                    align = "left",
                    TextWidget:new{
                        text  = _("Choose Catalog"),
                        face  = Font:getFace("smallinfofont", Screen:scaleBySize(17)),
                        bold  = true,
                    },
                    VerticalSpan:new{ width = Screen:scaleBySize(6) },
                    TextBoxWidget:new{
                        text  = _("Pick the catalog you want once. Simple UI will reopen that same source on later taps."),
                        face  = Font:getFace("smallinfofont", Screen:scaleBySize(11)),
                        width = math.floor(card_w * 0.72),
                        fgcolor = CLR_TEXT_SUB,
                    },
                },
            },
            HorizontalSpan:new{ width = Screen:scaleBySize(10) },
            TextWidget:new{
                text = _("Set"),
                face = Font:getFace("smallinfofont", Screen:scaleBySize(12)),
                bold = true,
                fgcolor = CLR_TEXT_SUB,
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
        if not Bottombar.launchOPDSCatalog or not Bottombar.launchOPDSCatalog(false, true) then
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
        FrameContainer:new{
            bordersize = 0,
            padding_left = UI.SIDE_PAD,
            padding_right = UI.SIDE_PAD,
            padding_top = UI.MOD_GAP,
            padding_bottom = UI.MOD_GAP,
            VerticalGroup:new{
                align = "left",
                TextWidget:new{
                    text = _("Catalogs"),
                    face = Font:getFace("smallinfofont", Screen:scaleBySize(10)),
                    fgcolor = CLR_TEXT_SUB,
                },
                VerticalSpan:new{ width = Screen:scaleBySize(6) },
                TextWidget:new{
                    text = _("Choose your OPDS source"),
                    face = Font:getFace("smallinfofont", Screen:scaleBySize(21)),
                    bold = true,
                    width = inner_w,
                },
                TextBoxWidget:new{
                    text  = _("After you choose one catalog, the OPDS tab will reopen that same source directly instead of landing on the selector."),
                    face  = Font:getFace("smallinfofont", Screen:scaleBySize(11)),
                    width = inner_w,
                    fgcolor = CLR_TEXT_SUB,
                },
                VerticalSpan:new{ width = Screen:scaleBySize(18) },
                launch,
                VerticalSpan:new{ width = Screen:scaleBySize(14) },
                FrameContainer:new{
                    bordersize = 0,
                    background = CLR_SURFACE,
                    radius = Screen:scaleBySize(10),
                    padding = Screen:scaleBySize(14),
                    dimen = Geom:new{ w = card_w, h = Screen:scaleBySize(74) },
                    VerticalGroup:new{
                        align = "left",
                        TextWidget:new{
                            text = _("Tip"),
                            face = Font:getFace("smallinfofont", Screen:scaleBySize(10)),
                            fgcolor = CLR_TEXT_SUB,
                        },
                        VerticalSpan:new{ width = Screen:scaleBySize(5) },
                        TextBoxWidget:new{
                            text = _("You can still switch later: go back to the OPDS root list and pick another catalog. Simple UI will remember the new one."),
                            face = Font:getFace("smallinfofont", Screen:scaleBySize(11)),
                            width = card_w - Screen:scaleBySize(28),
                            fgcolor = CLR_TEXT_SUB,
                        },
                    },
                },
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
    local ok_bb, Bottombar = pcall(require, "sui_bottombar")
    if ok_bb and Bottombar and Bottombar.hasPinnedOPDSCatalog
       and Bottombar.hasPinnedOPDSCatalog()
       and Bottombar.launchOPDSCatalog
       and Bottombar.launchOPDSCatalog(true) then
        return
    end
    if OPDSPage._instance then
        UIManager:close(OPDSPage._instance)
        OPDSPage._instance = nil
    end
    local w = OPDSPageWidget:new{}
    OPDSPage._instance = w
    UIManager:show(w)
end

return OPDSPage
