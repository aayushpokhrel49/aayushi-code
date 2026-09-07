-- mod-version:4
local syntax = require "core.syntax"

syntax.add {
  name = "JSON",
  files = { "%.json$", "%.jsonc$", "%.json5$" },
  comment = "//",
  block_comment = { "/*", "*/" },
  patterns = {
    { pattern = "//[^\n]*",                 type = "comment"  },
    { pattern = { "/%*", "%*/" },           type = "comment"  },
    { pattern = { '"', '"', '\\' },         type = "string"   },
    { pattern = "-?%d+[%d%.eE]*",           type = "number"   },
    { pattern = "0[xX][%da-fA-F]+",         type = "number"   },
    { pattern = "%[",                       type = "operator" },
    { pattern = "%]",                       type = "operator" },
    { pattern = "{",                        type = "operator" },
    { pattern = "}",                        type = "operator" },
    { pattern = ":",                        type = "operator" },
    { pattern = ",",                        type = "operator" },
    { pattern = "[%a_][%w_]*",              type = "symbol"   },
  },
  symbols = {
    ["true"]   = "literal",
    ["false"]  = "literal",
    ["null"]   = "literal",
  },
}