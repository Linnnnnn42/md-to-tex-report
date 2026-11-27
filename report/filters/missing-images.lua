-- Replace images whose file does not exist with a framed placeholder box,
-- so a template full of figure placeholders still compiles to PDF.
-- The figure keeps its caption and number; only the picture is swapped.

local function file_exists(path)
  local f = io.open(path, "rb")
  if f then
    f:close()
    return true
  end
  return false
end

local function is_remote(src)
  return src:match("^%a[%w+.-]*://") ~= nil
end

function Image(img)
  if not FORMAT:match("latex") then
    return nil
  end
  local src = pandoc.path.normalize(img.src)
  if is_remote(src) or file_exists(src) then
    return nil
  end
  io.stderr:write("[missing-images] placeholder used for missing image: " .. img.src .. "\n")
  local label = "Image placeholder"
  if #img.caption > 0 then
    label = pandoc.write(pandoc.Pandoc({ pandoc.Plain(img.caption) }), "latex"):gsub("%s+$", "")
  end
  local box = string.format(
    "\\fbox{\\parbox[c][4cm][c]{0.8\\linewidth}{\\centering %s\\\\[0.5em]\\footnotesize\\texttt{\\detokenize{%s}}}}",
    label,
    img.src
  )
  return pandoc.RawInline("latex", box)
end
