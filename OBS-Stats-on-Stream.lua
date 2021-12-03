obs = obslua
local ffi = require("ffi")
local socket = require("ljsocket")

ffi.cdef[[
	struct video_output;
	typedef struct video_output video_t;

	struct os_cpu_usage_info;
	typedef struct os_cpu_usage_info os_cpu_usage_info_t;

	uint32_t video_output_get_skipped_frames(const video_t *video);
	uint32_t video_output_get_total_frames(const video_t *video);
	double video_output_get_frame_rate(const video_t *video);
	
	os_cpu_usage_info_t *os_cpu_usage_info_start(void);
	double os_cpu_usage_info_query(os_cpu_usage_info_t *info);
	void os_cpu_usage_info_destroy(os_cpu_usage_info_t *info);

	video_t *obs_get_video(void);
]]

local output_mode = "simple_stream";

local timer_delay = 1000;
local bot_delay = 2000;

local bot_password = "";
local bot_nickname = "justinfan4269";

local channel_nickname = "";

local text_source = "";
local text_formatting = "";

local is_script_enabled = true;
local is_bot_enabled = true;
local is_output_to_file_enabled = false;
local is_debug_mode_enabled = false;

local file_output_name = "obs-stats.json";
local log_file_name = "obs-stats_" .. os.date("%d.%m.%Y") .. ".log";

local default_text_formatting = [[
Missed Frames: $missed_frames/$missed_total_frames ($missed_percents%)
Skipped Frames: $skipped_frames/$skipped_total_frames ($skipped_percents%)
Dropped Frames: $dropped_frames/$dropped_total_frames ($dropped_percents%)
Congestion: $congestion% (avg. $average_congestion%)
Memory Usage: $memory_usage MB
CPU Usage: $cpu_usage%
Frame Time: $average_frame_time ms
FPS: $fps/$target_fps (avg. $average_fps)
Bitrate: $bitrate kb/s
]];

local file_output_formatting = [[
{
	"encoder": "$encoder",
	"output_mode": "$output_mode",
	
	"canvas_resolution": "$canvas_resolution",
	"output_resolution": "$output_resolution",

	"missed_frames": $missed_frames,
	"missed_total_frames": $missed_total_frames,
	"missed_percents": $missed_percents,

	"skipped_frames": $skipped_frames,
	"skipped_total_frames": $skipped_total_frames,
	"skipped_percents": $skipped_percents,

	"dropped_frames": $dropped_frames,
	"dropped_total_frames": $dropped_total_frames,
	"dropped_percents": $dropped_percents,

	"congestion": $congestion,
	"average_congestion": $average_congestion,

	"average_frame_time": $average_frame_time,
	"fps": $fps,
	"target_fps": $target_fps,
	"average_fps": $average_fps,
	
	"memory_usage": $memory_usage,
	"cpu_cores": "$cpu_cores",
	"cpu_usage": $cpu_usage,

	"audio_bitrate": $audio_bitrate,
	"recording_bitrate": $recording_bitrate,
	"bitrate": $bitrate,

	"streaming_duration": "$streaming_duration",
	"recording_duration": "$recording_duration",

	"streaming_status": "$streaming_status",
	"recording_status": "$recording_status"
}
]];

local log_file_formatting = [[
[$current_time] Streaming duration: $streaming_duration, Recording Duration: $recording_duration, Streaming status: $streaming_status, Recording_status: $recording_status, Encoder: $encoder, Output Mode: $output_mode, Canvas Resolution: $canvas_resolution, Output Resolution: $output_resolution, Missed Frames: $missed_frames/$missed_total_frames ($missed_percents%), Skipped Frames: $skipped_frames/$skipped_total_frames ($skipped_percents%), Dropped Frames: $dropped_frames/$dropped_total_frames ($dropped_percents%), Congestion: $congestion% (avg. $average_congestion%), Memory Usage: $memory_usage MB, CPU Cores: $cpu_cores, CPU Usage: $cpu_usage%, Frame Time: $average_frame_time ms, FPS: $fps/$target_fps (avg. $average_fps), Bitrate: $bitrate kb/s, Audio Bitrate: $audio_bitrate kb/s, Recording bitrate: $recording_bitrate kb/s
]];

local encoder_string = "x264?";
local output_mode_string = "Simple?";

