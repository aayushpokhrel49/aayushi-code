-- mod-version:4
-- First-run setup: automatically downloads the bundled LSP server plugins
-- with the Lite XL plugin manager (lpm) on the first launch.
-- After a successful install this plugin does nothing.

local core = require "core"
local common = require "core.common"
local config = require "core.config"
local process = require "core.process"

config.plugins.firstrun = common.merge({
  enabled = true,
  -- plugins installed on the first launch.
  -- plugin_manager gives the user a graphical plugin manager (ctrl+shift+p);
  -- LSP server plugins are installed from there on demand, as they download
  -- large language-server binaries that shouldn't ship with the app.
  plugins = {
    "plugin_manager",
  },
  -- repository that provides the LSP server plugins
  lsp_repository = "https://github.com/lite-xl/lite-xl-lsp-servers.git",
  marker = ".aayushi-code-firstrun",
}, config.plugins.firstrun)

if not config.plugins.firstrun.enabled then
  return
end

local firstrun = config.plugins.firstrun
local marker_file = USERDIR .. PATHSEP .. firstrun.marker

-- bail out silently when the marker exists or lpm was not found
local lpm_binary
local function find_lpm()
  if lpm_binary then return lpm_binary end
  local prefixes = { EXEDIR }
  for _, prefix in ipairs(prefixes) do
    local candidates = {
      prefix .. PATHSEP .. "lpm",
      prefix .. PATHSEP .. "lpm.exe",
    }
    for _, candidate in ipairs(candidates) do
      if system.get_file_info(candidate) then
        lpm_binary = candidate
        return lpm_binary
      end
    end
  end
  -- fall back to a plain "lpm" resolved through PATH
  lpm_binary = "lpm"
  return lpm_binary
end

local function is_first_run()
  return not system.get_file_info(marker_file)
end

local function mark_done()
  system.mkdir(USERDIR)
  local fp = io.open(marker_file, "w")
  if fp then
    fp:close()
  end
end

local function notify(text)
  if core.status_view then
    core.status_view:show_message("i", "#00FF7F", text)
  end
  core.log(text)
end

local function run_lpm_install()
  if not is_first_run() then return end
  local lpm = find_lpm()
  if not lpm then return end

  -- make sure USERDIR exists before lpm runs
  system.mkdir(USERDIR)

  -- add the LSP servers repository, then install the bundled plugin set.
  -- note: the LSP server plugins and plugin_manager are still
  -- mod-version 3; the fork uses mod-version 4 so we request mod-version 3
  -- explicitly, otherwise those addons are treated as incompatible.
  local common_args = {
    "--userdir=" .. USERDIR,
    "--cachedir=" .. USERDIR .. PATHSEP .. ".cache",
    "--assume-yes",
    "--mod-version=3",
  }

  local lpm_args = {
    lpm,
    table.unpack(common_args),
    "add",
    firstrun.lsp_repository,
  }

  local ok, rc = pcall(function()
    return process.start(lpm_args):wait()
  end)

  if not ok or rc ~= 0 then
    core.log("Aayushi Code: failed to add the LSP server repository (lpm exited with %s).", tostring(rc))
    return
  end

  local install_args = {
    lpm,
    table.unpack(common_args),
    "install",
  }
  for _, plugin in ipairs(firstrun.plugins) do
    install_args[#install_args + 1] = plugin
  end

  ok, rc = pcall(function()
    return process.start(install_args):wait()
  end)

  if ok and rc == 0 then
    mark_done()
    notify("First-run setup done. Use Plugin Manager (cmd+shift+p) for LSP servers.")
  elseif ok then
    core.log("Aayushi Code: first-run plugin installation failed (lpm exited with %s).", tostring(rc))
  else
    core.log("Aayushi Code: first-run plugin installation failed: %s", tostring(rc))
  end
end

core.add_thread(run_lpm_install)