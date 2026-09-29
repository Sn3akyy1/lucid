-- A small JSON reader and writer for the modules that read Lucid's settings
-- files (binds.lua, monitors.lua). Hyprland's Lua has no JSON of its own.
--
--   local json = require("modules.json")
--   local data = json.decode(text)   -- raises "<what> at byte <n>" on bad input
--   local text = json.encode(data)

local M = {}

function M.decode(str)
    local pos = 1

    local function fail(msg)
        error(string.format("%s at byte %d", msg, pos), 0)
    end

    local function skip()
        pos = string.find(str, "[^ \t\r\n]", pos) or (#str + 1)
    end

    local escapes = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }

    local function read_string()
        local out = {}
        pos = pos + 1
        while true do
            local s = string.find(str, '["\\]', pos)
            if not s then fail("unterminated string") end
            out[#out + 1] = string.sub(str, pos, s - 1)
            if string.sub(str, s, s) == '"' then
                pos = s + 1
                return table.concat(out)
            end
            local c = string.sub(str, s + 1, s + 1)
            if c == "u" then
                local hex = string.match(str, "^%x%x%x%x", s + 2)
                if not hex then
                    pos = s
                    fail("bad \\u escape")
                end
                local cp = tonumber(hex, 16)
                pos = s + 6
                local lo = cp >= 0xD800 and cp <= 0xDBFF and string.match(str, "^\\u(%x%x%x%x)", pos)
                if lo then
                    cp = 0x10000 + (cp - 0xD800) * 0x400 + (tonumber(lo, 16) - 0xDC00)
                    pos = pos + 6
                end
                out[#out + 1] = utf8.char(cp)
            elseif escapes[c] then
                out[#out + 1] = escapes[c]
                pos = s + 2
            else
                pos = s
                fail("bad escape")
            end
        end
    end

    local read_value

    local function read_container(close, is_object)
        local out, n = {}, 0
        pos = pos + 1
        skip()
        if string.sub(str, pos, pos) == close then
            pos = pos + 1
            return out
        end
        while true do
            if is_object then
                skip()
                if string.sub(str, pos, pos) ~= '"' then fail("expected a key") end
                local key = read_string()
                skip()
                if string.sub(str, pos, pos) ~= ":" then fail("expected ':'") end
                pos = pos + 1
                out[key] = read_value()
            else
                n = n + 1
                out[n] = read_value()
            end
            skip()
            local c = string.sub(str, pos, pos)
            if c == close then
                pos = pos + 1
                return out
            end
            if c ~= "," then fail("expected ',' or '" .. close .. "'") end
            pos = pos + 1
        end
    end

    function read_value()
        skip()
        local c = string.sub(str, pos, pos)
        if c == "{" then return read_container("}", true) end
        if c == "[" then return read_container("]", false) end
        if c == '"' then return read_string() end
        if string.sub(str, pos, pos + 3) == "true" then
            pos = pos + 4
            return true
        end
        if string.sub(str, pos, pos + 4) == "false" then
            pos = pos + 5
            return false
        end
        if string.sub(str, pos, pos + 3) == "null" then
            pos = pos + 4
            return nil
        end
        local num = string.match(str, "^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
        if num and tonumber(num) then
            pos = pos + #num
            return tonumber(num)
        end
        fail(c == "" and "unexpected end of file" or ("unexpected '" .. c .. "'"))
    end

    local result = read_value()
    skip()
    if pos <= #str then fail("trailing characters") end
    return result
end

function M.encode(v)
    local t = type(v)
    if t == "table" then
        local parts = {}
        if #v > 0 or next(v) == nil then
            for i = 1, #v do parts[i] = M.encode(v[i]) end
            return "[" .. table.concat(parts, ",") .. "]"
        end
        for k, x in pairs(v) do
            parts[#parts + 1] = M.encode(tostring(k)) .. ":" .. M.encode(x)
        end
        return "{" .. table.concat(parts, ",") .. "}"
    elseif t == "string" then
        return '"' .. (string.gsub(v, '[%c"\\]', function(c) return string.format("\\u%04x", string.byte(c)) end)) .. '"'
    elseif t == "number" or t == "boolean" then
        return tostring(v)
    end
    return "null"
end

return M