local canvas_resolution_string = "1920x1080?";
local output_resolution_string = "1280x720?";

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

local memory_usage_string = "";
local cpu_usage_string = "";
local cpu_cores_string = "";

local average_frame_time_string = "";
local fps_string = "";
local target_fps_string = "30";
local average_fps_string = "";

local audio_bitrate_string = "160";
local bitrate_string = "";
local recording_bitrate_string = "";

local streaming_duration_string = "00:00:00";
local recording_duration_string = "00:00:00";

local streaming_status_string = "Offline";
local recording_status_string = "Off";

local bitrate = 0;
local last_bytes_sent = 0;
local last_bytes_time = 0;

local recording_bitrate = 0;
local recording_last_bytes_recorded = 0;

local is_timer_on = false;

local total_ticks = 0;
local congestion_cumulative = 0;
local fps_cumulative = 0;

local is_live = false;

local obsffi;
if ffi.os == "OSX" then
	obsffi = ffi.load("obs.0.dylib"); -- OS X
else
	obsffi = ffi.load("obs"); -- Windows
	-- Linux?
end

local cpu_info = nil;
local my_settings = nil;

local host = "irc.chat.twitch.tv";
local port = 6667;
local bot_socket = nil;

local auth_success = false;
local auth_requested = false;

function bot_socket_tick()
	if bot_socket:is_connected() then
		if not auth_success and not auth_requested then
			auth();
		end
		
		local response = receive();
		
		if response then
			for line in response:gmatch("[^\n]+") do
				repeat
					if not auth_success then
						auth_requested = false;
						if line:match(":tmi.twitch.tv 001") then
							bot_nickname = get_real_nickname(line);
							print("Authentication success: " .. bot_nickname);
							auth_success = true;
							
							send("JOIN #" .. channel_nickname);
							do break end
						else 
							print("Authentication to " .. bot_nickname .. " failed! Socket closed! Try reconnecting manually...");
							
							close_socket();
							return;
						end
					end
					
					if line:match("PING") then
						send("PONG");
						print("PING PONG");
						do break end
					end
					
					if line:match("JOIN") then
						print("Joined channel: " .. channel_nickname);
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
							if not word:match("󠀀") then
								if word:match("^@") then
									to_user = word:sub(2);
								else
									to_user = word;
								end
							end
							
						end
						
						i = i + 1;
					end

					if command:match("^!encoder") then
						send_message(string.format("@%s -> Encoder: %s", to_user, encoder_string));
						
					elseif command:match("^!output_mode") or command:match("^!outputmode") then
						send_message(string.format("@%s -> Output Mode: %s", to_user, output_mode_string));
						
					elseif command:match("^!canvas_resolution") or command:match("^!canvasresolution") then
						send_message(string.format("@%s -> Canvas Resolution: %s", to_user, canvas_resolution_string));
						
					elseif command:match("^!output_resolution") or command:match("^!outputresolution") then
						send_message(string.format("@%s -> Output Resolution: %s", to_user, output_resolution_string));
						
					elseif command:match("^!missed_frames") or command:match("^!missedframes") or command:match("^!missed") then
						send_message(string.format("@%s -> Missed Frames: %s/%s (%s%%)", to_user, lagged_frames_string, lagged_total_frames_string, lagged_percents_string));
						
					elseif command:match("^!skipped_frames") or command:match("^!skippedframes") or command:match("^!skipped") then
						send_message(string.format("@%s -> Skipped Frames: %s/%s (%s%%)", to_user, skipped_frames_string, skipped_total_frames_string, skipped_percents_string));
						
					elseif command:match("^!dropped_frames") or command:match("^!droppedframes") or command:match("^!dropped") then
						send_message(string.format("@%s -> Dropped Frames: %s/%s (%s%%)", to_user, dropped_frames_string, dropped_total_frames_string, dropped_percents_string));
						
					elseif command:match("^!congestion") then
						send_message(string.format("@%s -> Congestion: %s%% (average: %s%%)", to_user, congestion_string, average_congestion_string));
						
					elseif command:match("^!frame_time") or command:match("^!render_time") or command:match("^!frametime") or command:match("^!rendertime") then
						send_message(string.format("@%s -> Average Frame Time: %s ms", to_user, average_frame_time_string));
						
					elseif command:match("^!fps") or command:match("^!framerate") then
						send_message(string.format("@%s -> FPS: %s/%s (average: %s)", to_user, fps_string, target_fps_string, average_fps_string));
						
					elseif command:match("^!memory_usage") or command:match("^!memoryusage") or command:match("^!memory") then
						send_message(string.format("@%s -> Memory Usage: %s MB", to_user, memory_usage_string));
						
					elseif command:match("^!cpu_cores") or command:match("^!cpucores") or command:match("^!cores") then
						send_message(string.format("@%s -> CPU Cores: %s", to_user, cpu_cores_string));

					elseif command:match("^!cpu_usage") or command:match("^!cpuusage") then
						send_message(string.format("@%s -> CPU Usage: %s%%", to_user, cpu_usage_string));

					elseif command:match("^!audio_bitrate") or command:match("^!audiobitrate") then
						send_message(string.format("@%s -> Audio Bitrate: %s kb/s", to_user, audio_bitrate_string));

					elseif command:match("^!bitrate") then
						send_message(string.format("@%s -> Bitrate: %s kb/s", to_user, bitrate_string));

					elseif command:match("^!recording_bitrate") or command:match("^!recordingbitrate")then
						send_message(string.format("@%s -> Recording Bitrate: %s kb/s", to_user, recording_bitrate_string));

					elseif command:match("^!streaming_duration") or command:match("^!streamingduration") then
						send_message(string.format("@%s -> Streaming duration: %s", to_user, streaming_duration_string));
					
					elseif command:match("^!recording_duration") or command:match("^!recordingduration") then
						send_message(string.format("@%s -> Recording duration: %s", to_user, recording_duration_string));

					elseif command:match("^!streaming_status") or command:match("^!streamingstatus") then
						send_message(string.format("@%s -> Streaming status: %s", to_user, streaming_status_string));

					elseif command:match("^!recording_status") or command:match("^!recordingstatus") then
						send_message(string.format("@%s -> Recording status: %s", to_user, recording_status_string));
						
					elseif command:match("^!obs_static_stats") or command:match("^!obsstaticstats") then
						send_message(string.format("@%s -> Encoder: %s, Output Mode: %s, Canvas Resolution: %s, Output Resolution: %s, CPU cores: %s, Audio Bitrate: %s kb/s", to_user, encoder_string, output_mode_string, canvas_resolution_string, output_resolution_string, cpu_cores_string, audio_bitrate_string));

					elseif command:match("^!obs_stats") or command:match("^!obsstats") or command:match("^!obs_dynamic_stats") or command:match("^!obsdynamicstats")then
						send_message(string.format("@%s -> Missed frames: %s/%s (%s%%), Skipped frames: %s/%s (%s%%), Dropped frames: %s/%s (%s%%), Congestion: %s%% (average: %s%%), Average frame time: %s ms, FPS: %s/%s (average: %s), Memory usage: %s MB, CPU usage: %s%%, Bitrate: %s kb/s", to_user, lagged_frames_string, lagged_total_frames_string, lagged_percents_string, skipped_frames_string, skipped_total_frames_string, skipped_percents_string, dropped_frames_string, dropped_total_frames_string, dropped_percents_string, congestion_string, average_congestion_string, average_frame_time_string, fps_string, target_fps_string, average_fps_string, memory_usage_string, cpu_usage_string, bitrate_string));
					end
					
					do break end
				until true
			end
		end
	end
