-- module_reading_stats.lua — Simple UI
-- Reading Stats module: row of stat cards (today, averages, totals, streak).

local Blitbuffer      = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device          = require("device")
local Font            = require("ui/font")
local FrameContainer  = require("ui/widget/container/framecontainer")
local Geom            = require("ui/geometry")
local GestureRange    = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan  = require("ui/widget/horizontalspan")
local InputContainer  = require("ui/widget/container/inputcontainer")
local LineWidget      = require("ui/widget/linewidget")
local OverlapGroup    = require("ui/widget/overlapgroup")
local TextWidget      = require("ui/widget/textwidget")
local UIManager       = require("ui/uimanager")
local VerticalGroup   = require("ui/widget/verticalgroup")
local VerticalSpan    = require("ui/widget/verticalspan")
local Screen          = Device.screen
local _               = require("gettext")
local Config          = require("sui_config")

local UI      = require("sui_core")
local CLR_TEXT_SUB = UI.CLR_TEXT_SUB
local CLR_BORDER   = UI.CLR_BORDER
local CLR_SURFACE  = UI.CLR_SURFACE
local PAD     = UI.PAD

local _CLR_TEXT_BLK  = Blitbuffer.COLOR_BLACK

local _BASE_RS_CORNER_R = Screen:scaleBySize(12)
local _BASE_RS_GAP      = Screen:scaleBySize(12)
local _BASE_RS_CARD_H   = Screen:scaleBySize(78)
local _BASE_RS_VAL_FS   = Screen:scaleBySize(14)
local _BASE_RS_LBL_FS   = Screen:scaleBySize(9)
local _BASE_RS_SEP_W    = Screen:scaleBySize(1)
local _BASE_RS_PH_FS    = Screen:scaleBySize(11)  -- placeholder "No stats" text

local RS_N_COLS    = 7  -- max columns — not a dimension, no scaling needed

local SETTING_TYPE = "reading_stats_type"   -- suffix: pfx .. "reading_stats_type"

local function getType(pfx)
    return G_reader_settings:readSetting(pfx .. SETTING_TYPE) or "cards"
end

-- ---------------------------------------------------------------------------
-- Stat map
-- ---------------------------------------------------------------------------
local function fmtTime(secs)
    secs = math.floor(secs or 0)
    if secs <= 0 then return "0m" end
    local h = math.floor(secs / 3600); local m = math.floor((secs % 3600) / 60)
    if h > 0 and m > 0 then return string.format("%dh %dm", h, m)
    elseif h > 0        then return string.format("%dh", h)
    else                     return string.format("%dm", m) end
end

local STAT_MAP = {
    today_time  = { display_label = _("Today — Time"),      value = function(s) return fmtTime(s.today_secs) end,   label = _("of reading today") },
    today_pages = { display_label = _("Today — Pages"),     value = function(s) return tostring(s.today_pages) end, label = _("pages read today") },
    avg_time    = { display_label = _("Daily avg — Time"),  value = function(s) return fmtTime(s.avg_secs) end,     label = _("daily avg (7 days)") },
    avg_pages   = { display_label = _("Daily avg — Pages"), value = function(s) return tostring(s.avg_pages) end,   label = _("pages/day (7 days)") },
    total_time  = { display_label = _("All time — Time"),   value = function(s) return fmtTime(s.total_secs) end,   label = _("of reading, all time") },
    total_books = { display_label = _("All time — Books"),  value = function(s) return tostring(s.total_books) end, label = _("books finished") },
    streak      = { display_label = _("Streak"),            value = function(s) return s.streak > 0 and tostring(s.streak) or "—" end,
                    label_fn = function(s) return s.streak == 1 and _("day streak") or (s.streak == 0 and _("no streak") or _("days streak")) end },
}

local STAT_POOL = { "today_time","today_pages","avg_time","avg_pages","total_time","total_books","streak" }

