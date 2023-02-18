module DiffusionMap
using LinearAlgebra, StatsBase

export normalize_to_stochastic_matrix!, diffusion_map, gaussian_kernel, pca

function gaussian_kernel(xⱼ, xᵢ, ℓ::Float64)
    r² = sum((xᵢ - xⱼ) .^ 2)
    return exp(-r² / ℓ ^ 2)
end

"""
    normalize_to_stochastic_matrix!(P, check_symmetry=true)

normalize a kernel matrix `P` so that rows sum to one.

checks for symmetry.
"""
function normalize_to_stochastic_matrix!(P::Matrix{Float64}; 
                                         check_symmetry::Bool=true)
    if check_symmetry && (! all(isapprox.(P - P', 0.0; rtol=1e-8)))
        error("kernel matrix not symmetric!")
    end
    # make sure rows sum to one
    # this is equivalent to P = D⁻¹ * P
    #    with > d = vec(sum(P, dims=1))
    #         > D⁻¹ = diagm(1 ./ d)
    for i = 1:size(P)[1]
        P[i, :] = P[i, :] / sum(P[i, :])
    end
end

"""
    diffusion_map(P, d; t=1)
    diffusion_map(X, kernel, d, t=1)

compute diffusion map. 

two call signatures:
* the data matrix `X` is passed in. examples are in the columns.
* the right-stochastic matrix `P` is passed in. (eg. for a precomputed kernel matrix)

# arguments
* `d`: dim
* `t`: # of steps

# example
```julia
# define kernel
kernel(xᵢ, xⱼ) = gaussian_kernel(xᵢ, xⱼ, 0.5)

# data matrix (100 data pts, 2D vectors)
X = rand(2, 100)

# diffusion map to 1D
X̂ = diff_map(X, kernel, 1)
```
"""
function diffusion_map(P::Matrix{Float64}, d::Int; t::Int=1)
    if ! (size(P)[1] == size(P)[2])
        error("this should be a SQUARE right-stochastic matrix")
    end
    if ! all(sum.(eachrow(P)) .≈ 1.0)
        error("not a right-stochastic matrix. call normalize_to_stochastic_matrix!")
    end
    if ! all(P .>= 0.0)
        error("should be positive entries...")
    end

    # eigen-decomposition of the stochastic matrix
    eigen_decomp = eigen(P)

    if ! ((maximum(abs.(eigen_decomp.values)) - 1.0) < 0.0001)
        error("largest eigenvalue should be 1.0")
    end

    # sort eigenvalues, highest to lowest
    # skip the first eigenvalue
    idx = sortperm(eigen_decomp.values, rev=true)[2:end]

    # get first d eigenvalues and vectors. scale eigenvectors.
    λs = eigen_decomp.values[idx][1:d]
    Vs = eigen_decomp.vectors[:, idx][:, 1:d] * diagm(λs .^ t)
    return Vs
end

function diffusion_map(X::Matrix{Float64}, kernel::Function, 
                       d::Int; t::Int=1, verbose::Bool=true)
    if verbose
        println("# features: ", size(X)[1])
        println("# examples: ", size(X)[2])
    end

    # compute Laplacian matrix
    P = pairwise(kernel, eachcol(X), symmetric=true)
    normalize_to_stochastic_matrix!(P)

    return diffusion_map(P, d; t=t)
end

function pca(X::Matrix{Float64}, d::Int)
    println("# features: ", size(X)[1])
    println("# examples: ", size(X)[2])

    # center
    X̂ = deepcopy(X)
    for f = 1:size(X)[1]
        X̂[f, :] = X[f, :] .- mean(X[f, :])
    end

    the_svd = svd(X̂)
    return the_svd.V[:, 1:d] * diagm(the_svd.S[1:d])
end

end
