-- Start the appendices at the first top-level heading marked with {.appendix}.
-- Example:  # Meeting Minutes {.appendix}
-- LaTeX then numbers it "Appendix A" instead of the next chapter number.

local started = false

function Header(h)
  if started or h.level ~= 1 or not h.classes:includes("appendix") then
    return nil
  end
  started = true
  if FORMAT:match("latex") then
    return { pandoc.RawBlock("latex", "\\appendix"), h }
  end
  return nil
end
