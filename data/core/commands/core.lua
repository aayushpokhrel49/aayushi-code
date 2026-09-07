local core = require "core"
local common = require "core.common"
local command = require "core.command"
local config = require "core.config"
local keymap = require "core.keymap"
local LogView = require "core.logview"
local process = require "core.process"


local fullscreen = false
local restore_title_view = false

local function suggest_directory(text)
  text = common.home_expand(text)
  local basedir = common.dirname(core.root_project().path)
  return common.home_encode_list((basedir and text == basedir .. PATHSEP or text == "") and
    core.recent_projects or common.dir_path_suggest(text, core.root_project().path))
end

local function check_directory_path(path)
    local abs_path = system.absolute_path(path)
    local info = abs_path and system.get_file_info(abs_path)
    if not info or info.type ~= 'dir' then
      return nil
    end
    return abs_path
end

local function open_file(use_dialog)
  local view = core.active_view
  local default_text
  if view and view.doc and view.doc.abs_filename then
    local dirname, _ = view.doc.abs_filename:match("(.*)[/\\](.+)$")
    if dirname then
      if use_dialog then
        default_text = dirname
      else
        dirname = core.normalize_to_project_dir(dirname)
        default_text = dirname == core.root_project().path and "" or common.home_encode(dirname) .. PATHSEP
      end
    end
  end

  if use_dialog then
    core.open_file_dialog(core.window, function(status, result)
      if status == "accept" then
      	for _, filename in ipairs(result --[[ @as string[] ]]) do
          local info = system.get_file_info(filename)
          if info and info.type == "dir" then
            core.confirm_close_docs(core.docs, function(dirpath)
              core.open_project(dirpath)
            end, filename)
          else
            core.root_view:open_doc(core.open_doc(filename))
          end
      	end
      elseif status == "error" then
        core.error("Error while opening dialog: %s", result or "")
      end
    end, {
      default_location = default_text,
      allow_many = true,
    })
  	return
  end

  core.command_view:enter("Open File", {
    text = default_text,
    submit = function(text)
      local filename = core.project_absolute_path(common.home_expand(text))
      local info = system.get_file_info(filename)
      if info and info.type == "dir" then
        core.confirm_close_docs(core.docs, function(dirpath)
          core.open_project(dirpath)
        end, filename)
      else
        core.root_view:open_doc(core.open_doc(filename))
      end
    end,
    suggest = function (text)
      return common.home_encode_list(common.path_suggest(common.home_expand(text), core.root_project() and core.root_project().path))
    end,
    validate = function(text)
        local filename = core.project_absolute_path(common.home_expand(text))
        local path_stat, err = system.get_file_info(filename)
        if err then
          if err:find("No such file", 1, true) then
            -- check if the containing directory exists
            local dirname = common.dirname(filename)
            local dir_stat = dirname and system.get_file_info(dirname)
            if not dirname or (dir_stat and dir_stat.type == 'dir') then
              return true
            end
          end
          core.error("Cannot open file %s: %s", text, err)
        elseif --[[@cast path_stat -nil]] path_stat.type == 'dir' then
          -- TODO: remove the above cast once https://github.com/LuaLS/lua-language-server/discussions/3102 is implemented.
          return true
        else
          return true
        end
      end,
  })
end

local function open_folder_commandview(label, callback)
  local home = os.getenv("HOME") or "/"
  core.command_view:enter(label, {
    text = common.home_encode(home) .. PATHSEP,
    submit = function(input_text)
      local path = common.home_expand(input_text)
      local abs_path = system.absolute_path(path) or path
      local info = abs_path and system.get_file_info(abs_path)
      if not info then
        core.error("Path does not exist: %q", input_text)
        return
      end
      if info.type ~= "dir" then
        abs_path = common.dirname(abs_path)
      end
      if abs_path then
        callback({abs_path})
      end
    end,
    suggest = function(text)
      text = common.home_expand(text)
      return common.home_encode_list(common.dir_path_suggest(text))
    end
  })
