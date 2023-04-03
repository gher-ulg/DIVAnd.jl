using DIVAnd
using Test
using Random
using LinearAlgebra
using Dates
using Printf
using Statistics
using DelimitedFiles
using SpecialFunctions
using Downloads: download

@testset "DIVAnd" begin
    include("test_quadtrees.jl")

    # ndgrid
    include("test_ndgrid.jl")

    include("test_covaris.jl")

    # conjugate gradient
    include("test_conjugategradient.jl")

    include("test_sparse_diff.jl")
    include("test_localize_separable_grid.jl")

    include("test_statevector.jl")

    include("test_diagnostic_tools.jl")

    include("test_1dvar.jl")
    include("test_1D_seminormed.jl")


	# multivar

	include("test_multivar.jl")

	include("test_errormaps.jl")

    # dynamical constraints
    include("test_2dvar_adv.jl")
    include("test_2dvar_constcoast.jl")

    include("test_2dvar_iter.jl")

    include("test_2dvar_error.jl")

    include("test_2dvar_all_masked.jl")

    include("test_2dvar_obs_out.jl")

    include("test_derivative2.jl")
    include("test_2dvar_edge.jl")

    include("test_ndvar_point_cmp.jl")

    # cross-validation
    include("test_2dvar_cv.jl")

    include("test_2dvar_matfun.jl")
    include("test_2dvar_qc.jl")

    include("test_2dvar_outside.jl")
    include("test_2dvar_periodic.jl")

    include("test_variableLandpmn.jl")

    include("test_3dvar.jl")
    include("test_3dvar_large_stacked.jl")

    include("test_4dvar.jl")

    # comparision with analytical kernels
    include("test_ndvar_point.jl")

    include("test_DIVAndgo.jl")


    include("test_fzero.jl")

    # test 3D-var analysis
    include("test_varanalysis.jl")

    include("test_averaged_bg.jl")
    include("test_average_background_profile.jl")
    include("test_domain.jl")

    # SDN Vocabulary
    include("test_vocab.jl")

    # SDN ODVspreadsheet
    include("test_ODVspreadsheet.jl")

    # SDN NetCDF
    include("test_ncsdn.jl")
    include("test_ncodv.jl")

    # SDN metadata
    include("test_metadata.jl")

    # Saving data as NetCDF file
    include("test_save.jl")
    include("test_loadobs.jl")

    include("test_load_mask.jl")

    # Anamorphosis
    include("test_anam.jl")

    # Fitting covariance model
    include("test_select_time.jl")

    # Fitting covariance model
    include("test_fit.jl")

    # Test utility functions
    include("test_utils.jl")
    include("test_hmerge.jl")

    # Test utility functions
    include("test_obsstat.jl")
    include("test_average_file.jl")

    # Test XML metadata description
    include("test_xml.jl")

    # Test product generation
    include("test_product.jl")
    include("test_product_subset.jl")
    include("test_product_2d.jl")

    include("test_binning.jl")

    # Heatmap
    include("test_heatmap.jl")

	# DIVAndfun
	include("test_DIVAndfun.jl")

    # test DIVAnd_filter3
    A = zeros(5, 5, 5, 5, 5)
    A[3, 3, 3, 3, 3] = 1
    z = DIVAnd_filter3(A, 9999, 1)

    @test maximum(z) ≈ 0.00411522633744856

    # distance
    @test distance(0, 0, 1, 0) ≈ 1
    @test distance(0, 0, 90, 0) ≈ 90
    @test distance(0, 0, 0, 180) ≈ 180
    @test distance(0, 0, 0, 270) ≈ 90
    @test distance(1, 2, 3, 4) ≈ 2.82749366820155

    # test DIVAnd_metric
    lon, lat = ndgrid([0:10;], [0:5;])
    pm, pn = DIVAnd_metric(lon, lat)
    @test 111e3 < mean(1 ./ pm) < 112e3
    @test 111e3 < mean(1 ./ pn) < 112e3


    # test DIVAnd_kernel
    mu, K, len_scale = DIVAnd_kernel(2, [1, 2, 1])
    @test mu ≈ 4π
    @test K(0) ≈ 1
    @test K(1) ≈ SpecialFunctions.besselk(1, 1)
    @test K(len_scale) ≈ SpecialFunctions.besselk(1, 1) atol = 1e-6

    mu, K, len_scale = DIVAnd_kernel(2, [1, 3, 3, 1])
    @test K(len_scale) ≈ SpecialFunctions.besselk(1, 1) atol = 1e-6
    mu, K, len_scale = DIVAnd_kernel(2, [0, 3, 3, 1])
    @test K(len_scale) ≈ SpecialFunctions.besselk(1, 1) atol = 1e-6
end

@testset "DIVAnd-laplacian" begin
    include("test_laplacian.jl")
end

@testset "DIVAnd-jog" begin
    include("test_2dvar_jog.jl")
end

@testset "DIVAnd-kernel" begin
    # test kernel
    include("test_kernel.jl")
end
