local log = {};

local json;
local data;
local text_source_handler;

local obslua = obslua;
local require = require;
local script_path = script_path;
local print = print;

local file_output_name = "obs-stats_" .. os.date("%d.%m.%Y") .. ".log";

local log_file_formatting = [[
[$date_time] Streaming duration: $streaming_duration, Recording Duration: $recording_duration, Streaming status: $streaming_status, Recording_status: $recording_status, Encoder: $encoder, Output Mode: $output_mode, Canvas Resolution: $canvas_resolution, Output Resolution: $output_resolution, Missed Frames: $missed_frames/$missed_total_frames ($missed_percents%), Skipped Frames: $skipped_frames/$skipped_total_frames ($skipped_percents%), Dropped Frames: $dropped_frames/$dropped_total_frames ($dropped_percents%), Congestion: $congestion% (avg. $average_congestion%), Memory Usage: $memory_usage MB, CPU Cores: $cpu_cores, CPU Usage: $cpu_usage%, Frame Time: $average_frame_time ms, FPS: $fps/$target_fps (avg. $average_fps), Bitrate: $bitrate kb/s, Audio Bitrate: $audio_bitrate kb/s, Recording bitrate: $recording_bitrate kb/s
]];

function log.to_file()
	--print("Log to " .. file_output_name);

	local data_log = text_source_handler.format_text(log_file_formatting);
	--local data_log = json.encode(data.stats, { indent = false }) .. "\n";

	local script_path_ = script_path();
	local output_path = script_path_ .. file_output_name;

	local log_file = io.open(output_path, "a");
	log_file:write(data_log);
	log_file:close();
end

function log.init_module()
	json = require("modules.json");
	data = require("modules.data");
	text_source_handler = require("modules.text_source_handler");
end

return log;