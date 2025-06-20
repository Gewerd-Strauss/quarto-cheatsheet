-- cheatsheet.lua

local user_options = {}

local function latexcmd(s)
  s = pandoc.utils.stringify(s or "")
  if s == "" then return "" end
  if not s:match("^\\") then
    return "\\" .. s
  else
    return s
  end
end

function Meta(meta)
  -- Attempt to get options from format.quarto-cheatsheet-pdf or fallback top-level
  local fmt_opts = (meta.format and meta.format["quarto-cheatsheet-pdf"]) or {}

  local function getopt(key, default)
    if fmt_opts[key] ~= nil then
      return pandoc.utils.stringify(fmt_opts[key])
    elseif meta[key] ~= nil then
      return pandoc.utils.stringify(meta[key])
    else
      return default
    end
  end

  user_options = {
    cheat_vspace_above = getopt("cheat-vspace-above", "0pt"),
    cheat_vspace_below = getopt("cheat-vspace-below", "6pt"),
    body_fontsize      = latexcmd(getopt("body-fontsize", "normalsize")),
    cheat_fontsize     = latexcmd(getopt("cheat-fontsize", "tiny")),
    numcols            = tonumber(getopt("numcols", "1")) or 1,
  }

  -- Calculate and store a cheatbox width (approx 0.95 textwidth divided by numcols)
  local colwidth = string.format("%.4f\\textwidth", 0.95 / user_options.numcols)
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

function Pandoc(doc)
  local fontsize_cmd = user_options.body_fontsize or "\\normalsize"

  -- Wrap everything in multicols
  local start = pandoc.RawBlock("latex", "\\raggedcolumns\\begin{multicols}{" .. user_options.numcols .. "}")
  local stop = pandoc.RawBlock("latex", "\\end{multicols}")

  local new_blocks = {}
  table.insert(new_blocks, pandoc.RawBlock("latex", fontsize_cmd))
  table.insert(new_blocks, start)
  for _, block in ipairs(doc.blocks) do
    table.insert(new_blocks, block)
  end
  table.insert(new_blocks, stop)

  return pandoc.Pandoc(new_blocks, doc.meta)
end


function generateCheatBlockLatex(block)
  local title = pandoc.utils.stringify(block.attributes["title"] or "")
  local content = block.content

  local fs = user_options.cheat_fontsize or "\\tiny"
  local above = user_options.cheat_vspace_above or "0pt"
  local below = user_options.cheat_vspace_below or "6pt"
  local colwidth = string.format("%.4f\\linewidth", 0.98)  -- Keep relative to column width

  local pandocDoc = pandoc.Pandoc(content, {})
  local latexContent = pandoc.write(pandocDoc, "latex")

  local latex = {}

  table.insert(latex, "\\needspace{5\\baselineskip}")
  table.insert(latex, "\\vspace*{" .. above .. "}")

  table.insert(latex, "\\begin{minipage}{" .. colwidth .. "}")
  table.insert(latex, "\\begin{tikzpicture}")
  table.insert(latex, "  \\node [mybox] (box) {")
  table.insert(latex, "    {" .. fs)
  table.insert(latex, latexContent)
  table.insert(latex, "    }")
  table.insert(latex, "  };")
  table.insert(latex, "\\node[fancytitle, anchor=south, yshift=0pt] at (box.north) {" .. title .. "};")
  table.insert(latex, "\\end{tikzpicture}")
  table.insert(latex, "\\end{minipage}")

  table.insert(latex, "\\vspace*{" .. below .. "}")

  return pandoc.RawBlock("latex", table.concat(latex, "\n"))
end

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
  { Pandoc = Pandoc },
}
