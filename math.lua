local math = {}

function math.clamp(n, a, b)
    return math.max(math.min(n, b), a)
end

function math.sign(n)
    return x < 0 and -1 or x > 0 and 1 or 0
end

function math.is_nan(n)
    return n ~= n
end

function math.is_inf(n)
    return n == math.huge or n == -math.huge
end

return math
