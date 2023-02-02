local bot = {};

local script_handler;
local data_format;
local ljsocket;
local utils;

local obslua = obslua;
local require = require;
local assert = assert;
local string = string;
local print = print;
local error = error;
local tostring = tostring;

local host = "irc.chat.twitch.tv";
local port = 6667;
local bot_socket = nil;

local bot_nickname = "";
local bot_password = "";

local auth_success = false;
local auth_requested = false;

local joined_channel = "";

local password_length = 36;
local short_password_length = 30;

local oauth_string = "oauth:";

bot.is_timer_on = false;

function bot.tick()
	--print("Bot Tick");

	if not script_handler.is_script_enabled then
		return;
	end

	if bot_socket:is_connected() then
		if not auth_success and not auth_requested then
			bot.auth();
		end
		
		local response, err = bot.receive();

		if response ~= nil then
			for line in response:gmatch("[^\n]+") do
				if not auth_success then
					auth_requested = false;
					if line:match(":tmi.twitch.tv 001") then
						bot_nickname = bot.get_real_nickname(line);
						print("Authentication success: " .. bot_nickname);
						auth_success = true;
						
						bot.join_channel();
						goto continue;
					else 
						print("Authentication to " .. bot_nickname .. " failed! Socket closed! Trying to reconnect...");
						
						bot.reconnect();
						return;
					end
				end
				
				if line:match("PING") then
					bot.send("PONG");
					print("PING PONG");
					goto continue;
				end
				
				if line:match("JOIN") then
					print("Joined Channel: " .. joined_channel);
					goto continue;
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

				bot.process_commands(to_user, command);
				
				::continue::
			end
		end
	else
		bot_socket:poll_connect();
	end
end

