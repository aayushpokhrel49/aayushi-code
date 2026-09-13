-- mod-version:4
local core = require "core"
local common = require "core.common"
local config = require "core.config"
local style = require "core.style"
local command = require "core.command"
local keymap = require "core.keymap"
local process = require "core.process"

config.plugins.run = config.plugins.run or {}

-- Named tasks: { name = string, cmd = string|string[], cwd = string?, default = boolean? }
-- `cmd` supports placeholders: %f (absolute file), %d (file dir),
-- %b (basename without extension) and %e (extension without dot).
config.plugins.run.tasks = config.plugins.run.tasks or {}

-- Automatic commands for the active file, keyed by extension.
local DEFAULT_AUTO = {
  [".py"]   = { "python3", "%f" },
  [".pyw"]  = { "python3", "%f" },
  [".js"]   = { "node", "%f" },
  [".mjs"]  = { "node", "%f" },
  [".cjs"]  = { "node", "%f" },
  [".ts"]   = { "npx", "tsx", "%f" },
  [".tsx"]  = { "npx", "tsx", "%f" },
  [".jsx"]  = { "npx", "tsx", "%f" },
  [".go"]   = { "go", "run", "%f" },
  [".rs"]   = { "cargo", "run" },
  [".sh"]   = { "bash", "%f" },
  [".lua"]  = { "lua", "%f" },
  [".rb"]   = { "ruby", "%f" },
  [".php"]  = { "php", "%f" },
  [".pl"]   = { "perl", "%f" },
  [".r"]    = { "Rscript", "%f" },
  [".jl"]   = { "julia", "%f" },
  [".exs"]  = { "elixir", "%f" },
  [".hs"]   = { "runghc", "%f" },
  [".dart"] = { "dart", "run", "%f" },
  [".java"] = { "java", "%b" },
  [".cs"]   = { "dotnet", "script", "%f" },
}
config.plugins.run.auto = common.merge(DEFAULT_AUTO, config.plugins.run.auto or {})

-- Optional per-extension debug overrides; falls back to the run command.
local DEFAULT_DEBUG = {
  [".js"]  = { "node", "--inspect-brk", "%f" },
  [".mjs"] = { "node", "--inspect-brk", "%f" },
  [".cjs"] = { "node", "--inspect-brk", "%f" },
  [".ts"]  = { "npx", "tsx", "-w", "%f" },
  [".tsx"] = { "npx", "tsx", "-w", "%f" },
  [".jsx"] = { "npx", "tsx", "-w", "%f" },
  [".go"]  = { "dlv", "debug", "%f" },
}
config.plugins.run.debug_map = common.merge(DEFAULT_DEBUG, config.plugins.run.debug_map or {})

local MAX_LINES = 2000

local runner = {}
runner.running = nil   -- { proc, label, cwd, version } or nil
runner.version = 0     -- bumped on start/stop; stale pumps bail out on mismatch
runner.view = nil      -- bottom drawer debug console we stream into

local OK_COLOR = { common.color "#3fb950" }
local STOP_COLOR = { common.color "#d29922" }

-- Minimal POSIX-like tokenizer honoring single/double quotes and backslashes.
local function shell_split(line)
  local args, cur, mode = {}, nil, nil
  local i, n = 1, #line
  while i <= n do
    local c = line:sub(i, i)
    if mode == "single" then
      if c == "'" then mode = nil else cur = (cur or "") .. c end
    elseif mode == "double" then
      if c == '"' then mode = nil
      elseif c == "\\" then
        i = i + 1
        cur = (cur or "") .. line:sub(i, i)
      else
        cur = (cur or "") .. c
      end
    else
      if c == "'" then
        cur = cur or ""
        mode = "single"
      elseif c == '"' then
        mode = "double"
      elseif c == "\\" then
        i = i + 1
        cur = cur .. (line:sub(i, i) or "\\")
      elseif c:match("%s") then
        if cur then table.insert(args, cur); cur = nil end
      else
        cur = (cur or "") .. c
      end
    end
    i = i + 1
  end
  if cur then table.insert(args, cur) end
  return args
end

local function substitute(placeholders, str)
  return (str:gsub("%%([fdbe])", placeholders))
end

local function home_expand(str)
  return str:sub(1, 1) == "~" and common.home_expand(str) or str
end

local function build_args(raw, placeholders)
  if type(raw) == "table" then
    local args = {}
    for i, v in ipairs(raw) do
      args[i] = home_expand(substitute(placeholders, v))
    end
    return args
  elseif type(raw) == "string" then
    local args = shell_split(substitute(placeholders, raw))
    if args[1] then args[1] = home_expand(args[1]) end
    return args
  end
end

