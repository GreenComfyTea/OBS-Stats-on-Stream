# Bot Commands:
1. `!missed_frames [to_user]` (aliases: `!missedframes` `!missed`)
	```
	@to_user -> Missed frames: $missed_frames/$missed_total_frames ($missed_percents%)
	```
2. `!skipped_frames [to_user]` (aliases: `!skippedframes` `!skipped`)
	```
	@to_user -> Skipped frames: $skipped_frames/$skipped_total_frames ($skipped_percents%)
	```
3. `!dropped_frames [to_user]` (aliases: `!droppedframes` `!dropped`)
	```
	@to_user -> Dropped frames: $dropped_frames/$dropped_total_frames ($dropped_percents%)
	```
4. `!congestion [to_user]`
	```
	@to_user -> Congestion: $congestion% (average: $average_congestion%)
	```
5. `!frame_time [to_user]` (aliases: `!render_time` `!frametime` `!rendertime`)
	```
	@to_user -> Average frame time: $average_frame_time ms
	```
6. `!memory_usage [to_user]` (aliases: `!memoryusage` `!memory`)
	```
	@to_user -> Memory usage: $memory_usage MB
	```
7. `!cpu_cores [to_user]` (aliases: `!cpuccores` `!cores`)
	```
	@to_user -> CPU cores: $cpu_cores
	```
8. `!cpu_usage [to_user]` (aliases: `!cpuusage`)
	```
	@to_user -> CPU usage: $cpu_usage%
	```
9. `!bitrate [to_user]`
	```
	@to_user -> Bitrate: $bitrate Kb/s
	```
10. `!fps [to_user]` (aliases: `!framerate`)
	```
	@to_user -> FPS: $fps
	```
11. `!obsstats [to_user]`
	```
	@to_user -> Missed frames: $missed_frames/$missed_total_frames ($missed_percents%)
	Skipped frames: $skipped_frames/$skipped_total_frames ($skipped_percents%)
	Dropped frames: $dropped_frames/$dropped_total_frames ($dropped_percents%)
	Congestion: $congestion% (avg. $average_congestion%)
	Average frame time: $average_frame_time ms
	Memory Usage: $memory_usage MB
	CPU Cores: $cpu_cores
	CPU Usage: $cpu_usage%
	Bitrate: $bitrate kb/s
	FPS: $fps
	```
	
	