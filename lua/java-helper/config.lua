---@class JavaHelperConfig
---@field create_class_command string
---@field init_project_command? string
---@field go_to_test_command? string
---@field go_to_mapper_command? string
---@field mapper_hover_command? string
---@field auto_hover_mapper? boolean 是否在 CursorHold 时自动悬浮显示 SQL
---@field sub_package? string 子包名，如 "com.jasper"，将追加到 src/main/java 和 src/test/java 之后
---@field author? string 作者（Javadoc）
---@field since_format? string os.date 格式

local M = {}

---@type JavaHelperConfig
M.defaults = {
	create_class_command = "JavaCreateClass",
	init_project_command = "JavaInitProject",
	go_to_test_command = "JavaGoToTest",
	go_to_mapper_command = "JavaGoToMapper",
	mapper_hover_command = "JavaMapperHover",
	auto_hover_mapper = false,
	sub_package = nil,
	author = nil,
	since_format = "%Y-%m-%d %H:%M:%S",
}

---@type JavaHelperConfig|nil
local _active = nil

--- 存储 setup() 合并后的最终 config
---@param cfg JavaHelperConfig
function M.set(cfg)
	_active = cfg
end

--- 获取当前激活的 config（未 setup 则返回 defaults）
---@return JavaHelperConfig
function M.get()
	return _active or M.defaults
end

return M
