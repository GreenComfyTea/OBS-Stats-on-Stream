local data_format = {};

local data;

local require = require;
local tostring = tostring;
local string = string;

data_format.stats = {};

function data_format.update()
	local stats = data.stats;

	data_format.stats.date_time = tostring(stats.date_time);
	data_format.stats.date = tostring(stats.date);
	data_format.stats.time = tostring(stats.time);

	data_format.stats.encoder = tostring(stats.encoder);
	data_format.stats.output_mode = tostring(stats.output_mode);

	data_format.stats.canvas_width = string.format("%d", stats.canvas_width);
	data_format.stats.canvas_height = string.format("%d", stats.canvas_height);
	data_format.stats.canvas_resolution = tostring(stats.canvas_resolution);

	data_format.stats.output_width = string.format("%d", stats.output_width);
	data_format.stats.output_height = string.format("%d", stats.output_height);
	data_format.stats.output_resolution = tostring(stats.output_resolution);

	data_format.stats.missed_frames = string.format("%d", stats.missed_frames);
	data_format.stats.total_missed_frames = string.format("%d", stats.total_missed_frames);
	data_format.stats.missed_percents = string.format("%.2f", 100 * stats.missed_percents);

	data_format.stats.skipped_frames = string.format("%d", stats.skipped_frames);
	data_format.stats.total_skipped_frames = string.format("%d", stats.total_skipped_frames);
	data_format.stats.skipped_percents = string.format("%.2f", 100 * stats.skipped_percents);

	data_format.stats.dropped_frames = string.format("%d", stats.dropped_frames);
	data_format.stats.total_dropped_frames = string.format("%d", stats.total_dropped_frames);
	data_format.stats.dropped_percents = string.format("%.2f", 100 * stats.dropped_percents);

	data_format.stats.congestion = string.format("%.2f", 100 * stats.congestion);
	data_format.stats.average_congestion = string.format("%.2f", 100 * stats.average_congestion);

	data_format.stats.average_frame_time = string.format("%.1f", stats.average_frame_time);
	data_format.stats.fps = string.format("%.2f", stats.fps);
	data_format.stats.target_fps = string.format("%d", stats.target_fps);
	data_format.stats.average_fps = string.format("%.2f", stats.average_fps);

	data_format.stats.memory_usage = string.format("%.1f", stats.memory_usage);
	data_format.stats.cpu_physical_cores = string.format("%d", stats.cpu_physical_cores);
	data_format.stats.cpu_logical_cores = string.format("%d", stats.cpu_logical_cores);
	data_format.stats.cpu_cores = tostring(stats.cpu_cores);
	data_format.stats.cpu_usage = string.format("%.2f", 100 * stats.cpu_usage);

	data_format.stats.audio_bitrate = string.format("%d", stats.audio_bitrate);
	data_format.stats.recording_bitrate = string.format("%d", stats.recording_bitrate);
	data_format.stats.bitrate = string.format("%d", stats.bitrate);

	data_format.stats.streaming_total_seconds = string.format("%d", stats.streaming_total_seconds);
	data_format.stats.streaming_total_minutes = string.format("%d", stats.streaming_total_minutes);
	data_format.stats.streaming_hours = string.format("%d", stats.streaming_hours);
	data_format.stats.streaming_minutes = string.format("%d", stats.streaming_minutes);
	data_format.stats.streaming_seconds = string.format("%d", stats.streaming_seconds);
	data_format.stats.streaming_duration = tostring(stats.streaming_duration);

	data_format.stats.recording_total_seconds = string.format("%d", stats.recording_total_seconds);
	data_format.stats.recording_total_minutes = string.format("%d", stats.recording_total_minutes);
	data_format.stats.recording_hours = string.format("%d", stats.recording_hours);
	data_format.stats.recording_minutes = string.format("%d", stats.recording_minutes);
	data_format.stats.recording_seconds = string.format("%d", stats.recording_seconds);
	data_format.stats.recording_duration = tostring(stats.recording_duration);

	data_format.stats.streaming_status = tostring(stats.streaming_status);
	data_format.stats.recording_status = tostring(stats.recording_status);
end

function data_format.init_module()
	data = require("modules.data");
end

return data_format;