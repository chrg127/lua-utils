local fmt = {}

local math = require "math"

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
    local s = (opts.show_ptr and tostring(t) .. " " or "") .. "{" .. line_end
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

function fmt.bin(n)
    local s = ""
    while n > 0 do
        local digit = n % 2
        s = tostring(digit) .. s
        n = math.floor(n / 2)
    end
    return s
end

-- replacement_field ::=  "{" [arg_pos] [":" format_spec] "}"
-- arg_pos           ::=  [digit+]
-- format_spec       ::=  [[fill]align][sign]["#"]["0"][width][grouping_option]["." precision][type]
-- fill              ::=  <any character>
-- align             ::=  "<" | ">" | "=" | "^"
-- sign              ::=  "+" | "-" | " "
-- width             ::=  digit+
-- grouping_option   ::=  "_" | ","
-- precision         ::=  digit+
-- type              ::=  "b" | "c" | "d" | "e" | "E" | "f" | "F" | "g" | "G" | "o" | "s" | "x" | "X" | "%"
function fmt.parse_format_string(s)
    local i = 1
    local prev, cur = "", string.char(s:byte(i))

    function advance()
        i = i + 1
        prev = cur
        cur = string.char(s:byte(i))
    end

    function consume(c)
        if cur == c then
            advance()
            return
        end
        error("error: can't consume " .. c)
    end

    function match(c)
        if cur ~= c then
            return false
        end
        advance()
        return true
    end

    function collect_num()
        local num = ""
        while cur >= "0" and cur <= "9" do
            num = num .. cur
            advance()
        end
        return tonumber(num)
    end

    function arg_pos() return collect_num() end

    function align()
        local nextc = string.char(s:byte(i+1))
        if nextc == ">" or nextc == "<" or nextc == "=" or nextc == "^" then
            advance()
            return prev, cur
        end
        if match(">") or match("<") or match("=") or match("^") then
            return " ", prev
        end
        return " ", nil
    end

    -- also handle {} ?
    function width()
        local n = collect_num()
        return n == nil and 0 or n
    end

    function precision()
        return collect_num()
    end

    function group_opt()
        if match("_") or match(",") then
            return prev
        end
        return nil
    end

    function typ()
            if match("s") then return "string"
        elseif match("?") then return "debug"
        elseif match("c") then return "char"
        elseif match("d") then return "decimal"
        elseif match("b") then return "binary"
        elseif match("o") then return "octal"
        elseif match("x") then return "hex", "lower"
        elseif match("X") then return "hex", "upper"
        elseif match("e") then return "scientific", "lower"
        elseif match("E") then return "scientific", "upper"
        elseif match("f") then return "fixed", "lower"
        elseif match("F") then return "fixed", "upper"
        elseif match("g") then return "general", "lower"
        elseif match("G") then return "general", "upper"
        elseif match("%") then return "percent"
        else                   return "char" end
    end

    function format_spec()
        local r = {}
        r.fill, r.align  = align()
        r.sign           = (match("+") or match("-") or match(" ")) and prev or nil
        r.alternate_conv = match("#")
        r.zero_pad       = match("0")
        r.width          = width()
        r.group_opt      = group_opt()
        r.precision      = match(".") and precision() or nil
        r.typ, r.case    = typ()
        if r.zero_pad and r.align == nil and r.fill == " " then
            r.align = "="
            r.fill = "0"
        end
        return r
    end

    function replacement_field()
        consume("{")
        local r = {}
        r.pos = arg_pos()
        if match(":") then
            r.spec = format_spec()
        end
        consume("}")
        return r
    end

    local r = replacement_field()
    fmt.pyprint("r =", r)
    return r, i
end

function format_num(spec, num)
    if spec.typ == "decimal" then
        return tostring(num)
    elseif spec.typ == "hex" then
        local s = string.format(spec.case == "upper" and "%X" or "%x", num)
        return (spec.alternate_conv and spec.case == "upper") and "0X" .. s
            or (spec.alternate_conv)                          and "0x" .. s
            or s
    elseif spec.typ == "binary" then
        local s = fmt.bin(num)
        return spec.alternate_conv and "0b" .. s or s
    elseif spec.typ == "octal" then
        local s = string.format("%o", num)
        return (spec.alternate_conv and spec.case == "upper") and "0O" .. s
            or (spec.alternate_conv)                          and "0o" .. s
            or s
    elseif spec.typ == "fixed" then
        return (spec.case == "upper" and math.is_nan(num)) and "NAN"
            or (spec.case == "upper" and math.is_inf(num)) and "INF"
            or string.format("%." .. (spec.precision == nil and 6 or spec.precision) .. "f", num)
    elseif spec.typ == "percent" then
        return (spec.case == "upper" and math.is_nan(num)) and "NAN"
            or (spec.case == "upper" and math.is_inf(num)) and "INF"
            or string.format("%." .. (spec.precision == nil and 6 or spec.precision) .. "f", num * 100)
    elseif spec.typ == "scientific" then
        local fmtstr = "%" .. (spec.precision == nil and "" or "." .. spec.precision)
                           .. (spec.case == "upper" and "E" or "e")
        return string.format(fmtstr, num)
    else
        return tostring(num)
    end
end

function format_arg(spec, arg)
    if spec == nil then
        return fmt.pystr(arg)
    end
    local s = type(arg) == "number" and format_num(spec, math.abs(arg)) or fmt.pystr(arg)
    if spec.precision ~= nil then
        if type(arg) == "string" then
            s = s:sub(spec.precision)
        else
            error("when using precision, type of argument must be string or number with type f/F")
        end
    end
    if type(arg) ~= "number" and spec.sign ~= nil then
        error("sign can't be used with number arguments")
    end
    local sign = type(arg) ~= "number" and ""
              or spec.typ == "percent" and ""
              or spec.sign == "+" and (arg < 0 and "-" or "+")
              or spec.sign == " " and (arg < 0 and "-" or " ")
              or (arg < 0 and "-" or "")
    if spec.align == nil then
        spec.align = type(arg) == "number" and ">" or "<"
    end
    if spec.align == "<" then
        s = sign .. s .. string.rep(spec.fill, spec.width - #s - #sign)
    elseif spec.align == ">" then
        s = string.rep(spec.fill, spec.width - #s - #sign) .. sign .. s
    elseif spec.align == "^" then
        local fill = string.rep(spec.fill, (spec.width - #s - #sign)/2)
        s = fill .. sign .. s .. fill
    elseif spec.align == "=" then
        s = sign .. string.rep(spec.fill, spec.width - #s - #sign) .. s
    end
    return s
    -- missing: #, group_opt, support for actual types
end

function fmt.pyformat(fmtstr, ...)
    local args, res, n, i = pack(...), "", 1, 1

    function get_pos(pos, n)
        if pos ~= nil then
            if pos < 1 or pos > #args then
                error("positional argument out of range")
            end
            return pos
        end
        return n
    end

    while i <= #fmtstr do
        if fmtstr:byte(i) == string.byte("{") then
            local parse_data, new_i = fmt.parse_format_string(fmtstr:sub(i))
            res = res .. format_arg(parse_data.spec, args[get_pos(parse_data.pos, n)])
            i = new_i
            n = n + 1
        else
            res = res .. string.char(fmtstr:byte(i))
        end
        i = i + 1
    end
    return res
end

return fmt
