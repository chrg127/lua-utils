local fmt = {}

local old_tostring = tostring
local old_print = print

local function is_nan(n) return n ~= n end
local function is_inf(n) return n == math.huge or n == -math.huge end

local pack = table.pack or function(...)
    return { n = select('#', ...), ... }
end

function fmt.format_table(t, opts)
    function spaces(opts)
        return string.rep(" ", (opts.indent or 0) * (opts.depth or 1))
    end

    opts = opts or {}
    opts.indent = opts.indent or 0
    opts.depth = opts.depth or 0
    local line_end = (opts.indent ~= 0 and "\n" or "")
    if next(t) == nil then
        return spaces(opts) .. "{}"
    end
    local s = (opts.show_ptr and old_tostring(t) .. " " or "")
            .. "{" .. line_end
    opts.depth = opts.depth + 1
    local ss = spaces(opts)
    for k, v in pairs(t) do
        local key = type(k) == "string"
                  and k or "[" .. fmt.str_opts(opts, k) .. "]"
        s = s .. ss .. key .. " = "
              .. (v == t and '(self)' or fmt.str_opts(opts, v))
              .. ", " .. line_end
    end
    s = s:sub(1, -3) .. line_end
    opts.depth = opts.depth - 1
    return s .. spaces(opts) .. "}"
end

function fmt.str_opts(opts, ...)
    local args = pack(...)
    local s = ""
    for i = 1, args.n do
        s = s .. (type(args[i]) == "table"
                  and fmt.format_table(args[i], opts) .. " "
                  or  old_tostring(args[i]) .. " ")
    end
    return s:sub(1, -2)
end

function fmt.print_opts(opts, ...) old_print(fmt.str_opts(opts, ...)) end
function fmt.tostring(...) return fmt.str_opts(nil, ...) end
function fmt.print(...) return fmt.print_opts(nil, ...) end

function fmt.bin(n)
    local s = ""
    while n > 0 do
        local digit = n % 2
        s = (digit == 0 and "0" or "1") .. s
        n = math.floor(n / 2)
    end
    return s
end

function fmt.hex(n, upper)
    local s = ""
    local t = upper and { "0", "1", "2", "3", "4", "5", "6", "7",
                          "8", "9", "A", "B", "C", "D", "E", "F" }
                    or  { "0", "1", "2", "3", "4", "5", "6", "7",
                          "8", "9", "a", "b", "c", "d", "e", "f" }
    while n > 0 do
        s = s .. t[(n % 16) + 1]
        n = math.floor(n / 16)
    end
    return s
end

-- replacement_field ::=  "{" [arg_pos] [":" format_spec] "}"
-- arg_pos           ::=  [digit+]
-- format_spec       ::=  [[fill]align][sign]["#"]["0"][width]["." precision][type]
-- fill              ::=  <any character>
-- align             ::=  "<" | ">" | "=" | "^"
-- sign              ::=  "+" | "-" | " "
-- width             ::=  digit+
-- precision         ::=  digit+
-- type              ::=  "b" | "c" | "d" | "e" | "E" | "f" | "F" | "g" | "G" | "o" | "s" | "x" | "X" | "%"
local function parse_format_string(s)
    local i = 1
    local prev, cur = "", string.char(s:byte(i))

    local function advance()
        i = i + 1
        prev = cur
        cur = string.char(s:byte(i))
    end

    local function consume(c, error_string)
        if cur ~= c then
            error(error_string)
        end
        advance()
    end

    local function match(c)
        if cur == c then
            advance()
            return true
        end
        return false
    end

    local function collect_num(fail_val)
        local num = ""
        while cur >= "0" and cur <= "9" do
            num = num .. cur
            advance()
        end
        local n = tonumber(num)
        return n == nil and fail_val or n
    end

    local function arg_pos() return collect_num() end

    local function argument()
        local pos = arg_pos()
        consume("}")
        return { pos = pos }
    end

    local function align()
        local nextc = string.char(s:byte(i+1))
        if nextc == ">" or nextc == "<" or nextc == "=" or nextc == "^" then
            advance()
            local fill = prev
            advance()
            return fill, prev
        end
        if match(">") or match("<") or match("=") or match("^") then
            return " ", prev
        end
        return " ", nil
    end

    local function precision()
        return match("{") and argument() or collect_num()
    end

    local function typ()
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
        else                   return nil end
    end

    local function format_spec()
        local r = {}
        r.fill, r.align = align()
        r.sign          = (match("+") or match("-") or match(" ")) and prev or nil
        r.alt           = match("#")
        r.zero_pad      = match("0")
        r.width         = match("{") and argument() or collect_num(0)
        r.precision     = match(".") and precision() or nil
        r.typ, r.case   = typ()
        return r
    end

    local function replacement_field()
        consume("{", "expected { at start of format string")
        local r = {}
        local pos = arg_pos()
        local spec = match(":") and format_spec() or {
            fill = " ", width = 0, alt = false
        }
        spec.pos = pos
        consume("}", "expected } before end of format string, found " .. cur .. " instead")
        return spec
    end

    local r = replacement_field()
    return r, i
end

