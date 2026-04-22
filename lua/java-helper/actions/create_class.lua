local Util = require("java-helper.util")
local JavaRoot = require("java-helper.java_root")
local TargetDir = require("java-helper.target_dir")
local Templates = require("java-helper.templates")

local M = {}

---@param config JavaHelperConfig
function M.create_class(config)
	vim.ui.input({ prompt = "类名（无需 .java）: " }, function(input)
		if input == nil then
			return
		end

		local class_name, err = Util.sanitize_class_name(input)
		if not class_name then
			vim.notify(err, vim.log.levels.ERROR)
			return
		end
		class_name = Util.capitalize_first_letter(class_name)

		vim.ui.select(Templates.kinds(), {
			prompt = "新建类型：",
			format_item = function(item)
				return item.label
			end,
		}, function(choice)
			if not choice then
				return
			end

			local target_dir = TargetDir.default_target_dir()
			local java_root = JavaRoot.find_java_source_root(target_dir)
			local package_name = ""
			if java_root then
				java_root = vim.fn.fnamemodify(java_root, ":p"):gsub("/$", "")
				if vim.fn.stridx(target_dir, java_root) == 0 then
					package_name = JavaRoot.infer_package(java_root, target_dir)
				else
					target_dir = java_root
					package_name = ""
				end
			end

			local path = vim.fn.fnamemodify(target_dir .. "/" .. class_name .. ".java", ":p")
			if vim.fn.filereadable(path) == 1 or vim.fn.isdirectory(path) == 1 then
				vim.notify("文件已存在: " .. path, vim.log.levels.ERROR)
				return
			end

			local dir = vim.fn.fnamemodify(path, ":h")
			if vim.fn.isdirectory(dir) ~= 1 then
				vim.fn.mkdir(dir, "p")
			end

			local content = Templates.build_java_source(choice.kind, class_name, package_name, {
				author = config.author,
				since = os.date(config.since_format or "%Y-%m-%d %H:%M:%S"),
			})
			local ok, write_err = pcall(vim.fn.writefile, vim.split(content, "\n", { plain = true }), path)
			if not ok then
				vim.notify("写入失败: " .. tostring(write_err), vim.log.levels.ERROR)
				return
			end

			vim.notify("已创建: " .. path, vim.log.levels.INFO)
			vim.cmd.edit(vim.fn.fnameescape(path))
		end)
	end)
end

return M
