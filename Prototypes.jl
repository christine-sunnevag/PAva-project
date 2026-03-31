# Core

mutable struct Object
    slots::Dict{Symbol,Any}
    parents::Vector{Object}
end

const lobby = Object(Dict{Symbol, Any}(), Object[])

# Declared early so lobby slots can reference them
true_obj = Object(Dict{Symbol,Any}(), Object[])
false_obj = Object(Dict{Symbol,Any}(), Object[])

function object(; slots...)
    Object(Dict(slots), [lobby])
end

Base.getproperty(obj::Object, name::Symbol) =
    name in fieldnames(Object) ? getfield(obj, name) : get_slot(obj, name)

Base.setproperty!(obj::Object, name::Symbol, value) =
    name in fieldnames(Object) ? setfield!(obj, name, value) : set_slot!(obj, name, value)

# Slot access

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

function own_slots(obj)
    return collect(keys(obj.slots))
end

# Parent management

function get_parents(obj)
    return obj.parents
end

function add_parent!(obj, parent)
    push!(obj.parents, parent)
end

function remove_parent!(obj, parent)
    filter!(p -> p !== parent, obj.parents)
end

function set_parents!(obj, parents...)
    obj.parents = collect(parents)
end

# Clone

function clone(proto; slots...)
    Object(Dict(slots), [proto])
end

set_slot!(lobby, :clone,
    (self) -> clone(self)
)

# Traits

function trait(; methods...)
    Object(Dict{Symbol,Any}(methods), Object[])
end

function compose_traits(traits...; resolve=Dict{Symbol,Any}())
    merged = Dict{Symbol,Any}()
    conflicts = Set{Symbol}()

    for t in traits
        for (name, val) in t.slots
            if haskey(merged, name) && !haskey(resolve, name)
                push!(conflicts, name)
            else
                merged[name] = val
            end
        end
    end

    if !isempty(conflicts)
        error("Trait conflict on: $(join(conflicts, ", "))")
    end

    for (name, val) in resolve
        merged[name] = val
    end

    Object(merged, Object[])
end

function use_trait!(obj, t)
    for (name, val) in t.slots
        if !has_own_slot(obj, name)
            set_slot!(obj, name, val)
        end
    end
    obj
end

# Become

function become!(a::Object, b::Object)
    a.slots, b.slots = b.slots, a.slots
    a.parents, b.parents = b.parents, a.parents
    nothing
end

set_slot!(lobby, :become,
    (self, other) -> become!(self, other)
)

# Does not understand

set_slot!(lobby, :doesNotUnderstand,
    (self, msg, args...) -> error("Object does not understand message $msg")
)

# Responds to

set_slot!(lobby, :respondsTo,
    (self, msg) -> has_slot(self, msg) ? true_obj : false_obj
)

# Is a

set_slot!(lobby, :isA,
    (self, proto) -> begin
        if self === proto
            return true_obj
        end
        for p in get_parents(self)
            if send(p, :isA, proto) === true_obj
                return true_obj
            end
        end
        return false_obj
    end
)

# To object base

function to_object(x::Object)
    return x
end

# Boolean objects

function to_object(x::Bool)
    return x ? true_obj : false_obj
end

set_slot!(true_obj, :ifTrue, (self, block) -> send(block, :value))
set_slot!(false_obj, :ifTrue, (self, block) -> nothing)

set_slot!(true_obj, :ifFalse, (self, block) -> nothing)
set_slot!(false_obj, :ifFalse, (self, block) -> send(block, :value))

set_slot!(true_obj, :ifTrueIfFalse,
    (self, t_block, f_block) -> send(t_block, :value))

set_slot!(false_obj, :ifTrueIfFalse,
    (self, t_block, f_block) -> send(f_block, :value))

set_slot!(true_obj, :not, (self) -> false_obj)
set_slot!(false_obj, :not, (self) -> true_obj)

set_slot!(true_obj, :and, (self, other) -> to_object(other))
set_slot!(false_obj, :and, (self, other) -> false_obj)

set_slot!(true_obj, :or, (self, other) -> true_obj)
set_slot!(false_obj, :or, (self, other) -> to_object(other))

# Functions

function to_object(f::Function)
    obj = object()

    set_slot!(obj, :value, (self, args...) -> f(args...))

    set_slot!(obj, :whileTrue,
        (self, body) ->
            send(send(self, :value), :ifTrue,
                () -> begin
                    send(body, :value)
                    send(self, :whileTrue, body)
                end))

    set_slot!(obj, :whileFalse,
        (self, body) ->
            send(send(self, :value), :ifFalse,
                () -> begin
                    send(body, :value)
                    send(self, :whileFalse, body)
                end))

    return obj
end

# Numbers

function to_object(n::Number)
    obj = object()

    set_slot!(obj, :value, n)

    set_slot!(obj, :to,
        (self, other) -> begin
            a = get_slot(self, :value)
            b = other isa Object ? get_slot(other, :value) : other
            return to_object(a:b)
        end)

    set_slot!(obj, :timesRepeat,
        (self, block) -> begin
            n = get_slot(self, :value)
            counter = to_object(1)
            send(
                () -> get_slot(counter, :value) <= n,
                :whileTrue,
                () -> begin
                    send(block, :value)
                    set_slot!(counter, :value, get_slot(counter, :value) + 1)
                end)
        end)

    set_slot!(obj, :do,
        (self, block) -> begin
            n = get_slot(self, :value)
            send(to_object(0:(n-1)), :do, block)
        end)

    return obj
end

# Ranges

function to_object(r::AbstractRange)
    obj = object()

    set_slot!(obj, :value, r)

    set_slot!(obj, :do,
        (self, block) -> begin
            r0 = get_slot(self, :value)

            function iter(r)
                send(to_object(isempty(r)), :ifTrueIfFalse,
                    () -> nothing,
                    () -> begin
                        send(block, :value, first(r))
                        iter(r[2:end])
                    end
                )
            end

            iter(r0)
        end
    )

    set_slot!(obj, :collect,
        (self) -> begin
            result = []
            send(self, :do, x -> push!(result, x))
            result
        end)

    set_slot!(obj, :select,
        (self, block) -> begin
            result = []
            send(self, :do,
                x -> send(to_object(send(block, :value, x)), :ifTrue,
                    () -> push!(result, x)))
            result
        end)

    set_slot!(obj, :injectInto,
        (self, acc, func) -> begin
            result = Ref(acc)
            send(self, :do,
                x -> result[] = send(func, :value, result[], x))
            result[]
        end)

    set_slot!(obj, :by,
        (self, step) -> begin
            r = get_slot(self, :value)
            step_val = step isa Object ? get_slot(step, :value) : step
            return to_object(first(r):step_val:last(r))
        end)

    return obj
end

# Message passing

function send(obj, msg, args...)
    obj = to_object(obj)

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

macro send(obj, msg, args...)
    return :(send($(esc(obj)), $(QuoteNode(msg)), $(map(esc, args)...)))
end

