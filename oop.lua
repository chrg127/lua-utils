local oop = {}

local fmt = require "fmt"

-- Creates a new object, which will be an instance of 'class'.
-- The structure is essentially:
--
--    +---------+       +----------------------+
--    | object  |------>| metatable (class)    |
--    | (attrs) |       | (methods, operators) |
--    +---------+       +----------------------+
--
-- class.__name is set so that printing an instance of this class will
-- print "instance of 'class' (pointer)" instead of "table (pointer)".
-- Each instance also has a field __is_instance to permit differentiating
-- between objects created with new() and objects created with Object:extend.
-- An init method is called if found. By default it searches all superclasses
-- and stops when it finds one. It won't call any superclass's init method,
-- calling those must be done from the class.
function oop.new(class, ...)
    class.__index = class
    class.__name = class.__classname and "instance of " .. class.__classname
                                     or "instance of unknown class"
    local inst = setmetatable({ __is_instance = true }, class)
    local init_method = inst.init
    if init_method ~= nil then
        init_method(inst, ...)
    end
    return inst
end

-- Base object from which to create new classes. It contains nothing except
-- basic information found in every class.
-- Its metatable is not a class.
-- It is not marked 'local' so it can be used without the jarring 'oop.'. It
-- is still exported under 'oop' nonetheless.
Object = { __name = "instance of Object", __classname = "Object" }
setmetatable(Object, { __name = "Object" })
oop.Object = Object

-- extend() is how you create new classes. Formally, the object on which
-- you call extend is a prototype of the new object you're creating. In this
-- library, however, extend() is often used to create new classes.
-- 'name' is the name of the new class. It will be used by the library in some
-- cases (such as printing an instance's class with print).
-- 'obj' contains any class-specific attributes you want. It can be empty.
-- The function creates a new object with this structure:
--
--    +--------------------+       +------------------------------+
--    |      object        |------>| self (superclass, metatable) |
--    +--------------------+       +------------------------------+
--    | __classname = name |       |       __call = oop.new       |
--    | (other attributes) |       | (other attrs, __classname?)  |
--    +--------------------+       +------------------------------+
--
function Object:extend(name, obj)
    if self.__is_instance then
        print("note: extending an object:", tostring(self))
    end
    obj = obj or {}
    obj.__classname = name
    self.__index = self
    self.__call = oop.new
    return setmetatable(obj, self)
end

-- Returns a proxy object to the superclass of self. If self is an instance, it
-- first retrieves its class.
-- As an example, with A -> B -> b:
--   - b:super() => proxy to A
--   - B:super() => proxy to A
--   - A:super() => proxy to Object
-- The proxy accesses any attribute or function on the class normally, but any
-- method called will be called with self set to the self passed to super().
function Object:super()
    local class = self.__is_instance and getmetatable(self) or self
    local superclass = getmetatable(class)
    local proxy = { __ptr = self }

    function proxy:super()
        return class.super(obj)
    end

    return setmetatable(proxy, {
        __index = function (t, key)
            local method = superclass[key]
            if method == nil then
                error "attribute or method not found"
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

-- Checks if 'obj' is an instance of 'class'. It doesn't just look up the
-- immediate class of 'obj', but traverses the entire chain.
-- Therefore, with A -> B -> b, is_instance(b, A) == true.
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

-- Bind an object to a function. Useful for creating bound methods.
function oop.bind(obj, fun)
    return function (...)
        return fun(obj, ...)
    end
end

-- Adds attributes in 'attrs' to an object.
function oop.add_attributes(obj, attrs)
    for k, v in pairs(attrs) do
        obj[k] = v
    end
end

return oop
