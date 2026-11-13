-- tests/core/Toc_spec.lua -- smoke spec over the .toc: the numbers and files it declares.
-- Reads everything FROM the .toc (helper.readToc); nothing is hardcoded here, so a release
-- never has to touch this spec. Libraries: also assert `_VERSION` in the main .lua == the
-- .toc's `## Version:` (the lib's version lives in 3-5 places; this catches the one you forgot).
local helper = dofile("tests/helper.lua")
local fields, files = helper.readToc("QuantumDungeonTools/QuantumDungeonTools.toc")

describe("QuantumDungeonTools.toc", function()
  it("declares a numeric Interface (taintlint picks its database from it)", function()
    assert_true(fields.Interface:match("^%d+") ~= nil, "## Interface must start with the build number")
  end)

  it("keeps Version as the packager token or a SemVer string", function()
    local v = fields.Version
    assert_true(v == "@project-version@" or v:match("^%d+%.%d+%.%d+") ~= nil,
      "## Version must be @project-version@ or X.Y.Z, got " .. tostring(v))
  end)

  it("lists only files that exist (sync of .toc and disk)", function()
    assert_true(#files > 0, "the .toc loads nothing")
    for _, f in ipairs(files) do
      local fh = io.open("QuantumDungeonTools/" .. f, "rb")
      assert_true(fh ~= nil, "the .toc lists a missing file: " .. f)
      if fh then fh:close() end
    end
  end)
end)
