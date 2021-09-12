obs = obslua
local ffi = require("ffi")
local socket = require("ljsocket")

ffi.cdef[[

	struct video_output;
	typedef struct video_output video_t;

	//struct config_data;
	//typedef struct config_data config_t;

	struct os_cpu_usage_info;
	typedef struct os_cpu_usage_info os_cpu_usage_info_t;

	uint32_t video_output_get_skipped_frames(const video_t *video);
	uint32_t video_output_get_total_frames(const video_t *video);
	double video_output_get_frame_rate(const video_t *video);

	//const char *config_get_string(config_t *config, const char *section, const char *name);

	os_cpu_usage_info_t *os_cpu_usage_info_start(void);
	double os_cpu_usage_info_query(os_cpu_usage_info_t *info);
	void os_cpu_usage_info_destroy(os_cpu_usage_info_t *info);

	video_t *obs_get_video(void);
]]

local output_mode = "simple_stream";

local timer_delay = 1000;
local bot_delay = 2000;

local use_custom_bot = false;

local channel_password = "";
local channel_nickname = "";

local bot_password = "";
local bot_nickname = "justinfan4269";

local text_source = "";
local text_formatting = "";

local default_text_formatting = [[Missed frames: $missed_frames/$missed_total_frames ($missed_percents%)
Skipped frames: $skipped_frames/$skipped_total_frames ($skipped_percents%)
Dropped frames: $dropped_frames/$dropped_total_frames ($dropped_percents%)
Congestion: $congestion% (avg. $average_congestion%)
Average frame time: $average_frame_time ms
Memory Usage: $memory_usage MB
Bitrate: $bitrate kb/s
FPS: $fps]];


local lagged_frames_string = "";
local lagged_total_frames_string = "";
local lagged_percents_string = "";

local skipped_frames_string = "";
local skipped_total_frames_string = "";
local skipped_percents_string = "";

local dropped_frames_string = "";
local dropped_total_frames_string = "";
local dropped_percents_string = "";

local congestion_string = "";
local average_congestion_string = "";
local bitrate_string = "";

local memory_usage_string = "";
local fps_string = "";
local average_frame_time_string = "";

local last_bitrate = 0;
local last_bytes_sent = 0;
local last_bytes_sent_time = 0;

local is_script_enabled = true;
local is_bot_enabled = true;
local is_timer_on = false;

local total_ticks = 0;
local congestion_cumulative = 0;
local bitrate_cumulative = 0;

local obsffi;
if ffi.os == "OSX" then
	obsffi = ffi.load("obs.0.dylib"); -- OS X
else
	obsffi = ffi.load("obs"); -- Windows
	-- Linux?
end

local my_settings = nil;

local host = "irc.chat.twitch.tv";
local port = 6667;
local channel_socket = nil;
local bot_socket = nil;

local channel_auth_success = false;
local channel_auth_requested = false;

local bot_auth_success = false;
local bot_auth_requested = false;

local channel_joined = false;

function channel_socket_tick()
	if channel_socket:is_connected() then
		if not channel_auth_success and not channel_auth_requested then
			auth(channel_socket, channel_password, channel_nickname);
			channel_auth_requested = true;
		end
		
		local response = receive(channel_socket);
		
		if response then
			for line in response:gmatch("[^\n]+") do
				if not channel_auth_success then
					channel_auth_requested = false;
					if line:match(":tmi.twitch.tv 001") then
						channel_nickname = get_real_nickname(line);
						print("Authentication success: " .. channel_nickname);
						channel_auth_success = true;
						
						obs.timer_remove(channel_socket_tick);
						channel_socket:close();
						return;
					else 
						print("Authentication to " .. channel_nickname .. " failed! Socket closed! Try reconnecting manually...");
						close_sockets();
						return;
					end
				end
			end
		end
	end
end

