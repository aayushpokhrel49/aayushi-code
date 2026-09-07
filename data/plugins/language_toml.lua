-- mod-version:4
local syntax = require "core.syntax"

syntax.add {
  name = "TOML",
  files = { "%.toml$" },
  comment = "#",
  patterns = {
    { pattern = "#[^\n]*",                 type = "comment"  },
    { pattern = { '"', '"', '\\' },        type = "string"   },
    { pattern = { "'", "'" },              type = "string"   },
    { pattern = { '"""', '"""', '\\' },    type = "string"   },
    { pattern = { "'''", "'''" },          type = "string"   },
    { pattern = "%[%[?[%a_][%w_%.%-]*%]?%]", type = "keyword2" },
    { pattern = "%f[%a_][%a_][%w_%.%-]*%s*=", type = "keyword" },
    { pattern = "-?%d+[%d%.eE]*",          type = "number"   },
    { pattern = "[=.]",                    type = "operator" },
    { pattern = "[%a_][%w_]*",             type = "symbol"   },
  },
  symbols = {
    ["true"]       = "literal",
    ["false"]      = "literal",
    ["inf"]        = "literal",
    ["nan"]        = "literal",
    ["date"]       = "keyword",
    ["time"]       = "keyword",
    ["datetime"]   = "keyword",
  },
}