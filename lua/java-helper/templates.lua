---@alias JavaHelperKind "class"|"interface"|"enum"|"record"|"annotation"

local M = {}

---@param kind JavaHelperKind
---@param class_name string
---@param package_name string
---@return string
function M.build_java_source(kind, class_name, package_name)
	local lines = {}
	if package_name ~= "" then
		lines[#lines + 1] = "package " .. package_name .. ";"
		lines[#lines + 1] = ""
	end

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
