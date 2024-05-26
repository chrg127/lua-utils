local util = {}

-- Loop over every byte of a string using for.
function util.charbytes(s)
    function iter(s, i)
        i = i + 1
        if i <= #s then
            return i, string.char(s:byte(i))
        end
        return nil
    end
    return iter, s, 0
end

-- Loop over every UTF-8 codepoint of a string using for.
function util.chars(s)
    local fn = utf8.codes(s)
    function iter(s, i)
        local i, c = fn(s, i)
        if i ~= nil then
            return i, utf8.char(c)
        end
    end
    return iter, s, 0
end

-- Returns true if any value of `t` is true.
function util.any(t)
    for _, v in ipairs(t) do
        if v then
            return true
        end
    end
    return false
end

-- Returns true if all values of `t` are true.
function util.all(t)
    for _, v in ipairs(t) do
        if not v then
            return false
        end
    end
    return true
end

return util
