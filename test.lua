local fmt = require "fmt"
local oop = require "oop"

function test_fmt()
    local nested = { a = 1, b = 2, c = { d = 3, e = 4 }}
    print(fmt.format_table(nested, { indent = 4 }))
    print(fmt.format_table(nested, { indent = 2, show_ptr = true }))
    fmt.pyprint(5, print, {}, nil, { 1, 2, "a" }, io.stdin, { a = 1, b = 2 })
    local mt = { __add = function () return 1 end }
    local t = setmetatable({}, mt)
    fmt.pyprint(getmetatable(t))
    print(fmt.pyformat("x = {}", 1))
end

function test_oop()
    local Animal = Object:extend("Animal", {
        cries = 0,
    })

    function Animal:init()
        print("animal init")
    end

    function Animal:cry()
        print("adding cries")
        self.cries = self.cries + 1
    end

    local Cat = Animal:extend("Cat", {})

    function Cat:init(init_val)
        self:super():init()
        self.value = init_val or 0
        self.data = { "test data" }
    end

    function Cat:cry()
        print("meow!")
        self:super():cry()
    end

    function Cat:print_data()
        fmt.pyprint(self.data)
    end

    function Cat:__add(other)
        return Cat(self.value + other.value)
    end

    local cat = Cat(1)
    cat:cry()
    cat:cry()
    print(cat.cries)

    local catsum = cat + Cat(4)
    print(catsum.value)

    -- fmt.pyprint_opts({ show_ptr = true }, "Object =", Object)
    -- fmt.pyprint_opts({ show_ptr = true }, "Animal =", Animal)
    -- fmt.pyprint_opts({ show_ptr = true }, "Cat =", Cat)
    -- fmt.pyprint_opts({ show_ptr = true }, "cat =", cat)
    -- fmt.pyprint_opts({ show_ptr = true }, "cat:super() =", cat:super())
    -- fmt.pyprint_opts({ show_ptr = true }, "cat:super():super() =", cat:super():super())

    local anim = Animal()
    anim:cry()
    print(anim.cries)
    -- will error
    -- anim:print_data()
end

function test_oop2()
    -- Define the base class 'Animal'
    local Animal = Object:extend("Animal")

    function Animal:init(name, other)
        self.name = name
    end

    function Animal:speak()
        return self.name .. " makes a sound."
    end

    -- Define the subclass 'Dog' that extends 'Animal'
    local Dog = Animal:extend("Dog")

    function Dog:init(name, breed)
        self:super():init(name) -- Call the superclass's init method
        self.breed = breed
    end

    function Dog:speak()
        return self.name .. " barks!"
    end

    -- Create an instance of Dog
    local myDog = Dog("Rex", "Golden Retriever")

    -- Test the functionality
    print(myDog:speak())           -- Output: Rex barks!
    print(Dog:super().speak(myDog)) -- Output: Rex makes a sound.

    -- Check if myDog is an instance of Dog and Animal
    print("Is myDog a Dog?", oop.is_instance(myDog, Dog))           -- Output: true
    print("Is myDog an Animal?", oop.is_instance(myDog, Animal))    -- Output: true
end

test_fmt()
test_oop()
test_oop2()
