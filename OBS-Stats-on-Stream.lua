obs = obslua
local ffi = require("ffi")

ffi.cdef[[

struct video_output;
typedef struct video_output video_t;

uint32_t video_output_get_skipped_frames(const video_t *video);
uint32_t video_output_get_total_frames(const video_t *video);
double video_output_get_frame_rate(const video_t *video);
uint64_t video_output_get_frame_time(const video_t *video);

video_t *obs_get_video(void);
]]

local output_mode = "simple_stream"
local callback_delay = 1000
local text_source = ""
local script_active = false

local show_lagged_frames = true
local show_skipped_frames = true
local show_dropped_frames = true

local obsffi
if ffi.os == "OSX" then
	obsffi = ffi.load("obs.0.dylib") -- OS X
else
	obsffi = ffi.load("obs") -- Windows
	-- Linux?
end


function timer_callback()
	print("callback " .. output_mode)
	
	local source = obs.obs_get_source_by_name(text_source)
	if source == nil then
		print("no source, removing callback")
		obs.remove_current_callback()
		return
	end
	
	local render_frames = 0
	local render_lagged = 0

	local encoder_frames = 0
	local encoder_skipped = 0
	--local encoder_framerate = 0.0

	local output_frames = 0
	local output_dropped = 0
	--local output_congestion = 0.0
	
	render_frames = obs.obs_get_total_frames()
	render_lagged = obs.obs_get_lagged_frames()
	
	if obsffi ~= nil then
		local video = obsffi.obs_get_video()
		if video ~= nil then
			encoder_frames = obsffi.video_output_get_total_frames(video)
			encoder_skipped = obsffi.video_output_get_skipped_frames(video)
			--encoder_framerate =  obsffi.video_output_get_frame_rate(video);
		end
	end
	
	local output = obs.obs_get_output_by_name(output_mode)
	-- output will be nil when not actually streaming
	if output ~= nil then
		output_frames = obs.obs_output_get_total_frames(output)
		output_dropped = obs.obs_output_get_frames_dropped(output)
		--output_congestion = obs.obs_output_get_congestion(output)
		obs.obs_output_release(output)
	end
	
	--h264	???
	--obs_x264
	--jim_nvenc
	--streamfx-h264_nvenc
	--[[
	local encoder = obs.obs_get_encoder_by_name("h264")
	print("encoder is null: " .. tostring(encoder == nil))
	if(encoder ~= nil) then
		print("test")
		obs_output_release(encoder)
	end
	print("test2")
	--]]
	
	--[[
	local formattedString = "Encoder framerate: " .. tostring(encoder_framerate) .. "\n" .. 
	"Frames missed due to rendering lag: ?/" .. tostring(render_frames) .. "\n" .. 
	"Lagged frames: " .. tostring(render_lagged) .. "/" .. tostring(render_frames) .. "\n" .. 
	"Skipped frames due to encoding lag: " .. tostring(encoder_skipped) .. "/" .. tostring(encoder_frames) .. "\n" .. 
	"Dropped frames: " .. tostring(output_dropped) .. "/" .. tostring(output_frames) .. "\n" .. 
	"Congestion: " .. tostring(output_congestion)
	--]]
	
	local formattedString = ""
	if show_lagged_frames then
		formattedString = formattedString .. "Lagged frames: " .. tostring(render_lagged) .. "/" .. tostring(render_frames)
	end
	if show_skipped_frames then
		if show_lagged_frames then
			formattedString = formattedString .. "\n"
		end
		formattedString = formattedString .. "Skipped frames: " .. tostring(encoder_skipped) .. "/" .. tostring(encoder_frames)
	end
	if show_dropped_frames then
		if show_lagged_frames or show_skipped_frames then
			formattedString = formattedString .. "\n"
		end
		formattedString = formattedString .. "Dropped frames: " .. tostring(output_dropped) .. "/" .. tostring(output_frames)
	end

	local settings = obs.obs_data_create()
	obs.obs_data_set_string(settings, "text", formattedString)
	obs.obs_source_update(source, settings)
	obs.obs_source_release(source)
	obs.obs_data_release(settings)
