local column_count = 3  -- default value
local max_height = 700  -- crude height per column
local column_heights = {}
local current_column = 1

-- Get user-defined value from frontmatter
function Meta(meta)
  if meta["columns-per-page"] then
    column_count = tonumber(pandoc.utils.stringify(meta["columns-per-page"])) or 3
  end
  -- Reset tracking
  column_heights = {}
  for i = 1, column_count do column_heights[i] = 0 end
  current_column = 1
  return meta
end

function Pandoc(doc)
  -- Wrap the full document in paracol environment
  table.insert(doc.blocks, 1, pandoc.RawBlock('latex', '\\begin{paracol}{' .. column_count .. '}'))
  table.insert(doc.blocks, pandoc.RawBlock('latex', '\\end{paracol}'))
  return doc
end

-- Function to wrap the cheatbox
function wrap_cheatbox(content)
  return pandoc.Div({
    pandoc.RawBlock('latex', '\\begin{cheatbox}'),
    table.unpack(content),
    pandoc.RawBlock('latex', '\\end{cheatbox}')
  })
end

function Div(div)
  if div.classes:includes("cheat") then
    local est_height = 100  -- crude, fixed estimate

    if not column_heights[current_column] then
      column_heights[current_column] = 0
    end

    if column_heights[current_column] + est_height > max_height then
      if current_column < column_count then
        current_column = current_column + 1
        column_heights[current_column] = column_heights[current_column] or 0
        return {
          pandoc.RawBlock('latex', '\\switchcolumn'),
          wrap_cheatbox(div.content)
        }
      else
        -- all columns full, start new page
        current_column = 1
        for i = 1, column_count do column_heights[i] = 0 end
        return {
          pandoc.RawBlock('latex', '\\end{paracol}\\newpage\\begin{paracol}{' .. column_count .. '}'),
          wrap_cheatbox(div.content)
        }
      end
    end

    column_heights[current_column] = column_heights[current_column] + est_height
    return wrap_cheatbox(div.content)
  end
end
