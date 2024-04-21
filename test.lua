local fmt = require "fmt"
local oop = require "oop"

function test_fmt()
    local nested = { a = 1, b = 2, c = { d = 3, e = 4 }}
    print(fmt.format_table(nested, { indent = 4 }))
    print(fmt.format_table(nested, { indent = 2, table_pointers = true }))
    fmt.pyprint(5, print, {}, nil, { 1, 2, "a" }, io.stdin, { a = 1, b = 2 })
    local mt = { __add = function () return 1 end }
    local t = setmetatable({}, mt)
    fmt.pyprint(getmetatable(t))
    print(fmt.pyformat("x = {}", 1))
end

function test_oop()
    local Animal = Object:extend{
        cries = 0,
    }

    function Animal:init()
        print("animal init")
    end

    function Animal:cry()
        print("adding cries")
        self.cries = self.cries + 1
    end

    local Cat = Animal:extend{}

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

    fmt.pyprint_opts({ table_pointers = true }, "Object =", Object)
    fmt.pyprint_opts({ table_pointers = true }, "Animal =", Animal)
    fmt.pyprint_opts({ table_pointers = true }, "Cat =", Cat)
    fmt.pyprint_opts({ table_pointers = true }, "cat =", cat)
    fmt.pyprint_opts({ table_pointers = true }, "cat:super() =", cat:super())
    fmt.pyprint_opts({ table_pointers = true }, "cat:super():super() =", cat:super():super())

    local anim = Animal()
    anim:cry()
    print(anim.cries)
    -- will error
    anim:print_data()
end

test_fmt()
test_oop()