function bot.process_commands(to_user, command)
	local formatted_stats = data_format.stats;

	if command:match("^!encoder") then

		bot.send_message(string.format("@%s -> Encoder: %s",
			to_user,
			formatted_stats.encoder
		));

	elseif command:match("^!output_mode") or command:match("^!outputmode") then

		bot.send_message(string.format("@%s -> Output Mode: %s",
			to_user,
			formatted_stats.output_mode
		));
		
	elseif command:match("^!canvas_resolution") or command:match("^!canvasresolution") then

		bot.send_message(string.format("@%s -> Canvas Resolution: %s",
			to_user,
			formatted_stats.canvas_resolution
		));
		
	elseif command:match("^!output_resolution") or command:match("^!outputresolution") then

		bot.send_message(string.format("@%s -> Output Resolution: %s",
			to_user,
			formatted_stats.output_resolution
		));
		
	elseif command:match("^!missed_frames") or command:match("^!missedframes") or command:match("^!missed") then

		bot.send_message(string.format("@%s -> Missed Frames: %s/%s (%s%%)",
			to_user,
			formatted_stats.missed_frames,
			formatted_stats.total_missed_frames,
			formatted_stats.missed_percents
		));
		
	elseif command:match("^!skipped_frames") or command:match("^!skippedframes") or command:match("^!skipped") then

		bot.send_message(string.format("@%s -> Skipped Frames: %s/%s (%s%%)",
			to_user,
			formatted_stats.skipped_frames,
			formatted_stats.total_skipped_frames,
			formatted_stats.skipped_percents
		));
		
	elseif command:match("^!dropped_frames") or command:match("^!droppedframes") or command:match("^!dropped") then

		bot.send_message(string.format("@%s -> Dropped Frames: %s/%s (%s%%)",
			to_user,
			formatted_stats.dropped_frames,
			formatted_stats.total_dropped_frames,
			formatted_stats.dropped_percents
		));
		
	elseif command:match("^!congestion") then

		bot.send_message(string.format("@%s -> Congestion: %s%% (Average: %s%%)",
			to_user,
			formatted_stats.congestion,
			formatted_stats.average_congestion
		));
		
	elseif command:match("^!frame_time") or command:match("^!render_time") or command:match("^!frametime") or command:match("^!rendertime") then

		bot.send_message(string.format("@%s -> Average Frame Time: %s ms",
			to_user,
			formatted_stats.average_frame_time
		));
		
	elseif command:match("^!fps") or command:match("^!framerate") then

		bot.send_message(string.format("@%s -> FPS: %s/%s (Average: %s)",
			to_user,
			formatted_stats.fps,
			formatted_stats.target_fps,
			formatted_stats.average_fps
		));
		
	elseif command:match("^!memory_usage") or command:match("^!memoryusage") or command:match("^!memory") then

		bot.send_message(string.format("@%s -> Memory Usage: %s MB",
			to_user,
			formatted_stats.memory_usage
		));
		
	elseif command:match("^!cpu_cores") or command:match("^!cpucores") or command:match("^!cores") then

		bot.send_message(string.format("@%s -> CPU Cores: %s",
			to_user,
			formatted_stats.cpu_cores
		));

	elseif command:match("^!cpu_usage") or command:match("^!cpuusage") then

		bot.send_message(string.format("@%s -> CPU Usage: %s%%",
			to_user,
			formatted_stats.cpu_usage
		));

	elseif command:match("^!audio_bitrate") or command:match("^!audiobitrate") then

		bot.send_message(string.format("@%s -> Audio Bitrate: %s kb/s",
			to_user,
			formatted_stats.audio_bitrate
		));

	elseif command:match("^!bitrate") then

		bot.send_message(string.format("@%s -> Bitrate: %s kb/s",
			to_user,
			formatted_stats.bitrate
		));

	elseif command:match("^!recording_bitrate") or command:match("^!recordingbitrate")then

		bot.send_message(string.format("@%s -> Recording Bitrate: %s kb/s",
			to_user,
			formatted_stats.recording_bitrate
		));

	elseif command:match("^!streaming_duration") or command:match("^!streamingduration") then

		bot.send_message(string.format("@%s -> Streaming Duration: %s",
			to_user, 
			formatted_stats.streaming_duration
		));
	
	elseif command:match("^!recording_duration") or command:match("^!recordingduration") then

		bot.send_message(string.format("@%s -> Recording Duration: %s",
			to_user,
			formatted_stats.recording_duration
		));

	elseif command:match("^!streaming_status") or command:match("^!streamingstatus") then

		bot.send_message(string.format("@%s -> Streaming Status: %s",
			to_user, 
			formatted_stats.streaming_status
		));

	elseif command:match("^!recording_status") or command:match("^!recordingstatus") then

		bot.send_message(string.format("@%s -> Recording Status: %s",
			to_user,
			formatted_stats.recording_status
		));
		
	elseif command:match("^!obs_static_stats") or command:match("^!obsstaticstats") then

		bot.send_message(string.format("@%s -> Encoder: %s, Output Mode: %s, Canvas Resolution: %s, Output Resolution: %s, CPU Cores: %s, Audio Bitrate: %s kb/s",
			to_user,
			formatted_stats.encoder,
			formatted_stats.output_mode,
			formatted_stats.canvas_resolution,
			formatted_stats.output_resolution,
			formatted_stats.cpu_cores,
			formatted_stats.audio_bitrate
		));

	elseif command:match("^!obs_stats") or command:match("^!obsstats") or command:match("^!obs_dynamic_stats") or command:match("^!obsdynamicstats") then

		bot.send_message(string.format("@%s -> Missed: %s/%s (%s%%), Skipped: %s/%s (%s%%), Dropped: %s/%s (%s%%), Cong.: %s%% (average: %s%%), Frame Time: %s ms, FPS: %s/%s (average: %s), RAM: %s MB, CPU: %s%%, Bitrate: %s kb/s",
			to_user,
			formatted_stats.missed_frames,
			formatted_stats.total_missed_frames,
			formatted_stats.missed_percents,
			formatted_stats.skipped_frames,
			formatted_stats.total_skipped_frames,
			formatted_stats.skipped_percents,
			formatted_stats.dropped_frames,
			formatted_stats.total_dropped_frames,
			formatted_stats.dropped_percents,
			formatted_stats.congestion,
			formatted_stats.average_congestion,
			formatted_stats.average_frame_time,
			formatted_stats.fps,
			formatted_stats.target_fps,
			formatted_stats.average_fps,
			formatted_stats.memory_usage,
			formatted_stats.cpu_usage,
			formatted_stats.bitrate
		));
	end
