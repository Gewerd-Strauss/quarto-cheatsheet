local column_count = 4
local use_paracol = true
local cheat_fontsize = "small"
local cheattitle_fontsize = "small"
local blocks = {}

local color_by_key = {}

-- list of classes/attributes to exclude (still exclude those)
local exclude = {
  cheat=true,
  title=true,
  column=true,
  colframe=true,
  colback=true,
}

function Meta(meta)
  local fmt = meta['quarto-cheatsheet-paracol-pdf'] or meta['quarto-cheatsheet-pdf']
  cheat_fontsize = meta['cheat-fontsize']
  cheattitle_fontsize = meta['cheattitle-fontsize']
  column_count = 3 -- default
  column_count = tonumber(pandoc.utils.stringify(meta["numcols"])) or column_count

  if fmt then
    local n = tonumber(fmt.numcols)
    if n then column_count = n end
    use_paracol = fmt['use-paracol']=='true'
  end
  return meta
end

function Div(el)
  if el.classes:includes("cheat") then
    local keyclass = nil
    -- find first class matching /^color-.*$/
    for _, c in ipairs(el.classes) do
      if string.match(c, "^color%-") then
        keyclass = c
        break
      end
    end

    local colback = el.attributes.colback
    local colframe = el.attributes.colframe

    if keyclass then
      if (colback and colback ~= "") or (colframe and colframe ~= "") then
        -- store colors for this keyclass
        color_by_key[keyclass] = {
          colback = colback,
          colframe = colframe
        }
      else
        -- fill missing colback/colframe from stored colors
        local stored = color_by_key[keyclass]
        if stored then
          if (not colback or colback == "") and stored.colback then
            el.attributes.colback = stored.colback
          end
          if (not colframe or colframe == "") and stored.colframe then
            el.attributes.colframe = stored.colframe
          end
        end
      end
    end

    table.insert(blocks, el)
    return {}
  end
end

function Pandoc(doc)
  if not use_paracol then return doc end

  local cols = {}
  for i=1,column_count do cols[i]={} end
  local idx=1

  for _,b in ipairs(blocks) do
    local col_idx = tonumber(b.attributes.column)
    if col_idx == nil then
      col_idx = idx
      idx = idx % column_count + 1
    else
      col_idx = math.min(math.max(col_idx, 1), column_count)
    end
    table.insert(cols[col_idx], b)
  end

  local out = {}
  table.insert(out, pandoc.RawBlock("latex", "\\begin{paracol}{"..column_count.."}"))
  for i=1,column_count do
    if i>1 then table.insert(out, pandoc.RawBlock("latex", "\\switchcolumn")) end
    for _,b in ipairs(cols[i]) do
      local t = b.attributes.title or ""
      local colback = b.attributes.colback or ""
      local colframe = b.attributes.colframe or ""

      local fontsize_str = pandoc.utils.stringify(cheat_fontsize)
      local fontcmd = "\\" .. fontsize_str:lower()
      local fontsizetitle_str = pandoc.utils.stringify(cheattitle_fontsize)
      local fonttitlecmd = "\\" .. fontsizetitle_str:lower()

      local color_opts = ""
      if colback ~= "" then color_opts = color_opts .. "colback=" .. colback .. "," end
      if colframe ~= "" then color_opts = color_opts .. "colframe=" .. colframe .. "," end

      local box = string.format(
        "\\begin{tcolorbox}[cheatbox, fontupper={%s}, fonttitle={%s}, title={%s}, %s]\n%s\n\\end{tcolorbox}",
        fontcmd, fonttitlecmd, t, color_opts, pandoc.write(pandoc.Pandoc(b.content), "latex")
      )
      table.insert(out, pandoc.RawBlock("latex", box))
    end
  end
  table.insert(out, pandoc.RawBlock("latex", "\\end{paracol}"))

  return pandoc.Pandoc(out, doc.meta)
end
