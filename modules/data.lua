local data = {};

local ffi;
local text_source_handler;
local utils;

local obslua = obslua;
local print = print;
local tostring = tostring;
local math = math;
local require = require;
local string = string;
local os = os;

local obsffi = nil;
local bytes_to_megabytes = 1024 * 1024;
local ns_to_ms = 1000000;
local ms_to_s = 1000;
local s_to_m = 60;
local s_to_h = 3600;
local cpu_info  = nil;
local bitrate_update_delay = 2000;

local default_encoder = "x264"
local default_canvas_width = 1920;
local default_canvas_resolution = "1920x1080";
local default_output_resolution = "1280x720";
local default_target_fps = 30;

local defaults = {
	encoder = "x264?",
	output_mode = "Simple",
	canvas_width = 1920,
	canvas_height = 1080,
	canvas_resolution = "1920x1080?",
	output_width = 1280,
	output_height = 720,
	output_resolution = "1280x720",
	target_fps = 30,
	audio_bitrate = 160
}

local cumulative_fps = 0;
local cumulative_congestion = 0;
local last_bitrate_update_time = 0;
local last_bytes_sent = 0;
local last_bytes_recorded = 0;

data.ticks = 0;

data.streaming_statuses = {
	live = "Live",
	offline = "Offline"
};

data.recording_statuses = {
	on = "On",
	paused = "Paused",
	off = "Off"
};

data.output_modes = {
	simple = "Simple",
	advanced = "Advanced"
};

data.stats = {
	date = "01.01.1970",
	time = "00:00:00",
	date_time = "01.01.1970 00:00:00",
	encoder = defaults.encoder,
	output_mode = defaults.output_mode,
	canvas_width = defaults.canvas_width,
	canvas_height = defaults.canvas_height,
	canvas_resolution = defaults.canvas_resolution,
	output_width = defaults.output_width,
	output_height = defaults.output_height,
	output_resolution = defaults.output_resolution,
	missed_frames = 0,
	total_missed_frames = 0,
	missed_percents = 0,
	skipped_frames = 0,
	total_skipped_frames = 0,
	skipped_percents = 0,
	dropped_frames = 0,
	total_dropped_frames = 0,
	dropped_percents = 0,
	congestion = 0,
	average_congestion = 0,
	average_frame_time = 0,
	fps = 0,
	target_fps = defaults.target_fps,
	average_fps = 0,
	memory_usage = 0,
	cpu_physical_cores = 0,
	cpu_logical_cores = 0,
	cpu_cores = "0C/0T",
	cpu_usage = 0,
	audio_bitrate = defaults.audio_bitrate,
	recording_bitrate = 0,
	bitrate = 0,
	streaming_total_seconds = 0,
	streaming_total_minutes = 0,
	streaming_hours = 0,
	streaming_minutes = 0,
	streaming_seconds = 0;
	streaming_duration = "00:00:00",
	recording_total_seconds = 0,
	recording_total_minutes = 0,
	recording_hours = 0,
	recording_minutes = 0,
	recording_seconds = 0;
	recording_duration = "00:00:00",
	streaming_status = "Offline",
	recording_status = "Off"
}

function data.update()
	--print("Data Update Tick.");

	data.ticks = data.ticks + 1;

	-- streaming_output will be nil when not actually streaming
	local streaming_output = obslua.obs_frontend_get_streaming_output();
	local recording_output = obslua.obs_frontend_get_recording_output();

	local bitrate_time_passed = data.update_bitrate_time_passed();

	data.update_time();
	data.update_cpu_usage();
	data.update_memory_usage();
	data.update_fps();
	data.update_average_frame_time();
	data.update_missed_frames();
	data.update_skipped_frames();
	data.update_dropped_frames(streaming_output);
	data.update_congestion(streaming_output);
	data.update_streaming_bitrate(streaming_output, bitrate_time_passed);
	data.update_streaming_duration();
	data.update_recording_bitrate(recording_output, bitrate_time_passed);
	data.update_recording_duration(recording_output);

	if streaming_output ~= nil then
		obslua.obs_output_release(streaming_output);
	end

	if recording_output ~= nil then
		obslua.obs_output_release(recording_output);
	end
end

function data.update_time()
	data.stats.date = os.date("%d.%m.%Y");
	data.stats.time = os.date("%X");
	data.stats.date_time = os.date("%d.%m.%Y %X");
