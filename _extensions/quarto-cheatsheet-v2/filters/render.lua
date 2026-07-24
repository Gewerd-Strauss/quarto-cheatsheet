--------------------------------------------------------------------------------
-- Global state
--------------------------------------------------------------------------------

local column_count = 4
local use_paracol = true
local cheat_fontsize = "small"
local cheattitle_fontsize = "small"

local blocks = {}

local color_by_key = {}

-- list of classes/attributes to exclude (still exclude those)
local exclude = {
    cheat    = true,
    title    = true,
    column   = true,
    colframe = true,
    colback  = true,
}

--------------------------------------------------------------------------------
-- Metadata parsing
--------------------------------------------------------------------------------

local function parse_metadata(meta)
    local fmt           =
        meta["quarto-cheatsheet-paracol-pdf"]
        or meta["quarto-cheatsheet-pdf"]

    cheat_fontsize      = meta["cheat-fontsize"]
    cheattitle_fontsize = meta["cheattitle-fontsize"]

    column_count        = 3

    if meta["numcols"] ~= nil then
        local n = tonumber(pandoc.utils.stringify(meta["numcols"]))
        if n then
            column_count = n
        end
    end

    if fmt then
        local n = tonumber(fmt.numcols)

        if n then
            column_count = n
        end

        use_paracol = (fmt["use-paracol"] == "true")
    end
end

--------------------------------------------------------------------------------
-- Cheat collection
--------------------------------------------------------------------------------

local function collect_cheatblock(el)
    --------------------------------------------------------------------------
    -- hidden blocks
    --------------------------------------------------------------------------

    if el.classes:includes("hidden") then
        return {}
    end

    --------------------------------------------------------------------------
    -- breakable
    --------------------------------------------------------------------------

    if el.classes:includes("breakable") then
        el.attributes.breakable = "true"
    else
        el.attributes.breakable = "false"
    end

    --------------------------------------------------------------------------
    -- pushnext
    --------------------------------------------------------------------------

    if el.classes:includes("pushnext") then
        el.attributes.pushnext = "true"
    else
        el.attributes.pushnext = "false"
    end

    --------------------------------------------------------------------------
    -- determine color key
    --------------------------------------------------------------------------

    local keyclass = nil

    for _, c in ipairs(el.classes) do
        if string.match(c, "^color%-") then
            keyclass = c
            break
        end
    end

    --------------------------------------------------------------------------
    -- color inheritance
    --------------------------------------------------------------------------

    local colback  = el.attributes.colback
    local colframe = el.attributes.colframe

    if keyclass then
        ------------------------------------------------------------------------
        -- explicit colors -> remember
        ------------------------------------------------------------------------

        if (colback and colback ~= "")
            or
            (colframe and colframe ~= "") then
            color_by_key[keyclass] = {

                colback  = colback,
                colframe = colframe

            }

            ------------------------------------------------------------------------
            -- otherwise inherit previous colors
            ------------------------------------------------------------------------
        else
            local stored = color_by_key[keyclass]

            if stored then
                if (not colback or colback == "")
                    and stored.colback then
                    el.attributes.colback = stored.colback
                end

                if (not colframe or colframe == "")
                    and stored.colframe then
                    el.attributes.colframe = stored.colframe
                end
            end
        end
    end

    --------------------------------------------------------------------------
    -- store block
    --------------------------------------------------------------------------

    table.insert(blocks, el)

    --------------------------------------------------------------------------
    -- remove from original document
    --------------------------------------------------------------------------

    return {}
end

--------------------------------------------------------------------------------
-- Pandoc callbacks
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Column aggregation
--------------------------------------------------------------------------------

local function aggregate_columns()
    local layout = {
        column_count = column_count,
        columns = {}
    }

    --------------------------------------------------------------------------
    -- initialise columns
    --------------------------------------------------------------------------

    for i = 1, column_count do
        layout.columns[i] = {}
    end

    --------------------------------------------------------------------------
    -- automatic column assignment
    --------------------------------------------------------------------------

    local next_auto_column = 1

    for _, block in ipairs(blocks) do
        local col = tonumber(block.attributes.column)

        if col == nil then
            col = next_auto_column
            next_auto_column = next_auto_column % column_count + 1
        else
            col = math.max(1, math.min(column_count, col))
        end

        table.insert(layout.columns[col], block)
    end

    return layout
end


function Meta(meta)
    parse_metadata(meta)

    return meta
