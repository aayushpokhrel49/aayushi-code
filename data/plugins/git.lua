-- mod-version:4
-- Built-in git integration for Aayushi Code editor.
-- Provides: status panel, commit, push, pull, branch, log, stage/unstage, diff.
local core = require "core"
local common = require "core.common"
local config = require "core.config"
local command = require "core.command"
local keymap = require "core.keymap"
local style = require "core.style"
local View = require "core.view"


config.plugins.git = common.merge({
  auto_fetch_interval = 30,
  show_statusbar = true,
}, config.plugins.git or {})

local M = {}

local git_status = { branch = "", files = {}, ahead = 0, behind = 0, dirty = false }
local refresh_timer = 0
local is_in_repo = false
local git_view = nil

--- Run a git command in the project root and return stdout.
---@param args string[]
---@return string
---@return number
function M.git_cmd(args)
  local root = core.root_project()
  if not root then return "", 1 end
  local proc = process.start({"git", "-C", root.path, table.unpack(args)})
  if not proc then return "", 1 end
  local stdout = ""
  while proc:running() do
    coroutine.yield(0.05)
  end
  stdout = proc:read_stdout() or ""
  return stdout, proc:returncode()
end

--- Check if the current project is a git repository.
function M.check_repo()
  local root = core.root_project()
  if not root then
    is_in_repo = false
    return false
  end
  local _, rc = M.git_cmd({"rev-parse", "--is-inside-work-tree"})
  is_in_repo = (rc == 0)
  return is_in_repo
end