function fmt.format(fmtstr, ...)
    local args, res, n, i = pack(...), "", 1, 1

    local function format_num(spec, num)
        function prefix(if_upper, if_lower)
            return (spec.alt and spec.case == "upper") and if_upper
                or  spec.alt and if_lower or ""
        end
        if spec.precision ~= nil and spec.typ ~= nil and spec.typ ~= "scientific"
            and spec.typ ~= "fixed" and spec.typ ~= "general" then
            error("precision not allowed in format specifier '" .. spec.typ .. "'")
        end
        if spec.typ == "decimal" then
            return old_tostring(num)
        elseif spec.typ == "binary" then
            return prefix("0B", "0b") .. fmt.bin(num)
        elseif spec.typ == "hex" then
             return prefix("0X", "0x") .. fmt.bin(num, spec.case == "upper")
        elseif spec.typ == "octal" then
            return prefix("0O", "0o") .. string.format("%o", num)
        elseif spec.typ == "scientific" then
            return string.format("%" .. (spec.alt and "#" or "")
                                     .. "." .. (spec.precision == nil and 6 or spec.precision)
                                     .. (spec.case == "upper" and "E" or "e"), num)
        elseif spec.typ == "fixed" then
            return (spec.case == "upper" and is_nan(num)) and "NAN"
                or (spec.case == "upper" and is_inf(num)) and "INF"
                or string.format("%" .. (spec.alt and "#" or "")
                                     .. "." .. (spec.precision == nil and 6 or spec.precision)
                                     .. "f", num)
        elseif spec.typ == "general" or spec.typ == nil then
            return (spec.case == "upper" and is_nan(num)) and "NAN"
                or (spec.case == "upper" and is_inf(num)) and "INF"
                or string.format("%" .. (spec.alt and "#" or "")
                                     .. "." .. (spec.precision == nil and 6 or spec.precision)
                                     .. (spec.case == "upper" and "G" or "g"), num)
        elseif spec.typ == "percent" then
            spec.typ = "fixed"
            return format_num(num * 100) .. "%"
        else
            return error("unknown format " .. spec.typ .. " for argument '" .. num .. "' of type 'number'")
        end
    end

    local function format_string(spec, arg)
        if spec.typ == "string" or spec.typ == nil then
            return arg:sub(spec.precision == nil and 0 or spec.precision)
        else
            error("invalid format '" .. spec.typ .. "' for argument '" .. arg .. "' of type 'string'")
        end
    end

    local function format_char(arg)
        if arg < 0 then
            error("character code out of range: " .. num)
        else
            return utf8 ~= nil and utf8.char(arg) or string.char(arg)
        end
    end

    -- this is an extension
    local function format_table(spec, arg)
        return fmt.format_table(arg, spec.alt
            and { indent = spec.width == 0 and 4 or spec.width }
            or  {})
    end

    local function format_arg(spec, arg)
        local arg_type = type(arg)
        if spec.typ ~= nil and arg_type ~= "number" and arg_type ~= "string" then
            error("invalid format '" .. spec.typ .. "' for argument '" .. arg .. "' of type '" .. arg_type .. "'")
        end
        local s = spec.typ == "char" and format_char(arg)
               or arg_type == "number" and format_num(spec, math.abs(arg))
               or arg_type == "string" and format_string(spec, arg)
               or arg_type == "table" and format_table(spec, arg)
               or fmt.tostring(arg)
        if spec.sign ~= nil and arg_type ~= "number" then
            error("sign can't be used with argument '" .. arg .. "' of type '" .. arg_type .. "'")
        end
        local sign = arg_type ~= "number" and ""
                  or spec.typ == "percent" and ""
                  or spec.typ == "char" and ""
                  or spec.sign == "+" and (arg < 0 and "-" or "+")
                  or spec.sign == " " and (arg < 0 and "-" or " ")
                  or (arg < 0 and "-" or "")
        spec.fill = (spec.zero_pad and spec.fill == " ") and "0" or spec.fill
        if spec.align == "=" and arg_type ~= "number" then
            error("'=' alignment not allowed in argument '" .. arg .. "' of type '" .. arg_type .. "'")
        end
        spec.align = (spec.align == nil and arg_type == "number" and spec.zero_pad) and "="
                  or (spec.align == nil and arg_type == "number") and ">"
                  or spec.align == nil and "<" or spec.align
        if spec.align == "<" then
            return sign .. s .. string.rep(spec.fill, spec.width - #s - #sign)
        elseif spec.align == ">" then
            return string.rep(spec.fill, spec.width - #s - #sign) .. sign .. s
        elseif spec.align == "^" then
            local fill = string.rep(spec.fill, math.floor((spec.width - #s - #sign)/2))
            return fill .. sign .. s .. fill
        elseif spec.align == "=" then
            return sign .. string.rep(spec.fill, spec.width - #s - #sign) .. s
        end
    end

    local function get_arg(args, pos)
        if pos ~= nil then
            if pos < 1 or pos > #args then
                error("positional argument out of range")
            end
            return args[pos]
        else
            n = n + 1
            if n-1 > #args then
                error("not enough arguments")
            end
            return args[n-1]
        end
    end

    local function dependent_arg(arg, name)
        if type(arg) == "table" then
            arg = get_arg(args, spec.width.pos)
            if type(arg) ~= "number" then
                error(name .. " must be a number")
            end
        end
        return arg
    end

    while i <= #fmtstr do
        if fmtstr:byte(i) == string.byte("{") then
            local spec, index = parse_format_string(fmtstr:sub(i))
            spec.width     = dependent_arg(spec.width, "width")
            spec.precision = dependent_arg(spec.precision, "precision")
            res = res .. format_arg(spec, get_arg(args, spec.pos))
            i = index
        else
            res = res .. string.char(fmtstr:byte(i))
        end
        i = i + 1
    end
    return res
end

function fmt.patch_globals()
    _G.tostring = fmt.tostring
    _G.print = fmt.print
end

return fmt
