
mutable struct Object
    slots::Dict{Symbol,Any}
    parents::Vector{Object}
end

const lobby = Object(Dict{Symbol, Any}(), Object[])

function object(; slots...)
    Object(Dict(slots), [lobby])
end

function get_slot(obj, name)
    if has_own_slot(obj, name)
        return obj.slots[name]
    end    

    for parent in obj.parents
        if has_slot(parent, name)
            return get_slot(parent, name)
        end
    end
    
    error("Slot $name not found")
end

function set_slot!(obj, name, value)
    obj.slots[name] = value
end

function has_own_slot(obj, name)
    return haskey(obj.slots, name)
end

function has_slot(obj, name)
    if has_own_slot(obj, name)
        return true
    end

    for parent in obj.parents
        if has_slot(parent, name)
            return true
        end
    end 

    return false
end

function own_slots(obj)
    return collect(keys(obj.slots))
end

function get_parents(obj)
    return obj.parents
end

function add_parent!(obj, parent)
    push!(obj.parents, parent)
end

function remove_parent!(obj, parent)
    filter!(p -> p !== parent, obj.parents)
end

function set_parents!(obj, parents)
    obj.parents = parents
end 

function clone(proto; slots...)
    new_obj = Object(Dict(slots), [proto])
    return new_obj
end

set_slot!(lobby, :doesNotUnderstand,
    (self, msg, args...) -> error("Object does not understand message $msg")
)

function send(obj, msg, args...)
    if has_slot(obj, msg)
        value = get_slot(obj, msg)
        if value isa Function
            return value(obj, args...)
        else
            return value
        end
    else 
        dnu = get_slot(obj, :doesNotUnderstand)
        return dnu(obj, msg, args...)
    end
end




