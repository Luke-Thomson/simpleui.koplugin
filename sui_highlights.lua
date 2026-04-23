local BD        = require("ui/bidi")
local Menu      = require("ui/widget/menu")
local UIManager = require("ui/uimanager")
local _         = require("gettext")
local N_        = _.ngettext

local HighlightsPage = { _instance = nil }

local function extractStr(line, key)
    if not line:find(key, 1, true) then return nil end
    local val = line:match('%["' .. key .. '"%]%s*=%s*"(.*)"')
    if not val or val == "" then return nil end
    return val:gsub('\\"', '"'):gsub('\\n', ' '):gsub('\\\\', '\\')
end

local function truncateText(text, max_len)
    if not text or #text <= max_len then return text end
    return text:sub(1, max_len - 3) .. "..."
end

local function openBook(filepath, pos0, page)
    local doOpen = function()
        local ReaderUI = package.loaded["apps/reader/readerui"]
            or require("apps/reader/readerui")
        ReaderUI:showReader(filepath)
        if pos0 or page then
            UIManager:scheduleIn(0.5, function()
                local rui = package.loaded["apps/reader/readerui"]
                if not (rui and rui.instance) then return end
                if pos0 then
                    rui.instance:handleEvent(
                        require("ui/event"):new("GotoXPointer", pos0, pos0))
                elseif page then
                    rui.instance:handleEvent(
                        require("ui/event"):new("GotoPage", page))
                end
            end)
        end
    end
    if G_reader_settings:isTrue("file_ask_to_open") then
        local ConfirmBox = require("ui/widget/confirmbox")
        UIManager:show(ConfirmBox:new{
            text = _("Open this file?") .. "\n\n" .. BD.filename(filepath:match("([^/]+)$")),
            ok_text = _("Open"),
            ok_callback = doOpen,
        })
    else
        doOpen()
    end
end

local _HIGHLIGHT_DRAWERS = {
    highlight = true,
    lighten = true,
    underscore = true,
}

local function loadGroups()
    local ok_lfs, lfs = pcall(require, "libs/libkoreader-lfs")
    local ok_ds, DocSettings = pcall(require, "docsettings")
    local ReadHistory = package.loaded["readhistory"] or require("readhistory")
    if not (ok_lfs and ok_ds and ReadHistory and ReadHistory.hist) then return {} end

    local seen = {}
    local groups = {}

    for _, hist_entry in ipairs(ReadHistory.hist) do
        local fp = hist_entry and hist_entry.file
        if fp and not seen[fp] and lfs.attributes(fp, "mode") == "file" then
            seen[fp] = true
            local sidecar = DocSettings:findSidecarFile(fp)
            if sidecar and lfs.attributes(sidecar, "mode") == "file" then
                local f = io.open(sidecar, "r")
                if f then
                    local group = {
                        filepath   = fp,
                        title      = nil,
                        authors    = nil,
                        highlights = {},
                    }
                    local pending_text = nil
                    local pending_pos0 = nil
                    local pending_page = nil
                    local is_highlight = false

                    local function flushBlock()
                        if pending_text and is_highlight then
                            group.highlights[#group.highlights + 1] = {
                                text = pending_text,
                                pos0 = pending_pos0,
                                page = pending_page,
                            }
                        end
                        pending_text = nil
                        pending_pos0 = nil
                        pending_page = nil
                        is_highlight = false
                    end

                    for line in f:lines() do
                        if line:match("^%s*%[%d+%]%s*=%s*{") then
                            flushBlock()
                        elseif line:find('["text"]', 1, true) then
                            local text = extractStr(line, "text")
                            if text and #text > 0 then
                                pending_text = text
                            else
                                pending_text = nil
                            end
                        elseif line:find('["pos0"]', 1, true) then
                            pending_pos0 = extractStr(line, "pos0")
                        elseif line:find('["page"]', 1, true) and not line:find('["pagemap"]', 1, true) then
                            pending_page = tonumber(line:match('%["page"%]%s*=%s*(%d+)'))
                        elseif line:find('["drawer"]', 1, true) then
                            local drawer = extractStr(line, "drawer")
                            is_highlight = drawer ~= nil and _HIGHLIGHT_DRAWERS[drawer] == true
                        elseif not group.title and line:find('["title"]', 1, true) then
                            group.title = extractStr(line, "title") or group.title
                        elseif not group.authors and line:find('["authors"]', 1, true) then
                            group.authors = extractStr(line, "authors")
                        end
                    end
                    flushBlock()
                    f:close()

                    if #group.highlights > 0 then
                        if not group.title or group.title == "" then
                            group.title = fp:match("([^/]+)%.[^%.]+$") or fp:match("([^/]+)$") or "?"
                        end
                        groups[#groups + 1] = group
                    end
                end
            end
        end
    end

    return groups
end

local function buildItemTable(groups)
    if #groups == 0 then
        return {
            {
                text = _("No highlights found yet."),
                enabled = false,
            },
            {
                text = _("Open a book and highlight some passages to populate this page."),
                enabled = false,
            },
        }
    end

    local items = {}
    for _, group in ipairs(groups) do
        local sub_items = {}
        for _, highlight in ipairs(group.highlights) do
            local label = truncateText(highlight.text:gsub("%s+", " "), 140)
            local mandatory = highlight.page and string.format(_("p. %d"), highlight.page) or nil
            sub_items[#sub_items + 1] = {
                text = label,
                mandatory = mandatory,
                callback = function()
                    openBook(group.filepath, highlight.pos0, highlight.page)
                end,
            }
        end
        items[#items + 1] = {
            text = group.authors and group.authors ~= ""
                and (group.title .. " - " .. group.authors)
                or group.title,
            mandatory = string.format(N_("%d highlight", "%d highlights", #group.highlights), #group.highlights),
            sub_item_table = sub_items,
        }
    end
    return items
end

function HighlightsPage.show()
    if HighlightsPage._instance then
        UIManager:close(HighlightsPage._instance)
        HighlightsPage._instance = nil
    end

    local menu = Menu:new{
        name               = "highlights",
        title              = _("Highlights"),
        item_table         = buildItemTable(loadGroups()),
        covers_fullscreen  = true,
        is_borderless      = true,
        title_bar_fm_style = true,
        width              = require("device").screen:getWidth(),
        height             = require("device").screen:getHeight(),
    }
    local orig_close = menu.onCloseWidget
    menu.onCloseWidget = function(self_menu)
        if HighlightsPage._instance == self_menu then
            HighlightsPage._instance = nil
        end
        if orig_close then return orig_close(self_menu) end
    end

    HighlightsPage._instance = menu
    UIManager:show(menu)
end

return HighlightsPage
