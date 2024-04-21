local oop = require('oop')
local fmt = require "fmt"

-- Define the base class 'Animal'
local Animal = Object:extend{}

function Animal:init(name, other)
    fmt.pyprint(name, other)
    self.name = name
end

function Animal:speak()
    return self.name .. " makes a sound."
end

-- Define the subclass 'Dog' that extends 'Animal'
local Dog = Animal:extend{}

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
-- print(Dog:super().speak(myDog)) -- Output: Rex makes a sound.

-- Check if myDog is an instance of Dog and Animal
print("Is myDog a Dog?", oop.is_instance(myDog, Dog))           -- Output: true
print("Is myDog an Animal?", oop.is_instance(myDog, Animal))    -- Output: true
