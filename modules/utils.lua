local utils = {};

local next = next;
local type = type;
local pairs = pairs;
local string = string;
local table = table;
local tostring = tostring;
local require = require;
local math = math;

function utils.table_tostring(table_)
	if type(table_) == "number" or type(table_) == "boolean" or type(table_) == "string" then
		return tostring(table_);
	end

	if utils.is_table_empty(table_) then
		return "{}"; 
	end

	local cache = {};
	local stack = {};
	local output = {};
    local depth = 1;
    local output_str = "{\n";

    while true do
        local size = 0;
        for k,v in pairs(table_) do
            size = size + 1;
        end

        local cur_index = 1;
        for k,v in pairs(table_) do
            if cache[table_] == nil or cur_index >= cache[table_] then

                if string.find(output_str, "}", output_str:len()) then
                    output_str = output_str .. ",\n";
                elseif not string.find(output_str, "\n", output_str:len()) then
                    output_str = output_str .. "\n";
                end

                -- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
                table.insert(output,output_str);
                output_str = "";

                local key;
                if type(k) == "number" or type(k) == "boolean" then
                    key = "[" .. tostring(k) .. "]";
                else
                    key = "['" .. tostring(k) .. "']";
                end

                if type(v) == "number" or type(v) == "boolean" then
                    output_str = output_str .. string.rep('\t', depth) .. key .. " = "..tostring(v);
                elseif type(v) == "table" then
                    output_str = output_str .. string.rep('\t', depth) .. key .. " = {\n";
                    table.insert(stack, table_);
                    table.insert(stack, v);
                    cache[table_] = cur_index + 1;
                    break;
                else
                    output_str = output_str .. string.rep('\t', depth) .. key .. " = '" .. tostring(v) .. "'";
                end

                if cur_index == size then
                    output_str = output_str .. "\n" .. string.rep('\t', depth - 1) .. "}";
                else
                    output_str = output_str .. ",";
                end
            else
                -- close the table
                if cur_index == size then
                    output_str = output_str .. "\n" .. string.rep('\t', depth - 1) .. "}";
                end
            end

            cur_index = cur_index + 1;
        end

        if size == 0 then
            output_str = output_str .. "\n" .. string.rep('\t', depth - 1) .. "}";
        end

        if #stack > 0 then
            table_ = stack[#stack];
            stack[#stack] = nil;
            depth = cache[table_] == nil and depth + 1 or depth - 1;
        else
            break
        end
    end

    -- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
    table.insert(output, output_str);
    output_str = table.concat(output);

    return output_str;
end

function utils.table_tostringln(table_)
	return "\n" .. utils.table_tostring(table_);
end

function utils.is_table_empty(table_)
	return next(table_) == nil;
end

function utils.is_NaN(value)
	return tostring(value) == tostring(0/0);
end

function utils.round(value)
	return math.floor(value + 0.5);
end

function utils.trim(str)
	return str:match("^%s*(.-)%s*$");
end

function utils.starts_with(str, pattern)
	return str:find("^".. pattern) ~= nil;
end

function utils.init_module()
end

return utils;