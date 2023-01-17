
mutable struct CovarIS{T,TA} <: AbstractMatrix{T}
    IS::TA
    factors::Union{SuiteSparse.CHOLMOD.Factor{T},AlgebraicMultigrid.Preconditioner,Nothing}
    maxiter::Int
    abstol::Float64
    reltol::Float64
    verbose::Bool
end

function CovarIS(IS::TA; maxiter = 100,
                 abstol = 0., reltol = 1e-5, verbose=true) where {TA<:AbstractMatrix}
    factors = nothing
    @debug "CovarIS: reltol: $(reltol)"
    @debug "CovarIS: abstol: $(abstol)"
    @debug "CovarIS: maxiter: $(maxiter)"
    return CovarIS{eltype(TA),TA}(IS, factors, maxiter,abstol,reltol,verbose)
end


Base.inv(C::CovarIS) = C.IS

Base.size(C::CovarIS) = size(C.IS)

function Base.:*(C::CovarIS, v::TV)::TV where {TV<:AbstractVector{Float64}}
    if C.factors isa AlgebraicMultigrid.Preconditioner
        @debug "Call conjugate gradient with $(C.maxiter) iterations."
        @debug "Relative tolerance $(C.reltol)"
        @debug "Note the following is the norm of the residual, i.e. the sum (not the mean) of all elements of the residual squared"
        @debug "checksum $(sum(C.IS))  $(sum(v))"
        @debug "size $(size(C.IS))  $(size(v))"

        log = true
        @debug begin
            log = true
        end
        x,convergence_history = cg(
            C.IS, v, Pl = C.factors,
            verbose = C.verbose,
            log = log,
            abstol = C.abstol,
            reltol = C.reltol,
            maxiter = C.maxiter)

        @debug "Number of iterations: $(convergence_history.iters)"
        @debug "Final norm of residue: $(convergence_history.data[:resnorm][end])"
        @debug begin
            @show norm(C.IS * x - v)
        end
        @show convergence_history
		return x
    elseif C.factors != nothing
        return C.factors \ v
    else
        return C.IS \ v
    end
end

Base.:*(C::CovarIS, v::SparseVector{Float64,Int}) = C * full(v)


function A_mul_B(C::CovarIS, M::TM)::TM where {TM<:AbstractMatrix{Float64}}
    if C.factors != nothing
        return C.factors \ M
    else
        return C.IS \ M
    end
end


# workaround
# https://github.com/JuliaLang/julia/issues/27860
function Base.:\(
    A::LinearAlgebra.Hermitian{TA,SparseArrays.SparseMatrixCSC{TA,Int}},
    B::LinearAlgebra.Adjoint{TB,TM},
) where {TM<:AbstractMatrix{TB}} where {TA,TB}
    return A \ copy(B)
end

using SuiteSparse
function Base.:\(
    A::SuiteSparse.CHOLMOD.FactorComponent{Float64,:PtL},
    B::LinearAlgebra.Adjoint{Float64,SparseArrays.SparseMatrixCSC{Float64,Int}},
)
    return A \ copy(B)
end


# end workaround for julia 0.7.0

# call to C * M
Base.:*(C::CovarIS, M::AbstractMatrix{Float64}) = A_mul_B(C, M)

# another workaround for julia 0.7.0
# https://github.com/JuliaLang/julia/issues/28363
Base.:*(C::CovarIS, M::Adjoint{Float64,SparseMatrixCSC{Float64,Int}}) = A_mul_B(C, copy(M))


function Base.getindex(C::CovarIS, i::Int, j::Int)
    ei = zeros(eltype(C), size(C, 1))
    ei[i] = 1

    if C.factors == nothing || i != j
        ej = zeros(eltype(C), size(C, 1))
        ej[j] = 1
        return ej ⋅ (C * ei)
    else
        z = C.factors.PtL \ ei
        return sum(z .^ 2)
    end
end


Base.:\(C::CovarIS, M::AbstractArray{Float64,2}) = C.IS * M

function factorize!(C::CovarIS)
    C.factors = cholesky(Symmetric(C.IS))
end