end

function on_event(event)
	
	if event == obs.OBS_FRONTEND_EVENT_STREAMING_STARTED then
		print("streaming started")
		script_active = true
		obs.timer_add(timer_callback, callback_delay)
	end
	if event == obs.OBS_FRONTEND_EVENT_STREAMING_STOPPED then
		print("streaming stopped")
		script_active = false
		obs.timer_remove(timer_callback)
	end
end
		
function script_properties()
	local props = obs.obs_properties_create()

	local output_mode_prop = obs.obs_properties_add_list(props, "output_mode", "Output Mode", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
	obs.obs_property_list_add_string(output_mode_prop, "Simple", "simple_stream")
	obs.obs_property_list_add_string(output_mode_prop, "Advanced", "adv_stream")
	obs.obs_property_set_long_description(output_mode_prop, "Must match the OBS streaming mode you are using.")
	
	local callback_delay_prop = obs.obs_properties_add_int(props, "callback_delay", "Update Delay", 100, 1000, 100)
	obs.obs_property_set_long_description(callback_delay_prop, "Determines how often the data will update.")
	
	local text_source_prop = obs.obs_properties_add_list(props,
		"text_source", "Text(GDI+) Source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	local sources = obs.obs_enum_sources()
	if sources ~= nil then
		for _, source in ipairs(sources) do
			local source_id = obs.obs_source_get_id(source)
			if source_id == "text_gdiplus_v2" then
				local name = obs.obs_source_get_name(source)
				obs.obs_property_list_add_string(text_source_prop, name, name)
			end
		end
	end
	obs.source_list_release(sources)
	obs.obs_property_set_long_description(text_source_prop,
		"Text(GDI+) source that will be used to display the data.")
	
	local show_lagged_frames_prop = obs.obs_properties_add_bool(props, "show_lagged_frames", "Show Lagged Frames")
	
	local show_skipped_frames_prop = obs.obs_properties_add_bool(props, "show_skipped_frames", "Show Skipped Frames")
	obs.obs_property_set_long_description(callback_delay_prop, "Show Skipped Frames due to Rendering Lag.")
	
	local show_dropped_frames_prop = obs.obs_properties_add_bool(props, "show_dropped_frames", "Show Dropped Frames")
	
	return props
end

function script_defaults(settings)
	obs.obs_data_set_default_string(settings, "output_mode", "simple_stream")
	obs.obs_data_set_default_int(settings, "callback_delay", 1000)
	obs.obs_data_set_default_string(settings, "text_source", "")
	obs.obs_data_set_default_bool(settings, "show_lagged_frames", true)
	obs.obs_data_set_default_bool(settings, "show_skipped_frames", true)
	obs.obs_data_set_default_bool(settings, "show_dropped_frames", true)
end

function script_update(settings)
	output_mode = obs.obs_data_get_string(settings, "output_mode")
	callback_delay = obs.obs_data_get_int(settings, "callback_delay")
	text_source = obs.obs_data_get_string(settings, "text_source")
	show_lagged_frames = obs.obs_data_get_bool(settings, "show_lagged_frames")
	show_skipped_frames = obs.obs_data_get_bool(settings, "show_skipped_frames")
	show_dropped_frames = obs.obs_data_get_bool(settings, "show_dropped_frames")

	if script_active then
		obs.timer_remove(timer_callback)
		obs.timer_add(timer_callback, callback_delay)
	end
end

function script_description()
	return "Prints stream bitrate, dropped frames, frames missed due to rendering lag, skipped frames due to encoding lag."
end


function script_load(settings)
	print("script loaded")
	obs.obs_frontend_add_event_callback(on_event)
	
	if(obs.obs_frontend_streaming_active()) then
		print("streaming in progress")
		script_active = true
		obs.timer_add(timer_callback, callback_delay)
	end
end