end

local function open_directory(label, use_dialog, allow_many, callback)
  local home = os.getenv("HOME") or "/"

  if use_dialog then
    core.open_directory_dialog(core.window, function(status, result)
      if status == "accept" and result and #result > 0 then
        callback(result)
      else
        -- Native dialog cancelled or failed on platform: fallback to Command View selector
        core.log("Opening folder selector...")
        open_folder_commandview(label, callback)
      end
    end, {
      default_location = home,
      allow_many = allow_many,
      title = label,
    })
    return
  end

  open_folder_commandview(label, callback)
end

local function handle_open_folder(abs_path)
  if not abs_path or #abs_path == 0 then return end
  local target = abs_path[1]
  if not target then return end
  local info = system.get_file_info(target)
  if info and info.type ~= "dir" then
    target = common.dirname(target)
  end
  if not target then return end
  local root = core.root_project()
  if root and not core.empty_project and target == root.path then
    core.log("Folder %q is already open", target)
    return
  end
  core.confirm_close_docs(core.docs, function(dirpath)
    core.open_project(dirpath)
  end, target)
end

local function change_project_directory(use_dialog)
  open_directory("Change Project Folder", use_dialog, false, handle_open_folder)
end

local function open_project_directory(use_dialog)
  open_directory("Open Project Folder", use_dialog, false, handle_open_folder)
end

local function add_project_directory(use_dialog)
  open_directory("Add Directory", use_dialog, true, function(abs_path)
    for _, dir in ipairs(abs_path) do
      print(dir)
      core.add_project(system.absolute_path(dir))
    end
  end)
end

