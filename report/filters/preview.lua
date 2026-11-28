-- Keep only selected chapters, for a quick local preview (scripts/preview.*).
-- Does nothing unless the metadata field "preview-chapters" is set, so the
-- normal build is unaffected.
--
-- Metadata:
--   preview-chapters      chapters to keep, as numbers shown in the PDF:
--                         "2", "2 5", "2-4", appendices as letters "A", "B-C"
--   preview-bibliography  false to drop the bibliography (kept by default so
--                         citations still link)
--   preview-title         true to keep the title page (dropped by default)
--
-- Skipped chapters still advance the chapter counter, so a kept chapter keeps
-- the number (and figure/table numbers) it has in the full report.

local function letter(n)
  return string.char(string.byte("A") + n - 1)
end

local function letter_index(s)
  return string.byte(s) - string.byte("A") + 1
end

-- Parse "2 5,7 2-4 A B-C" into a set of chapter labels ("2", "A", ...).
local function parse_selection(text)
  local selected, count = {}, 0
  for token in text:gmatch("[^%s,]+") do
    token = token:upper()
    local a, b = token:match("^(%d+)%-(%d+)$")
    local la, lb = token:match("^(%a)%-(%a)$")
    if a then
      for n = tonumber(a), tonumber(b) do
        selected[tostring(n)] = true
      end
    elseif la then
      for n = letter_index(la), letter_index(lb) do
        selected[letter(n)] = true
      end
    elseif token:match("^%d+$") then
      selected[tostring(tonumber(token))] = true
    elseif token:match("^%a$") then
      selected[token] = true
    else
      error("preview: can't read chapter '" .. token .. "'. Use numbers (2, 2-4) or appendix letters (A, A-B).")
    end
    count = count + 1
  end
  if count == 0 then
    error("preview: no chapters selected")
  end
  return selected
end

local function meta_string(value)
  if value == nil then
    return nil
  end
  if type(value) == "boolean" then
    return tostring(value)
  end
  return pandoc.utils.stringify(value)
end

local function is_bibliography(h)
  if h.classes:includes("bibliography") then
    return true
  end
  local title = pandoc.utils.stringify(h.content):lower()
  return title == "bibliography" or title == "references"
end

function Pandoc(doc)
  local selection = meta_string(doc.meta["preview-chapters"])
  if not selection or selection == "" then
    return nil
  end
  local selected = parse_selection(selection)
  local keep_bib = meta_string(doc.meta["preview-bibliography"]) ~= "false"
  local keep_title = meta_string(doc.meta["preview-title"]) == "true"

  local out = pandoc.Blocks({})
  local chapter, in_appendix, keep = 0, false, false
  local found = {}

  for _, block in ipairs(doc.blocks) do
    if block.t == "Header" and block.level == 1 then
      -- Start the appendices here, then drop the class so appendix.lua
      -- doesn't start them a second time.
      if block.classes:includes("appendix") then
        if not in_appendix then
          in_appendix = true
          chapter = 0
          out:insert(pandoc.RawBlock("latex", "\\appendix"))
        end
        block.classes = block.classes:filter(function(c) return c ~= "appendix" end)
      end

      if block.classes:includes("unnumbered") then
        keep = keep_bib and is_bibliography(block)
      else
        chapter = chapter + 1
        local label = in_appendix and letter(chapter) or tostring(chapter)
        keep = selected[label] == true
        if keep then
          found[label] = true
        else
          -- Keep numbering identical to the full report.
          out:insert(pandoc.RawBlock("latex", "\\stepcounter{chapter}"))
        end
      end
    end
    if keep then
      out:insert(block)
    end
  end

  local missing = {}
  for label in pairs(selected) do
    if not found[label] then
      table.insert(missing, label)
    end
  end
  if #missing > 0 then
    table.sort(missing)
    error("preview: no chapter " .. table.concat(missing, ", ") .. " in this report")
  end

  if not keep_title then
    doc.meta.title = nil
  end
  doc.blocks = out
  return doc
end