end

function data.update_bitrate_time_passed()
	local current_time = obslua.os_gettime_ns();
	local time_passed = (current_time - last_bitrate_update_time) / ns_to_ms;
	
	if time_passed >= bitrate_update_delay then
		last_bitrate_update_time = current_time;
	end

	return time_passed;
end

function data.start_cpu_usage_info()
	if obsffi == nil then
		return;
	end

	data.destroy_cpu_usage_info();

	data.cpu_info = obsffi.os_cpu_usage_info_start();
end

function data.destroy_cpu_usage_info()
	if data.cpu_info == nil or obsffi == nil then
		return;
	end

	obsffi.os_cpu_usage_info_destroy(data.cpu_info);
	data.cpu_info = nil;
end

function data.update_cpu_usage()
	if data.cpu_info == nil or obsffi == nil then
		return;
	end
	
	local cpu_usage = obsffi.os_cpu_usage_info_query(data.cpu_info);

	if cpu_usage ~= nil then
		data.stats.cpu_usage = cpu_usage / 100;
	end
	
end

function data.update_memory_usage()
	local memory_usage = obslua.os_get_proc_resident_size() / bytes_to_megabytes;

	if memory_usage ~= nil then
		data.stats.memory_usage = memory_usage;
	end
end

function data.update_fps()
	local fps = obslua.obs_get_active_fps();

	if fps ~= nil then
		data.stats.fps = fps;
		cumulative_fps = cumulative_fps + fps;
		data.stats.average_fps = cumulative_fps / data.ticks;
	end
end

function data.update_average_frame_time()
	local average_frame_time = obslua.obs_get_average_frame_time_ns() / ns_to_ms;

	if average_frame_time ~= nil then
		data.stats.average_frame_time = average_frame_time;
	end
end

function data.update_missed_frames()
	local total_missed_frames = obslua.obs_get_total_frames();	-- total rendered frames
	local missed_frames = obslua.obs_get_lagged_frames();		-- lagged frames

	if total_missed_frames ~= nil then
		data.stats.total_missed_frames = total_missed_frames;
	end

	if missed_frames ~= nil then
		data.stats.missed_frames = missed_frames;
	end

	if data.stats.total_missed_frames == 0 then
		data.stats.missed_percents = 0;
	else
		data.stats.missed_percents = data.stats.missed_frames / data.stats.total_missed_frames;
	end
end

function data.update_skipped_frames()
	if obsffi == nil then
		return;
	end

	local video = obsffi.obs_get_video();

	if video == nil then
		return;
	end

	local total_skipped_frames = obsffi.video_output_get_total_frames(video);	-- total encoded frames
	local skipped_frames = obsffi.video_output_get_skipped_frames(video);		-- skipped frames

	if total_skipped_frames ~= nil then
		data.stats.total_skipped_frames = total_skipped_frames;
	end

	if skipped_frames ~= nil then
		data.stats.skipped_frames = skipped_frames;
	end

	if data.stats.total_skipped_frames == 0 then
		data.stats.skipped_percents = 0;
	else
		data.stats.skipped_percents = data.stats.skipped_frames / data.stats.total_skipped_frames;
	end
end

function data.update_dropped_frames(streaming_output)
	if streaming_output == nil then
		return;
	end
	
	local dropped_frames = obslua.obs_output_get_frames_dropped(streaming_output); -- dropped frames
	local total_frames = obslua.obs_output_get_total_frames(streaming_output);		-- total dropped frames
	
	if total_frames ~= nil then
		data.stats.total_dropped_frames = total_frames;
	end

	if dropped_frames ~= nil then
		data.stats.dropped_frames = dropped_frames;
	end

	if data.stats.total_dropped_frames == 0 then
		data.stats.dropped_percents = 0;
	else
		data.stats.dropped_percents = data.stats.dropped_frames / data.stats.total_dropped_frames;
	end
end

function data.update_congestion(streaming_output)
	if streaming_output == nil then
		return;
	end
	
	local congestion = obslua.obs_output_get_congestion(streaming_output);

	-- Check that congestion is not NaN
	if(congestion ~= nil and not utils.is_NaN(congestion)) then
		cumulative_congestion = cumulative_congestion + congestion;

		data.stats.congestion = congestion;
		data.stats.average_congestion =  cumulative_congestion / data.ticks;
	end