-- Build placeholders + default working directory for a document.
local function placeholders_for(doc)
  local file = doc and doc.abs_filename
  local dir = file and common.dirname(file) or nil
  local base = file and common.basename(file) or ""
  local name = base:match("^(.*)%.[^%.]+$") or base
  local ext = base:match("%.([^%.]+)$") or ""
  local project = core.root_project()
  local cwd = project and project.path and not core.empty_project and project.path or dir or "."
  return { f = file or "", d = dir or "", b = name, e = ext }, cwd
end

-- Resolve the drawer debug-console view (opens it on first use only).
-- Deliberately avoids per-line checks; only revalidates when the drawer
-- was torn down or recreated, throttled so we never steal focus in a loop.
local last_panel_check = 0
local function ensure_view()
  local v = runner.view
  if v and v.console_write then
    if core.terminal_view and core.terminal_view ~= v then
      runner.view = core.terminal_view; v = runner.view -- drawer was recreated, adopt it
    elseif not core.terminal_view and system.get_time() - last_panel_check > 0.5 then
      last_panel_check = system.get_time()
      if command.is_valid("terminal:open-debug") then
        command.perform("terminal:open-debug")
      end
      runner.view = core.terminal_view; v = core.terminal_view
    end
    if v and v.console_write then return v end
  end
  runner.view = nil
  if command.is_valid("terminal:open-debug") then
    command.perform("terminal:open-debug")
    local dv = core.terminal_view
    if dv and dv.console_write then runner.view = dv; return dv end
  end
  return nil
end

local function write_line(color, text)
  if not text or #text == 0 then return end
  local tv = ensure_view()
  if tv then
    for line in tostring(text):gmatch("[^\r\n]+") do
      tv:console_write(color, line)
      if #tv.console_lines > MAX_LINES then
        table.remove(tv.console_lines, 1)
      end
    end
    core.redraw = true
  else
    for line in tostring(text):gmatch("[^\r\n]+") do
      core.log_quiet("%s", line)
    end
  end
end

local function banner(label, args, cwd)
  write_line(style.accent, "────────── " .. label)
  if cwd and #cwd > 0 then
    write_line(style.dim, "  cwd: " .. cwd)
  end
  if args and #args > 0 then
    write_line(style.dim, "  $ " .. table.concat(args, " "))
  end
end

local function pump(proc, stream, color, version, done)
  while runner.running and runner.running.version == version do
    local chunk = stream:read("L")
    if not chunk then break end
    if #chunk > 0 then write_line(color, chunk) end
  end
  done()
end

local function start_command(label, args, cwd)
  if runner.running then runner.stop() end
  if not args or #args == 0 then
    core.error("No command to run")
    return false
  end
  local ok, proc = pcall(function()
    return process.start(args, { cwd = cwd })
  end)
  if not ok or not proc then
    core.error("Failed to start command: %s", table.concat(args, " "))
    return false
  end
  runner.version = runner.version + 1
  local version = runner.version
  runner.running = { proc = proc, version = version }

  banner("Running: " .. label, args, cwd)
  ensure_view()

  local remaining = 2
  local function done() remaining = remaining - 1 end
  core.add_thread(pump, nil, proc, proc.stdout, style.text, version, done)
  core.add_thread(pump, nil, proc, proc.stderr, style.error, version, done)
  core.add_thread(function()
    proc:wait()
    while remaining > 0 and runner.running and runner.running.version == version do
      coroutine.yield(0.05)
    end
    if runner.running and runner.running.version == version then
      runner.running = nil
      local code = proc:returncode() or -1
      write_line(code == 0 and OK_COLOR or style.error,
        string.format("────────── Process exited with code %d", code))
      core.redraw = true
    end
  end)
  return true
end

local function active_doc()
  local view = core.active_view
  return view and view.doc or nil
end

local function resolve_auto(doc, debug)
  local file = doc and doc.abs_filename
  if not file then return nil end
  local ext = file:match("%.([^%.]+)$")
  ext = "." .. ext
  local key = debug and config.plugins.run.debug_map[ext] or config.plugins.run.auto[ext]
  if not key then return nil end
  local placeholders, cwd = placeholders_for(doc)
  return build_args(key, placeholders), cwd
end

local function find_task(name)
  for _, t in ipairs(config.plugins.run.tasks) do
    if t.name == name then return t end
  end
end

local function default_task()
  for _, t in ipairs(config.plugins.run.tasks) do
    if t.default then return t end
  end
end

