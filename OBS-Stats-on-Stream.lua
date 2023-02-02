local require = require;
local print = print;

local json = require("modules.json");
local ljsocket = require("modules.ljsocket");
local bot = require("modules.bot");
local data_format = require("modules.data_format");
local data = require("modules.data");
local output = require("modules.output");
local log = require("modules.log");
local profile_handler = require("modules.profile_handler");
local script_handler = require("modules.script_handler");
local text_source_handler = require("modules.text_source_handler");
local utils = require("modules.utils");

bot.init_module();
data_format.init_module();
data.init_module();
output.init_module();
log.init_module();
profile_handler.init_module();
script_handler.init_module();
text_source_handler.init_module();
utils.init_module();