end

function data.update_streaming_status(is_live)
	if is_live then
		data.stats.streaming_status = data.streaming_statuses.live;
	else
		data.stats.streaming_status = data.streaming_statuses.offline;
		data.stats.bitrate = 0;
	end
end

function data.update_recording_status(is_recording, is_paused)
	if is_recording then
		if is_paused then
			data.stats.recording_status = data.recording_statuses.paused;
		else
			data.stats.recording_status = data.recording_statuses.on;
		end
		
	else
		data.stats.recording_status = data.recording_statuses.off;
		data.stats.recording_bitrate = 0;
	end
end

function data.update_streaming_bitrate(streaming_output, time_passed)
	if streaming_output == nil then
		return;
	end

	if time_passed < bitrate_update_delay then
		return;
	end

	local bytes_sent = obslua.obs_output_get_total_bytes(streaming_output);

	if bytes_sent == nil then
		return;
	end
	
	-- the fck is this?
	if bytes_sent < last_bytes_sent then
		bytes_sent = 0;
	end
	
	local bits_between = (bytes_sent - last_bytes_sent) * 8;
	local bitrate = bits_between / time_passed;

	last_bytes_sent = bytes_sent;

	if bitrate ~= nil then
		data.stats.bitrate = bitrate;
	end
end

function data.update_recording_bitrate(recording_output, time_passed)
	if recording_output == nil then
		return;
	end

	if time_passed < bitrate_update_delay then
		return;
	end
	
	local bytes_recorded = obslua.obs_output_get_total_bytes(recording_output);

	if bytes_recorded == nil then
		return;
	end
	
	-- what the fck is this?
	if bytes_recorded < last_bytes_recorded then
		bytes_recorded = 0;
	end

	local recording_bits_between = (bytes_recorded - last_bytes_recorded) * 8;
	local recording_bitrate = recording_bits_between / time_passed / ms_to_s;

	last_bytes_recorded = bytes_recorded;

	if recording_bitrate ~= nil then
		data.stats.recording_bitrate = recording_bitrate;
	end
end

function data.update_streaming_duration()
	-- Needs better approach?
	-- Duration is incorrect if fps is not stable

	if data.stats.streaming_status == data.streaming_statuses.offline then
		data.stats.streaming_total_minutes = 0;
		data.stats.streaming_total_seconds = 0;
		data.stats.streaming_hours = 0;
		data.stats.streaming_minutes = 0;
		data.stats.streaming_seconds = 0;
		data.stats.streaming_duration = "00:00:00";

		return;
	end

	local fps = data.stats.fps;

	local streaming_total_seconds = data.stats.total_dropped_frames;
	local streaming_total_minutes = 0;
	local streaming_hours = 0;
	local streaming_minutes = 0;
	local streaming_seconds = 0;

	if fps ~= 0 then
		streaming_total_seconds = streaming_total_seconds / fps;
	end

	streaming_hours = math.floor(streaming_total_seconds / 3600);
	streaming_minutes = math.floor((streaming_total_seconds % 3600) / 60);
	streaming_seconds = math.floor(0.5 + streaming_total_seconds % 60);

	data.stats.streaming_total_minutes = math.floor(streaming_total_seconds / 60);
	data.stats.streaming_total_seconds = streaming_total_seconds;

	data.stats.streaming_hours = streaming_hours;
	data.stats.streaming_minutes = streaming_minutes;
	data.stats.streaming_seconds = streaming_seconds;
	data.stats.streaming_duration = string.format("%.2d:%.2d:%.2d", streaming_hours, streaming_minutes, streaming_seconds);
end