local function task_names()
  local names = {}
  for _, t in ipairs(config.plugins.run.tasks) do names[#names + 1] = t.name end
  return names
end

local function resolve_task(task, doc)
  local placeholders, cwd = placeholders_for(doc)
  if task.cwd then cwd = common.home_expand(task.cwd) end
  return build_args(task.cmd, placeholders), cwd
end

local function save_tasks()
  local parts = {
    "-- Aayushi Code run tasks. Loaded at startup; edit freely.",
    "-- Placeholders: %f absolute file, %d file dir, %b basename w/o ext, %e ext.",
    "return {",
  }
  for _, t in ipairs(config.plugins.run.tasks) do
    local fields = { string.format("  { name = %q", t.name) }
    if type(t.cmd) == "string" then
      fields[#fields + 1] = string.format(", cmd = %q", t.cmd)
    else
      local parts2 = {}
      for _, v in ipairs(t.cmd) do parts2[#parts2 + 1] = string.format("%q", v) end
      fields[#fields + 1] = ", cmd = { " .. table.concat(parts2, ", ") .. " }"
    end
    if t.cwd then fields[#fields + 1] = string.format(", cwd = %q", t.cwd) end
    if t.default then fields[#fields + 1] = ", default = true" end
    parts[#parts + 1] = table.concat(fields) .. " },"
  end
  parts[#parts + 1] = "}"
  local fp, err = io.open(USERDIR .. PATHSEP .. "run_tasks.lua", "w")
  if not fp then
    core.error("Cannot write tasks file: %s", err)
    return false
  end
  fp:write(table.concat(parts, "\n") .. "\n")
  fp:close()
  return true
end

local function load_tasks()
  local ok, tasks = pcall(dofile, USERDIR .. PATHSEP .. "run_tasks.lua")
  if ok and type(tasks) == "table" then
    config.plugins.run.tasks = tasks
  end
end

function runner.stop()
  local state = runner.running
  if not state then
    core.error("Nothing is currently running")
    return
  end
  runner.running = nil
  runner.version = runner.version + 1
  local proc = state.proc
  local ok = pcall(function() return proc.process:terminate() end)
  if not ok then pcall(function() return proc.process:kill() end) end
  write_line(STOP_COLOR, "────────── Process stopped")
  core.redraw = true
end

local function do_run(debug)
  local doc = active_doc()
  local task = default_task()
  local label, args, cwd
  if task then
    label = task.name
    args, cwd = resolve_task(task, doc)
  else
    args, cwd = resolve_auto(doc, debug)
    label = doc and doc.abs_filename and (common.basename(doc.abs_filename) .. (debug and " (debug)" or "")) or "task"
  end
  if not args then
    core.error("No task or automatic command for %q. Use \"Add Configuration...\".",
      doc and doc.filename or "(unsaved file)")
    return
  end
  start_command(label, args, cwd)
end

function runner.run(debug)
  do_run(debug)
end

function runner.run_task(name)
  local names = task_names()
  if #names == 0 then
    core.error("No tasks configured. Use \"Add Configuration...\" to create one.")
    return
  end
  if name and #name > 0 then
    local task = find_task(name)
    if task then
      start_command(task.name, resolve_task(task, active_doc()))
    else
      core.error("Unknown task %q", name)
    end
    return
  end
  core.command_view:enter("Run task", {
    submit = function(value) runner.run_task(value) end,
    suggest = function(text)
      local out = {}
      for _, n in ipairs(names) do
        if n:find(text, 1, true) then out[#out + 1] = n end
      end
      return out
    end,
  })
end

function runner.add_task()
  core.command_view:enter("Task name", {
    submit = function(name)
      name = name:gsub("^%s+", ""):gsub("%s+$", "")
      if #name == 0 then return end
      core.command_view:enter("Command for \"" .. name .. "\" (%f %d %b %e placeholders)", {
        submit = function(cmdline)
          if not cmdline or cmdline:match("^%s*$") then
            core.warn("Add Configuration cancelled: empty command")
            return
          end
          local task = find_task(name)
          if task then
            task.cmd = cmdline
          else
            table.insert(config.plugins.run.tasks, { name = name, cmd = cmdline })
          end
          save_tasks()
          core.log("Saved task %q → %q", name, cmdline)
          core.add_thread(function()
            runner.run_task(name)
          end)
        end,
      })
    end,
  })
end

function runner.configure_tasks()
  local path = USERDIR .. PATHSEP .. "run_tasks.lua"
  if not system.get_file_info(path) then
    if #config.plugins.run.tasks == 0 then
      table.insert(config.plugins.run.tasks,
        { name = "python script", cmd = "python3 %f", default = true })
    end
    save_tasks()
  end
  load_tasks()
  local doc = core.open_doc(path)
  if doc then core.root_view:open_doc(doc) end
end

-- Enables/disables menu entries based on context.
command.add(function()
  local doc = active_doc()
  return doc and doc.abs_filename ~= nil
end, {
  ["runner:run"]   = function() runner.run(false) end,
  ["runner:debug"] = function() runner.run(true) end,
})

command.add(function()
  return runner.running ~= nil
end, {
  ["runner:stop"] = function() runner.stop() end,
})

command.add(nil, {
  ["runner:run-task"]     = function() runner.run_task() end,
  ["runner:add-task"]     = function() runner.add_task() end,
  ["runner:configure-tasks"] = function() runner.configure_tasks() end,
})

keymap.add {
  ["f5"] = "runner:debug",
  ["ctrl+f5"] = "runner:run",
  ["shift+f5"] = "runner:stop",
}

load_tasks()

return runner