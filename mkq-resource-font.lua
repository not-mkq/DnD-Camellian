-- Full TrueType font for editable Chinese/Latin AcroForm notes.
-- CID values are Unicode BMP code points, with an explicit CID-to-glyph map.
-- Keeping the entire font allows readers to save characters absent from the
-- initial notes. No external PDF postprocessing or JavaScript is required.
local M = {}

function M.embed(filename)
  if M.object then return M.object end
  local path = kpse.find_file(filename, "truetype fonts") or filename
  local handle = assert(io.open(path, "rb"), "Resource note font not found: " .. filename)
  local bytes = handle:read("*a")
  handle:close()
  local loaded = assert(fontloader.open(path), "Cannot load resource note font: " .. path)
  local data = fontloader.to_table(loaded)
  local scale = 1000 / data.units_per_em
  local function metric(n) return math.floor(n * scale + 0.5) end
  local map, widths = {}, {}
  local fontbox = {0, -data.descent, 1000, data.ascent}
  for _, glyph in pairs(data.glyphs) do
    local b = glyph.boundingbox
    if b then
      fontbox[1] = math.min(fontbox[1], b[1])
      fontbox[2] = math.min(fontbox[2], b[2])
      fontbox[3] = math.max(fontbox[3], b[3])
      fontbox[4] = math.max(fontbox[4], b[4])
    end
  end
  for code = 0, 65535 do
    local gid = data.map.map[code] or 0
    if gid < 0 or gid > 65535 then gid = 0 end
    map[#map + 1] = string.char(math.floor(gid / 256), gid % 256)
    local glyph = data.glyphs[gid]
    if gid > 0 and glyph then
      local width = metric(glyph.width)
      if width ~= 1000 then widths[#widths + 1] = code .. " [" .. width .. "]" end
    end
  end
  local name = data.fontname:gsub("[^A-Za-z0-9_-]", "")
  local fontfile = pdf.immediateobj("stream", bytes, "/Length1 " .. #bytes)
  local cidmap = pdf.immediateobj("stream", table.concat(map))
  local tounicode = pdf.immediateobj("stream", [[
/CIDInit /ProcSet findresource begin
12 dict begin begincmap
/CIDSystemInfo << /Registry (Adobe) /Ordering (UCS) /Supplement 0 >> def
/CMapName /MKQNotes-UCS def /CMapType 2 def
1 begincodespacerange <0000> <FFFF> endcodespacerange
1 beginbfrange <0000> <FFFF> <0000> endbfrange
endcmap CMapName currentdict /CMap defineresource pop end end
]])
  local descriptor = pdf.immediateobj(string.format(
    "<< /Type /FontDescriptor /FontName /%s /Flags 4 /FontBBox [%d %d %d %d] " ..
    "/ItalicAngle 0 /Ascent %d /Descent %d /CapHeight %d /StemV 80 /FontFile2 %d 0 R >>",
    name, metric(fontbox[1]), metric(fontbox[2]), metric(fontbox[3]), metric(fontbox[4]),
    metric(data.ascent), -metric(data.descent), metric(data.ascent), fontfile))
  local descendant = pdf.immediateobj(string.format(
    "<< /Type /Font /Subtype /CIDFontType2 /BaseFont /%s " ..
    "/CIDSystemInfo << /Registry (Adobe) /Ordering (Identity) /Supplement 0 >> " ..
    "/FontDescriptor %d 0 R /DW 1000 /W [%s] /CIDToGIDMap %d 0 R >>",
    name, descriptor, table.concat(widths, " "), cidmap))
  M.object = pdf.immediateobj(string.format(
    "<< /Type /Font /Subtype /Type0 /BaseFont /%s /Encoding /Identity-H " ..
    "/DescendantFonts [%d 0 R] /ToUnicode %d 0 R >>", name, descendant, tounicode))
  fontloader.close(loaded)
  return M.object
end

return M