-- Pre-sort the pool alphabetically by display label — done once at module load,
-- not on every menu open.
local _sorted_pool = {}
for _, sid in ipairs(STAT_POOL) do
    _sorted_pool[#_sorted_pool+1] = { id = sid, label = STAT_MAP[sid].display_label }
end
table.sort(_sorted_pool, function(a, b) return a.label:lower() < b.label:lower() end)

-- ---------------------------------------------------------------------------
-- Stat widget builders
-- ---------------------------------------------------------------------------

-- Cards mode: compact stat blocks with a stronger text hierarchy.
-- `d` is the scaled-dims table produced once per M.build() call.
-- Streak value widget: icon (dark grey) + space + number (black), side by side.
-- To change icon colour: edit _STREAK_ICON_CLR.
-- To change spacing:     edit _STREAK_ICON_GAP.
local _STREAK_ICON     = ""            -- U+F490 Nerd Fonts flame
local _STREAK_ICON_CLR = Blitbuffer.gray(0.80)  -- dark grey; 0=black, 1=white
local _STREAK_ICON_GAP = 6                   -- pixels between icon and number

local function makeStreakValWidget(val_str, d)
    return HorizontalGroup:new{ align = "center",
        TextWidget:new{
            text    = _STREAK_ICON,
            face    = d.face_val,
            fgcolor = _STREAK_ICON_CLR,
        },
        HorizontalSpan:new{ width = _STREAK_ICON_GAP },
        TextWidget:new{
            text    = val_str,
            face    = d.face_val,
            bold    = true,
            fgcolor = _CLR_TEXT_BLK,
        },
    }
end

local function buildStatContent(card_w, stat_id, stats, d)
    local entry = STAT_MAP[stat_id]
    if not entry then return nil end
    local val_str = entry.value(stats)
    local lbl_str = entry.label_fn and entry.label_fn(stats) or entry.label
    local inner_w = math.max(0, card_w - d.card_pad * 2)
    return VerticalGroup:new{
        align = "left",
        stat_id == "streak" and stats.streak >= 5
            and makeStreakValWidget(val_str, d)
            or  TextWidget:new{
                    text    = val_str,
                    face    = d.face_val,
                    bold    = true,
                    fgcolor = _CLR_TEXT_BLK,
                    width   = inner_w,
                },
        TextWidget:new{
            text    = lbl_str,
            face    = d.face_lbl,
            fgcolor = CLR_TEXT_SUB,
            width   = inner_w,
        },
    }
end

local function buildStatCardWidget(card_w, stat_id, stats, d)
    local content = buildStatContent(card_w, stat_id, stats, d)
    if not content then return nil end
    return FrameContainer:new{
        dimen      = Geom:new{ w = card_w, h = d.card_h },
        bordersize = 1,
        color      = CLR_BORDER,
        background = Blitbuffer.COLOR_WHITE,
        radius     = d.corner_r,
        padding    = d.card_pad,
        content,
    }
end

-- Flat mode: same layout, but on a soft tinted surface.
local function buildStatFlatWidget(card_w, stat_id, stats, d)
    local content = buildStatContent(card_w, stat_id, stats, d)
    if not content then return nil end
    return FrameContainer:new{
        dimen      = Geom:new{ w = card_w, h = d.card_h },
        bordersize = 0,
        background = CLR_SURFACE,
        radius     = d.corner_r,
        padding    = d.card_pad,
        content,
    }
end
local function buildStatListCell(cell_w, stat_id, stats, show_sep, d)
    local content = buildStatContent(cell_w, stat_id, stats, d)
    if not content then return nil end

    local card = FrameContainer:new{
        dimen      = Geom:new{ w = cell_w, h = d.card_h },
        bordersize = 0,
        background = Blitbuffer.COLOR_WHITE,
        padding    = d.card_pad,
        content,
    }

    local og = OverlapGroup:new{
        dimen = Geom:new{ w = cell_w, h = d.card_h },
        card,
    }
    if show_sep then
        local sep = LineWidget:new{
            dimen      = Geom:new{ w = d.sep_w, h = d.card_h },
            background = CLR_BORDER,
        }
        sep.overlap_offset = { cell_w - d.sep_w, 0 }
        og[#og+1] = sep
    end
    return og
end

local function openReaderProgress()
    UIManager:broadcastEvent(require("ui/event"):new("ShowReaderProgress"))
end

local function getGridMetrics(w, n, d)
    local avail_w  = w - PAD * 2
    local max_cols = math.min(3, n)
    local fit_cols = math.max(1, math.floor((avail_w + d.gap) / (d.min_card_w + d.gap)))
    local cols     = math.max(1, math.min(max_cols, fit_cols))
    local rows     = math.ceil(n / cols)
    return {
        avail_w = avail_w,
        cols    = cols,
        rows    = rows,
        h       = rows * d.card_h + (rows - 1) * d.row_gap,
    }
end

local function buildGridRows(w, stat_ids, stats, d, mode)
    local n      = math.min(#stat_ids, RS_N_COLS)
    local grid_d = getGridMetrics(w, n, d)
    local grid   = VerticalGroup:new{ align = "left" }
    local cursor = 1

    for row_idx = 1, grid_d.rows do
        local remaining     = n - cursor + 1
        local cols_this_row = math.min(grid_d.cols, remaining)
        local row = HorizontalGroup:new{ align = "top" }

        if mode == "list" then
            local cell_w = math.floor(grid_d.avail_w / cols_this_row)
            for i = 1, cols_this_row do
                row[#row + 1] = buildStatListCell(cell_w, stat_ids[cursor], stats, i < cols_this_row, d)
                    or OverlapGroup:new{ dimen = Geom:new{ w = cell_w, h = d.card_h } }
                cursor = cursor + 1
            end
        else
            local card_w = math.floor((grid_d.avail_w - d.gap * (cols_this_row - 1)) / cols_this_row)
            for i = 1, cols_this_row do
                local card = mode == "flat"
                    and buildStatFlatWidget(card_w, stat_ids[cursor], stats, d)
                    or  buildStatCardWidget(card_w, stat_ids[cursor], stats, d)
                if i > 1 then row[#row + 1] = HorizontalSpan:new{ width = d.gap } end
                row[#row + 1] = card or FrameContainer:new{
                    dimen = Geom:new{ w = card_w, h = d.card_h },
                    bordersize = 0, padding = 0,
                }
                cursor = cursor + 1
            end
        end

        grid[#grid + 1] = CenterContainer:new{
            dimen = Geom:new{ w = w, h = d.card_h },
            row,
        }
        if row_idx < grid_d.rows then
            grid[#grid + 1] = VerticalSpan:new{ width = d.row_gap }
        end
    end

    local frame = FrameContainer:new{
        dimen      = Geom:new{ w = w, h = grid_d.h },
        bordersize = 0,
        padding    = 0,
        grid,
    }
    local tappable = InputContainer:new{
        dimen = Geom:new{ w = w, h = grid_d.h },
        [1]   = frame,
    }
    tappable.ges_events = {
        TapStatCard = { GestureRange:new{ ges = "tap", range = function() return tappable.dimen end } },
    }
    function tappable:onTapStatCard() openReaderProgress(); return true end
    return tappable
end

-- ---------------------------------------------------------------------------
-- Module API
-- ---------------------------------------------------------------------------
local M = {}

M.id         = "reading_stats"
M.name       = _("Reading Stats")
M.label      = nil   -- no section label; uses own top-padding
M.default_on = false
M.MAX_ITEMS  = RS_N_COLS   -- public field instead of getMaxItems() function

function M.isEnabled(pfx)
    return G_reader_settings:readSetting(pfx .. "reading_stats_enabled") == true
end

function M.setEnabled(pfx, on)
    G_reader_settings:saveSetting(pfx .. "reading_stats_enabled", on)
end

function M.getCountLabel(pfx)
    local n      = #(G_reader_settings:readSetting(pfx .. "reading_stats_items") or {})
    local max_rs = M.MAX_ITEMS
    local rem    = max_rs - n
    if n == 0   then return nil end
    if rem <= 0 then return string.format("(%d/%d — at limit)", n, max_rs) end
    return string.format("(%d/%d — %d left)", n, max_rs, rem)
end

function M.getStatLabel(id)
    return STAT_MAP[id] and STAT_MAP[id].display_label or id
end

function M.getCardHeight()
    return math.floor(_BASE_RS_CARD_H * Config.getModuleScale())
end

M.STAT_POOL = STAT_POOL

function M.invalidateCache()
    -- Delegate to the shared provider — it owns the cache now.
    local SP = package.loaded["desktop_modules/module_stats_provider"]
    if SP then SP.invalidate() end
end

function M.build(w, ctx)
    if not M.isEnabled(ctx.pfx) then return nil end
    local stat_ids = G_reader_settings:readSetting(ctx.pfx .. "reading_stats_items") or {}

    -- Compute all scaled dims once for this render pass.
    local scale     = Config.getModuleScale("reading_stats", ctx and ctx.pfx)
    local text_scale = scale * (Config.getRSTextScalePct() / 100)
    local _val_fs = math.max(8, math.floor(_BASE_RS_VAL_FS * text_scale))
    local _lbl_fs = math.max(6, math.floor(_BASE_RS_LBL_FS * text_scale))
    local _ph_fs  = math.max(8, math.floor(_BASE_RS_PH_FS  * scale))
    local d = {
        card_h   = math.floor(_BASE_RS_CARD_H   * scale),
        gap      = math.max(2, math.floor(_BASE_RS_GAP      * scale)),
        corner_r = math.floor(_BASE_RS_CORNER_R  * scale),
        row_gap  = math.max(PAD, math.floor(_BASE_RS_GAP * scale * 0.75)),
        val_fs   = _val_fs,
        lbl_fs   = _lbl_fs,
        sep_w    = math.max(1, math.floor(_BASE_RS_SEP_W    * scale)),
        ph_fs    = _ph_fs,
        card_pad = math.max(6, math.floor(Screen:scaleBySize(10) * scale)),
        min_card_w = math.max(Screen:scaleBySize(96), math.floor(Screen:scaleBySize(110) * scale)),
        -- Pre-resolved font faces — shared by all card builders, avoids
        -- repeated Font:getFace calls inside the per-card build loop.
        face_val = Font:getFace("smallinfofont", _val_fs),
        face_lbl = Font:getFace("cfont",         _lbl_fs),
        face_ph  = Font:getFace("smallinfofont", _ph_fs),
    }

    -- Show a placeholder when enabled but no stats have been selected yet.
    if #stat_ids == 0 then
        return CenterContainer:new{
            dimen = Geom:new{ w = w, h = d.card_h },
            TextWidget:new{
                text    = _("No stats selected"),
                face    = d.face_ph,
                fgcolor = CLR_TEXT_SUB,
                width   = w - PAD * 2,
            },
        }
    end

    -- Stats are pre-fetched by StatsProvider (via _buildCtx) and passed in
    -- ctx.stats — no DB access or cache logic here.
    local sp   = ctx.stats or {}
    local stats = {
        today_secs  = sp.today_secs  or 0,
        today_pages = sp.today_pages or 0,
        avg_secs    = sp.avg_secs    or 0,
        avg_pages   = sp.avg_pages   or 0,
        total_secs  = sp.total_secs  or 0,
        total_books = sp.books_total or 0,
        streak      = sp.streak      or 0,
    }
    if sp.db_conn_fatal and ctx then ctx.db_conn_fatal = true end
    local mode  = getType(ctx.pfx)
    return buildGridRows(w, stat_ids, stats, d, mode)
end

function M.getHeight(_ctx)
    local pfx   = _ctx and _ctx.pfx
    local scale = Config.getModuleScale("reading_stats", pfx)
    local n     = #(G_reader_settings:readSetting((pfx or "") .. "reading_stats_items") or {})
    if n == 0 then
        return math.floor(_BASE_RS_CARD_H * scale)
    end
    local d = {
        card_h = math.floor(_BASE_RS_CARD_H * scale),
        gap = math.max(2, math.floor(_BASE_RS_GAP * scale)),
        row_gap = math.max(PAD, math.floor(_BASE_RS_GAP * scale * 0.75)),
        min_card_w = math.max(Screen:scaleBySize(96), math.floor(Screen:scaleBySize(110) * scale)),
    }
    local w = Screen:getWidth() - UI.SIDE_PAD * 2
    return getGridMetrics(w, math.min(n, RS_N_COLS), d).h
end


local function _makeScaleItem(ctx_menu)
    local pfx = ctx_menu.pfx
    local _lc = ctx_menu._
    return Config.makeScaleItem({
        text_func    = function() return _lc("Scale") end,
        enabled_func = function() return not Config.isScaleLinked() end,
        title        = _lc("Scale"),
        info         = _lc("Scale for this module.\n100% is the default size."),
        get          = function() return Config.getModuleScalePct("reading_stats", pfx) end,
        set          = function(v) Config.setModuleScale(v, "reading_stats", pfx) end,
        refresh      = ctx_menu.refresh,
    })
end
function M.getMenuItems(ctx_menu)
    local pfx         = ctx_menu.pfx
    local _UIManager  = ctx_menu.UIManager
    local InfoMessage = ctx_menu.InfoMessage
    local SortWidget  = ctx_menu.SortWidget
    local refresh     = ctx_menu.refresh
    local _lc         = ctx_menu._
    local N_lc        = _lc.ngettext
    local items_key   = pfx .. "reading_stats_items"
    local MAX_RS      = M.MAX_ITEMS

    local function getItems() return G_reader_settings:readSetting(items_key) or {} end
    local function isSelected(id)
        for _, v in ipairs(getItems()) do if v == id then return true end end; return false
    end
    local function toggleItem(id)
        local cur = getItems(); local new_items = {}; local found = false
        for _, v in ipairs(cur) do if v == id then found = true else new_items[#new_items+1] = v end end
        if not found then
            if #cur >= MAX_RS then
                _UIManager:show(InfoMessage:new{
                    text = string.format(N_lc("The maximum of %d stat per row has been reached. Remove one first.",
                           "The maximum of %d stats per row has been reached. Remove one first.", MAX_RS), MAX_RS), timeout = 2 })
                return
            end
            new_items[#new_items+1] = id
        end
        G_reader_settings:saveSetting(items_key, new_items); refresh()
    end

    local items = {
        {
            text           = _lc("Type"),
            sub_item_table = {
                {
                    text           = _lc("Cards"),
                    radio          = true,
                    keep_menu_open = true,
                    checked_func   = function() return getType(pfx) == "cards" end,
                    callback       = function()
                        G_reader_settings:saveSetting(pfx .. SETTING_TYPE, "cards")
                        refresh()
                    end,
                },
                {
                    text           = _lc("Flat"),
                    radio          = true,
                    keep_menu_open = true,
                    checked_func   = function() return getType(pfx) == "flat" end,
                    callback       = function()
                        G_reader_settings:saveSetting(pfx .. SETTING_TYPE, "flat")
                        refresh()
                    end,
                },
                {
                    text           = _lc("List"),
                    radio          = true,
                    keep_menu_open = true,
                    checked_func   = function() return getType(pfx) == "list" end,
                    callback       = function()
                        G_reader_settings:saveSetting(pfx .. SETTING_TYPE, "list")
                        refresh()
                    end,
                },
            },
        },
        _makeScaleItem(ctx_menu),
        Config.makeScaleItem({
            text_func     = function()
                local pct = Config.getRSTextScalePct()
                return pct == Config.RS_TEXT_SCALE_DEF
                    and _lc("Text Size")
                    or  string.format(_lc("Text Size — %d%%"), pct)
            end,
            title         = _lc("Text Size"),
            info          = _lc("Size of the text inside the stat cards.\nDoes not affect card size or padding.\n100% is the default size."),
            get           = function() return Config.getRSTextScalePct() end,
            set           = function(pct) Config.setRSTextScalePct(pct) end,
            refresh       = ctx_menu.refresh,
            value_min     = Config.RS_TEXT_SCALE_MIN,
            value_max     = Config.RS_TEXT_SCALE_MAX,
            value_step    = Config.RS_TEXT_SCALE_STEP,
            default_value = Config.RS_TEXT_SCALE_DEF,
        }),
        { text = _lc("Arrange"), keep_menu_open = true, separator = true, callback = function()
            local rs_ids = getItems()
            if #rs_ids < 2 then
                _UIManager:show(InfoMessage:new{ text = _lc("Add at least 2 stats to arrange."), timeout = 2 }); return
            end
            local sort_items = {}
            for _, id in ipairs(rs_ids) do
                sort_items[#sort_items+1] = { text = M.getStatLabel(id), orig_item = id }
            end
            _UIManager:show(SortWidget:new{ title = _lc("Arrange Reading Stats"), covers_fullscreen = true,
                item_table = sort_items, callback = function()
                    local new_order = {}
                    for _, item in ipairs(sort_items) do new_order[#new_order+1] = item.orig_item end
                    G_reader_settings:saveSetting(items_key, new_order); refresh()
                end })
        end },
    }

    -- Use pre-sorted pool (sorted once at module load, not per menu open).
    for _, entry in ipairs(_sorted_pool) do
        local _sid = entry.id; local _lbl = entry.label
        items[#items+1] = {
            text_func = function()
                if isSelected(_sid) then return _lbl end
                local rem = MAX_RS - #getItems()
                if rem <= 2 then return _lbl .. string.format(N_lc("  (%d left)", "  (%d left)", rem), rem) end
                return _lbl
            end,
            checked_func   = function() return isSelected(_sid) end,
            keep_menu_open = true,
            callback       = function() toggleItem(_sid) end,
        }
    end
    return items
end

return M
