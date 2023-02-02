local profile_handler = {};

local data;

local obslua = obslua;
local print = print;
local tonumber = tonumber;
local require = require;

function profile_handler.read_config()
	local profile = obslua.obs_frontend_get_current_profile():gsub("[^%w_ ]", ""):gsub("%s", "_");
	
	local profile_relative_path = "obs-studio\\basic\\profiles\\" .. profile .. "\\basic.ini";
	
	-- char profile_path[512];
	local profile_path = "                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                ";
	obslua.os_get_abs_path("..\\..\\config\\" .. profile_relative_path, profile_path, #profile_path);
	
	if not obslua.os_file_exists(profile_path) then	
		obslua.os_get_config_path(profile_path, #profile_path, profile_relative_path);
	
		if not obslua.os_file_exists(profile_path) then	
			print("Profile Config File not found.");
			return;
		end
	end

	local config_text = obslua.os_quick_read_utf8_file(profile_path);

	if config_text == nil then 
		print("Couldn't read Profile Config File.");
		return;
	end
	
	print("Profile Config loaded: " ..  profile_path);
	
	local config = profile_handler.parse_ini(config_text);
	
	if config.Output == nil then
		data.update_output_mode(nil);
	else
		data.update_output_mode(config.Output.Mode);
	end

	if config.Video == nil then
		data.update_target_fps(nil);
	else
		data.update_canvas_resolution(config.Video.BaseCX, config.Video.BaseCY);
		data.update_output_resolution(config.Video.OutputCX, config.Video.OutputCY);
		data.update_target_fps(config.Video.FPSCommon);
	end

	if data.stats.output_mode == data.output_modes.simple then
		if config.SimpleOutput == nil then
			data.update_audio_bitrate(nil);
		else
			data.update_encoder(config.SimpleOutput.StreamEncoder);
			data.update_audio_bitrate(config.SimpleOutput.ABitrate);
		end
	else
		if config.AdvOut == nil then
			data.update_audio_bitrate(nil);
		else
			data.update_encoder(config.AdvOut.Encoder);
			data.update_audio_bitrate(config.AdvOut.Track1Bitrate);
		end
	end
end

function profile_handler.parse_ini(ini_text)
	local data = {};
	local section;

	for line in ini_text:gmatch("[^\r\n]+") do
		local tempSection = line:match('^%[([^%[%]]+)%]$');

		if tempSection then
			section = tonumber(tempSection) and tonumber(tempSection) or tempSection;
			data[section] = data[section] or {};
		end

		local param, value = line:match('^([%w|_]+)%s-=%s-(.+)$');

		if param and value ~= nil then

			if tonumber(value) then
				value = tonumber(value);
			elseif value == 'true' then
				value = true;
			elseif value == 'false' then
				value = false;
			end

			if tonumber(param) then
				param = tonumber(param);
			end

			data[section][param] = value;
		end
	end
	return data;
end

function profile_handler.init_module()
	data = require("modules.data");
end

return profile_handler;