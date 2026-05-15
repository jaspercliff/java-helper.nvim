local Config = require("java-helper.config")
local CreateClass = require("java-helper.actions.create_class")
local InitProject = require("java-helper.actions.init_project")
local GoToTest = require("java-helper.actions.go_to_test")
local GoToMapper = require("java-helper.actions.go_to_mapper")

local M = {}

---@param opts JavaHelperConfig|nil
function M.setup(opts)
	-- 将多个table合并为一个table  force 后面覆盖前面的  keep 保留前面的 error 报错
	-- opt 为nil 则使用{}
	local config = vim.tbl_extend("force", Config.defaults, opts or {})
	Config.set(config) -- 存储供 snacks 等其他入口使用

	vim.api.nvim_create_user_command(config.create_class_command, function()
		CreateClass.create_class(config)
	end, { desc = "在当前目录创建 Java 类（自动包名与类骨架）" })

	if config.init_project_command then
		vim.api.nvim_create_user_command(config.init_project_command, function()
			InitProject.init_project(config)
		end, { desc = "在当前目录初始化 Maven 标准目录结构（src/main/java, src/test/java）" })
	end

	if config.go_to_test_command then
		vim.api.nvim_create_user_command(config.go_to_test_command, function()
			GoToTest.go_to_test(config)
		end, { desc = "在源文件和对应的测试文件之间跳转" })
	end

	if config.go_to_mapper_command then
		vim.api.nvim_create_user_command(config.go_to_mapper_command, function()
			GoToMapper.go_to_mapper(config)
		end, { desc = "在 Java 接口和对应的 Mapper XML 之间跳转" })
	end

	if config.mapper_hover_command then
		vim.api.nvim_create_user_command(config.mapper_hover_command, function()
			GoToMapper.mapper_hover(config)
		end, { desc = "悬浮显示 Java 方法对应的 Mapper XML SQL 语句" })
	end

	if config.auto_hover_mapper then
		local group = vim.api.nvim_create_augroup("JavaHelperAutoHover", { clear = true })
		vim.api.nvim_create_autocmd("CursorHold", {
			group = group,
			pattern = "*.java",
			callback = function()
				GoToMapper.mapper_hover(config, true)
			end,
			desc = "自动悬浮显示 Java Mapper 对应的 SQL",
		})
	end
end

return M
