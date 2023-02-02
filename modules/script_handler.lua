local script_handler = {};

local data;
local data_format;
local bot;
local output;
local log;
local profile_handler;
local text_source_handler;

local obslua = obslua;
local ipairs = ipairs;
local print = print;
local require = require;

local description = [[
<center><h2>OBS Stats on Stream v2.0</h2></center>
<center>Made by <a href="https://twitch.tv/greencomfytea">GreenComfyTea</a> | 2023</center>
<center><a href="https://linktr.ee/greencomfytea">Socials</a> | <a href="https://ko-fi.com/greencomfytea">Buy me a tea</a> | <a href="https://streamelements.com/greencomfytea/tip">Donate</a></center>
<center><p>Shows OBS Stats (like Bitrate, Dropped Frames and more) on Stream and/or in Twitch Chat.</p></center>
<center><a href="https://twitchapps.com/tmi/">Twitch Chat OAuth Password Generator</a></center>
<center><a href="https://github.com/GreenComfyTea/OBS-Stats-on-Stream/blob/main/Text-Formatting-Variables.md">Text Formatting Variables</a> | <a href="https://github.com/GreenComfyTea/OBS-Stats-on-Stream/blob/main/Bot-Commands.md">Bot commands</a></center>
<hr/>
]];

local my_settings = nil;

script_handler.is_script_enabled = true;
script_handler.timer_delay = 1000;
script_handler.text_source = "";
script_handler.text_formatting = "";

script_handler.is_output_to_file_enabled = false;
script_handler.is_logging_enabled = false;

script_handler.is_bot_enabled = true;
script_handler.bot_delay = 2000;

script_handler.bot_password = "";
script_handler.bot_nickname = "justinfan4269";

script_handler.channel_nickname = "";

script_handler.is_timer_on = false;

function script_handler.tick()
	--print("Tick");

	if not script_handler.is_script_enabled then
		return;
	end

	data.update();
	data_format.update();
	text_source_handler.update();

	if script_handler.is_output_to_file_enabled then
		output.to_json();
	end

	if script_handler.is_logging_enabled then
		log.to_file();
	end
end

function script_handler.reset_formatting(properties, property)
	script_handler.text_formatting = default_text_formatting;

	obslua.obs_data_set_string(my_settings, "text_formatting", default_text_formatting);
	obslua.obs_properties_apply_settings(properties, my_settings);

	return true;
end

function script_handler.on_event(event)
	if event == obslua.OBS_FRONTEND_EVENT_STREAMING_STARTED then
		data.update_streaming_status(true);
	elseif event == obslua.OBS_FRONTEND_EVENT_STREAMING_STOPPED then
		data.update_streaming_status(false);
	elseif event == obslua.OBS_FRONTEND_EVENT_RECORDING_STARTED then
		data.update_recording_status(true, false);
	elseif event == obslua.OBS_FRONTEND_EVENT_RECORDING_STOPPED then
		data.update_recording_status(false, false);
	elseif event == obslua.OBS_FRONTEND_EVENT_RECORDING_PAUSED then
		data.update_recording_status(true, true);
	elseif event == obslua.OBS_FRONTEND_EVENT_RECORDING_UNPAUSED then
		data.update_recording_status(true, false);
	elseif event == obslua.OBS_FRONTEND_EVENT_FINISHED_LOADING
	or event == obslua.OBS_FRONTEND_EVENT_PROFILE_CHANGED
	or event == obslua.OBS_FRONTEND_EVENT_PROFILE_LIST_CHANGED
	or event == obslua.OBS_FRONTEND_EVENT_STREAMING_STARTING
	or event == obslua.OBS_FRONTEND_EVENT_STREAMING_STOPPING
	or event == obslua.OBS_FRONTEND_EVENT_RECORDING_STARTING
	or event == obslua.OBS_FRONTEND_EVENT_RECORDING_STOPPING then
		profile_handler.read_config();
	end
end