function bot_socket_tick()
	if bot_socket:is_connected() then
		if not bot_auth_success and not bot_auth_requested then
			auth(bot_socket, bot_password, bot_nickname);
			bot_auth_requested = true;
		end
		
		local response = receive(bot_socket);
		if response then
			print(response);
			for line in response:gmatch("[^\n]+") do
				repeat
					if not bot_auth_success then
						bot_auth_requested = false;
						if line:match(":tmi.twitch.tv 001") then
							bot_nickname = get_real_nickname(line);
							print("Authentication success: " .. bot_nickname);
							bot_auth_success = true;
							
							if not use_custom_bot then
								send("JOIN #" .. channel_nickname);
							end
							
							do break end
						else 
							print("Authentication to " .. bot_nickname .. " failed! Socket closed! Try reconnecting manually...");
							
							close_sockets();
							return;
						end
					end
					
					if use_custom_bot then
						if channel_auth_success then
							if not channel_joined then
								send("JOIN #" .. channel_nickname);
								channel_joined = true;
							end
						else
							return;
						end
					end
				
					print("test");
					
					if line:match("PING") then
						send("PONG");
						print("PING PONG");
						do break end
					end
				
					local i = 0;
					local to_user = "";
					local command = "";
					
					for word in line:gmatch("[^%s]+") do
						if i == 0 then
							local j = 0;
							for token in word:gmatch("[^!]+") do
								if j == 0 then
									to_user = token:sub(2);
								end
								j = j + 1;
							end
							
						end
						
						if i == 1 then
							if word ~= "PRIVMSG" then
								return;
							end
						end
						
						if i == 3 then
							command = word:sub(2):lower();
						end
						
						if i == 4 then
							if word:match("^@") then
								to_user = word:sub(2);
							else
								to_user = word;
							end
							
						end
						
						i = i + 1;
					end

					if command:match("^!missed_frames") or command:match("^!missedframes") or command:match("^!missed") then
						send_message(string.format("@%s -> Missed frames: %s/%s (%s%%)", to_user, lagged_frames_string, lagged_total_frames_string, lagged_percents_string));
						
					elseif command:match("^!skipped_frames") or command:match("^!skippedframes") or command:match("^!skipped") then
						send_message(string.format("@%s -> Skipped frames: %s/%s (%s%%)", to_user, skipped_frames_string, skipped_total_frames_string, skipped_percents_string));
						
					elseif command:match("^!dropped_frames") or command:match("^!droppedframes") or command:match("^!dropped") then
						send_message(string.format("@%s -> Dropped frames: %s/%s (%s%%)", to_user, dropped_frames_string, dropped_total_frames_string, dropped_percents_string));
						
					elseif command:match("^!congestion") then
						send_message(string.format("@%s -> Congestion: %s%% (average: %s%%)", to_user, congestion_string, average_congestion_string));
						
					elseif command:match("^!frame_time") or command:match("^!render_time") or command:match("^!frametime") or command:match("^!rendertime") then
						send_message(string.format("@%s -> Average frame time: %s ms", to_user, average_frame_time_string));
						
					elseif command:match("^!memory_usage") or command:match("^!memoryusage") or command:match("^!memory") then
						send_message(string.format("@%s -> Memory usage: %s MB", to_user, memory_usage_string));
						
					elseif command:match("^!bitrate") then
						send_message(string.format("@%s -> Bitrate: %s kb/s", to_user, bitrate_string));
						
					elseif command:match("^!fps") or command:match("^!framerate") then
						send_message(string.format("@%s -> FPS: %s", to_user, fps_string));
						
					elseif command:match("^!obsstats") then
						send_message(string.format("@%s -> Missed frames: %s/%s (%s%%), Skipped frames: %s/%s (%s%%), Dropped frames: %s/%s (%s%%), Congestion: %s%% (average: %s%%), Average frame time: %s ms, Memory usage: %s MB, Bitrate: %s kb/s, FPS: %s", to_user, lagged_frames_string, lagged_total_frames_string, lagged_percents_string, skipped_frames_string, skipped_total_frames_string, skipped_percents_string, dropped_frames_string, dropped_total_frames_string, dropped_percents_string, congestion_string, average_congestion_string, average_frame_time_string, memory_usage_string, bitrate_string, fps_string));
					end
					
					do break end
				until true
			end
		end
	end
end

function reset_bot_data()
	channel_auth_success = false;
	channel_auth_requested = false;
	
	bot_auth_success = false;
	bot_auth_requested = false;
end

function auth(socket, password, nickname)
	print("Authentication attempt: " .. nickname);
	assert(socket:send(
		string.format("PASS %s\r\nNICK %s\r\n", password, nickname)
	));
