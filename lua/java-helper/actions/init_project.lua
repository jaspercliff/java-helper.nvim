local M = {}

--- 将点分包名转换为相对路径，例如 "com.jasper" -> "com/jasper"
---@param pkg string 点分包名，可为空字符串
---@return string 相对路径（无前后斜杠）
local function pkg_to_path(pkg)
	if pkg == nil or pkg == "" then
		return ""
	end
	return pkg:gsub("%.", "/")
end

--- 在 root 下新建名为 project_name 的子目录，并初始化 Maven 标准目录结构：
---   src/main/java[/<sub_pkg>]
---   src/main/resources
---   src/test/java[/<sub_pkg>]
---   src/test/resources
--- 同时生成 build.gradle.kts，并向上查找 settings.gradle.kts 追加 include
---@param config JavaHelperConfig
---@param opts? {target_dir?: string}
function M.init_project(config, opts)
	opts = opts or {}

	-- DEBUG: 打印收到的 config，确认 sub_package 是否正确传入
	--vim.notify("[java-helper DEBUG] sub_package = " .. tostring(config.sub_package), vim.log.levels.WARN)

	local parent_dir
	if opts.target_dir then
		parent_dir = vim.fn.fnamemodify(opts.target_dir, ":p"):gsub("/$", "")
	else
		local TargetDir = require("java-helper.target_dir")
		parent_dir = vim.fn.fnamemodify(TargetDir.default_target_dir(), ":p"):gsub("/$", "")
	end

	vim.ui.input({ prompt = "项目名: " }, function(project_name)
		if project_name == nil or vim.trim(project_name) == "" then
			return
		end
		project_name = vim.trim(project_name)

		local root = parent_dir .. "/" .. project_name

		if vim.fn.isdirectory(root) == 1 then
			vim.notify("目录已存在: " .. root, vim.log.levels.ERROR)
			return
		end

		local sub_pkg = config.sub_package or ""
		local sub_path = pkg_to_path(sub_pkg)

		--- 要创建的目录列表（相对于 root）
		local dirs = {
			"src/main/java",
			"src/main/resources",
			"src/test/java",
			"src/test/resources",
		}

		local created = {}

		for _, rel in ipairs(dirs) do
			local full
			if sub_path ~= "" and (rel == "src/main/java" or rel == "src/test/java") then
				full = root .. "/" .. rel .. "/" .. sub_path
			else
				full = root .. "/" .. rel
			end
			full = vim.fn.fnamemodify(full, ":p"):gsub("/$", "")
			vim.fn.mkdir(full, "p")
			table.insert(created, full)
		end

		-- 生成 build.gradle.kts
		local gradle_path = root .. "/build.gradle.kts"
		local gradle_content = "dependencies {\n}\n"
		local ok, err = pcall(
			vim.fn.writefile,
			vim.split(gradle_content, "\n", { plain = true }),
			gradle_path
		)
		if not ok then
			vim.notify("build.gradle.kts 写入失败: " .. tostring(err), vim.log.levels.ERROR)
			return
		end

		-- 向上查找 settings.gradle.kts 并追加 include
		local settings_msg = ""
		local dir = parent_dir
		local settings_path = nil
		while dir ~= "" and dir ~= "/" do
			local candidate = dir .. "/settings.gradle.kts"
			if vim.fn.filereadable(candidate) == 1 then
				settings_path = candidate
				break
			end
			local parent = vim.fn.fnamemodify(dir, ":h")
			if parent == dir then
				break
			end
			dir = parent
		end

		if settings_path then
			local lines = vim.fn.readfile(settings_path)
			table.insert(lines, 'include("' .. project_name .. '")')
			local ok2, err2 = pcall(vim.fn.writefile, lines, settings_path)
			if ok2 then
				settings_msg = "\n已追加到: " .. settings_path
			else
				settings_msg = "\nsettings.gradle.kts 写入失败: " .. tostring(err2)
			end
		else
			settings_msg = "\n未找到 settings.gradle.kts，请手动添加 include"
		end

		vim.notify(
			"已创建项目: " .. root .. "\n" .. table.concat(created, "\n") .. "\n" .. gradle_path .. settings_msg,
			vim.log.levels.INFO
		)
	end)
end

return M
