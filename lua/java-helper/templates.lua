---@alias JavaHelperKind "class"|"interface"|"enum"|"record"|"annotation"

local M = {}

---@param author string
---@param since string
---@return string[]
local function build_javadoc(author, since)
	return {
		"/**",
		(" * @author %s"):format(author),
		(" * @since %s"):format(since),
		" */",
	}
end

---@param opts? {author?: string, since?: string}
---@return string author, string since
local function resolve_doc_opts(opts)
	opts = opts or {}
	local author = opts.author
	if not author or author == "" then
		author = vim.env.GIT_AUTHOR_NAME or vim.env.GIT_COMMITTER_NAME or vim.env.USER or vim.env.LOGNAME or "unknown"
	end
	local since = opts.since
	if not since or since == "" then
		since = os.date("%Y-%m-%d %H:%M:%S")
	end
	return author, since
end

---@param kind JavaHelperKind
---@param class_name string
---@param package_name string
---@param doc? {author?: string, since?: string}
---@return string
function M.build_java_source(kind, class_name, package_name, doc)
	local lines = {}
	if package_name ~= "" then
		lines[#lines + 1] = "package " .. package_name .. ";"
		lines[#lines + 1] = ""
	end

	local author, since = resolve_doc_opts(doc)
	vim.list_extend(lines, build_javadoc(author, since))

	if kind == "interface" then
		lines[#lines + 1] = "public interface " .. class_name .. " {"
		lines[#lines + 1] = "}"
	elseif kind == "enum" then
		lines[#lines + 1] = "public enum " .. class_name .. " {"
		lines[#lines + 1] = "}"
	elseif kind == "record" then
		lines[#lines + 1] = "public record " .. class_name .. "() {"
		lines[#lines + 1] = "}"
	elseif kind == "annotation" then
		lines[#lines + 1] = "public @interface " .. class_name .. " {"
		lines[#lines + 1] = "}"
	else
		lines[#lines + 1] = "public class " .. class_name .. " {"
		lines[#lines + 1] = "}"
	end
	lines[#lines + 1] = ""
	return table.concat(lines, "\n")
end

---@return {label: string, kind: JavaHelperKind}[]
function M.kinds()
	return {
		{ label = "class", kind = "class" },
		{ label = "interface", kind = "interface" },
		{ label = "enum", kind = "enum" },
		{ label = "record", kind = "record" },
		{ label = "annotation", kind = "annotation" },
	}
end

return M
