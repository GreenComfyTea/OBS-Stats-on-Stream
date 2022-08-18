# OBS Stats on Stream
Shows obs stats on stream and/or in Twitch chat. Supported data: encoder, output mode, canvas resolution, output resolution, missed frames, skipped frames, dropped frames, congestion,  average frame time, fps, memory usage, cpu core count, cpu usage, audio bitrate, video bitrate, streaming duration, recording duration, streaming status and recording status.

<table style="width:100%">
<tr><th colspan="2"></th></tr>
<tr>
	<td align="center"><a href="./Text-Formatting-Variables.md">Text Formatting Variables</a></td>
	<td align="center"><a href="./Bot-Commands.md">Bot Commands</a></td>	
</tr>
  <tr><th colspan="2"></th></tr>
</table>

<img src="https://i.imgur.com/uMnrq4r.png" />
<img src="https://i.imgur.com/6E7Ku9B.png" />
<img src="https://i.imgur.com/Wfi0c1u.png" />


# How to use
1. Download the script files. You only need `OBS-Stats-on-Stream.lua` and `ljsocket.lua`. These two files must be placed in the same folder.
2. Add a text source to your scene. This source will be used to display the data.
3. Open Tools -> Scripts. Add the `OBS-Stats-on-Stream.lua` script (only this one).
4. Configure the script.
	* If you don't need Twitch Bot functionality, uncheck `Enable Bot` mark.
    * `Update Delay` determines how often the data will be updated. 1000 ms means once a second. 100 ms means 10 times a second.
	* `Bot Delay` determines how often the bot will read chat and write to it.
    
	* Enter bot's (or your own) nickname in `Bot Nickname` field.
	* Enter `Bot OAuth Password` for the bot's (or your own) twitch account. You can get it here: [click](https://twitchapps.com/tmi).
	* Enter `Channel Nickname` your bot gonna join (it gonna accept commands from this chat and print there). PLEASE, ONLY JOIN YOUR OWN CHANNEL. DO NOT TRY TO JOIN OTHER CHANNELS.
	* Link your created text source.
    * Modify `Text Formatting` if needed. all $name are variables and are replaced with actual values.
5. You are ready to go!

>**:pushpin: NOTE:**   If you don't need Text Source functionality, you don't need to add a text source and link it in the script.

>**:pushpin: NOTE:**   If you don't need Twitch Bot functionality, you can use `Enable Bot` checkbox to disable it. You also don't need to type `Bot Nickname`, `Bot OAuth Password` and `Channel Nickname` in that case.

>**:pushpin: NOTE:**   Bot only works on Twitch. I have no knowledge nor intentions to make it work on YT or any other platform.

# Contribution

Big thanks to [jammehcow](https://github.com/jammehcow) for helping me with figuring out Socket functionality in Lua!

OBS Docs are very confusing. If you want to contribute feel free to message me, make a pull request or open an issue!

# Donate

Another way to support me is donating! Thank you for using this script!

 <a href="https://streamelements.com/greencomfytea/tip">
  <img alt="Qries" src="https://panels.twitch.tv/panel-48897356-image-c6155d48-b689-4240-875c-f3141355cb56">
</a>
<a href="https://ko-fi.com/greencomfytea">
  <img alt="Qries" src="https://panels.twitch.tv/panel-48897356-image-c2fcf835-87e4-408e-81e8-790789c7acbc">
</a>
