local M = {}

local ns_id = vim.api.nvim_create_namespace("JavaHelperMapper")

local function get_java_methods(bufnr)
	local methods = {}
	local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "java")
	if ok and parser then
		local tree = parser:parse()[1]
		local root = tree:root()
		local query_string = [[
			(method_declaration
				name: (identifier) @method_name)
		]]
		local ok_q, query = pcall(vim.treesitter.query.parse, "java", query_string)
		if ok_q and query then
			for id, node, metadata in query:iter_captures(root, bufnr, 0, -1) do
				local name = vim.treesitter.get_node_text(node, bufnr)
				local row, _, _ = node:start()
				table.insert(methods, { name = name, line = row })
			end
			return methods
		end
	end

	-- fallback
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	for i, line in ipairs(lines) do
		local match = line:match("([%w_]+)%s*%(")
		if match and not line:match("class%s+") and not line:match("interface%s+") and not line:match("public%s+[%w_]+%s*{") then
			table.insert(methods, { name = match, line = i - 1 })
		end
	end
	return methods
end

local function get_java_methods_from_string(content_str)
	local methods = {}
	local ok, parser = pcall(vim.treesitter.get_string_parser, content_str, "java")
	if ok and parser then
		local tree = parser:parse()[1]
		local query_string = [[
			(method_declaration
				name: (identifier) @method_name)
		]]
		local ok_q, query = pcall(vim.treesitter.query.parse, "java", query_string)
		if ok_q and query then
			for id, node, metadata in query:iter_captures(tree:root(), content_str, 0, -1) do
				local name = vim.treesitter.get_node_text(node, content_str)
				local row, _, _ = node:start()
				table.insert(methods, { name = name, line = row })
			end
			return methods
		end
	end

	local lines = vim.split(content_str, "\n", { plain = true })
	for i, line in ipairs(lines) do
		local match = line:match("([%w_]+)%s*%(")
		if match and not line:match("class%s+") and not line:match("interface%s+") and not line:match("public%s+[%w_]+%s*{") then
			table.insert(methods, { name = match, line = i - 1 })
		end
	end
	return methods
end

local function get_xml_statements(filepath)
	local ok, lines = pcall(vim.fn.readfile, filepath)
	if not ok or not lines then return {} end
	
	local content = table.concat(lines, "\n")
	local statements = {}
	
	local s = 1
	while true do
		local start_idx, end_idx, id = content:find('<[%w_]+[^>]*id=["\']([%w_]+)["\']', s)
		if not start_idx then break end
		
		local prefix = content:sub(1, start_idx)
		local line_num = 0
		for _ in prefix:gmatch("\n") do line_num = line_num + 1 end
		
		table.insert(statements, { name = id, line = line_num })
		s = end_idx + 1
	end
	
	return statements
end

local function diagnose_java_file(bufnr, config)
	if not vim.api.nvim_buf_is_valid(bufnr) then return end
	local filepath = vim.api.nvim_buf_get_name(bufnr)
	if not filepath:match("Mapper%.java$") and not filepath:match("Dao%.java$") then
		return
	end
	
	local basename = vim.fn.fnamemodify(filepath, ":t:r")
	local project_root = vim.fn.getcwd()
	local java_root_mod = require("java-helper.java_root")
	local java_root = java_root_mod.find_java_source_root(vim.fn.fnamemodify(filepath, ":h"))
	if java_root then
		local possible_root = vim.fn.fnamemodify(java_root, ":h:h")
		if vim.fn.isdirectory(possible_root) == 1 then
			project_root = possible_root
		end
	end
	
	local go_to_mapper = require("java-helper.actions.go_to_mapper")
	if not go_to_mapper.find_files_async then return end

	go_to_mapper.find_files_async(project_root, basename, ".xml", function(results)
		if #results == 0 or not vim.api.nvim_buf_is_valid(bufnr) then return end
		local target_xml = results[1]
		
		local java_methods = get_java_methods(bufnr)
		local xml_statements = get_xml_statements(target_xml)
		
		local xml_set = {}
		for _, st in ipairs(xml_statements) do
			xml_set[st.name] = true
		end
		
		local diagnostics = {}
		for _, method in ipairs(java_methods) do
			if not xml_set[method.name] then
				table.insert(diagnostics, {
					lnum = method.line,
					col = 0,
					severity = vim.diagnostic.severity.WARN,
					source = "java-helper",
					message = "在对应的 XML 中找不到语句: " .. method.name,
				})
			end
		end
		
		vim.diagnostic.set(ns_id, bufnr, diagnostics)
	end)
end

local function diagnose_xml_file(bufnr, config)
	if not vim.api.nvim_buf_is_valid(bufnr) then return end
	local filepath = vim.api.nvim_buf_get_name(bufnr)
	if not filepath:match("Mapper%.xml$") and not filepath:match("Dao%.xml$") then
		return
	end

	local basename = vim.fn.fnamemodify(filepath, ":t:r")
	local project_root = vim.fn.getcwd()
	
	local go_to_mapper = require("java-helper.actions.go_to_mapper")
	if not go_to_mapper.find_files_async then return end

	go_to_mapper.find_files_async(project_root, basename, ".java", function(results)
		if #results == 0 or not vim.api.nvim_buf_is_valid(bufnr) then return end
		local target_java = results[1]
		
		local ok, lines = pcall(vim.fn.readfile, target_java)
		if not ok or not lines then return end
		local java_content = table.concat(lines, "\n")
		local java_methods = get_java_methods_from_string(java_content)
		
		local buf_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		local content = table.concat(buf_lines, "\n")
		local xml_statements = {}
		local s = 1
		while true do
			local start_idx, end_idx, id = content:find('<[%w_]+[^>]*id=["\']([%w_]+)["\']', s)
			if not start_idx then break end
			local prefix = content:sub(1, start_idx)
			local line_num = 0
			for _ in prefix:gmatch("\n") do line_num = line_num + 1 end
			table.insert(xml_statements, { name = id, line = line_num })
			s = end_idx + 1
		end
		
		local java_set = {}
		for _, m in ipairs(java_methods) do
			java_set[m.name] = true
		end
		
		local diagnostics = {}
		for _, st in ipairs(xml_statements) do
			if not java_set[st.name] then
				table.insert(diagnostics, {
					lnum = st.line,
					col = 0,
					severity = vim.diagnostic.severity.WARN,
					source = "java-helper",
					message = "在对应的 Java 接口中找不到方法: " .. st.name,
				})
			end
		end
		
		vim.diagnostic.set(ns_id, bufnr, diagnostics)
	end)
end

function M.setup(config)
	if not config.enable_mapper_diagnostics then return end

	local group = vim.api.nvim_create_augroup("JavaHelperDiagnostics", { clear = true })
	
	vim.api.nvim_create_autocmd({"BufEnter", "BufWritePost", "InsertLeave", "TextChanged"}, {
		group = group,
		pattern = "*.java",
		callback = function(args)
			diagnose_java_file(args.buf, config)
		end,
		desc = "诊断 Java Mapper 缺失的 XML 语句",
	})
	
	vim.api.nvim_create_autocmd({"BufEnter", "BufWritePost", "InsertLeave", "TextChanged"}, {
		group = group,
		pattern = "*.xml",
		callback = function(args)
			diagnose_xml_file(args.buf, config)
		end,
		desc = "诊断 XML Mapper 缺失的 Java 方法",
	})
end

return M