end

function Div(el)
    if el.classes:includes("cheat") then
        return collect_cheatblock(el)
    end
end

--------------------------------------------------------------------------------
-- xcolor -> CSS
--------------------------------------------------------------------------------

local xcolor_rgb = {
    black     = { 0, 0, 0 },
    white     = { 255, 255, 255 },
    red       = { 255, 0, 0 },
    green     = { 0, 255, 0 },
    blue      = { 0, 0, 255 },
    cyan      = { 0, 255, 255 },
    magenta   = { 255, 0, 255 },
    yellow    = { 255, 255, 0 },
    gray      = { 128, 128, 128 },
    darkgray  = { 64, 64, 64 },
    lightgray = { 192, 192, 192 },
    brown     = { 165, 42, 42 },
    lime      = { 0, 255, 0 },
    olive     = { 128, 128, 0 },
    orange    = { 255, 165, 0 },
    pink      = { 255, 192, 203 },
    purple    = { 128, 0, 128 },
    teal      = { 0, 128, 128 },
    violet    = { 238, 130, 238 },
}

local function rgb_to_css(rgb)
    return string.format("rgb(%d,%d,%d)", rgb[1], rgb[2], rgb[3])
end

local function mix_rgb(a, b, percent)
    local p = percent / 100
    local q = 1 - p

    return {
        math.floor(a[1] * p + b[1] * q + 0.5),
        math.floor(a[2] * p + b[2] * q + 0.5),
        math.floor(a[3] * p + b[3] * q + 0.5),
    }
end

local function xcolor_to_css(color)
    if not color or color == "" then
        return ""
    end

    --------------------------------------------------------------------------
    -- plain CSS colors / #RRGGBB
    --------------------------------------------------------------------------

    if color:match("^#") then
        return color
    end

    if color:match("^rgb") then
        return color
    end

    --------------------------------------------------------------------------
    -- plain xcolor name
    --------------------------------------------------------------------------

    local rgb = xcolor_rgb[color:lower()]

    if rgb then
        return rgb_to_css(rgb)
    end

    --------------------------------------------------------------------------
    -- xcolor mix:
    --
    --     red!30!blue
    --
    --------------------------------------------------------------------------

    local c1, pct, c2 =
        color:match("^([%a]+)!([%d%.]+)!([%a]+)$")

    if c1 then
        local rgb1 = xcolor_rgb[c1:lower()]
        local rgb2 = xcolor_rgb[c2:lower()]

        if rgb1 and rgb2 then
            return rgb_to_css(
                mix_rgb(rgb1, rgb2, tonumber(pct))
            )
        end
    end

    --------------------------------------------------------------------------
    -- fallback
    --------------------------------------------------------------------------

    return color
end



--------------------------------------------------------------------------------
-- HTML renderer
--------------------------------------------------------------------------------

local function render_html(doc, layout)
    local out = {}

    --------------------------------------------------------------------------
    -- grid container
    --------------------------------------------------------------------------

    table.insert(
        out,
        pandoc.RawBlock(
            "html",
            string.format(
                '<div class="cheatsheet-grid" style="--columns:%d;">',
                layout.column_count
            )
        )
    )

    --------------------------------------------------------------------------
    -- columns
    --------------------------------------------------------------------------

    for _, column in ipairs(layout.columns) do
        table.insert(
            out,
            pandoc.RawBlock(
                "html",
                '<div class="cheatsheet-column">'
            )
        )

        for _, block in ipairs(column) do
            local title    = block.attributes.title or ""
            local colback  = block.attributes.colback or ""
            local colframe = block.attributes.colframe or ""

            ------------------------------------------------------------------
            -- dynamic styles
            ------------------------------------------------------------------

            local attrs    = {
                'class="cheatbox"'
            }

            local style    = {}

            if colframe ~= "" then
                local css = xcolor_to_css(colframe)
                table.insert(style, "--cheatbox-frame: " .. css)
                
                if css == "rbg(0,0,0)" then
                    table.insert(style, "--cheatbox-title-bg:white")
                end
            end

            if colback ~= "" then
                table.insert(style, "--cheatbox-back:" .. xcolor_to_css(colback))
            end

            if #style > 0 then
                table.insert(
                    attrs,
                    'style="' .. table.concat(style, ";") .. '"'
                )
            end

            table.insert(
                out,
                pandoc.RawBlock(
                    "html",
                    "<section " .. table.concat(attrs, " ") .. ">"
                )
            )

            ------------------------------------------------------------------
            -- title
            ------------------------------------------------------------------

            if title ~= "" then
                table.insert(
                    out,
                    pandoc.RawBlock(
                        "html",
                        "<header class=\"cheatbox-title\">"
                        .. title ..
                        "</header>"
                    )
                )
            end

            ------------------------------------------------------------------
            -- body
            ------------------------------------------------------------------

            for _, inner in ipairs(block.content) do
                table.insert(out, inner)
            end

            table.insert(
                out,
                pandoc.RawBlock(
                    "html",
                    "</section>"
                )
            )
        end

        table.insert(
            out,
            pandoc.RawBlock(
                "html",
                "</div>"
            )
        )
    end

    table.insert(
        out,
        pandoc.RawBlock(
            "html",
            "</div>"
        )
    )

    return pandoc.Pandoc(out, doc.meta)
