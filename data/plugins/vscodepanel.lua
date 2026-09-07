-- mod-version:4
-- Compatibility shim: the VS Code-style bottom panel lives in the terminal
-- plugin as tabbed drawer (PROBLEMS | OUTPUT | DEBUG CONSOLE | TERMINAL).
-- This module redirects the old panel commands to the terminal drawer tabs.

local command = require "core.command"

command.add(nil, {
  ["vscode-panel:toggle"]        = function() command.perform("terminal:toggle-drawer") end,
  ["vscode-panel:open-problems"] = function() command.perform("terminal:open-problems") end,
  ["vscode-panel:open-output"]   = function() command.perform("terminal:open-output") end,
  ["vscode-panel:open-terminal"] = function() command.perform("terminal:open-terminal") end,
  ["vscode-panel:open-debug"]    = function() command.perform("terminal:open-debug") end,
  ["vscode-panel:open-ports"]    = function() command.perform("terminal:open-ports") end,
})