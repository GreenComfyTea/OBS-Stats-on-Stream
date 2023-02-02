local text_source_handler = {};

local data_format;
local script_handler;
local utils;

local obslua = obslua;
local print = print;
local os = os;
local tostring = tostring;
local string = string;
local require = require;

text_source_handler.default_formatting = [[
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

function text_source_handler.update()
	--print("Text Source Update Tick.");

	local text_source_name = script_handler.text_source;

	if text_source_name == nil or text_source_name == "" then
		print("Text Source not specified.");
		return;
	end

	local source = obslua.obs_get_source_by_name(text_source_name);
	if source == nil then
		print("Text Source not found.");
	end

	-- Make a string for display in a text source
	local formatted_text = text_source_handler.format_text(script_handler.text_formatting);

	local settings = obslua.obs_data_create();
	obslua.obs_data_set_string(settings, "text", formatted_text);
	obslua.obs_source_update(source, settings);
	obslua.obs_source_release(source);
	obslua.obs_data_release(settings);
end

function text_source_handler.format_text(text_formatting)
	local formatted_text = text_formatting;
	local formatted_stats = data_format.stats;

	formatted_text = formatted_text:gsub("$date_time", formatted_stats.date_time);
	formatted_text = formatted_text:gsub("$date", formatted_stats.date);
	formatted_text = formatted_text:gsub("$time", formatted_stats.time);

	formatted_text = formatted_text:gsub("$encoder", formatted_stats.encoder);
	formatted_text = formatted_text:gsub("$output_mode", formatted_stats.output_mode);

	formatted_text = formatted_text:gsub("$canvas_width", formatted_stats.canvas_width);
	formatted_text = formatted_text:gsub("$canvas_height", formatted_stats.canvas_height);
	formatted_text = formatted_text:gsub("$canvas_resolution", formatted_stats.canvas_resolution);

	formatted_text = formatted_text:gsub("$output_width", formatted_stats.output_width);
	formatted_text = formatted_text:gsub("$output_height", formatted_stats.output_height);
	formatted_text = formatted_text:gsub("$output_resolution", formatted_stats.output_resolution);

	formatted_text = formatted_text:gsub("$missed_frames", formatted_stats.missed_frames);
	formatted_text = formatted_text:gsub("$missed_total_frames", formatted_stats.total_missed_frames);
	formatted_text = formatted_text:gsub("$total_missed_frames", formatted_stats.total_missed_frames);
	formatted_text = formatted_text:gsub("$missed_percents", formatted_stats.missed_percents);

	formatted_text = formatted_text:gsub("$skipped_frames", formatted_stats.skipped_frames);
	formatted_text = formatted_text:gsub("$skipped_total_frames", formatted_stats.total_skipped_frames);
	formatted_text = formatted_text:gsub("$total_skipped_frames", formatted_stats.total_skipped_frames);
	formatted_text = formatted_text:gsub("$skipped_percents", formatted_stats.skipped_percents);

	formatted_text = formatted_text:gsub("$dropped_frames", formatted_stats.dropped_frames);
	formatted_text = formatted_text:gsub("$dropped_total_frames", formatted_stats.total_dropped_frames);
	formatted_text = formatted_text:gsub("$total_dropped_frames", formatted_stats.total_dropped_frames);
	formatted_text = formatted_text:gsub("$dropped_percents", formatted_stats.dropped_percents);

	formatted_text = formatted_text:gsub("$congestion", formatted_stats.congestion);
	formatted_text = formatted_text:gsub("$average_congestion", formatted_stats.average_congestion);

	formatted_text = formatted_text:gsub("$average_frame_time", formatted_stats.average_frame_time);
	formatted_text = formatted_text:gsub("$fps", formatted_stats.fps);
	formatted_text = formatted_text:gsub("$target_fps", formatted_stats.target_fps);
	formatted_text = formatted_text:gsub("$average_fps", formatted_stats.average_fps);
	
	formatted_text = formatted_text:gsub("$memory_usage", formatted_stats.memory_usage);
	formatted_text = formatted_text:gsub("$cpu_physical_cores", formatted_stats.cpu_physical_cores);
	formatted_text = formatted_text:gsub("$cpu_logical_cores", formatted_stats.cpu_logical_cores);
	formatted_text = formatted_text:gsub("$cpu_cores", formatted_stats.cpu_cores);
	formatted_text = formatted_text:gsub("$cpu_usage", formatted_stats.cpu_usage);

	formatted_text = formatted_text:gsub("$audio_bitrate", formatted_stats.audio_bitrate);
	formatted_text = formatted_text:gsub("$recording_bitrate", formatted_stats.recording_bitrate);
	formatted_text = formatted_text:gsub("$bitrate", formatted_stats.bitrate);

	formatted_text = formatted_text:gsub("$streaming_total_seconds", formatted_stats.streaming_total_seconds);
	formatted_text = formatted_text:gsub("$streaming_total_minutes", formatted_stats.streaming_total_minutes);
	formatted_text = formatted_text:gsub("$streaming_hours", formatted_stats.streaming_hours);
	formatted_text = formatted_text:gsub("$streaming_minutes", formatted_stats.streaming_minutes);
	formatted_text = formatted_text:gsub("$streaming_seconds", formatted_stats.streaming_seconds);
	formatted_text = formatted_text:gsub("$streaming_duration", formatted_stats.streaming_duration);

	formatted_text = formatted_text:gsub("$recording_total_seconds", formatted_stats.recording_total_seconds);
	formatted_text = formatted_text:gsub("$recording_total_minutes", formatted_stats.recording_total_minutes);
	formatted_text = formatted_text:gsub("$recording_hours", formatted_stats.recording_hours);
	formatted_text = formatted_text:gsub("$recording_minutes", formatted_stats.recording_minutes);
	formatted_text = formatted_text:gsub("$recording_seconds", formatted_stats.recording_seconds);
	formatted_text = formatted_text:gsub("$recording_duration", formatted_stats.recording_duration);

	formatted_text = formatted_text:gsub("$streaming_status", formatted_stats.streaming_status);
	formatted_text = formatted_text:gsub("$recording_status", formatted_stats.recording_status);

	return formatted_text;
end

function text_source_handler.init_module()
	data_format = require("modules.data_format");
	script_handler = require("modules.script_handler");
	utils = require("modules.utils");
end

return text_source_handler;