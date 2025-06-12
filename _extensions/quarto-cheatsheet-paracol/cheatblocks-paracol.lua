local column_count = 4
local use_paracol = true
local cheat_fontsize = "small"
local cheattitle_fontsize = "small"
local blocks = {}

function Meta(meta)
  local fmt = meta['quarto-cheatsheet-paracol-pdf'] or meta['quarto-cheatsheet-pdf']
  cheat_fontsize = meta['cheat-fontsize']
  cheattitle_fontsize = meta['cheattitle-fontsize']
  column_count = 3 -- this successfully overwrites 
  column_count = tonumber(pandoc.utils.stringify(meta["numcols"]))

  if fmt then
    local n= tonumber(fmt.numcols)
    if n then column_count = n end
    use_paracol = fmt['use-paracol']=='true'
  end
  return meta
end

function Div(el)
  if el.classes:includes("cheat") then
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
    table.insert(cols[idx],b)
    idx = idx % column_count + 1
  end

  local out = {}
  table.insert(out, pandoc.RawBlock("latex", "\\begin{paracol}{"..column_count.."}"))
  for i=1,column_count do
    if i>1 then table.insert(out, pandoc.RawBlock("latex", "\\switchcolumn")) end
    for _,b in ipairs(cols[i]) do
      local t = b.attributes.title or ""
      local c = pandoc.write(pandoc.Pandoc(b.content), "latex")
      local fontsize_str = pandoc.utils.stringify(cheat_fontsize)
      local fontcmd = "\\" .. fontsize_str:lower()  -- converts "HUGE" to "\huge" (and equivalents) (LaTeX command) 
      local fontsizetitle_str = pandoc.utils.stringify(cheattitle_fontsize)
      local fonttitlecmd = "\\" .. fontsizetitle_str:lower()  -- converts "HUGE" to "\huge" (and equivalents) (LaTeX command) 
      local box = string.format(
        "\\begin{tcolorbox}[cheatbox, fontupper={%s}, fonttitle={%s}, title={%s}]\n%s\n\\end{tcolorbox}",
        fontcmd, fonttitlecmd, t, c
      )
      table.insert(out, pandoc.RawBlock("latex", box))
    end
  end
  table.insert(out, pandoc.RawBlock("latex", "\\end{paracol}"))

  return pandoc.Pandoc(out, doc.meta)
end
