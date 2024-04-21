local fmt = {}

local pack = table.pack or function(...)
    return { n = select('#', ...), ... }
end

local function spaces(opts)
    return string.rep(" ", (opts.indent or 0) * (opts.depth or 1))
end

function fmt.format_table(t, opts)
    opts = opts or {}
    opts.indent = opts.indent or 0
    opts.depth = opts.depth or 0
    local line_end = (opts.indent ~= 0 and "\n" or "")
    local next = next
    if next(t) == nil then
        return spaces(opts) .. "{}"
    end
    local s = (opts.table_pointers and tostring(t) .. " " or "") .. "{" .. line_end
    opts.depth = opts.depth + 1
    local ss = spaces(opts)
    for k, v in pairs(t) do
        local key = type(k) == "string" and k or "[" .. fmt.pystr_opts(opts, k) .. "]"
        s = s .. ss .. key .. " = "
              .. (v == t and '(self)' or fmt.pystr_opts(opts, v))
              .. ", " .. line_end
    end
    s = s:sub(1, -3) .. line_end
    opts.depth = opts.depth - 1
    return s .. spaces(opts) .. "}"
end

function fmt.pystr_opts(opts, ...)
    local args = pack(...)
    local s = ""
    for i = 1, args.n do
        if type(args[i]) == "table" then
            s = s .. fmt.format_table(args[i], opts) .. " "
        else
            s = s .. tostring(args[i]) .. " "
        end
    end
    return s:sub(1, -2)
end

function fmt.pyprint_opts(opts, ...)
    print(fmt.pystr_opts(opts, ...))
end

function fmt.pystr(...) return fmt.pystr_opts(nil, ...) end
function fmt.pyprint(...) return fmt.pyprint_opts(nil, ...) end

function fmt.pyformat(fmtstr, ...)
    local args = pack(...)
    local n = 1
    local res = ""
    local i = 1
    while i <= #fmtstr do
        if fmtstr:byte(i) == string.byte("{") and fmtstr:byte(i+1) == string.byte("}") then
            res = res .. fmt.pystr(args[n])
            i = i + 1
        else
            res = res .. string.char(fmtstr:byte(i))
        end
        i = i + 1
    end
    return res
end

return fmt
