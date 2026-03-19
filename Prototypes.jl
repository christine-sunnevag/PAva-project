
mutable struct Object
    slots::Dict{Symbol,Any}
    parents::Vector{Object}
end

function object(; slots...)
    Object(Dict(slots), Object[])
end

function get_slot(obj, name)
    return obj.slots[name]
end

function set_slot!(obj, name, value)
    obj.slots[name] = value
end


p = object(x=1)
println(get_slot(p, :x))

set_slot!(p, :x, 10)
println(get_slot(p, :x))