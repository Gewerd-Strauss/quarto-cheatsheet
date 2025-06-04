local column_count = 3
local max_height = 700
local blocks = {}
-- local use_paracol = true
function Pandoc(doc)
    if not use_paracol then return nil end
  
    local num = tonumber(numcols) or 2
    local cols = {}
    for i = 1, num do cols[i] = {} end
  
    -- Fill columns top-to-bottom, left-to-right
    local col = 1
    for _, el in ipairs(doc.blocks) do
      if el.t == "Div" and el.classes:includes("cheat") then
        table.insert(cols[col], el)
        col = (col % num) + 1
      end
    end
  
    local output = { pandoc.RawBlock("latex", "\\begin{paracol}{" .. num .. "}") }
    for i = 1, num do
      if i > 1 then
        table.insert(output, pandoc.RawBlock("latex", "\\switchcolumn"))
      end
      for _, box in ipairs(cols[i]) do
        table.insert(output, box)
      end
    end
    table.insert(output, pandoc.RawBlock("latex", "\\end{paracol}"))
  
    return pandoc.Pandoc(output, doc.meta)
  end
  
function Meta(meta)
    if meta["quarto-cheatsheet-pdf"] then
        local format_opts = meta["quarto-cheatsheet-pdf"]
        if format_opts.numcols then
            local val = pandoc.utils.stringify(format_opts.numcols)
            local n = tonumber(val)
            if n then
                column_count = n
            end
        end
        if format_opts["use-paracol"] then
            use_paracol = pandoc.utils.stringify(format_opts["use-paracol"]) == "true"
        end
    end
    return meta
end

function Div(div)
    if div.classes:includes("cheat") then
      local content = {
        pandoc.RawBlock("latex", "\\begin{cheatboxparacol}"),
      }
      for _, el in ipairs(div.content) do
        table.insert(content, el)
      end
      table.insert(content, pandoc.RawBlock("latex", "\\end{cheatboxparacol}"))
      return pandoc.Div(content)
    end
    return nil
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
                table.insert(out, pandoc.RawBlock("latex", "\\noindent\\begin{cheatboxparacol}"))
                for _, el in ipairs(blk.content) do table.insert(out, el) end
                table.insert(out, pandoc.RawBlock("latex", "\\end{cheatboxparacol}"))
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
            table.insert(out, pandoc.RawBlock("latex", "\\noindent\\begin{cheatboxparacol}"))
            for _, el in ipairs(blk.content) do table.insert(out, el) end
            table.insert(out, pandoc.RawBlock("latex", "\\end{cheatboxparacol}"))
            col_heights[1] = h
        end
    end

    table.insert(out, pandoc.RawBlock("latex", "\\EndCheatColumns"))
    return pandoc.Pandoc(out, body.meta)
end
