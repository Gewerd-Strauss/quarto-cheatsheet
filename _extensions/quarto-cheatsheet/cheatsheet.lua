-- cheatsheet.lua

local user_options = {}
local function latexcmd(s)
  s = pandoc.utils.stringify(s or "")
  if not s:match("^\\") then
    return "\\" .. s
  else
    return s
  end
end

-- Extract metadata when the document is first loaded
function Meta(meta)
  -- local ext = meta.format and meta.format["quarto-cheatsheet-pdf"] or {}
  local ext = meta
  for k, v in pairs(meta) do
    io.stderr:write("ext[" .. tostring(k) .. "] = " .. pandoc.utils.stringify(v) .. "\n")
  end
  
  local function getopt(key, default)
    if ext[key] ~= nil then
      return pandoc.utils.stringify(ext[key])
    else
      return default
    end
  end

  user_options = {
    cheat_vspace_above = getopt("cheat-vspace-above", "0pt"),
    cheat_vspace_below = getopt("cheat-vspace-below", "6pt"),
    body_fontsize      = latexcmd(ext["body-fontsize"] or "tiny"),
    cheat_fontsize     = latexcmd(ext["cheat-fontsize"] or "tiny"),
    numcols            = getopt("numcols", "1"),
  }

  local colwidth = string.format("%.4f\\textwidth", 0.95)
  meta["cheatboxwidth"] = pandoc.MetaInlines({ pandoc.Str(colwidth) })

  return meta

end


function Header(el)
  if el.level == 1 then
    return {
      el,
      pandoc.RawBlock("latex", user_options.body_fontsize or "\\normalsize")
    }
  end
end

-- function Pandoc(doc)
--   local fontsize_cmd = user_options.body_fontsize or "\\normalsize"

--   -- Wrap all blocks in multicols
--   local start = pandoc.RawBlock("latex", "\\raggedcolumns\\begin{multicols}{" .. user_options.numcols .. "}")
--   local stop = pandoc.RawBlock("latex", "\\end{multicols}")

--   local new_blocks = {}
--   table.insert(new_blocks, pandoc.RawBlock("latex", fontsize_cmd))
--   table.insert(new_blocks, start)
--   for _, block in ipairs(doc.blocks) do
--     table.insert(new_blocks, block)
--   end
--   table.insert(new_blocks, stop)

--   return pandoc.Pandoc(new_blocks, doc.meta)
-- end

function Pandoc(doc)
  local numcols = tonumber(user_options.numcols or 2)
  local before = pandoc.RawBlock("latex", "\\begin{paracol}{" .. numcols .. "}")
  local after = pandoc.RawBlock("latex", "\\end{paracol}")
  table.insert(doc.blocks, 1, before)
  table.insert(doc.blocks, after)
  return doc
end


function generateCheatBlockLatex(block)
  local title = pandoc.utils.stringify(block.attributes["title"] or "")
  local content = block.content

  local fs = user_options.cheat_fontsize or "small"
  local vspace_above = user_options.cheat_vspace_above or "0pt"
  local vspace_below = user_options.cheat_vspace_below or "6pt"

  local pandocDoc = pandoc.Pandoc(content, {})
  local latexContent = pandoc.write(pandocDoc, "latex")

  local latex = {}

  table.insert(latex, "\\vspace*{" .. vspace_above .. "}")
  table.insert(latex, "\\begin{tcolorbox}[enhanced, colback=white, colframe=black, title={" .. title .. "}, fonttitle=\\bfseries, boxrule=0.5pt, sharp corners]")
  table.insert(latex, fs)
  table.insert(latex, latexContent)
  table.insert(latex, "\\end{tcolorbox}")
  table.insert(latex, "\\vspace*{" .. vspace_below .. "}")

  return pandoc.RawBlock("latex", table.concat(latex, "\n"))
end

-- function generateCheatBlockLatex(block)
--   local title = pandoc.utils.stringify(block.attributes["title"] or "")
--   local content = block.content

--   local fs = user_options.cheat_fontsize or "small"
--   local above = user_options.cheat_vspace_above or "0pt"
--   local below = user_options.cheat_vspace_below or "6pt"
--   local numcols = tonumber(user_options.numcols) or 1
--   local colwidth = string.format("%.4f\\linewidth", 0.98)  -- Adjusted to use \linewidth

--   local pandocDoc = pandoc.Pandoc(content, {})
--   local latexContent = pandoc.write(pandocDoc, "latex")

--   local latex = {}

--   table.insert(latex, "\\needspace{5\\baselineskip}")
--   table.insert(latex, "\\vspace*{" .. above .. "}")

--   -- Wrap the TikZ picture in a minipage to confine it within the column width
--   table.insert(latex, "\\begin{minipage}{" .. colwidth .. "}")
--   table.insert(latex, "\\begin{tikzpicture}")
--   table.insert(latex, "  \\node [mybox] (box) {")
--   table.insert(latex, "    {%" .. fs)
--   table.insert(latex, latexContent)
--   table.insert(latex, "    }")
--   table.insert(latex, "  };")
--   -- table.insert(latex, "\\node[fancytitle, anchor=south west] at (box.north west) {" .. title .. "};")
--   -- table.insert(latex, "\\node[fancytitle, anchor=south, yshift=-5pt] at (box.north) {" .. title .. "};")
--   table.insert(latex, "\\node[fancytitle, anchor=south, yshift=0pt] at (box.north) {" .. title .. "};")

--   table.insert(latex, "\\end{tikzpicture}")
--   table.insert(latex, "\\end{minipage}")

--   table.insert(latex, "\\vspace*{" .. below .. "}")

--   return pandoc.RawBlock("latex", table.concat(latex, "\n"))
-- end

-- Replace ::: {.cheat title="..."} blocks with TikZ-rendered LaTeX
function replaceCheatBlock(block)
  if block.classes:includes("cheat") then
    return generateCheatBlockLatex(block)
  else
    return nil
  end
end

-- Register filter hooks
return {
  { Meta = Meta },
  { Header = Header },
  { Div = replaceCheatBlock },
  { Pandoc = Pandoc }
}