end

function send(message)
	assert(bot_socket:send(
		string.format("%s\r\n", message)
	));
end

function send_message(message)
	assert(bot_socket:send(
		string.format("PRIVMSG #%s :%s\r\n", channel_nickname, message)
	));
end

function receive(socket)
	local response, err = socket:receive();
	if response then
		return response;
	elseif err ~= "timeout" then
		error(err);
	end
end

function get_real_nickname(line)
	local i = 0;
	for word in line:gmatch("[^%s]+") do
		if i == 2 then
			return word;
		end
		i = i + 1;
	end
end

function timer_tick()
	total_ticks = total_ticks + 1;
	
	local source = obs.obs_get_source_by_name(text_source);
	
	-- Not working for some reason?
	-- Crashing on config_get_string mutex
	-- I want to detect output mode automatically.
	
	--[[
	local profile = obs.obs_frontend_get_current_profile();
	print("profile: " .. profile);
	
	local profile_path = "                                                                                                                                                                                                                                                               ";
	obs.os_get_config_path(profile_path, #profile_path, "obs-studio\\basic\\profiles\\" ..profile .. "\\basic.ini");
	print("path: " .. profile_path);
	
	local config = obs.obs_frontend_get_profile_config();
	local gconfig = obs.obs_frontend_get_global_config();

	print("config: " .. tostring(config));
	print("config: " .. tostring(gconfig));

	if obsffi ~= nil then
		local mode = obsffi.config_get_string(config, "Output", "Mode");
		--local gmode = obsffi.config_get_string(gconfig, "Output", "Mode");

		print("config: " .. tostring(mode));
		print("config: " .. tostring(gmode));
	end
	--]]
	

	--local config = nil
	--local config_open_success = obs.config_open(config, profile_path, 0)
	--print("success: " .. tostring(config_open_success))
	
	--obs.config_close(config)
	
	--Not working for some reason?
	--info_query return nan
	--[[
	if obsffi ~= nil then
		local cpu_info = obsffi.os_cpu_usage_info_start();
		print(tostring(cpu_info));
		local usage = obsffi.os_cpu_usage_info_query(cpu_info);
		print(usage);
		obsffi.os_cpu_usage_info_destroy(cpu_info);
	end
	--]]
	
	-- Get memory usage
	local memory_usage = obs.os_get_proc_resident_size() / (1024.0 * 1024.0);
	
	-- Get FPS/framerate
	local fps = obs.obs_get_active_fps();
	
	-- Get average time to render frame
	local average_frame_time = obs.obs_get_average_frame_time_ns() / 1000000.0;
	
	-- Get lagged/missed frames
	local rendered_frames = obs.obs_get_total_frames();
	local lagged_frames = obs.obs_get_lagged_frames();
	
	-- Get skipped frames
	local encoded_frames = 0;
	local skipped_frames = 0;
	
	if obsffi ~= nil then
		local video = obsffi.obs_get_video();
		if video ~= nil then
			encoded_frames = obsffi.video_output_get_total_frames(video);
			skipped_frames = obsffi.video_output_get_skipped_frames(video);
		end
	end
	
	-- Get dropped frames, congestion and total bytes
	local total_frames = 0;
	local dropped_frames = 0;
	local congestion = 0.0;
	local total_bytes = 0;

	local output = obs.obs_get_output_by_name(output_mode);
	-- output will be nil when not actually streaming
	if output ~= nil then
		total_frames = obs.obs_output_get_total_frames(output);
		dropped_frames = obs.obs_output_get_frames_dropped(output);
		congestion = obs.obs_output_get_congestion(output);
		total_bytes = obs.obs_output_get_total_bytes(output);
		--local connect_time = obs.obs_output_get_connect_time_ms(output)
		obs.obs_output_release(output);
	end
	
	congestion_cumulative = congestion_cumulative + congestion

	-- Get bitrate
	local bytes_sent = total_bytes;
	local current_time = obs.os_gettime_ns();

	if bytes_sent < last_bytes_sent then
		bytes_sent = 0;
	end
	if bytes_sent == 0 then
		last_bytes_sent = 0;
	end
		
	local time_passed = (current_time - last_bytes_sent_time) / 1000000000.0;
	local bits_between = (bytes_sent - last_bytes_sent) * 8;
	bitrate = bits_between / time_passed / 1000.0;


	local bitrate = last_bitrate;
	if time_passed > 2.0 then
		local bits_between = (bytes_sent - last_bytes_sent) * 8;
		bitrate = bits_between / time_passed / 1000.0;

		last_bytes_sent = bytes_sent;
		last_bytes_sent_time = current_time;
		last_bitrate = bitrate;
	end

	-- Update strings with new values
	lagged_frames_string = tostring(lagged_frames);
	lagged_total_frames_string = tostring(rendered_frames);
	lagged_percents_string = string.format("%.1f", 100.0 * lagged_frames / rendered_frames);

	skipped_frames_string = tostring(skipped_frames);
	skipped_total_frames_string = tostring(encoded_frames);
	skipped_percents_string = string.format("%.1f", 100.0 * skipped_frames / encoded_frames);

	dropped_frames_string = tostring(dropped_frames);
	dropped_total_frames_string = tostring(total_frames);
	dropped_percents_string = string.format("%.1f", 100.0 * dropped_frames / total_frames);

	congestion_string = string.format("%.2f", 100 * congestion);
	average_congestion_string = string.format("%.2f", 100 * congestion_cumulative / total_ticks);
	
	average_frame_time_string = string.format("%.1f", average_frame_time);
	memory_usage_string = string.format("%.1f", memory_usage);
	bitrate_string = string.format("%.0f", bitrate);
	fps_string = string.format("%.2g", fps);
	
	-- Make a string for display in a text source
	local formatted_text = text_formatting;

	formatted_text = formatted_text:gsub("$missed_frames", lagged_frames_string);
	formatted_text = formatted_text:gsub("$missed_total_frames", lagged_total_frames_string);
	formatted_text = formatted_text:gsub("$missed_percents", lagged_percents_string);

	formatted_text = formatted_text:gsub("$skipped_frames", skipped_frames_string);
	formatted_text = formatted_text:gsub("$skipped_total_frames", skipped_total_frames_string);
	formatted_text = formatted_text:gsub("$skipped_percents", skipped_percents_string);

	formatted_text = formatted_text:gsub("$dropped_frames", dropped_frames_string);
	formatted_text = formatted_text:gsub("$dropped_total_frames", dropped_total_frames_string);
	formatted_text = formatted_text:gsub("$dropped_percents", dropped_percents_string);

	formatted_text = formatted_text:gsub("$congestion", congestion_string);
	formatted_text = formatted_text:gsub("$average_congestion",average_congestion_string);

	formatted_text = formatted_text:gsub("$average_frame_time", average_frame_time_string);
	formatted_text = formatted_text:gsub("$memory_usage", memory_usage_string);
	formatted_text = formatted_text:gsub("$bitrate", bitrate_string);
	formatted_text = formatted_text:gsub("$fps", fps_string);

	-- Update text source
	if source ~= nil then
		local settings = obs.obs_data_create();
		obs.obs_data_set_string(settings, "text", formatted_text);
		obs.obs_source_update(source, settings);
		obs.obs_source_release(source);
		obs.obs_data_release(settings);
	end
end

function reset_formatting(properties, property)
	text_formatting = default_text_formatting;

	obs.obs_data_set_string(my_settings, "text_formatting", default_text_formatting);
	obs.obs_properties_apply_settings(properties, my_settings);

	return true;
end

function recconect()
	print("Reconnecting...");
	if is_timer_on then
		obs.timer_remove(bot_socket_tick);
	end
	
	close_sockets();

	if is_bot_enabled then
		bot_socket = assert(socket.create("inet", "stream", "tcp"));
		assert(bot_socket:set_blocking(false));
		assert(bot_socket:connect(host, port));
		
		obs.timer_add(bot_socket_tick, bot_delay);
	end
end
	
function init_sockets()
	bot_socket = assert(socket.create("inet", "stream", "tcp"));
	assert(bot_socket:set_blocking(false));
	assert(bot_socket:connect(host, port));
	
	obs.timer_add(bot_socket_tick, bot_delay);
	
	if use_custom_bot then
		channel_socket = assert(socket.create("inet", "stream", "tcp"));
		assert(channel_socket:set_blocking(false));
		assert(channel_socket:connect(host, port));
		
		obs.timer_add(channel_socket_tick, bot_delay);
	end
end

function close_sockets()					
	obs.timer_remove(channel_socket_tick);
	obs.timer_remove(bot_socket_tick);

	if bot_socket:is_connected() then
		bot_socket:close();
	end
	
	if channel_socket:is_connected() then
		channel_socket:close();
	end
	
	reset_bot_data();
end
	
function custom_bot_visibility(properties, property, settings)
	obs.obs_property_set_visible(obs.obs_properties_get(properties, "bot_nickname"), use_custom_bot);
	obs.obs_property_set_visible(obs.obs_properties_get(properties, "bot_password"), use_custom_bot);
	return true;
end
	
function on_event(event)
	if event == obs.OBS_FRONTEND_EVENT_FINISHED_LOADING then
		print("scene loaded");
		
		if is_script_enabled then
			print("script is enabled");
			is_timer_on = true;
			
			obs.timer_add(timer_tick, timer_delay);
			
			if is_bot_enabled then
				init_sockets();
			end
		end
	end
end
		
function script_properties()
	local properties = obs.obs_properties_create();

	local enable_script_property = obs.obs_properties_add_bool(properties, "is_script_enabled", "Enable Script");
	local enable_bot_property = obs.obs_properties_add_bool(properties, "is_bot_enabled", "Enable Bot");
	
	local output_mode_property = obs.obs_properties_add_list(properties, "output_mode", "Output Mode", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING);
	obs.obs_property_list_add_string(output_mode_property, "Simple", "simple_stream");
	obs.obs_property_list_add_string(output_mode_property, "Advanced", "adv_stream");
	obs.obs_property_set_long_description(output_mode_property, "Must match the output mode you are using in OBS -> Settings -> Output -> Output mode.");
	
	local timer_delay_property = obs.obs_properties_add_int(properties, "timer_delay", "Update Delay (ms)", 100, 2000, 100);
	obs.obs_property_set_long_description(timer_delay_property, "Determines how often the data will update.");

	local bot_delay_property = obs.obs_properties_add_int(properties, "bot_delay", "Bot Delay (ms)", 500, 5000, 100);
	obs.obs_property_set_long_description(bot_delay_property, "Determines how often the bot will read chat and write to it.");
	
	local channel_nickname_property = obs.obs_properties_add_text(properties, "channel_nickname", "Channel Nickname", obs.OBS_TEXT_DEFAULT);
	obs.obs_property_set_long_description(channel_nickname_property, "Nickname of your channel.");
	
	local channel_oauth_property = obs.obs_properties_add_text(properties, "channel_password", "Channel OAuth Password", obs.OBS_TEXT_PASSWORD);
	obs.obs_property_set_long_description(channel_oauth_property, "Format: oauth:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx. Visit https://twitchapps.com/tmi/ to get the AOuth Password.");
	
	local use_custom_bot_property = obs.obs_properties_add_bool(properties, "use_custom_bot", "Use Custom Bot");
	obs.obs_property_set_modified_callback(use_custom_bot_property, custom_bot_visibility);
	
	local bot_nickname_property = obs.obs_properties_add_text(properties, "bot_nickname", "Bot Nickname", obs.OBS_TEXT_DEFAULT);
	obs.obs_property_set_long_description(bot_nickname_property, "Nickname of your bot.");
	
	local bot_oauth_property = obs.obs_properties_add_text(properties, "bot_password", "Bot OAuth Password", obs.OBS_TEXT_PASSWORD);
	obs.obs_property_set_long_description(bot_oauth_property, "Format: oauth:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx. Visit https://twitchapps.com/tmi/ to get the AOuth Password for the bot (you must login to twitch.tv accordingly.");
	
	obs.obs_properties_add_button(properties, "recconect_button", "Reconnect...", recconect);
	
	local text_source_property = obs.obs_properties_add_list(properties,
		"text_source", "Text Source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING);
	local sources = obs.obs_enum_sources();
	if sources ~= nil then
		for _, source in ipairs(sources) do
			local source_id = obs.obs_source_get_id(source);
			if source_id == "text_gdiplus_v2" or source_id == "text_ft2_source_v2" then
				local name = obs.obs_source_get_name(source);
				obs.obs_property_list_add_string(text_source_property, name, name);
			end
		end
	end
	obs.source_list_release(sources);
	obs.obs_property_set_long_description(text_source_property, "Text source that will be used to display the data.");

	obs.obs_properties_add_text(properties, "text_formatting", "Text Formatting", obs.OBS_TEXT_MULTILINE);
	obs.obs_properties_add_button(properties, "reset_formatting_button", "Reset Formatting", reset_formatting);

	obs.obs_properties_apply_settings(properties, my_settings);

	return properties;
end

function script_defaults(settings)
	obs.obs_data_set_default_bool(settings, "is_script_enabled", true);
	obs.obs_data_set_default_bool(settings, "is_bot_enabled", true);
	obs.obs_data_set_default_string(settings, "output_mode", "simple_stream");
	
	obs.obs_data_set_default_int(settings, "timer_delay", 1000);
	obs.obs_data_set_default_int(settings, "bot_delay", 2000);
	
	obs.obs_data_set_default_string(settings, "channel_nickname", "");
	obs.obs_data_set_default_string(settings, "channel_password", "");
	
	obs.obs_data_set_default_bool(settings, "use_custom_bot", false);
	
	obs.obs_data_set_default_string(settings, "bot_nickname", "");
	obs.obs_data_set_default_string(settings, "bot_password", "");
	
	obs.obs_data_set_default_string(settings, "text_source", "");
	obs.obs_data_set_default_string(settings, "text_formatting", default_text_formatting);
end

function script_update(settings)
	my_settings = settings;

	is_script_enabled = obs.obs_data_get_bool(settings, "is_script_enabled");
	is_bot_enabled = obs.obs_data_get_bool(settings, "is_bot_enabled");
	output_mode = obs.obs_data_get_string(settings, "output_mode");
	
	timer_delay = obs.obs_data_get_int(settings, "timer_delay");
	bot_delay = obs.obs_data_get_int(settings, "bot_delay");
	
	channel_nickname = obs.obs_data_get_string(settings, "channel_nickname"):lower();
	channel_password = obs.obs_data_get_string(settings, "channel_password");
	
	use_custom_bot = obs.obs_data_get_bool(settings, "use_custom_bot");
	
	bot_nickname = obs.obs_data_get_string(settings, "bot_nickname"):lower();
	bot_password = obs.obs_data_get_string(settings, "bot_password");
	
	text_source = obs.obs_data_get_string(settings, "text_source");
	
	text_formatting = obs.obs_data_get_string(settings, "text_formatting");
	
	if not use_custom_bot then
		bot_nickname = channel_nickname;
		bot_password = channel_password;
	end
	
	if is_timer_on then
		close_sockets();
		
		is_timer_on = false;
	end

	local source = obs.obs_get_source_by_name(text_source)

	if source == nil then
		print("No source found");
		is_timer_on = false;
		return;
	end
	
	obs.obs_source_release(source);
	
	if not is_script_enabled then
		print("Script is disabled");
		is_timer_on = false;
		return;
	end
	
	print("Script is reloaded");
	is_timer_on = true;
	
	if is_bot_enabled then 
		init_sockets();
	end
	
	obs.timer_add(timer_tick, timer_delay);
end

function script_description()
	return [[
<center><h2>OBS Stats on Stream v0.6</h2></center>
<center><a href="https://twitch.tv/GreenComfyTea">twitch.tv/GreenComfyTea</a> - 2021</center>
<center><p>Shows missed frames, skipped frames, dropped frames, congestion, bitrate, fps, memory usage and average frame time on stream as text source and/or in Twitch chat.</p></center>
<center><a href="https://twitchapps.com/tmi/">Twitch Chat OAuth Password Generator</a></center>
<center><a href="https://github.com/GreenComfyTea/OBS-Stats-on-Stream/blob/main/Text-Formatting-Variables.md">Text Formatting Variables</a></center>
<center><a href="https://github.com/GreenComfyTea/OBS-Stats-on-Stream/blob/main/Bot-Commands.md">Bot commands</a></center>
<br>
<hr/>
]];
end

function script_load(settings)
	print("script loaded");
	obs.obs_frontend_add_event_callback(on_event);
end