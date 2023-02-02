local output = {};

local json;
local data;

local obslua = obslua;
local require = require;
local script_path = script_path;
local print = print;

local file_output_name = "obs-stats.json";

function output.to_json()
	--print("Output to " .. file_output_name);

	local data_json = json.encode(data.stats, { indent = true });

	local script_path_ = script_path();
	local output_path = script_path_ .. file_output_name;

	obslua.os_quick_write_utf8_file(output_path, data_json, #data_json, false);
end

function output.init_module()
	json = require("modules.json");
	data = require("modules.data");
end

return output;