end


--------------------------------------------------------------------------------
-- PDF renderer
--------------------------------------------------------------------------------

local function render_pdf(doc, layout)
    if not use_paracol then
        return doc
    end

    local out = {}

    --------------------------------------------------------------------------
    -- begin paracol
    --------------------------------------------------------------------------

    table.insert(
        out,
        pandoc.RawBlock(
            "latex",
            "\\begin{paracol}{" .. layout.column_count .. "}"
        )
    )

    --------------------------------------------------------------------------
    -- emit each column
    --------------------------------------------------------------------------

    for col_idx, column in ipairs(layout.columns) do
        if col_idx > 1 then
            table.insert(
                out,
                pandoc.RawBlock("latex", "\\switchcolumn")
            )
        end

        for _, block in ipairs(column) do
            ------------------------------------------------------------
            -- block options
            ------------------------------------------------------------

            local title         = block.attributes.title or ""
            local colback       = block.attributes.colback or ""
            local colframe      = block.attributes.colframe or ""
            local breakable     = block.attributes.breakable or false
            local pushnext      = block.attributes.pushnext or false

            local fontsize      =
                "\\" ..
                pandoc.utils.stringify(cheat_fontsize):lower()

            local titlefontsize =
                "\\" ..
                pandoc.utils.stringify(cheattitle_fontsize):lower()

            ------------------------------------------------------------
            -- tcolorbox options
            ------------------------------------------------------------

            local color_opts    = ""

            if colback ~= "" then
                color_opts = color_opts ..
                    "colback=" .. colback .. ","
            end

            if colframe ~= "" then
                color_opts = color_opts ..
                    "colframe=" .. colframe .. ","
            end

            local extra_opts = ""

            if breakable == "true" then
                extra_opts = extra_opts .. "breakable,"
            end

            local box_opts = color_opts .. extra_opts

            ------------------------------------------------------------
            -- pushnext
            ------------------------------------------------------------

            if pushnext == "true" then
                table.insert(
                    out,
                    pandoc.RawBlock(
                        "latex",
                        "\\par\\penalty -10000\\relax"
                    )
                )
            end

            ------------------------------------------------------------
            -- begin box
            ------------------------------------------------------------

            table.insert(
                out,
                pandoc.RawBlock(
                    "latex",
                    string.format(
                        "\\begin{tcolorbox}[cheatbox,fontupper={%s},fonttitle={%s},title={%s},%s]",
                        fontsize,
                        titlefontsize,
                        title,
                        box_opts
                    )
                )
            )

            ------------------------------------------------------------
            -- original block contents
            ------------------------------------------------------------

            for _, inner in ipairs(block.content) do
                table.insert(out, inner)
            end

            ------------------------------------------------------------
            -- end box
            ------------------------------------------------------------

            table.insert(
                out,
                pandoc.RawBlock(
                    "latex",
                    "\\end{tcolorbox}"
                )
            )
        end
    end

    --------------------------------------------------------------------------
    -- end paracol
    --------------------------------------------------------------------------

    table.insert(
        out,
        pandoc.RawBlock(
            "latex",
            "\\end{paracol}"
        )
    )

    return pandoc.Pandoc(out, doc.meta)
end



function Pandoc(doc)
    if not use_paracol then
        return doc
    end

    local cols = aggregate_columns()

    if FORMAT:match("html") then
        -- return render_pdf(doc, cols)
        return render_html(doc, cols)
    else
        return render_pdf(doc, cols)
    end
end