--- Refresh the git status (branch, file changes, ahead/behind).
function M.refresh_status()
  if not M.check_repo() then
    git_status.branch = ""
    git_status.files = {}
    git_status.ahead = 0
    git_status.behind = 0
    git_status.dirty = false
    return
  end

  local branch_out = M.git_cmd({"branch", "--show-current"})
  git_status.branch = branch_out:gsub("^%s+", ""):gsub("%s+$", "")

  local status_out = M.git_cmd({"status", "--porcelain=v1"})
  local files = {}
  for line in status_out:gmatch("[^\n]+") do
    local index_status = line:sub(1, 1)
    local work_status = line:sub(2, 2)
    local filepath = line:sub(4)
    local status = "modified"
    if index_status == "A" or work_status == "A" then
      status = "added"
    elseif index_status == "D" or work_status == "D" then
      status = "deleted"
    elseif index_status == "?" and work_status == "?" then
      status = "untracked"
    elseif index_status == "R" or work_status == "R" then
      status = "renamed"
    end
    files[#files + 1] = { path = filepath, status = status }
  end
  git_status.files = files
  git_status.dirty = #files > 0

  if git_status.branch ~= "" then
    local tracking = M.git_cmd({"rev-parse", "--abbrev-ref", "HEAD@{upstream}"})
    tracking = tracking:gsub("^%s+", ""):gsub("%s+$", "")
    if tracking ~= "" then
      local range = "HEAD..."..tracking
      local counts = M.git_cmd({"rev-list", "--left-right", "--count", range})
      local ahead_s, behind_s = counts:match("(%d+)%s+(%d+)")
      git_status.ahead = tonumber(ahead_s) or 0
      git_status.behind = tonumber(behind_s) or 0
    else
      git_status.ahead = 0
      git_status.behind = 0
    end
  end
end

function M.get_status()
  return git_status
end


---------------------------------------------------------------------------
-- GitStatusView: a sidebar panel showing changed files
---------------------------------------------------------------------------
local GitStatusView = View:extend()

function GitStatusView:__tostring() return "GitStatusView" end

function GitStatusView:new()
  GitStatusView.super.new(self)
  self.scrollable = true
  self.visible = true
  self.target_size = 250 * SCALE
  self.selected_idx = 0
  self.hovered_idx = 0
  self.header_height = style.font:get_height() + style.padding.y * 2
end

function GitStatusView:set_target_size(axis, value)
  if axis == "x" then
    self.target_size = value
    return true
  end
end

function GitStatusView:get_item_count()
  return #git_status.files + (is_in_repo and 1 or 0)
end

function GitStatusView:get_item_height()
  return style.font:get_height() + style.padding.y
end

function GitStatusView:on_mouse_moved(x, y, ...)
  GitStatusView.super.on_mouse_moved(self, x, y, ...)
  local idx = self:get_item_at(y)
  self.hovered_idx = idx
end

function GitStatusView:get_item_at(y)
  local top = self.header_height
  local h = self:get_item_height()
  if y < top or not is_in_repo then return 0 end
  local idx = math.floor((y - top) / h) + 1
  if idx > #git_status.files then return 0 end
  return idx
end

function GitStatusView:on_mouse_pressed(button, x, y, clicks)
  if button == "left" then
    local idx = self:get_item_at(y)
    if idx > 0 and git_status.files[idx] then
      self.selected_idx = idx
      local root = core.root_project()
      if root then
        local full = root.path .. PATHSEP .. git_status.files[idx].path
        local _, doc = core.open_doc(full)
        if doc then
          core.root_view:open_doc(doc)
        end
      end
    end
  end
  return GitStatusView.super.on_mouse_pressed(self, button, x, y, clicks)
end

function GitStatusView:draw()
  self:draw_background(style.background)

  if not is_in_repo then
    local text = "Not a git repository"
    local tw = style.font:get_width(text)
    local tx = (self.size.x - tw) / 2
    local ty = (self.size.y - style.font:get_height()) / 2
    renderer.draw_text(style.font, text, tx, ty, style.dim)
    return
  end

  local y = style.padding.y

  local branch_text = "Branch: " .. (git_status.branch or "detached")
  renderer.draw_text(style.font, branch_text, style.padding.x, y, style.accent)
  y = y + style.font:get_height() + style.padding.y

  local summary = string.format(
    "%d change%s%s",
    #git_status.files,
    #git_status.files == 1 and "" or "s",
    git_status.ahead > 0 and string.format(" (%d ahead)", git_status.ahead) or ""
  )
  renderer.draw_text(style.font, summary, style.padding.x, y, style.dim)
  y = y + style.font:get_height() + style.padding.y

  local divider_y = y
  renderer.draw_rect(style.padding.x, divider_y, self.size.x - style.padding.x * 2, style.divider_size, style.divider)
  y = y + style.padding.y

  if #git_status.files == 0 then
    local no_changes = "No changes"
    local nw = style.font:get_width(no_changes)
    local nx = (self.size.x - nw) / 2
    renderer.draw_text(style.font, no_changes, nx, y + style.padding.y, style.dim)
    return
  end

  local h = self:get_item_height()
  local visible_start = math.floor(self.scroll.y / h)
  local visible_end = math.min(#git_status.files, visible_start + math.ceil(self.size.y / h) + 1)

  local status_colors = {
    added = style.gitdiff_addition or { common.color "#4ec9b0" },
    modified = style.gitdiff_modification or { common.color "#dcdcaa" },
    deleted = style.gitdiff_deletion or { common.color "#f44747" },
    renamed = style.gitdiff_modification or { common.color "#569cd6" },
    untracked = style.dim,
  }

  local status_labels = {
    added = "A",
    modified = "M",
    deleted = "D",
    renamed = "R",
    untracked = "?",
  }

  for i = visible_start + 1, visible_end do
    local file = git_status.files[i]
    local iy = y + (i - 1 - visible_start) * h
    local is_hovered = (i == self.hovered_idx)
    local is_selected = (i == self.selected_idx)

    if is_hovered or is_selected then
      renderer.draw_rect(style.padding.x, iy, self.size.x - style.padding.x * 2, h, style.selection or style.accent)
    end

    local color = status_colors[file.status] or style.text
    local label = status_labels[file.status] or "M"
    renderer.draw_text(style.code_font, label, style.padding.x + 4, iy + (h - style.code_font:get_height()) / 2, color)

    local path = file.path
    if #path > 40 then
      path = "..." .. path:sub(-37)
    end
    renderer.draw_text(style.font, path, style.padding.x + style.code_font:get_width("M") + 12, iy + (h - style.font:get_height()) / 2, style.text)
  end

  self.scroll.y = common.clamp(self.scroll.y, 0, math.max(0, #git_status.files * h - self.size.y + self.header_height))
end

function GitStatusView:get_scrollable_size()
  return self.header_height + #git_status.files * self:get_item_height() + style.padding.y
end

function GitStatusView:try_close()
  return false
end

function GitStatusView:set_visible(visible)
  self.visible = visible
end


---------------------------------------------------------------------------
-- Git commands
---------------------------------------------------------------------------

command.add(nil, {
  ["git:refresh"] = function()
    if not is_in_repo then return end
    M.refresh_status()
    core.log("Git status refreshed")
  end,

  ["git:toggle-panel"] = function()
    if not git_view then return end
    git_view.visible = not git_view.visible
    core.redraw = true
  end,

  ["git:commit"] = function()
    if not is_in_repo then
      core.warn("Not a git repository")
      return
    end
    core.command_view:enter("Commit message", {
      submit = function(message)
        if not message or message:match("^%s*$") then
          core.warn("Commit message cannot be empty")
          return
        end
        core.add_thread(function()
          M.git_cmd({"add", "-A"})
          local _, rc = M.git_cmd({"commit", "-m", message})
          if rc == 0 then
            core.log("Committed: %s", message)
            M.refresh_status()
          else
            core.error("Git commit failed")
          end
        end)
      end
    })
  end,

  ["git:commit-amend"] = function()
    if not is_in_repo then
      core.warn("Not a git repository")
      return
    end
    core.command_view:enter("Amend with message (empty to keep original)", {
      submit = function(message)
        core.add_thread(function()
          M.git_cmd({"add", "-A"})
          local args = {"commit", "--amend"}
          if message and not message:match("^%s*$") then
            args[#args + 1] = "-m"
            args[#args + 1] = message
          else
            args[#args + 1] = "--no-edit"
          end
          local _, rc = M.git_cmd(args)
          if rc == 0 then
            core.log("Amended last commit")
            M.refresh_status()
          else
            core.error("Git amend failed")
          end
        end)
      end
    })
  end,

  ["git:push"] = function()
    if not is_in_repo then return end
    core.add_thread(function()
      core.log("Pushing to origin...")
      local out, rc = M.git_cmd({"push"})
      if rc == 0 then
        core.log("Pushed successfully")
        M.refresh_status()
      else
        core.error("Git push failed: %s", out)
      end
    end)
  end,

  ["git:push-force"] = function()
    if not is_in_repo then return end
    core.add_thread(function()
      core.log("Force pushing to origin...")
      local out, rc = M.git_cmd({"push", "--force-with-lease"})
      if rc == 0 then
        core.log("Force pushed successfully")
        M.refresh_status()
      else
        core.error("Git force push failed: %s", out)
      end
    end)
  end,

  ["git:pull"] = function()
    if not is_in_repo then return end
    core.add_thread(function()
      core.log("Pulling from origin...")
      local out, rc = M.git_cmd({"pull", "--rebase"})
      if rc == 0 then
        core.log("Pulled successfully")
        M.refresh_status()
      else
        core.error("Git pull failed: %s", out)
      end
    end)
  end,

  ["git:fetch"] = function()
    if not is_in_repo then return end
    core.add_thread(function()
      core.log("Fetching from origin...")
      local _, rc = M.git_cmd({"fetch", "--all", "--prune"})
      if rc == 0 then
        core.log("Fetched successfully")
        M.refresh_status()
      else
        core.error("Git fetch failed")
      end
    end)
  end,

  ["git:branch-create"] = function()
    if not is_in_repo then return end
    core.command_view:enter("New branch name", {
      submit = function(name)
        if not name or name:match("^%s*$") then return end
        core.add_thread(function()
          local _, rc = M.git_cmd({"checkout", "-b", name})
          if rc == 0 then
            core.log("Created and switched to branch: %s", name)
            M.refresh_status()
          else
            core.error("Failed to create branch: %s", name)
          end
        end)
      end
    })
  end,

  ["git:branch-switch"] = function()
    if not is_in_repo then return end
    local branches_out = M.git_cmd({"branch", "--format=%(refname:short)"})
    local branches = {}
    for b in branches_out:gmatch("[^\n]+") do
      branches[#branches + 1] = b
    end
    if #branches == 0 then
      core.warn("No branches found")
      return
    end
    core.command_view:enter("Switch to branch", {
      submit = function(name)
        if not name or name:match("^%s*$") then return end
        core.add_thread(function()
          local _, rc = M.git_cmd({"checkout", name})
          if rc == 0 then
            core.log("Switched to branch: %s", name)
            M.refresh_status()
          else
            core.error("Failed to switch to branch: %s", name)
          end
        end)
      end,
      suggest = function(text)
        local items = {}
        for _, b in ipairs(branches) do
          if b:find(text, 1, true) then
            items[#items + 1] = b
          end
        end
        return items
      end
    })
  end,

  ["git:branch-delete"] = function()
    if not is_in_repo then return end
    local branches_out = M.git_cmd({"branch", "--format=%(refname:short)"})
    local branches = {}
    for b in branches_out:gmatch("[^\n]+") do
      if b ~= git_status.branch then
        branches[#branches + 1] = b
      end
    end
    if #branches == 0 then
      core.warn("No other branches to delete")
      return
    end
    core.command_view:enter("Delete branch", {
      submit = function(name)
        if not name or name:match("^%s*$") then return end
        core.add_thread(function()
          local _, rc = M.git_cmd({"branch", "-D", name})
          if rc == 0 then
            core.log("Deleted branch: %s", name)
            M.refresh_status()
          else
            core.error("Failed to delete branch: %s", name)
          end
        end)
      end,
      suggest = function(text)
        local items = {}
        for _, b in ipairs(branches) do
          if b:find(text, 1, true) then
            items[#items + 1] = b
          end
        end
        return items
      end
    })
  end,

  ["git:stage-all"] = function()
    if not is_in_repo then return end
    core.add_thread(function()
      M.git_cmd({"add", "-A"})
      core.log("Staged all changes")
      M.refresh_status()
    end)
  end,

  ["git:unstage-all"] = function()
    if not is_in_repo then return end
    core.add_thread(function()
      M.git_cmd({"reset", "HEAD"})
      core.log("Unstaged all changes")
      M.refresh_status()
    end)
  end,

  ["git:discard-changes"] = function()
    if not is_in_repo then return end
    core.add_thread(function()
      M.git_cmd({"checkout", "."})
      M.git_cmd({"clean", "-fd"})
      core.log("Discarded all changes")
      M.refresh_status()
    end)
  end,

  ["git:diff-current"] = function()
    if not is_in_repo then return end
    local doc = core.active_view and core.active_view.doc
    if not doc or not doc.abs_filename then
      core.warn("No active document")
      return
    end
    local root = core.root_project()
    local rel = root and doc.abs_filename:sub(#root.path + 2) or doc.abs_filename
    core.add_thread(function()
      local out = M.git_cmd({"diff", "HEAD", "--", rel})
      if out == "" then
        out = M.git_cmd({"diff", "--cached", "--", rel})
      end
      if out == "" then
        core.log("No diff for %s", rel)
        return
      end
      local diff_doc = core.open_doc(nil)
      diff_doc:set_text(out)
      diff_doc.abs_filename = nil
      diff_doc:assert_modify()
      core.root_view:open_doc(diff_doc)
      core.log("Showing diff for %s", rel)
    end)
  end,

  ["git:log"] = function()
    if not is_in_repo then return end
    core.add_thread(function()
      local out = M.git_cmd({"log", "--oneline", "-20"})
      if out == "" then
        core.warn("No git log available")
        return
      end
      local log_doc = core.open_doc(nil)
      log_doc:set_text(out)
      log_doc.abs_filename = nil
      log_doc:assert_modify()
      core.root_view:open_doc(log_doc)
      core.log("Showing git log (last 20 commits)")
    end)
  end,

  ["git:stash"] = function()
    if not is_in_repo then return end
    core.add_thread(function()
      local _, rc = M.git_cmd({"stash"})
      if rc == 0 then
        core.log("Changes stashed")
        M.refresh_status()
      end
    end)
  end,

  ["git:stash-pop"] = function()
    if not is_in_repo then return end
    core.add_thread(function()
      local _, rc = M.git_cmd({"stash", "pop"})
      if rc == 0 then
        core.log("Stash applied")
        M.refresh_status()
      else
        core.error("Failed to pop stash")
      end
    end)
  end,

  ["git:blame-current"] = function()
    if not is_in_repo then return end
    local doc = core.active_view and core.active_view.doc
    if not doc or not doc.abs_filename then
      core.warn("No active document")
      return
    end
    local root = core.root_project()
    local rel = root and doc.abs_filename:sub(#root.path + 2) or doc.abs_filename
    core.add_thread(function()
      local out = M.git_cmd({"blame", "--line-porcelain", rel})
      if out == "" then
        core.warn("No blame data for %s", rel)
        return
      end
      local blame_lines = {}
      for line in out:gmatch("[^\n]+") do
        if line:match("^author ") then
          blame_lines[#blame_lines + 1] = line:sub(8)
        end
      end
      if #blame_lines == 0 then
        core.warn("No blame data for %s", rel)
        return
      end
      local blame_doc = core.open_doc(nil)
      blame_doc:set_text(table.concat(blame_lines, "\n"))
      blame_doc.abs_filename = nil
      blame_doc:assert_modify()
      core.root_view:open_doc(blame_doc)
      core.log("Showing blame for %s", rel)
    end)
  end,
})


---------------------------------------------------------------------------
-- Statusbar item
---------------------------------------------------------------------------
if config.plugins.git.show_statusbar then
  core.status_view:add_item({
    name = "git:branch",
    alignment = "left",
    position = 1,
    get_item = function()
      if not is_in_repo then return {} end
      local text = git_status.branch or ""
      if git_status.dirty then
        text = text .. " *"
      end
      if git_status.ahead > 0 then
        text = text .. string.format(" ^%d", git_status.ahead)
      end
      return {
        style.font, style.accent, text,
        style.font, style.text, string.format("  %d~", #git_status.files),
      }
    end,
    command = "git:toggle-panel",
    tooltip = "Git: Click to toggle Source Control panel",
    predicate = function()
      return is_in_repo
    end,
  })
end


---------------------------------------------------------------------------
-- Keymaps
---------------------------------------------------------------------------
keymap.add {
  ["ctrl+shift+g"] = "git:toggle-panel",
  ["ctrl+shift+c"] = "git:commit",
  ["ctrl+shift+p"] = "git:push",
  ["ctrl+shift+l"] = "git:log",
}


---------------------------------------------------------------------------
-- Initialization
---------------------------------------------------------------------------
local function init_git_view()
  git_view = GitStatusView()
  local active_node = core.root_view:get_active_node()
  local tree_node = nil

  for _, child in ipairs({active_node.a, active_node.b}) do
    if child and child.type == "leaf" then
      for _, v in ipairs(child.views) do
        if v and v.__tostring and v:__tostring() == "TreeView" then
          tree_node = child
          break
        end
      end
    end
    if tree_node then break end
  end

  if tree_node then
    tree_node:add_view(git_view)
  else
    local node = core.root_view:get_active_node()
    node:split("left", git_view, {x = true}, true)
  end

  git_view.visible = false
end

core.add_thread(function()
  while not core.root_view do
    coroutine.yield(0.5)
  end
  coroutine.yield(0.5)
  init_git_view()

  M.refresh_status()
  if git_view then
    git_view.visible = true
  end

  while true do
    coroutine.yield(config.plugins.git.auto_fetch_interval)
    if is_in_repo then
      M.refresh_status()
    end
  end
end)

return M
