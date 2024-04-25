local oop = {}

local fmt = require "fmt"

-- Glossary:
-- - object: a lua table that has Object or another object as its metatable.
--   The object's metatable is its 'class', and the object is said to be an
--   'instance' of that class.
--
-- - class: an object created by extending Object or another class.
--
-- - instance of X: an object that was created by extending X or one of its
--   subclasses, or calling oop.new with X or one of its subclasses as the
--   first argument.
--
-- - subclass of X: a class that was created by extending X or one of its
--   subclasses.
--
-- - superclass: a superclass of X is any class that is either the class of
--   X's class or a superclass of X's class.
--
-- - descriptor: an attribute of an object that is specifically a table with
--   a __get function inside. When it's accessed, the descriptor runs the __get
--   function and returns its result.

-- Any object is an instance of a class. This function gets that class.
function oop.get_class(obj)
    return getmetatable(obj)
end

-- Gets an attribute from an object.
function oop.get_attr(obj, attr_name)
    local attr = oop.get_class(obj)[attr_name]
    if type(attr) == 'table' and type(attr.__get) == 'function' then
        return attr.__get(obj)
    else
        return attr
    end
end

-- Creates a new object, which will be an instance of 'class'.
--
--    +--------------+       +---------------------------+
--    |    object    |------>|     @class (metatable)    |
--    +--------------+       +---------------------------+
--    | (attributes) |       | __instname = "class"      |
--    +--------------+       | __name = "class instance" |
--                           | __call = oop.new          |
--                           | __index = oop.get_attr    |
--                           | (methods, operators)      |
--                           +---------------------------+
--
-- An init method is called if found. By default it searches the entire chain
-- and stops when it finds one defined (if found). Only the first init() method
-- found is called, any more init() methods from up in the chain must be called
-- manually.
function oop.new(class, ...)
    local inst = setmetatable({}, class)
    inst.__instname = class.__name
    inst.__name = class.__name .. " instance"
    local init_method = inst.init
    if init_method ~= nil then
        init_method(inst, ...)
    end
    return inst
end

-- Base object from which to create new instances. It contains nothing except
-- basic information found in every class.
-- It's metatable is not a class and is only used for print functionality.
-- It's not marked 'local' so it can be used without putting 'oop.' as a prefix.
-- It's still exported under 'oop' nonetheless.
Object = {
    __instname = "Object",
    __name = "Object instance",
    __index = oop.get_attr,
    __call = oop.new
}
setmetatable(Object, { __name = "Object" })
oop.Object = Object

-- extend() is used to create new classes. Formally, a new object is created
-- with extend(), and that is an instance of the class it was extended from.
-- The function creates a new object with this structure:
--
--    +---------------------------+       +-----------------------------------+
--    |           object          |------>|         self (metatable)          |
--    +---------------------------+       +-----------------------------------+
--    | __instname = @name        |       | __instname = (name of class)      |
--    | __index = oop.get_attr    |       | __index = oop.get_attr            |
--    | __call = oop.new          |       | __call = oop.new                  |
--    | __name = "@name instance" |       | __name = (name of class) instance |
--    | @attrs                    |       | (attributes, methods, operators)  |
--    +---------------------------+       +-----------------------------------+
--
-- @name is the name of the new class. The library uses it for two things: first,
-- it provides a way for the user to figure out which class is which by having
-- @obj.__instname set to @name. Second, when tostring()-ing an instance of @obj,
-- print() will put @obj.__name instead of "table" in the result.
-- @attrs contains any class-specific attributes to define in the new class. It
-- can be empty.
function Object:extend(name, attrs)
    local obj = setmetatable(attrs or {}, self)
    obj.__instname = name
    obj.__name = (name or "unknown class") .. " instance"
    obj.__index = oop.get_attr
    obj.__call = oop.new
    return obj
end

-- Returns a proxy object to @class that will call methods from @class with the
-- self pointer set to @self. @class must be either @self's class or one
-- of its parents up in the chain. As an example, with A -> B -> b:
--     b:super(B)      -- proxy to B, overrides any function set on b
--     b:super(A)      -- proxy to A, overrides any function set on b and B
--     B:super(A)      -- proxy to A, self points to B
--     B:super(Object) -- proxy to Object, self points to B
function Object:super(class)
    if class == nil then
        error("super() needs a class")
    elseif not oop.is_instance(self, class) then
        error(tostring(self) .. "is not an instance of " .. class.__instname)
    end
    local proxy = { __ptr = self }
    return setmetatable(proxy, {
        __index = function (t, key)
            local method = class[key]
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

-- Checks if @obj is an instance of @class. An object is an instance of a class
-- if was created by extending or using new() on that class or one of its
-- subclasses.
-- As an example: A -> B -> b, is_instance(b, A) == true.
function oop.is_instance(obj, class)
    while obj ~= nil do
        local superclass = oop.get_class(obj)
        if superclass == class then
            return true
        end
        obj = superclass
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

-- Creates a simple descriptor with only a __get function defined.
-- Descriptors run code when accessed.
function oop.property(fn)
    return { __get = fn }
end

return oop
