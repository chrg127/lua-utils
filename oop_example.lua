local oop = require "oop"
local fmt = require "fmt"

-- declare a class:
local A = Object:extend("A", { val = 42 })

-- A is defined as a table.
-- using the simple print() function will show that A is an instance of Object.
-- using fmt's extended print, we can peek at the class's internals (show_ptr
-- also prints the table's tostring()).
-- in particular:
--     - all classes have a super() method, a __name key (used for instances, not
--       an actual attribute) and a __classname field (that will be what you
--       pass as the first argument to extend())
--     - the class A has a class attribute val. you can access this in methods
--       either with self.val or A.val.
--     - extend is also where you should be defining "static" methods.
fmt.pyprint_opts({ indent = 4, show_ptr = true }, "A =", A)

-- declare a constructor
function A:init(bar, greet)
    -- here we can declare any attribute we want.
    -- self will be set to a new instance.
    self.foo = bar
    self.greet = greet
end

-- create a new instance
local a = A(2, "hi")
-- you can also say:
local ab = oop.new(A, 3, "hii")

-- let's inspect this instance.
-- we find all attributes we declared in A:init(). we also find a __class key,
-- that points to the instance's class.
-- note that that __class key is the only real difference between objects created
-- with extend() and those created with classname(). this difference is important
-- when considering methods like super().
fmt.pyprint_opts({ indent = 4, show_ptr = true }, "a =", a)

-- declare a subclass of A
local B = A:extend("B", { qux = 64 })

-- inspecting B shows that it's an instance of A, with a single class field 'qux'
fmt.pyprint_opts({ indent = 4, show_ptr = true }, "B =", B)

-- you can, by the way, extend an object. this likely won't do any good for you,
-- so if this happens then a warning will be issued.
local aa = a:extend("aa")
fmt.pyprint_opts({ indent = 4, show_ptr = true }, "aa =", aa)

-- declare a method on A, then override it on B
function A:print_foo()
    print(self.foo)
end

function B:print_foo()
    print("foo is")
    -- to call a superclass method, you must use this syntax:
    self:super():print_foo()
    -- super() is actually a method found on Object, therefore it can be called
    -- on any instance of Object (i.e. any class)
    -- super() returns a proxy object that lets you access attributes and method
    -- of the superclass, but any method call will be done with self as the
    -- original object
    -- as an example, this also works:
    B:super():print_foo()
    -- and A:print_foo will be called with B as the self object, which in this
    -- example will print a nil value since B.foo doesn't exist.
    -- you can also do a normal function call and pass whatever you want as the
    -- self.this line is the same as self:super():print_foo()
    B:super().print_foo(self)
end

-- a little note about constructors. if a constructor is not defined, the
-- superclass's constructor will be used. if that is not defined, then the
-- superclass's subclass's will be used, and so on.
-- defining a constructor however won't automatically call the others up in
-- the chain. for that you must use super().
function B:init(some_value)
    self:super():init(1, "hello")
    self.some_value = some_value
end

local b = B("some_value")

b:print_foo()

-- operator overriding works as expected.
-- here's a simple vector class:
local Vec2 = Object:extend("Vec2")

function Vec2:init(x, y)
    self.x = x or 0
    self.y = y or 0
end

function Vec2:__add(v)
    self.x = self.x + v.x
    self.y = self.y + v.y
    return self
end

function Vec2:__mul(s)
    self.x = self.x * s
    self.y = self.y * s
    return self
end

local v1 = Vec2(4, 5)
local v2 = v1 + Vec2(5, 4)
local v3 = v2 * 3
print(v3.x, v3.y) -- prints 27 27

-- you can get an object's class directly using get_class:
fmt.pyprint(oop.get_class(a))

-- the library provides an is_instance function.
-- it will check if the provided object is an instance of a class, following
-- parent classes too.
-- of course, because classes are instances of other classes,
-- this function works on classes too.
-- note that if you just want to test the direct class (and not its parents),
-- just use __class.
print(oop.is_instance(a, A)) -- true
print(oop.is_instance(b, A)) -- true
print(oop.is_instance(a, Object)) -- true
print(oop.is_instance(v1, A)) -- false
print(oop.is_instance(b, Vec2)) -- false

-- unfortunately, bound methods don't really work.
-- it's possible to implement them, but requires more complex (and therefore
-- less performant) method lookup.
-- as a workaround, you can use oop.bind to pass bound methods
function B:test_bound()
    print(self.some_value)
end

local method = oop.bind(b, b.test_bound)
fmt.pyprint("method =", method)
method()

-- another utility function is oop.add_attributes. this can be used in ctors
-- (but also elsewhere) to add arbitrary attributes to objects.
local C = Object:extend("C")
function C:init(attrs)
    oop.add_attributes(self, attrs)
end

local c = C{x = 1, foo = "hi", bar = 3}
fmt.pyprint("c =", c)
print(c.x, c.foo, c.bar)

-- here's a really weird feature:
-- because classes are instances of their superclass, any method defined on a
-- superclass can be called on a class:
function A:some_method()
    print("some_method")
end

B:some_method()
