
mutable struct Object
    slots::Dict{Symbol,Any}
    parents::Vector{Object}
end

function object(; slots...)
    Object(Dict(slots), Object[])
end

function get_slot(obj, name)
    if haskey(obj.slots, name)
        return obj.slots[name]
    else
        for parent in obj.parents
            if haskey(parent.slots, name)
                return parent.slots[name]
            end
        end
    end
    error("Slot $name not found")
end

function set_slot!(obj, name, value)
    obj.slots[name] = value
end


function clone(proto; slots...)
    new_obj = Object(Dict(slots), [proto])
    return new_obj
end

function send(obj, msg, args...)
    value = get_slot(obj, msg)
    if value isa Function
        return value(obj, args...)
    else
        return value
    end
end


dog = object(
    name="Rex",
    speak=(self) -> "$(get_slot(self, :name)) says woof"
)

println(send(dog, :speak))