end

function auth()
	print("Authentication attempt: " .. bot_nickname);
	auth_requested = true;
	assert(bot_socket:send(
		string.format("PASS %s\r\nNICK %s\r\n", bot_password, bot_nickname)
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

function receive()
	local response, err = bot_socket:receive();
	if response then
		return response;
	elseif err ~= nil then
		if err == "timeout" then
			return;
		--"An established connection was aborted by the software in your host machine."
		elseif err:match("An established connection was aborted") then
			print(tostring(err));
			print("Reconnecting...");
			close_socket();
			init_socket();
		else
			error(err);
		end
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

function recconect()
	print("Reconnecting...");
	
	close_socket();

	if is_bot_enabled then
		init_socket();
	end
end
	
function init_socket()
	bot_socket = assert(socket.create("inet", "stream", "tcp"));
	assert(bot_socket:set_blocking(false));
	assert(bot_socket:connect(host, port));
	
	obs.timer_add(bot_socket_tick, bot_delay);
end

function close_socket()					
	obs.timer_remove(bot_socket_tick);


	if bot_socket ~= nil and bot_socket:is_connected() then
		bot_socket:close();
	end
	
	reset_bot_data();
end

function reset_bot_data()
	auth_success = false;
	auth_requested = false;
end

function obs_stats_tick()
	total_ticks = total_ticks + 1;
	
	-- Get CPU usage
	local cpu_usage = 0.0;
	if obsffi ~= nil then
		cpu_usage = obsffi.os_cpu_usage_info_query(cpu_info);
	end
	
	-- Get memory usage
	local memory_usage = obs.os_get_proc_resident_size() / (1024.0 * 1024.0);
	
	-- Get FPS/framerate
	local fps = obs.obs_get_active_fps();
	fps_cumulative = fps_cumulative + fps;
	
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
	local dropped_frames = 0;
	local congestion = 0.0;
	local total_bytes = 0;
	local total_frames = 0;

	-- local streaming_status = is_live ? "Live" : "Offline";
	local streaming_status = "Offline";
	if is_live then 
		streaming_status = "Live";
	end

	local streaming_duration_total_seconds = 0;

	local streaming_output = obs.obs_frontend_get_streaming_output();
	-- output will be nil when not actually streaming
	if streaming_output ~= nil then
		dropped_frames = obs.obs_output_get_frames_dropped(streaming_output);
		congestion = obs.obs_output_get_congestion(streaming_output);
		total_bytes = obs.obs_output_get_total_bytes(streaming_output);
		--local connect_time = obs.obs_output_get_connect_time_ms(streaming_output)
		
		-- Streaming status
		local is_reconnecting = obs.obs_output_reconnecting(streaming_output);
		if is_reconnecting then
			streaming_status = "Reconnecting";
		end

		-- Get streaming duration
		total_frames = obs.obs_output_get_total_frames(streaming_output);
		streaming_duration_total_seconds =  total_frames / fps;

		obs.obs_output_release(streaming_output);
	end
	
	-- Check that congestion is not NaN
	if(congestion == congestion) then
		congestion_cumulative = congestion_cumulative + congestion
	end

	-- Get bitrate
	local current_time = obs.os_gettime_ns();
	local time_passed = (current_time - last_bytes_time) / 1000000000.0;
	
	if time_passed > 2.0 then
		local bytes_sent = total_bytes;
		
		if bytes_sent < last_bytes_sent then
			bytes_sent = 0;
		end
		if bytes_sent == 0 then
			last_bytes_sent = 0;
		end
		
		local bits_between = (bytes_sent - last_bytes_sent) * 8;
		bitrate = bits_between / time_passed / 1000.0;

		last_bytes_sent = bytes_sent;
		last_bytes_time = current_time;
	end
	
	local recording_duration_total_seconds = 0;

	-- Get recording bitrate
	if obs.obs_frontend_recording_active() then
		local recording_output = obs.obs_frontend_get_recording_output();
		local recording_total_bytes = 0;

		if recording_output ~= nil then
			recording_total_bytes = obs.obs_output_get_total_bytes(recording_output);

			-- Get recording duration
			local recording_total_frames = obs.obs_output_get_total_frames(recording_output);
			recording_duration_total_seconds = recording_total_frames / fps;

			obs.obs_output_release(recording_output);
		end
		
		if time_passed > 2.0 then
			local recording_bytes_recorded = recording_total_bytes;
			
			if recording_bytes_recorded < recording_last_bytes_recorded then
				recording_bytes_recorded = 0;
			end
			if recording_bytes_recorded == 0 then
				recording_last_bytes_recorded = 0;
			end
			
			local recording_bits_between = (recording_bytes_recorded - recording_last_bytes_recorded) * 8;
			recording_bitrate = recording_bits_between / time_passed / 1000.0;

			recording_last_bytes_recorded = recording_bytes_recorded;
		end
	end

	-- fix NaN
	if rendered_frames == 0 then
		rendered_frames = 1;
	end
	
	if encoded_frames == 0 then
		encoded_frames = 1;
	end
	
	if total_frames == 0 then
		total_frames = 1;
	end
	
	if total_ticks == 0 then
		total_ticks = 1;
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
	fps_string = string.format("%.2g", fps);
	average_fps_string = string.format("%.2g", fps_cumulative / total_ticks);
	
	memory_usage_string = string.format("%.1f", memory_usage);
	cpu_usage_string = string.format("%.1f", cpu_usage);

	bitrate_string = string.format("%.0f", bitrate);
	recording_bitrate_string = string.format("%.0f", recording_bitrate);

	streaming_status_string = string.format("%s", streaming_status);

	-- Time formating
	if is_live then
		local streaming_hours = string.format("%d", math.floor(streaming_duration_total_seconds / 3600));
		local streaming_minutes = string.format("%d", math.floor((streaming_duration_total_seconds % 3600) / 60));
		local streaming_seconds = string.format("%d", math.floor(0.5 + streaming_duration_total_seconds % 60));
	
		if string.len(streaming_hours) <= 1 then
			streaming_hours = "0" .. streaming_hours;
		end
	
		if string.len(streaming_minutes) <= 1 then
			streaming_minutes = "0" .. streaming_minutes;
		end
	
		if string.len(streaming_seconds) <= 1 then
			streaming_seconds = "0" .. streaming_seconds;
		end

		streaming_duration_string = string.format("%s:%s:%s", streaming_hours, streaming_minutes, streaming_seconds);
	else
		streaming_duration_string = "00:00:00";
	end

	if recording_status_string ~= "Off" then
		local recording_hours = string.format("%d", math.floor(recording_duration_total_seconds / 3600));
		local recording_minutes = string.format("%d", math.floor((recording_duration_total_seconds % 3600) / 60));
		local recording_seconds = string.format("%d", math.floor(0.5 + recording_duration_total_seconds % 60));

		if string.len(recording_hours) <= 1 then
			recording_hours = "0" .. recording_hours;
		end

		if string.len(recording_minutes) <= 1 then
			recording_minutes = "0" .. recording_minutes;
		end

		if string.len(recording_seconds) <= 1 then
			recording_seconds = "0" .. recording_seconds;
		end

		recording_duration_string = string.format("%s:%s:%s", recording_hours, recording_minutes, recording_seconds);
	else
		recording_duration_string = "00:00:00";
	end

	local source = obs.obs_get_source_by_name(text_source);
	-- Update text source
	if source ~= nil then
		-- Make a string for display in a text source
		local formatted_text = format_variables(text_formatting);

		local settings = obs.obs_data_create();
		obs.obs_data_set_string(settings, "text", formatted_text);
		obs.obs_source_update(source, settings);
		obs.obs_source_release(source);
		obs.obs_data_release(settings);
	end

	if is_output_to_file_enabled then
		local formatted_file_text = format_variables(file_output_formatting);
		save_output_to_file(formatted_file_text);
	end

	if is_debug_mode_enabled then
		local formatted_log_file_text = format_variables(log_file_formatting);
		log_to_file(formatted_log_file_text);
	end
end

function log_to_file(file_json_text)
	local script_path_ = script_path();
	local log_file_path = script_path_ .. log_file_name;

	local log_file = io.open(log_file_path, "a");
	log_file:write(file_json_text);
	log_file:close();
end

function save_output_to_file(file_json_text)
	local script_path_ = script_path();
	local output_path = script_path_ .. file_output_name;

	obs.os_quick_write_utf8_file(output_path, file_json_text, #file_json_text, false);
end

function read_profile_config()
	local profile = obs.obs_frontend_get_current_profile():gsub("[^%w_ ]", ""):gsub("%s", "_");
	
	local profile_relative_path = "obs-studio\\basic\\profiles\\" .. profile .. "\\basic.ini";
	
	-- char dst[512];
	local profile_path = "                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                ";
	obs.os_get_abs_path("..\\..\\config\\" .. profile_relative_path, profile_path, #profile_path);
	
	if not obs.os_file_exists(profile_path) then	
		obs.os_get_config_path(profile_path, #profile_path, profile_relative_path);
	
		if not obs.os_file_exists(profile_path) then	
			print("Config file not found.");
			return;
		end
	end

	local config_text = obs.os_quick_read_utf8_file(profile_path);

	if(config_text == nil) then 
		print("Couldn't read config file.");
		return;
	end
	
	print("Config loaded: " ..  profile_path);
	
	local config = parse_ini(config_text);
	
	if config.Video ~= nil then
		if config.Video.BaseCX ~= nil and config.Video.BaseCY ~= nil then
			canvas_resolution_string = string.format("%sx%s", config.Video.BaseCX, config.Video.BaseCY);
		end 
		
		if config.Video.OutputCX ~= nil and config.Video.OutputCY ~= nil then
			output_resolution_string = string.format("%sx%s", config.Video.OutputCX, config.Video.OutputCY);
		end 
	
		if config.Video.FPSCommon ~= nil then
			target_fps_string = config.Video.FPSCommon;
		end 
	end

	if config.Output ~= nil then
		if config.Output.Mode ~= nil then
			output_mode_string = config.Output.Mode;
			if config.Output.Mode == "Simple" then
				output_mode = "simple_stream";
			else
				output_mode = "adv_stream";
			end
		end
	end

	if output_mode == "simple_stream" then
		if config.SimpleOutput ~= nil then
			if config.SimpleOutput.StreamEncoder ~= nil then
				encoder_string_string = config.SimpleOutput.StreamEncoder;
			end
			
			if config.SimpleOutput.ABitrate ~= nil then
				audio_bitrate_string = config.SimpleOutput.ABitrate;
			end
		end
	else
		if config.AdvOut ~= nil then
			if config.AdvOut.Encoder ~= nil then
				encoder_string = config.AdvOut.Encoder;
			end
			
			if config.AdvOut.Track1Bitrate ~= nil then
				audio_bitrate_string = config.AdvOut.Track1Bitrate;
			end
		end
	end
end

function parse_ini(ini_text)
	local data = {};
	local section;
	for line in ini_text:gmatch("[^\r\n]+") do
		local tempSection = line:match('^%[([^%[%]]+)%]$');
		if(tempSection) then
			section = tonumber(tempSection) and tonumber(tempSection) or tempSection;
			data[section] = data[section] or {};
		end
		local param, value = line:match('^([%w|_]+)%s-=%s-(.+)$');
		if(param and value ~= nil) then
			if(tonumber(value)) then
				value = tonumber(value);
			elseif(value == 'true') then
				value = true;
			elseif(value == 'false') then
				value = false;
			end
			if(tonumber(param)) then
				param = tonumber(param);
			end
			data[section][param] = value;
		end
	end
	return data;
end

function reset_formatting(properties, property)
	text_formatting = default_text_formatting;

	obs.obs_data_set_string(my_settings, "text_formatting", default_text_formatting);
	obs.obs_properties_apply_settings(properties, my_settings);

	return true;
end

function start_cpu_usage_info()
	if obsffi ~= nil then
		cpu_info = obsffi.os_cpu_usage_info_start();
	end
end

function destroy_cpu_usage_info()
	if cpu_info ~= nil and obsffi ~= nil then
		obsffi.os_cpu_usage_info_destroy(cpu_info);
		cpu_info = nil;
	end
end

function format_variables(unformatted_text)
	local formatted_text = unformatted_text;

	formatted_text = formatted_text:gsub("$current_time", os.date("%d.%m.%Y %X"));

	formatted_text = formatted_text:gsub("$encoder", encoder_string);
	formatted_text = formatted_text:gsub("$output_mode", output_mode_string);
	
	formatted_text = formatted_text:gsub("$canvas_resolution", canvas_resolution_string);
	formatted_text = formatted_text:gsub("$output_resolution", output_resolution_string);

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
	formatted_text = formatted_text:gsub("$fps", fps_string);
	formatted_text = formatted_text:gsub("$target_fps", target_fps_string);
	formatted_text = formatted_text:gsub("$average_fps", average_fps_string);
	
	formatted_text = formatted_text:gsub("$memory_usage", memory_usage_string);
	formatted_text = formatted_text:gsub("$cpu_cores", cpu_cores_string);
	formatted_text = formatted_text:gsub("$cpu_usage", cpu_usage_string);

	formatted_text = formatted_text:gsub("$audio_bitrate", audio_bitrate_string);
	formatted_text = formatted_text:gsub("$recording_bitrate", recording_bitrate_string);
	formatted_text = formatted_text:gsub("$bitrate", bitrate_string);

	formatted_text = formatted_text:gsub("$streaming_duration", streaming_duration_string);
	formatted_text = formatted_text:gsub("$recording_duration", recording_duration_string);

	formatted_text = formatted_text:gsub("$streaming_status", streaming_status_string);
	formatted_text = formatted_text:gsub("$recording_status", recording_status_string);

	return formatted_text;
end

function on_event(event)
	if event == obs.OBS_FRONTEND_EVENT_FINISHED_LOADING then
		print("scene loaded");
		read_profile_config();

		if is_script_enabled then
			print("script is enabled");
			is_timer_on = true;
			
			obs.timer_add(obs_stats_tick, timer_delay);

			start_cpu_usage_info();

			if is_bot_enabled then
				init_socket();
			end
		end
	elseif event == obs.OBS_FRONTEND_EVENT_STREAMING_STARTED then
		is_live = true;
	elseif event == obs.OBS_FRONTEND_EVENT_STREAMING_STOPPED then
		is_live = false;
	elseif event == obs.OBS_FRONTEND_EVENT_RECORDING_STARTED then
		recording_status_string = "On";
	elseif event == obs.OBS_FRONTEND_EVENT_RECORDING_STOPPED then
		recording_status_string = "Off";
	elseif event == obs.OBS_FRONTEND_EVENT_RECORDING_PAUSED then
		recording_status_string = "Paused";
	elseif event == obs.OBS_FRONTEND_EVENT_RECORDING_UNPAUSED then
		recording_status_string = "On";
	elseif event == obs.OBS_FRONTEND_EVENT_STREAMING_STARTING or 
		event == obs.OBS_FRONTEND_EVENT_STREAMING_STOPPING or 
		event == obs.OBS_FRONTEND_EVENT_RECORDING_STARTING or 
		event == obs.OBS_FRONTEND_EVENT_RECORDING_STOPPING then
		read_profile_config();
	end
end
		
function script_properties()
	local properties = obs.obs_properties_create();

	local enable_script_property = obs.obs_properties_add_bool(properties, "is_script_enabled", "Enable Script");
	local enable_bot_property = obs.obs_properties_add_bool(properties, "is_bot_enabled", "Enable Bot");
	
	local timer_delay_property = obs.obs_properties_add_int(properties, "timer_delay", "Update Delay (ms)", 100, 2000, 100);
	obs.obs_property_set_long_description(timer_delay_property, "Determines how often the data will update.");

	local bot_delay_property = obs.obs_properties_add_int(properties, "bot_delay", "Bot Delay (ms)", 500, 5000, 100);
	obs.obs_property_set_long_description(bot_delay_property, "Determines how often the bot will read chat and write to it.");
	
	local bot_nickname_property = obs.obs_properties_add_text(properties, "bot_nickname", "Bot Nickname", obs.OBS_TEXT_DEFAULT);
	obs.obs_property_set_long_description(bot_nickname_property, "Nickname of your bot.");
	
	local bot_oauth_property = obs.obs_properties_add_text(properties, "bot_password", "Bot OAuth Password", obs.OBS_TEXT_PASSWORD);
	obs.obs_property_set_long_description(bot_oauth_property, "Format: oauth:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx. Visit https://twitchapps.com/tmi/ to get the AOuth Password for the bot (you must login to twitch.tv accordingly.");
	
	local channel_nickname_property = obs.obs_properties_add_text(properties, "channel_nickname", "Channel Nickname", obs.OBS_TEXT_DEFAULT);
	obs.obs_property_set_long_description(channel_nickname_property, "Nickname of your channel for bot to join. If empty bot will join his own chat.");
	
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

	local enable_output_to_file_property = obs.obs_properties_add_bool(properties, "is_output_to_file_enabled", "Output to File");
	local enable_debug_mode_property = obs.obs_properties_add_bool(properties, "is_debug_mode_enabled", "Debug Mode");

	obs.obs_properties_apply_settings(properties, my_settings);

	return properties;
end

function script_defaults(settings)
	obs.obs_data_set_default_bool(settings, "is_script_enabled", true);
	obs.obs_data_set_default_bool(settings, "is_bot_enabled", true);
	
	obs.obs_data_set_default_int(settings, "timer_delay", 1000);
	obs.obs_data_set_default_int(settings, "bot_delay", 2000);

	obs.obs_data_set_default_string(settings, "bot_nickname", "");
	obs.obs_data_set_default_string(settings, "bot_password", "");
	
	obs.obs_data_set_default_string(settings, "channel_nickname", "");
	
	obs.obs_data_set_default_string(settings, "text_source", "");
	obs.obs_data_set_default_string(settings, "text_formatting", default_text_formatting);

	obs.obs_data_set_default_bool(settings, "is_output_to_file_enabled", false);
	obs.obs_data_set_default_bool(settings, "is_debug_mode_enabled", false);
end

function script_update(settings)
	my_settings = settings;

	is_script_enabled = obs.obs_data_get_bool(settings, "is_script_enabled");
	is_bot_enabled = obs.obs_data_get_bool(settings, "is_bot_enabled");
	
	timer_delay = obs.obs_data_get_int(settings, "timer_delay");
	bot_delay = obs.obs_data_get_int(settings, "bot_delay");
	
	bot_nickname = obs.obs_data_get_string(settings, "bot_nickname"):lower();
	bot_password = obs.obs_data_get_string(settings, "bot_password");
	channel_nickname = obs.obs_data_get_string(settings, "channel_nickname"):lower();
	
	text_source = obs.obs_data_get_string(settings, "text_source");
	text_formatting = obs.obs_data_get_string(settings, "text_formatting");

	is_output_to_file_enabled = obs.obs_data_get_bool(settings, "is_output_to_file_enabled");
	is_debug_mode_enabled = obs.obs_data_get_bool(settings, "is_debug_mode_enabled");

	local physical_cores = obs.os_get_physical_cores();
	local logical_cores = obs.os_get_logical_cores();

	is_live = obs.obs_frontend_streaming_active();
	
	local recording_active = obs.obs_frontend_recording_active();
	if obs.obs_frontend_recording_active() then
		if obs.obs_frontend_recording_paused() then
			recording_status_string = "Paused";
		else 
			recording_status_string = "On";
		end
	else
		recording_status_string = "Off";
	end

	cpu_cores_string = string.format("%sC/%sT", physical_cores, logical_cores);

	read_profile_config();

	if channel_nickname == nil or channel_nickname:match("%S") == nil then
		channel_nickname = bot_nickname;
	end
	
	if is_obs_stats_timer_on then
		close_socket();

		destroy_cpu_usage_info();

		is_obs_stats_timer_on = false;
		obs.timer_remove(obs_stats_tick);
	end

	local source = obs.obs_get_source_by_name(text_source)

	if source == nil then
		print("No source found");
	end
	
	obs.obs_source_release(source);
	
	if not is_script_enabled then
		print("Script is disabled");
		is_obs_stats_timer_on = false;
		return;
	end
	
	print("Script is reloaded");
	is_obs_stats_timer_on = true;
	
	if is_bot_enabled then 
		init_socket();
	end
	
	start_cpu_usage_info();

	obs.timer_add(obs_stats_tick, timer_delay);
end

function script_description()
	return [[
<center><h2>OBS Stats on Stream v1.3</h2></center>
<center><a href="https://twitch.tv/GreenComfyTea">twitch.tv/GreenComfyTea</a> - 2021</center>
<center><p>Shows obs stats on stream and/or in Twitch chat. Supported data: encoder, output mode, canvas resolution, output resolution, missed frames, skipped frames, dropped frames, congestion,  average frame time, fps, memory usage, cpu core count, cpu usage, recording and streaming duration, audio bitrate, recording bitrate and streaming bitrate streaming status and recording status.</p></center>
<center><a href="https://twitchapps.com/tmi/">Twitch Chat OAuth Password Generator</a></center>
<center><a href="https://github.com/GreenComfyTea/OBS-Stats-on-Stream/blob/main/Text-Formatting-Variables.md">Text Formatting Variables</a></center>
<center><a href="https://github.com/GreenComfyTea/OBS-Stats-on-Stream/blob/main/Bot-Commands.md">Bot commands</a></center>
<hr/>
]];
end

function script_load(settings)
	obs.obs_frontend_add_event_callback(on_event);
	print("script loaded");
end