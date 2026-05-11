local M = {}

---@param config JavaHelperConfig
function M.go_to_test(config)
	local current_file = vim.api.nvim_buf_get_name(0)

	if not current_file:match("%.java$") then
		vim.notify("当前文件不是 Java 文件", vim.log.levels.WARN, { title = "Java Helper" })
		return
	end

	local is_main = current_file:find("/src/main/java/", 1, true)
	local is_test = current_file:find("/src/test/java/", 1, true)

	if not is_main and not is_test then
		vim.notify("当前文件不在 src/main/java 或 src/test/java 目录下", vim.log.levels.WARN, { title = "Java Helper" })
		return
	end

	local target_file
	if is_main then
		-- src/main/java/.../X.java -> src/test/java/.../XTest.java
		target_file = current_file:gsub("/src/main/java/", "/src/test/java/")
		target_file = target_file:gsub("%.java$", "Test.java")
	else
		-- src/test/java/.../XTest.java -> src/main/java/.../X.java
		target_file = current_file:gsub("/src/test/java/", "/src/main/java/")
		target_file = target_file:gsub("Test%.java$", ".java")
	end

	if target_file == current_file then
		vim.notify("无法确定目标文件路径", vim.log.levels.ERROR, { title = "Java Helper" })
		return
	end

	-- 确保目标目录存在
	local target_dir = vim.fn.fnamemodify(target_file, ":h")
	if vim.fn.isdirectory(target_dir) == 0 then
		vim.fn.mkdir(target_dir, "p")
	end

	-- 直接打开目标文件
	vim.cmd("edit " .. vim.fn.fnameescape(target_file))
end

return M
