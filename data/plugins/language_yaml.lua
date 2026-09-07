-- mod-version:4
local syntax = require "core.syntax"

syntax.add {
  name = "YAML",
  files = { "%.ya?ml$", "%.yaml$" },
  comment = "#",
  patterns = {
    { pattern = "#[^\n]*",                    type = "comment"  },
    { pattern = { "'", "'" },                 type = "string"   },
    { pattern = { '"', '"', '\\' },           type = "string"   },
    { pattern = "%s+%-%s+",                   type = "operator" },
    { pattern = "%-%f[%w]",                   type = "operator" },
    { pattern = "%s+%[%b[]",                  type = "operator" },
    { pattern = "-?%d+[%d%.eE]*",             type = "number"   },
    { pattern = "%f[%a_][%a_][%w_%.%-]*%:%s", type = "keyword2" },
    { pattern = "&[%a_][%w_]*",               type = "keyword2" },
    { pattern = "%-%-%-",                     type = "keyword"  },
    { pattern = "%.%.%."  ,                   type = "keyword"  },
    { pattern = "[%a_][%w_]*",                type = "symbol"   },
  },
  symbols = {
    ["true"]   = "literal",
    ["false"]  = "literal",
    ["yes"]    = "literal",
    ["no"]     = "literal",
    ["null"]   = "literal",
    ["~"]      = "literal",
    ["on"]     = "literal",
    ["off"]    = "literal",
  },
}