function diagMtCM(C::CovarIS, M::AbstractMatrix{Float64})
    if C.factors != nothing
        PtL = C.factors.PtL
        return sum((abs.(PtL \ M)) .^ 2, dims = 1)[1, :]
    else
        return diag(M' * (C.IS \ M))
    end
end

function diagLtCM(L::AbstractMatrix{Float64}, C::CovarIS, M::AbstractMatrix{Float64})
    if C.factors != nothing

        PtL = C.factors.PtL

        # workaround for issue
        # https://github.com/JuliaLang/julia/issues/27860
        return sum((PtL \ M) .* (PtL \ copy(L)), dims = 1)[1, :]
    else
        return diag(L' * (C.IS \ M))
    end
end



# MatFun: a matrix defined by a function representing the matrix product

mutable struct MatFun{T} <: AbstractMatrix{Float64}
    sz::Tuple{T,T}
    fun::Function
    funt::Function
end

Base.size(MF::MatFun) = MF.sz

for op in [:+, :-]
    @eval begin
        function Base.$op(MF1::MatFun, MF2::MatFun)
            return MatFun(
                size(MF1),
                x -> $op(MF1.fun(x), MF2.fun(x)),
                x -> $op(MF2.funt(x), MF1.funt(x)),
            )
        end

        Base.$op(MF::MatFun, S::AbstractSparseMatrix) = $op(MF, MatFun(S))
        Base.$op(S::AbstractSparseMatrix, MF::MatFun) = $op(MatFun(S), MF)
    end
end

Base.:*(MF::MatFun, x::AbstractVector) = MF.fun(x)
Base.:*(MF::MatFun, M::AbstractMatrix) = hcat([MF.fun(M[:, i]) for i = 1:size(M, 2)]...)

function A_mul_B(MF1::MatFun, MF2::MatFun)
    if size(MF1, 2) != size(MF2, 1)
        error("incompatible sizes")
    end
    return MatFun(
        (size(MF1, 1), size(MF2, 2)),
        x -> MF1.fun(MF2.fun(x)),
        x -> MF2.funt(MF1.funt(x)),
    )
end

Base.:*(MF1::MatFun, MF2::MatFun) = A_mul_B(MF1, MF2)
Base.:*(MF::MatFun, S::AbstractSparseMatrix) = MF * MatFun(S)
Base.:*(S::AbstractSparseMatrix, MF::MatFun) = MatFun(S) * MF

for op in [:/, :*]
    @eval begin
        Base.$op(MF::MatFun, a::Number) =
            MatFun(size(MF), x -> $op(MF.fun(x), a), x -> $op(MF.funt(x), a))
    end
end

Base.:*(a::Number, MF::MatFun) = MatFun(size(MF), x -> a * MF.fun(x), x -> a * MF.funt(x))


function Base.:^(MF::MatFun, n::Int)
    if n == 0
        return MatFun(size(MF), identity, identity)
    else
        return MF * (MF^(n - 1))
    end
end

Base.:transpose(MF::MatFun) = MatFun((MF.sz[2], MF.sz[1]), MF.funt, MF.fun)
Base.:adjoint(MF::MatFun) = MatFun((MF.sz[2], MF.sz[1]), MF.funt, MF.fun)


MatFun(S::AbstractSparseMatrix) = MatFun(size(S), x -> S * x, x -> S' * x)


# CovarHPHt representing H P Hᵀ

mutable struct CovarHPHt{T} <: AbstractMatrix{T}
    P::AbstractMatrix{T}
    H::AbstractMatrix{T}
end

Base.size(C::CovarHPHt) = (size(C.H, 1), size(C.H, 1))

#function CovarHPHt(P::AbstractMatrix,H::AbstractMatrix)
#    CovarIS(IS,factors)
#end

function Base.:*(C::CovarHPHt, v::AbstractVector{Float64})
    return C.H * (C.P * (C.H' * v))
end


function A_mul_B(C::CovarHPHt, M::AbstractMatrix{Float64})
    return C.H * (C.P * (C.H' * M))
end

# call to C * M
Base.:*(C::CovarHPHt, M::AbstractMatrix{Float64}) = A_mul_B(C, M)

# The following two definitions are necessary; otherwise the full C matrix will be formed when
# calculating C * M' or C * transpose(M)

function Base.getindex(C::CovarHPHt, i::Int, j::Int)
    ei = zeros(eltype(C), size(C, 1))
    ei[i] = 1
    ej = zeros(eltype(C), size(C, 1))
    ej[j] = 1

    return (ej'*(C*ei))[1]
end