function script_properties()
	local properties = obslua.obs_properties_create();

	local enable_script_property = obslua.obs_properties_add_bool(properties, "is_script_enabled", "Enable Script");
	local enable_bot_property = obslua.obs_properties_add_bool(properties, "is_bot_enabled", "Enable Bot");

	local timer_delay_property = obslua.obs_properties_add_int(properties, "timer_delay", "Update Delay (ms)", 100, 2000, 100);
	obslua.obs_property_set_long_description(timer_delay_property, "Determines how often the data will update.");
	
	local bot_delay_property = obslua.obs_properties_add_int(properties, "bot_delay", "Bot Delay (ms)", 500, 5000, 100);
	obslua.obs_property_set_long_description(bot_delay_property, "Determines how often the bot will read chat and write to it.");

	local bot_nickname_property = obslua.obs_properties_add_text(properties, "bot_nickname", "Bot Nickname", obslua.OBS_TEXT_DEFAULT);
	obslua.obs_property_set_long_description(bot_nickname_property, "Nickname of your bot.");
	
	local bot_oauth_property = obslua.obs_properties_add_text(properties, "bot_password", "Bot OAuth Password", obslua.OBS_TEXT_PASSWORD);
	obslua.obs_property_set_long_description(bot_oauth_property, "Format: oauth:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx. Visit https://twitchapps.com/tmi/ to get the AOuth Password for the bot (you must login to twitch.tv accordingly.");

	local channel_nickname_property = obslua.obs_properties_add_text(properties, "channel_nickname", "Channel Nickname", obslua.OBS_TEXT_DEFAULT);
	obslua.obs_property_set_long_description(channel_nickname_property, "Nickname of your channel for bot to join. If empty bot will join his own chat.");

	obslua.obs_properties_add_button(properties, "recconect_button", "Reconnect...", bot.reconnect);

	local text_source_property = obslua.obs_properties_add_list(properties, "text_source", "Text Source", obslua.OBS_COMBO_TYPE_EDITABLE, obslua.OBS_COMBO_FORMAT_STRING);

	local sources = obslua.obs_enum_sources();
	if sources ~= nil then
		for _, source in ipairs(sources) do
			local source_id = obslua.obs_source_get_id(source);
			if source_id == "text_gdiplus_v2" or source_id == "text_ft2_source_v2" then
				local name = obslua.obs_source_get_name(source);
				obslua.obs_property_list_add_string(text_source_property, name, name);
			end
		end
	end
	obslua.source_list_release(sources);
	
	obslua.obs_property_set_long_description(text_source_property, "Text source that will be used to display the data.");

	obslua.obs_properties_add_text(properties, "text_formatting", "Text Formatting", obslua.OBS_TEXT_MULTILINE);
	obslua.obs_properties_add_button(properties, "reset_formatting_button", "Reset Formatting", script_handler.reset_formatting);

	obslua.obs_properties_apply_settings(properties, my_settings);

	local enable_output_to_file_property = obslua.obs_properties_add_bool(properties, "is_output_to_file_enabled", "Output to File");
	local enable_logging_property = obslua.obs_properties_add_bool(properties, "is_logging_enabled", "Enable Logging");

	return properties;
end

function script_defaults(settings)
	my_settings = settings;

	obslua.obs_data_set_default_bool(settings, "is_script_enabled", true);
	obslua.obs_data_set_default_bool(settings, "is_bot_enabled", true);

	obslua.obs_data_set_default_int(settings, "timer_delay", 1000);
	obslua.obs_data_set_default_int(settings, "bot_delay", 2000);

	obslua.obs_data_set_default_string(settings, "bot_nickname", "");
	obslua.obs_data_set_default_string(settings, "bot_password", "");
	obslua.obs_data_set_default_string(settings, "channel_nickname", "");

	obslua.obs_data_set_default_string(settings, "text_source", "");
	obslua.obs_data_set_default_string(settings, "text_formatting", text_source_handler.default_formatting);

	obslua.obs_data_set_default_bool(settings, "is_output_to_file_enabled", false);
	obslua.obs_data_set_default_bool(settings, "is_logging_enabled", false);

	print("Settings were reset.");
end

function script_update(settings)
	my_settings = settings;

	script_handler.is_script_enabled = obslua.obs_data_get_bool(settings, "is_script_enabled");
	script_handler.is_bot_enabled = obslua.obs_data_get_bool(settings, "is_bot_enabled");

	script_handler.timer_delay = obslua.obs_data_get_int(settings, "timer_delay");
	script_handler.bot_delay = obslua.obs_data_get_int(settings, "bot_delay");

	script_handler.bot_nickname = obslua.obs_data_get_string(settings, "bot_nickname");
	script_handler.bot_password = obslua.obs_data_get_string(settings, "bot_password");
	script_handler.channel_nickname = obslua.obs_data_get_string(settings, "channel_nickname");

	script_handler.text_source = obslua.obs_data_get_string(settings, "text_source");
	script_handler.text_formatting = obslua.obs_data_get_string(settings, "text_formatting");

	script_handler.is_output_to_file_enabled = obslua.obs_data_get_bool(settings, "is_output_to_file_enabled");
	script_handler.is_logging_enabled = obslua.obs_data_get_bool(settings, "is_logging_enabled");

	data.start_cpu_usage_info();

	if script_handler.is_timer_on then
		script_handler.is_timer_on = false;
		obslua.timer_remove(script_handler.tick);
		
		print("Timer removed.");
	end

	bot.close_socket();

	print("Settings were updated.");

	profile_handler.read_config();
	data.update_cores_on_script_settings_changed();
	data.update_streaming_status_on_script_settings_changed();
	data.update_recording_status_on_script_settings_changed();

	if script_handler.is_script_enabled then
		script_handler.is_timer_on = true;
		obslua.timer_add(script_handler.tick, script_handler.timer_delay);
		print("Timer added.");

		bot.init_socket();
	end
end

function script_description()
	return description;
end

function script_load(settings)
	obslua.obs_frontend_add_event_callback(script_handler.on_event);
	print("Script is loaded.");
end

function script_unload()
	-- not working???

	--if is_script_enabled then
	--	is_timer_on = false;
	--	obslua.timer_remove(data.tick);
	--	print("Timer removed.");
	--end

	bot.close_socket_on_unload();

	print("[OBS-Stats-on-Stream.lua] Script unloaded.");
end

function script_handler.init_module()
	data = require("modules.data");
	data_format = require("modules.data_format");
	output = require("modules.output");
	log = require("modules.log");
	profile_handler = require("modules.profile_handler");
	text_source_handler = require("modules.text_source_handler");
	bot = require("modules.bot");
end

return script_handler;