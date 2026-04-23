local SnacksState = require("java-helper.snacks")
local CreateClass = require("java-helper.actions.create_class")
local InitProject = require("java-helper.actions.init_project")
local Config = require("java-helper.config")

local M = {}

---@class JavaHelperSnacksExplorerOpts
---@field key? string 创建 Java 类的按键（list window），默认 "N"
---@field init_key? string 初始化项目目录结构的按键（list window），默认 "M"

---@param user_config? JavaHelperConfig  已废弃，保留用于向后兼容；优先使用 setup() 里存储的 config
---@param opts? JavaHelperSnacksExplorerOpts
---@return table explorer_source_patch 直接合并到 `Snacks` 的 `picker.sources.explorer`
function M.patch(user_config, opts)
	opts = opts or {}
	local key = opts.key or "N"
	local init_key = opts.init_key or "M"

	return {
		actions = {
			java_create = function(picker, item)
				-- 每次触发时从 Config.get() 读取最新 config，确保 sub_package 等已生效
				local config = vim.tbl_extend("force", Config.get(), user_config or {})
				local dir = SnacksState.dir_from_item(item) or (picker and picker.dir and picker:dir()) or nil
				if dir then
					SnacksState.set_last_dir(dir)
					CreateClass.create_class(config, { target_dir = dir })
				else
					CreateClass.create_class(config)
				end
			end,
			java_init_project = function(picker, item)
				local config = vim.tbl_extend("force", Config.get(), user_config or {})
				local dir = SnacksState.dir_from_item(item) or (picker and picker.dir and picker:dir()) or nil
				if dir then
					SnacksState.set_last_dir(dir)
					InitProject.init_project(config, { target_dir = dir })
				else
					InitProject.init_project(config)
				end
			end,
		},
		win = {
			list = {
				keys = {
					[key] = "java_create",
					[init_key] = "java_init_project",
				},
			},
		},
	}
end

return M