end

function bot.auth()
	print("Authentication attempt: " .. bot_nickname);
	auth_requested = true;
	assert(bot_socket:send(
		string.format("PASS %s\r\nNICK %s\r\n", bot_password, bot_nickname)
	));
end

function bot.send(message)
	print(string.format("Sending Message: %s", message));
	assert(bot_socket:send(
		string.format("%s\r\n", message)
	));
end

function bot.send_message(message)
	print(string.format("Sending Message to %s: %s", joined_channel, message));
	assert(bot_socket:send(
		string.format("PRIVMSG #%s :%s\r\n", joined_channel, message)
	));
end

function bot.receive()
	local response, err = bot_socket:receive();

	if response ~= nil then
		return response;
	elseif err ~= nil then
		if err == "timeout" then
			return nil;
		--"An established connection was aborted by the software in your host machine."
		elseif err:match("An established connection was aborted") then
			print(tostring(err));
			bot.reconnect();
			return nil;
		else
			print(tostring(err));
			return nil;
		end
	else
		print("Unknown Error");
		return nil;
	end
end

function bot.join_channel(channel)
	if channel == nil or channel == "" then
		channel = script_handler.channel_nickname;
	end

	if channel == nil or channel == "" then
		channel = bot_nickname;
	end

	joined_channel = channel;
	bot.send("JOIN #" .. channel);

end

function bot.get_real_nickname(line)
	local i = 0;
	for word in line:gmatch("[^%s]+") do
		if i == 2 then
			return word;
		end
		i = i + 1;
	end
end

function bot.reconnect()
	print("Reconnecting...");
	
	bot.close_socket();
	bot.init_socket();
end
	
function bot.init_socket()
	if not script_handler.is_bot_enabled then
		return;
	end

	local nickname = bot.validate_nickname(script_handler.bot_nickname);
	local password = bot.validate_password(script_handler.bot_password);

	if nickname ~= nil then
		bot_nickname = nickname;
	else
		return;
	end

	if password ~= nil then
		bot_password = password;
	else
		return;
	end

	bot_socket = assert(ljsocket.create("inet", "stream", "tcp"));
	assert(bot_socket:set_blocking(false));
	assert(bot_socket:connect(host, port));

	if not bot.is_timer_on then
		bot.is_timer_on = true;
		obslua.timer_add(bot.tick, script_handler.bot_delay);

		print("Bot Timer added.");
	end
end

function bot.close_socket()
	if bot.is_timer_on then
		bot.is_timer_on = false;
		obslua.timer_remove(bot.tick);

		print("Bot Timer removed.");
	end

	if bot_socket ~= nil then
		bot_socket:close();
		bot_socket = nil;
	end
	
	bot.reset_data();
end

function bot.close_socket_on_unload()
	if bot_socket ~= nil then
		bot_socket:close();
	end
end

function bot.validate_nickname(nickname)
	if nickname == nil then
		print("No Bot Nickname provided.");
		return nil;
	end

	nickname = utils.trim(nickname):lower();

	if nickname == "" then
		print("No Bot Nickname provided.");
		return nil;
	end

	return nickname;
end

function bot.validate_password(password)
	if password == nil then
		print("No Bot OAuth Password provided.");
		return nil;
	end

	password = utils.trim(password):lower();

	if password == "" then
		print("No Bot OAuth Password provided.");
		return nil;
	end

	if utils.starts_with(password, oauth_string) then
		if #password ~= password_length then
			print("Incorrect OAuth Password provided.");
			return nil;
		end
	else
		if #password ~= short_password_length then
			print("Incorrect OAuth Password provided.");
			return nil;
		end

		password = oauth_string .. password;
	end

	return password;
end

function bot.reset_data()
	auth_success = false;
	auth_requested = false;
end

function bot.init_module()
	script_handler = require("modules.script_handler");
	data_format = require("modules.data_format");
	ljsocket = require("modules.ljsocket");
	utils = require("modules.utils");
end

return bot;