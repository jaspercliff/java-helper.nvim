local Config = require("java-helper.config")
local CreateClass = require("java-helper.actions.create_class")

local M = {}

---@param opts JavaHelperConfig|nil
function M.setup(opts)
	local config = vim.tbl_extend("force", Config.defaults, opts or {})

	vim.api.nvim_create_user_command(config.create_class_command, function()
		CreateClass.create_class(config)
	end, { desc = "在当前目录创建 Java 类（自动包名与类骨架）" })
end

return M
