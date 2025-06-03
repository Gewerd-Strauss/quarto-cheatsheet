-- cheatblocks-paracol.lua
local column_count = 3
local current_column = 1
local max_height = 700  -- arbitrary max height per column (adjust based on your content)
local heights = {}
local blocks = {}

function Meta(meta)
    if meta.numcols and meta.numcols.t == "MetaInlines" then
        local val = pandoc.utils.stringify(meta.numcols)
        local n = tonumber(val)
        if n then
            column_count = n
        end
    end
    return meta
end

function Div(div)
    if div.classes:includes("cheat") then
        table.insert(blocks, div)
        return pandoc.Null() -- Remove original
    end
end

function Doc(body)
    -- Simulated layout tracking
    local col_heights = {}
    for i = 1, column_count do col_heights[i] = 0 end

    local out = {}
    table.insert(out, pandoc.RawBlock("latex", "\\StartCheatColumns{" .. column_count .. "}"))

    for _, blk in ipairs(blocks) do
        local h = 100 -- Simulated fixed height per box (adjustable)
        local placed = false

        for i = 1, column_count do
            if col_heights[i] + h <= max_height then
                table.insert(out, pandoc.RawBlock("latex", "\\switchcolumn[" .. i .. "]"))
                table.insert(out, pandoc.RawBlock("latex", "\\noindent\\begin{cheatbox}"))
                for _, el in ipairs(blk.content) do table.insert(out, el) end
                table.insert(out, pandoc.RawBlock("latex", "\\end{cheatbox}"))
                col_heights[i] = col_heights[i] + h
                placed = true
                break
            end
        end

        if not placed then
            -- New page and reset
            table.insert(out, pandoc.RawBlock("latex", "\\EndCheatColumns"))
            table.insert(out, pandoc.RawBlock("latex", "\\newpage"))
            col_heights = {}
            for i = 1, column_count do col_heights[i] = 0 end
            table.insert(out, pandoc.RawBlock("latex", "\\StartCheatColumns{" .. column_count .. "}"))

            -- Insert into first column
            table.insert(out, pandoc.RawBlock("latex", "\\switchcolumn[1]"))
            table.insert(out, pandoc.RawBlock("latex", "\\noindent\\begin{cheatbox}"))
            for _, el in ipairs(blk.content) do table.insert(out, el) end
            table.insert(out, pandoc.RawBlock("latex", "\\end{cheatbox}"))
            col_heights[1] = h
        end
    end

    table.insert(out, pandoc.RawBlock("latex", "\\EndCheatColumns"))
    return pandoc.Pandoc(out, body.meta)
end
