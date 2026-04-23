local Config = require("java-helper.config")
local CreateClass = require("java-helper.actions.create_class")
local InitProject = require("java-helper.actions.init_project")

local M = {}

---@param opts JavaHelperConfig|nil
function M.setup(opts)
	local config = vim.tbl_extend("force", Config.defaults, opts or {})
	Config.set(config) -- 存储供 snacks 等其他入口使用

	vim.api.nvim_create_user_command(config.create_class_command, function()
		CreateClass.create_class(config)
	end, { desc = "在当前目录创建 Java 类（自动包名与类骨架）" })

	vim.api.nvim_create_user_command(config.init_project_command, function()
		InitProject.init_project(config)
	end, { desc = "在当前目录初始化 Maven 标准目录结构（src/main/java, src/test/java）" })
end

return M