function data.update_recording_duration(recording_output)
	-- Needs better approach?
	-- Duration is incorrect if fps is not stable

	if recording_output == nil then
		return;
	end

	if data.stats.recording_status == data.recording_statuses.off then
		data.stats.recording_total_minutes = 0;
		data.stats.recording_total_seconds = 0;
		data.stats.recording_hours = 0;
		data.stats.recording_minutes = 0;
		data.stats.recording_seconds = 0;
		data.stats.recording_duration = "00:00:00";

		return;
	end

	local recording_total_frames = obslua.obs_output_get_total_frames(recording_output);

	if recording_total_frames == nil then
		return;
	end

	local fps = data.stats.fps;

	local recording_total_seconds = recording_total_frames;
	local recording_total_minutes = 0;
	local recording_hours = 0;
	local recording_minutes = 0;
	local recording_seconds = 0;

	if fps ~= 0 then
		recording_total_seconds = recording_total_seconds / fps;
	end

	recording_hours = math.floor(recording_total_seconds / 3600);
	recording_minutes = math.floor((recording_total_seconds % 3600) / 60);
	recording_seconds = math.floor(0.5 + recording_total_seconds % 60);

	data.stats.recording_total_minutes = math.floor(recording_total_seconds / 60);
	data.stats.recording_total_seconds = recording_total_seconds;

	data.stats.recording_hours = recording_hours;
	data.stats.recording_minutes = recording_minutes;
	data.stats.recording_seconds = recording_seconds;
	data.stats.recording_duration = string.format("%.2d:%.2d:%.2d", recording_hours, recording_minutes, recording_seconds);
end

function data.update_output_mode(output_mode)
	if output_mode == nil then
		data.stats.output_mode = defaults.output_mode;
	else
		data.stats.output_mode = output_mode;
	end
end

function data.update_encoder(encoder)
	if encoder ~= nil then
		data.stats.encoder = encoder;
	end
end

function data.update_canvas_resolution(width, height)
	if width ~= nil then
		data.stats.canvas_width = width;
	end

	if height ~= nil then
		data.stats.canvas_height = height;
	end

	if width ~= nil or height ~= nil then
		data.stats.canvas_resolution = string.format("%dx%d", data.stats.canvas_width, data.stats.canvas_height);
	end
end

function data.update_output_resolution(width, height)
	if width == nil then
		data.stats.output_width = defaults.output_width;
	else
		data.stats.output_width = width;
	end

	if height == nil then
		data.stats.output_height = defaults.output_height;
	else
		data.stats.output_height = height;
	end

	data.stats.output_resolution = string.format("%dx%d", data.stats.output_width, data.stats.output_height);
end

function data.update_target_fps(target_fps)
	if target_fps == nil then
		data.stats.target_fps = defaults.target_fps;
	else
		data.stats.target_fps = target_fps;
	end
end

function data.update_audio_bitrate(audio_bitrate)
	if audio_bitrate == nil then
		data.stats.audio_bitrate = defaults.audio_bitrate;
	else
		data.stats.audio_bitrate = audio_bitrate;
	end
end

function data.update_cores_on_script_settings_changed()
	local physical_cores = obslua.os_get_physical_cores();
	local logical_cores = obslua.os_get_logical_cores();

	if physical_cores ~= nil then
		data.stats.cpu_physical_cores = physical_cores;
	end

	if logical_cores ~= nil then
		data.stats.cpu_logical_cores = logical_cores;
	end

	data.stats.cpu_cores = string.format("%dC/%dT", data.stats.cpu_physical_cores, data.stats.cpu_logical_cores);
end

function data.update_streaming_status_on_script_settings_changed()
	local is_streaming_active = obslua.obs_frontend_streaming_active();

	if is_streaming_active == nil then
		return;
	end

	if is_streaming_active then
		data.stats.streaming_status = data.streaming_statuses.live;
	else
		data.stats.streaming_status = data.streaming_statuses.offline;
		data.stats.bitrate = 0;
	end
end

function data.update_recording_status_on_script_settings_changed()
	local is_recording_active = obslua.obs_frontend_recording_active();

	if is_recording_active == nil then
		return;
	end

	if is_recording_active then
		local is_recording_paused = obslua.obs_frontend_recording_paused();

		if is_recording_paused == nil then
			return;
		end

		if is_recording_paused then
			data.stats.recording_status = data.recording_statuses.paused;
		else 
			data.stats.recording_status = data.recording_statuses.on;
		end
	else
		data.stats.recording_status = data.recording_statuses.off;
		data.stats.recording_bitrate = 0;
	end
end

function data.init_module()
	ffi = require("ffi");
	text_source_handler = require("modules.text_source_handler");
	utils = require("modules.utils");
	
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

	if ffi.os == "OSX" then
		obsffi = ffi.load("obs.0.dylib"); -- OS X
	else
		obsffi = ffi.load("obs"); -- Windows
		-- Linux?
	end
end

return data;