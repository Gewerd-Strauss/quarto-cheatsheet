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
    numcols            = getopt("numcols", "2"),
  }
  

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
  table.insert(doc.blocks, 1, pandoc.RawBlock("latex", fontsize_cmd))
  return doc
end



-- Generate LaTeX for a single cheat block
function generateCheatBlockLatex(block)
  local title = pandoc.utils.stringify(block.attributes["title"])
  local content = block.content
  -- the variables below do not access what they are supposed to access.
  local fs = user_options.cheat_fontsize or "small"
  local above = user_options.cheat_vspace_above or "0pt"
  local below = user_options.cheat_vspace_below or "6pt"
  print("user cheat fontsize:")
  print( user_options.cheat_fontsize)
  local pandocDoc = pandoc.Pandoc(content, {})
  local latexContent = pandoc.write(pandocDoc, "latex")

  local latex = {}
  table.insert(latex, "\\par\\vspace*{" .. above .. "}")
  -- table.insert(latex, "\\par\\vspace*{400pt}") -- this works, so the value of `above` seems to be wrong. #TODO: fix. 
  table.insert(latex, "\\begin{tikzpicture}")
  table.insert(latex, "  \\node [mybox] (box) {")
  table.insert(latex, "    {%" .. fs)
  table.insert(latex, latexContent)
  table.insert(latex, "\\text{" .. above .. "}")
  table.insert(latex, "\\text{" .. fs .. "}")
  table.insert(latex, "    }")
  table.insert(latex, "  };")

  table.insert(latex, "  \\node[fancytitle, right=10pt] at (box.north west) {" .. title .. "};")
  table.insert(latex, "\\end{tikzpicture}")
  table.insert(latex, "\\par\\vspace*{" .. below .. "}")

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
  { Pandoc = Pandoc }
}
