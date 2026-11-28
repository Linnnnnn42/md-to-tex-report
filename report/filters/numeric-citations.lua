-- Turn numeric citations such as [3], [1, 4] or [2-5] into links to the
-- matching entry of the bibliography.
--
-- The bibliography is the first numbered list after a level-1 heading that is
-- titled "Bibliography" or "References", or carries the {.bibliography} class:
--
--   # Bibliography {-}
--
--   1. Author, A. Title ...
--   2. Author, B. Title ...
--
-- Entry N gets the anchor "ref-N". Only numbers that exist in that list are
-- linked, so other bracketed numbers in the text are left alone.

local refs = {}   -- refs[n] = true for every entry number in the bibliography

local function is_bibliography_heading(h)
  if h.level ~= 1 then
    return false
  end
  if h.classes:includes("bibliography") then
    return true
  end
  local title = pandoc.utils.stringify(h.content):lower()
  return title == "bibliography" or title == "references"
end

-- Give every entry of the reference list an anchor at its start.
local function anchor_entries(list)
  local start = list.start or 1
  for i, item in ipairs(list.content) do
    local n = start + i - 1
    refs[n] = true
    local anchor = pandoc.Span({}, pandoc.Attr("ref-" .. n))
    local first = item[1]
    if first and (first.t == "Plain" or first.t == "Para") then
      first.content:insert(1, anchor)
    else
      item:insert(1, pandoc.Plain({ anchor }))
    end
  end
end

local function find_bibliography(blocks)
  local in_bib = false
  for _, block in ipairs(blocks) do
    if block.t == "Header" and block.level == 1 then
      in_bib = is_bibliography_heading(block)
    elseif in_bib and block.t == "OrderedList" then
      anchor_entries(block)
      return
    end
  end
end

local function link(text, n)
  return pandoc.Link({ pandoc.Str(text) }, "#ref-" .. n)
end

-- Parse the inside of a bracket ("3", "1, 4", "2-5", "2–5") into citation
-- parts, or return nil if it isn't a citation of known entries.
local function parse_citation(inner)
  local parts = {}
  local normalized = inner:gsub("–", "-")  -- accept en dash ranges
  for part in normalized:gmatch("[^,]+") do
    part = part:match("^%s*(.-)%s*$")
    local a, b = part:match("^(%d+)%s*%-%s*(%d+)$")
    if a then
      a, b = tonumber(a), tonumber(b)
      if not (refs[a] and refs[b] and a < b) then
        return nil
      end
      table.insert(parts, { a, b })
    elseif part:match("^%d+$") then
      local n = tonumber(part)
      if not refs[n] then
        return nil
      end
      table.insert(parts, { n })
    else
      return nil
    end
  end
  if #parts == 0 then
    return nil
  end
  return parts
end

-- Inlines for one citation: "[3]" links as a whole; in lists and ranges each
-- number links to its own entry.
local function citation_inlines(parts)
  if #parts == 1 and #parts[1] == 1 then
    local n = parts[1][1]
    return { link("[" .. n .. "]", n) }
  end
  local out = { pandoc.Str("[") }
  for i, part in ipairs(parts) do
    if i > 1 then
      out[#out + 1] = pandoc.Str(",")
      out[#out + 1] = pandoc.Space()
    end
    out[#out + 1] = link(tostring(part[1]), part[1])
    if part[2] then
      out[#out + 1] = pandoc.Str("–")
      out[#out + 1] = link(tostring(part[2]), part[2])
    end
  end
  out[#out + 1] = pandoc.Str("]")
  return out
end

-- Replace every citation inside one piece of text, keeping the text around it.
local function convert_text(text)
  local out = {}
  local pos = 1
  local changed = false
  while true do
    local s, e, inner = text:find("%[(%d[^%[%]]*)%]", pos)
    if not s then
      break
    end
    local parts = parse_citation(inner)
    if parts then
      if s > pos then
        out[#out + 1] = pandoc.Str(text:sub(pos, s - 1))
      end
      for _, il in ipairs(citation_inlines(parts)) do
        out[#out + 1] = il
      end
      changed = true
    elseif e >= pos then
      out[#out + 1] = pandoc.Str(text:sub(pos, e))
    end
    pos = e + 1
  end
  if not changed then
    return nil
  end
  if pos <= #text then
    out[#out + 1] = pandoc.Str(text:sub(pos))
  end
  return out
end

-- A citation with spaces ("[1, 4]") is split over several Str and Space
-- elements, so join such runs before converting.
local function convert_inlines(inlines)
  local out = pandoc.Inlines({})
  local i = 1
  while i <= #inlines do
    local el = inlines[i]
    local consumed = 1
    local replacement = nil
    if el.t == "Str" then
      local text = el.text
      -- An opening bracket with a number and no closing bracket yet:
      -- join the following Str/Space elements up to the closing bracket.
      if text:find("%[%d[^%]]*$") then
        local joined = text
        local j = i + 1
        while j <= #inlines and j <= i + 12 do
          local nxt = inlines[j]
          if nxt.t == "Space" then
            joined = joined .. " "
          elseif nxt.t == "Str" then
            joined = joined .. nxt.text
            if nxt.text:find("%]") then
              break
            end
          else
            break
          end
          j = j + 1
        end
        if j <= #inlines and inlines[j].t == "Str" and inlines[j].text:find("%]") then
          local converted = convert_text(joined)
          if converted then
            replacement = converted
            consumed = j - i + 1
          end
        end
      end
      if not replacement then
        replacement = convert_text(text)
      end
    end
    if replacement then
      out:extend(replacement)
    else
      out:insert(el)
    end
    i = i + consumed
  end
  return out
end

function Pandoc(doc)
  find_bibliography(doc.blocks)
  if next(refs) == nil then
    return nil
  end
  return doc:walk({ Inlines = convert_inlines })
end
