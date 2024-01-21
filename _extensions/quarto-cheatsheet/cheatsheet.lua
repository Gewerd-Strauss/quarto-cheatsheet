function replaceCheatBlock(block)
    local blockType = block.classes[1]
    local title = pandoc.utils.stringify(block.attributes["title"])
    local content = pandoc.utils.stringify(block.content)

    if blockType == "cheat" then
        local latexCode = "\\begin{tikzpicture}\n"
        latexCode = latexCode .. "    \\node [mybox, align=left] (box){%\n"
        latexCode = latexCode .. "     " .. content .. "\n"
        latexCode = latexCode .. "    };\n"
        latexCode = latexCode .. "    %------------ Header ---------------------\n"
        latexCode = latexCode .. "    \\node[fancytitle, right=10pt] at (box.north west) {" .. title .. "};\n"
        latexCode = latexCode .. " \\end{tikzpicture}\\smallskip"
        
        return pandoc.RawBlock('latex', latexCode)
    else
        return block
    end
end

-- Füge den Filter zu Pandoc hinzu
return {
    { Div = replaceCheatBlock }
}
