local SnacksState = require("java-helper.snacks")
local CreateClass = require("java-helper.actions.create_class")
local Config = require("java-helper.config")

local M = {}

---@class JavaHelperSnacksExplorerOpts
---@field key? string 默认按键（list window）

---@param user_config? JavaHelperConfig
---@param opts? JavaHelperSnacksExplorerOpts
---@return table explorer_source_patch 直接合并到 `Snacks` 的 `picker.sources.explorer`
function M.patch(user_config, opts)
	opts = opts or {}
	local key = opts.key or "N"
	local config = vim.tbl_extend("force", Config.defaults, user_config or {})

	return {
		actions = {
			java_create = function(picker, item)
				local dir = SnacksState.dir_from_item(item) or (picker and picker.dir and picker:dir()) or nil
				if dir then
					SnacksState.set_last_dir(dir)
					-- 触发一次 focused_explorer_dir 会顺便写 last_dir
					-- 但这里我们直接走 item 更准确
					CreateClass.create_class(config, { target_dir = dir })
				else
					CreateClass.create_class(config)
				end
			end,
		},
		win = {
			list = {
				keys = {
					[key] = "java_create",
				},
			},
		},
	}
end

return M