command.add(nil, {
  ["core:quit"] = function()
    core.quit()
  end,

  ["core:restart"] = function()
    core.restart()
  end,

  ["core:force-quit"] = function()
    core.quit(true)
  end,

  ["core:toggle-fullscreen"] = function()
    fullscreen = not fullscreen
    if fullscreen then
      restore_title_view = core.title_view.visible
    end
    system.set_window_mode(core.window, fullscreen and "fullscreen" or "normal")
    core.show_title_bar(not fullscreen and restore_title_view)
    core.title_view:configure_hit_test(not fullscreen and restore_title_view)
  end,

  ["core:reload-module"] = function()
    core.command_view:enter("Reload Module", {
      submit = function(text, item)
        text = item and item.text or text
        core.reload_module(text)
        core.log("Reloaded module %q", text)
      end,
      suggest = function(text)
        local items = {}
        for name in pairs(package.loaded) do
          table.insert(items, name)
        end
        return common.fuzzy_match(items, text)
      end
    })
  end,

  ["core:find-command"] = function()
    local commands = command.get_all_valid()
    core.command_view:enter("Do Command", {
      submit = function(text, item)
        if item then
          command.perform(item.command)
        end
      end,
      suggest = function(text)
        local res = {}
        local matched = common.fuzzy_match(commands, text)
        for i, name in ipairs(matched) do
          res[i] = {
            text = command.prettify_name(name),
            info = keymap.get_binding(name),
            command = name,
          }
        end
        return res
      end
    })
  end,

  ["core:new-doc"] = function()
    core.root_view:open_doc(core.open_doc())
  end,

  ["core:new-named-doc"] = function()
    core.command_view:enter("File name", {
      submit = function(text)
        core.root_view:open_doc(core.open_doc(text))
      end
    })
  end,

  ["core:open-file"] = function()
    open_file(config.use_system_file_picker)
  end,

  ["core:open-file-picker"] = function()
    open_file(true)
  end,

  ["core:open-file-commandview"] = function()
    open_file(false)
  end,

  ["core:open-log"] = function()
    local node = core.root_view:get_active_node_default()
    node:add_view(LogView())
  end,

  ["core:open-user-module"] = function()
    local user_module_doc = core.open_doc(USERDIR .. "/init.lua")
    if not user_module_doc then return end
    core.root_view:open_doc(user_module_doc)
  end,

  ["core:open-project-module"] = function()
    if not system.get_file_info(".lite_project.lua") then
      core.try(core.write_init_project_module, ".lite_project.lua")
    end
    local doc = core.open_doc(".lite_project.lua")
    core.root_view:open_doc(doc)
    doc:save()
  end,

  ["core:change-project-folder"] = function()
    change_project_directory(config.use_system_file_picker)
  end,

  ["core:change-project-folder-picker"] = function()
    change_project_directory(true)
  end,

  ["core:change-project-folder-commandview"] = function()
    change_project_directory(false)
  end,

  ["core:open-project-folder"] = function()
    open_project_directory(config.use_system_file_picker)
  end,

  ["core:open-project-folder-picker"] = function()
    open_project_directory(true)
  end,

  ["core:open-project-folder-commandview"] = function()
    open_project_directory(false)
  end,

  ["core:add-directory"] = function()
    add_project_directory(config.use_system_file_picker)
  end,

  ["core:add-directory-picker"] = function()
    add_project_directory(true)
  end,

  ["core:add-directory-commandview"] = function()
    add_project_directory(false)
  end,

  ["core:remove-directory"] = function()
    local dir_list = {}
    local n = #core.projects
    for i = n, 2, -1 do
      dir_list[n - i + 1] = core.projects[i].name
    end
    core.command_view:enter("Remove Directory", {
      submit = function(text, item)
        text = common.home_expand(item and item.text or text)
        if not core.remove_project(text) then
          core.error("No directory %q to be removed", text)
        end
      end,
      suggest = function(text)
        text = common.home_expand(text)
        return common.home_encode_list(common.dir_list_suggest(text, dir_list))
      end
    })
  end,

  ["core:clone-repository"] = function()
    core.command_view:enter("Git Repository URL (e.g. https://github.com/user/repo.git)", {
      submit = function(url)
        if not url or url:match("^%s*$") then return end
        url = url:gsub("^%s*", ""):gsub("%s*$", "")
        local repo_name = url:match("([^/]+)%.git$") or url:match("([^/]+)$") or "cloned-repo"
        repo_name = repo_name:gsub("[^%w_%-%.]", "")

        local default_dir = system.absolute_path(".")
        if core.root_project() and core.root_project().path then
          default_dir = common.dirname(core.root_project().path) or default_dir
        end

        core.open_directory_dialog(core.window, function(status, result)
          local target_parent = (status == "accept" and result and result[1]) or default_dir
          local target_dir = target_parent .. PATHSEP .. repo_name
          core.log("Cloning repository %s into %s...", url, target_dir)

          core.add_thread(function()
            local proc = process.start({"git", "clone", url, target_dir})
            local exit_code = proc:wait()
            if exit_code == 0 then
              core.log("Successfully cloned %s to %s", url, target_dir)
              system.exec(string.format("%q %q", EXEFILE, target_dir))
            else
              local err_output = proc.stderr and proc.stderr:read("all") or "Git clone failed"
              core.error("Git clone failed (exit code %d): %s", exit_code, err_output)
            end
          end)
        end, {
          title = "Select Destination Folder for Cloned Repository",
          default_location = default_dir,
        })
      end
    })
  end,

  ["core:open-in-system-file-manager"] = function()
    local path
    if core.active_view and core.active_view.doc and core.active_view.doc.abs_filename then
      path = common.dirname(core.active_view.doc.abs_filename)
    elseif core.root_project() then
      path = core.root_project().path
    end
    if path then
      if PLATFORM == "Windows" then
        system.exec(string.format("explorer %q", path))
      elseif PLATFORM == "Mac OS X" then
        system.exec(string.format("open %q", path))
      else
        system.exec(string.format("xdg-open %q", path))
      end
    end
  end,
})
