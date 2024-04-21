local oop = {}

Object = {}

function Object:extend(class)
    self.__index = self
    self.__call = function (class, ...)
        local inst = {}
        class.__index = class
        setmetatable(inst, class)
        if class.init ~= nil then
            inst:init(...)
        end
        return inst
    end

    function class:super()
        local obj = self
        local class = getmetatable(obj)
        -- if class == nil then
        --     error "passed argument not instance of any class"
        -- end
        local superclass = getmetatable(class)
        -- if superclass == nil then
        --     error "class of object doesn't have a superclass"
        -- end
        local proxy = { __ptr = self }

        function proxy:super()
            return class.super(obj)
        end

        return setmetatable(proxy, {
            __index = function (t, key)
                local method = superclass[key]
                if method == nil then
                    error "method not found"
                end
                if type(method) ~= "function" then
                    return method
                end
                local method_proxy = { __ptr = method }
                return setmetatable(method_proxy, {
                    __call = function (first_arg, ...)
                        if first_arg == superclass then
                            return method_proxy.__ptr(first_arg, ...)
                        end
                        return method_proxy.__ptr(proxy.__ptr, ...)
                    end
                })
            end
        })
    end

    return setmetatable(class, self)
end

function is_instance(obj, class)
    return getmetatable(obj) == class
end

-- alternate super() implementation

-- function super(obj, class)
--     class = class or getmetatable(obj)
--     if class == nil then
--         error "passed argument not instance of any class"
--     end
--     local superclass = getmetatable(class)
--     if superclass == nil then
--         error "class of object doesn't have a superclass"
--     end
--     local proxy = { __ptr = obj }
--     return setmetatable(proxy, {
--         __index = function (t, key)
--             local method = superclass[key]
--             if method == nil then
--                 error "method not found"
--             end
--             if type(method) ~= "function" then
--                 return method
--             end
--             local method_proxy = { __ptr = method }
--             return setmetatable(method_proxy, {
--                 __call = function (first_arg, ...)
--                     if first_arg == superclass then
--                         return method_proxy.__ptr(first_arg, ...)
--                     end
--                     return method_proxy.__ptr(proxy.__ptr, ...)
--                 end
--             })
--         end
--     })
-- end

return oop
