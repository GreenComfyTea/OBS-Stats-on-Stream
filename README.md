# OBS Stats on Stream
The script allow to shows missed frames, skipped frames, dropped frames, congestion, bitrate, fps, memory usage and average frame time on stream as text source and/or in chat.

<table style="width:100%">
<tr><th colspan="2"></th></tr>
<tr>
	<td align="center"><a href="./OBS-Stats-on-Stream/Text-Formatting-Variables.md">Text Formatting Variables</a></td>
	<td align="center"><a href="./OBS-Stats-on-Stream/Bot-Commands.md">Bot Commands</a></td>	
</tr>
  <tr><th colspan="2"></th></tr>
</table>

<img src="https://i.imgur.com/qglRNBr.png" />
<img src="https://i.imgur.com/QA2VMT1.png" />

# How to use
1. Download the script files. You only need `OBS-Stats-on-Stream.lua` and `ljsocket.lua`. These two files must be placed in the same folder.
2. Add a text source to your scene. This source will be used to display the data.
3. Open Tools -> Scripts. Add the `OBS-Stats-on-Stream.lua` script (only this one).
4. Configure the script.
	* If you don't need Bot functionality, uncheck `Enable Bot` mark.
    * `Output Mode` must match the OBS encoder mode. Check it by going `OBS -> Settings -> Output -> Output Mode` (on the very top).
    * `Update Delay` determines how often the data will be updated. 1000 ms means once a second. 100 ms means 10 times a second.
	* `Bot Delay` determines how often the bot will read chat and write to it.
    * Link your created text source.
	* Enter your twitch nickname in `Nickname` field.
	* Enter `OAuth Password` for your twitch account. You can get it here: [click](https://twitchapps.com/tmi).
    * Modify `Text Formatting` if needed. all $name are variables and are replaced with actual values.
5. You are ready to go!

>**:pushpin: NOTE:**   If you don't need Text Source functionality, you don't need to add a text source and link it in the script.
>**:pushpin: NOTE:**   If you don't need Bot functionality, you can use `Enable Bot` checkbox to disable it. You also don't need to type `Nickname` and `OAuth Password` in that case. 

# TODO
* Automatic Output Mode?
* CPU Usage?

# Contribution

Big thanks to [jammehcow](https://github.com/jammehcow) for helping me with figuring out Socket functionality in Lua!

OBS Docs are very confusing. If you want to contribute feel free to message me, make a pull request or open an issue!

# Donate

Another way to support me is donating! Thank you for using this script!

 <a href="https://streamelements.com/greencomfytea/tip">
  <img alt="Qries" src="https://panels-images.twitch.tv/panel-48897356-image-c6155d48-b689-4240-875c-f3141355cb56">
</a>
<a href="https://ko-fi.com/greencomfytea">
  <img alt="Qries" src="https://panels-images.twitch.tv/panel-48897356-image-c2fcf835-87e4-408e-81e8-790789c7acbc">
</a>
