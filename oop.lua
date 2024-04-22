local oop = {}

local fmt = require "fmt"

Object = { __name = "instance of Object", __classname = "Object" }
setmetatable(Object, { __name = "Object" })
oop.Object = Object

function Object:super()
    local obj = self
    local class = self.__class and getmetatable(obj) or obj
    local superclass = getmetatable(class)
    local proxy = { __ptr = self, name = "proxy for " .. tostring(class) }

    function proxy:super()
        return class.super(obj)
    end

    return setmetatable(proxy, {
        __index = function (t, key)
            local method = superclass[key]
            if method == nil then
                error "method not found"
            elseif type(method) ~= "function" then
                return method
            else
                return function (self, ...)
                    -- if method was called on proxy, hijack it
                    return method(self == proxy and proxy.__ptr or self, ...)
                end
            end
        end
    })
end

function Object:extend(name, class)
    class = class or {}
    class.__classname = name

    if self.__class then
        print("note: extending an object:", tostring(self))
    end

    self.__index = self
    self.__call = function (class, ...)
        class.__name = "instance of " .. class.__classname
        class.__index = class
        local inst = setmetatable({ __class = class }, class)
        local init_method = inst.init
        if init_method ~= nil then
            init_method(inst, ...)
        end
        return inst
    end

    return setmetatable(class, self)
end

function oop.is_instance(obj, class)
    while obj ~= nil do
        local mt = getmetatable(obj)
        if mt == class then
            return true
        end
        obj = mt
    end
    return false
end

function oop.bind(obj, method)
    return function (...)
        return method(obj, ...)
    end
end

function oop.add_attributes(obj, attrs)
    for k, v in pairs(attrs) do
        obj[k] = v
    end
end

return oop
