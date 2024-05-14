local util = {}

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

return util
