# Bot Commands:
1. `!encoder [to_user]`

	```
	@to_user -> Encoder: $encoder
	```
2. `!output_mode [to_user]` (aliases: `!outputmode`)

	```
	@to_user -> Output Mode: $output_mode
	```
3. `!canvas_resolution [to_user]` (aliases: `!canvasresolution`)

	```
	@to_user -> Canvas Resolution: $canvas_resolution
	```
4. `!output_resolution [to_user]` (aliases: `!outputresolution`)

	```
	@to_user -> Output Resolution: $output_resolution
	```
5. `!missed_frames [to_user]` (aliases: `!missedframes` `!missed`)

	```
	@to_user -> Missed Frames: $missed_frames/$missed_total_frames ($missed_percents%)
	```
6. `!skipped_frames [to_user]` (aliases: `!skippedframes` `!skipped`)

	```
	@to_user -> Skipped Frames: $skipped_frames/$skipped_total_frames ($skipped_percents%)
	```
7. `!dropped_frames [to_user]` (aliases: `!droppedframes` `!dropped`)

	```
	@to_user -> Dropped Frames: $dropped_frames/$dropped_total_frames ($dropped_percents%)
	```
8. `!congestion [to_user]`

	```
	@to_user -> Congestion: $congestion% (average: $average_congestion%)
	```
9. `!frame_time [to_user]` (aliases: `!render_time` `!frametime` `!rendertime`)

	```
	@to_user -> Average Frame Time: $average_frame_time ms
	```
10. `!fps [to_user]` (aliases: `!framerate`)

	```
	@to_user -> FPS: $fps/%target_fps (average: %average_fps)
	```
11. `!memory_usage [to_user]` (aliases: `!memoryusage` `!memory`)

	```
	@to_user -> Memory usage: $memory_usage MB
	```
12. `!cpu_cores [to_user]` (aliases: `!cpuccores` `!cores`)

	```
	@to_user -> CPU cores: $cpu_cores
	```
13. `!cpu_usage [to_user]` (aliases: `!cpuusage`)

	```
	@to_user -> CPU usage: $cpu_usage%
	```
14. `!audio_bitrate [to_user]` (aliases: `!audiobitrate`)

	```
	@to_user -> Audio Bitrate: $audio_bitrate kb/s
	```
15. `!recording_bitrate [to_user]` (aliases: `!recordingbitrate`)

	```
	@to_user -> Recording Bitrate: $recording_bitrate kb/s
	```
16. `!bitrate [to_user]`

	```
	@to_user -> Bitrate: $bitrate kb/s
	```
17. `!recording_bitrate [to_user]` (aliases: `!recordingbitrate`)

	```
	@to_user -> Recording Bitrate: $recording_bitrate kb/s
	```
18. `!streaming_duration [to_user]` (aliases: `!streamingduration`)

	```
	@to_user -> Streaming duration: 03:32:59
	```
19. `!recording_duration [to_user]` (aliases: `!recordingduration`)

	```
	@to_user -> Recording duration: 03:32:59
	```
20. `!streaming_status [to_user]` (aliases: `!streamingstatus`)

	```
	@to_user -> Streaming status: Live
	```
	```
	@to_user -> Streaming status: Reconnecting
	```
	```
	@to_user -> Streaming status: Offline
	```
21. `!recording_status [to_user]`  (aliases: `!recordingstatus`)

	```
	@to_user -> Recording status: On
	```
	```
	@to_user -> Recording status: Paused
	```
	```
	@to_user -> Recording status: Off
	```
22. `!obs_static_stats [to_user]`  (aliases: `!obsstaticstats`)

	```
	@to_user -> Encoder: $encoder,
	Output Mode: $output_mode,
	Canvas Resolution: $canvas_resolution,
	Output Resolution: $output_resolution,
	CPU cores: $cpu_cores,
	Audio Bitrate: $audio_bitrate kb/s
	```
23. `!obsstats [to_user]`

	```
	@to_user -> Missed frames: $missed_frames/$missed_total_frames ($missed_percents%),
	Skipped frames: $skipped_frames/$skipped_total_frames ($skipped_percents%),
	Dropped frames: $dropped_frames/$dropped_total_frames ($dropped_percents%),
	Congestion: $congestion% (avg. $average_congestion%),
	Average frame time: $average_frame_time ms,
	FPS: $fps/$target_fps (average: $average_fps),
	Memory Usage: $memory_usage MB,
	CPU Usage: $cpu_usage%,
	Bitrate: $bitrate kb/s
	```
	
	