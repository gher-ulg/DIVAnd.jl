
type CovarIS{T} <: AbstractMatrix{T}
    IS:: AbstractMatrix{T}
    factors
end

function CovarIS{T}(IS::AbstractMatrix{T})
    factors = nothing
    CovarIS(IS,factors)
end


Base.inv{T}(C::CovarIS{T}) = C.IS

Base.size{T}(C::CovarIS{T}) = size(C.IS)

function Base.:*{T}(C::CovarIS{T}, M::AbstractMatrix{Float64})
    if C.factors != nothing
        return C.factors \ M
    else
        return C.IS \ M
    end
end

function Base.:*{T}(C::CovarIS{T}, M::AbstractVector{Float64})
    if C.factors != nothing
        return C.factors \ M
    else
        return C.IS \ M
    end
end


function Base.getindex{T}(C::CovarIS{T}, i::Int,j::Int)
    ei = zeros(eltype(C),size(C,1)); ei[i] = 1
    ej = zeros(eltype(C),size(C,1)); ej[j] = 1

    return (ej'*(C*ei))[1]
end


Base.:\{T}(C::CovarIS{T}, M::AbstractArray{Float64,2}) = C.IS * M

function factorize!{T}(C::CovarIS{T})
#    C.factors = cholfact(Symmetric(C.IS), Val{true})
    C.factors = cholfact(Symmetric(C.IS))
#    C.factors = cholfact(C.IS, Val{true})
end

# MatFun: a matrix defined by a function representing the matrix product

type MatFun{T}  <: AbstractMatrix{Float64}
    sz::Tuple{T,T}
    fun:: Function
    funt:: Function
end

Base.size{T}(MF::MatFun{T}) = MF.sz
Base.:*{T,S}(MF:: MatFun{T}, x::AbstractVector{S}) = MF.fun(x)
Base.:*{T,S}(MF:: MatFun{T}, M::AbstractMatrix{S}) = cat(2,[MF.fun(M[:,i]) for i = 1:size(M,2)]...)
Base.:transpose{T}(MF:: MatFun{T}) = MatFun((MF.sz[2],MF.sz[1]),MF.funt,MF.fun)
Base.Ac_mul_B{T,S}(MF:: MatFun{T}, x::AbstractVector{S}) = MF.funt(x)
