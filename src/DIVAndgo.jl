"""

    fi, erri, residuals, qcvalues, scalefactore = DIVAndgo(mask,pmn,xi,x,f,len,epsilon2,errormethod; ...);



# Input:
*  Same arguments as DIVAndrun with in addition
*  `errormethod` :   you have the choice between `:cpme` (clever poorman's method, default method if parameter not provided), `:none` or `:exact` (only available if windowed analysis are done with DIVAndrun)
*  `MEMTOFIT=`: keyword controlling how to cut the domain depending on the memory remaining available for inversion (not total memory)
*  `RTIMESONESCALES=` : if you provide a tuple of length scales, data are weighted differently depending on the numbers of neighbours they have. See `weight_RtimesOne` for details
*  `QCMETHOD=` : if you provide a qc method parameter, quality flags are calculated. See `DIVAnd_cv` for details
*  `solver` (default `:auto`:). :direct for the direct solver or :auto for automatic choice between the direct solver or the iterative solver.
* `overlapfactor` : describes how many times the length scale is used for the overlapping. default is 3.3. use lower values ONLY for very good data coverage.

# Output:
*  `fi`: the analysed field
*  `erri`: relative error field on the same grid as fi. () if errormethod is fixed to `:none`
* `residuals`: array of residuals at data points. For points not on the grid or on land: `NaN`
* `qcvalues`: if `QCMETHOD=` is provided, the output array contains the quality flags otherwise qcvalues is (). For points on land or not on the grid: 0
* `scalefactore`: Desroziers et al. 2005 (doi: 10.1256/qj.05.108) scale factor for `epsilon2`

Perform an n-dimensional variational analysis of the observations `f` located at
the coordinates `x`. The array `fi` represent the interpolated field at the grid
defined by the coordinates `xi` and the scales factors `pmn`.

IMPORTANT: DIVAndgo is very similar to DIVAndrun and is only interesting to use if DIVAndrun cannot fit into memory or if you want to parallelize.
(In the latter case do not forget to define the number of workers; see `addprocs` for example)

"""
function DIVAndgo(
    mask::AbstractArray{Bool,n},
    pmn,
    xi,
    x,
    f,
    Labs,
    epsilon2,
    errormethod = :cpme;
    moddim = zeros(n),
    velocity = (),
    MEMTOFIT = 16,
    QCMETHOD = (),
    RTIMESONESCALES = (),
    solver = :auto,
    overlapfactor = 3.3,
    filteranom = 2,
    filtererr = 3,
    otherargs...,
) where {n}
    # function DIVAndgo(mask::AbstractArray{Bool,n},pmn,xi,x,f,Labs,epsilon2,errormethod=:cpme) where n
    #     moddim = zeros(n)
    #     velocity = ()
    #     MEMTOFIT = 16
    #     QCMETHOD = ()
    #     RTIMESONESCALES = ()

    dothinning = RTIMESONESCALES != ()
    doqc = QCMETHOD != ()

    # DOES NOT YET WORK WITH PERIODIC DOMAINS OTHER THAN TO MAKE SURE THE DOMAIN IS NOT CUT
    # IN THIS DIRECTION. If adapation is done make sure the new moddim is passed to DIVAndrun
    # General approach in this future case prepare window indexes just taking any range including negative value and
    # apply a mod(myindexes-1,size(mask)[i])+1 in direction i when extracting
    # for coordinates tuples of the grid (xin,yin, .. )  and data (x,y)
    # in the direction, shift coordinates and apply modulo mod(x-x0+L/2,L)
    #

    # Analyse rations l/dx etc

    Lpmnrange = DIVAnd_Lpmnrange(pmn, Labs)

    # Create list of windows, steps for the coarsening during preconditioning and mask for lengthscales to decoupled directions during preconditioning
    windowlist, csteps, lmask, alphanormpc = DIVAnd_cutter(
        Lpmnrange,
        size(mask),
        moddim,
        MEMTOFIT;
        solver = solver,
        overlapfactor = overlapfactor,
    )

    @debug "csteps $csteps"

    # For parallel version declare SharedArray(Float,size(mask)) instead of zeros() ? ? and add a @sync @parallel in front of the for loop ?
    # Seems to work with an addprocs(2); @everywhere using DIVAnd to start the main program. To save space use Float32 ?
    #fi = zeros(size(mask));

    #fi = SharedArray(Float64,size(mask));
    #erri = SharedArray(Float64,size(mask));
    fi = SharedArray{Float32}(size(mask))
    fi .= 0

    erri = SharedArray{Float32}(size(mask))
    erri .= 1.0

    qcdata = SharedArray{Float32}(size(f, 1))
    qcdata .= 0

    # Add now analysis at data points for further output
    fidata = SharedArray{Float32}(size(f, 1))
    fidata .= 0

    # fidata and qcdata is a weighted average to
    # account for data point between the subdomains solution
    fidata_weight = SharedArray{Float32}(size(f, 1))
    fidata_weight .= 0

    @debug "error method: $(errormethod)"
    @info "number of windows: $(length(windowlist))"

    mean_Labs = collect(mean.(Labs))
    @debug "mean_Labs: $(mean_Labs)"

    @sync @distributed for iwin = 1:size(windowlist, 1)
    #@sync @distributed for iwin = 44:size(windowlist, 1)
        iw1 = windowlist[iwin][1]
        iw2 = windowlist[iwin][2]
        isol1 = windowlist[iwin][3]
        isol2 = windowlist[iwin][4]
        istore1 = windowlist[iwin][5]
        istore2 = windowlist[iwin][6]

        @debug "window: $iwin, indices: $(windowlist[iwin])"

        windowpointssol = ([isol1[i]:isol2[i] for i = 1:n]...,)
        windowpointsstore = ([istore1[i]:istore2[i] for i = 1:n]...,)

        #@warn "Test window $iw1 $iw2 $isol1 $isol2 $istore1 $istore2 "

        windowpoints = ([iw1[i]:iw2[i] for i = 1:n]...,)

        #################################################
        # Need to check how to work with additional constraints...
        #################################################

        #################################

        # Search for velocity argument:
        if velocity != ()
            @warn "There is an advection constraint; make sure the window sizes are large enough for the increased correlation length"
            # modify the parameter
            velocity = ([x[windowpoints...] for x in velocity]...,)
        end

        # If C is square then maybe just take the sub-square corresponding to the part taken from x hoping the constraint is a local one ?
        #


        # If C projects x on a low dimensional vector: maybe C'C x-C'd as a constraint, then pseudo inverse and woodbury to transform into a similar constraint but on each subdomain
        # Would for example replace a global average constraint to be replaced by the same constraint applied to each subdomain. Not exact but not too bad neither


        fw = 0

        xiw = ([x[windowpoints...] for x in xi]...,)
        pmniw = ([x[windowpoints...] for x in pmn]...,)

        # NEED TO CATCH IF Labs is a tuple of grid values; if so need to extract part of interest...

        Labsw = Labs
        if !isa(Labs, Number)
            if !isa(Labs[1], Number)
                Labsw = ([x[windowpoints...] for x in Labs]...,)
            end
        end

        # code seeting alphabc to 1 was disabled (and now removed)

        # Work only on data which fall into bounding box

        xinwin, finwin, winindex, epsinwin =
            DIVAnd_datainboundingbox(xiw, x, f; Rmatrix = epsilon2)

        if dothinning
            epsinwin = epsinwin ./ weight_RtimesOne(xinwin, RTIMESONESCALES)
        end

        # The problem now is that to go back into the full matrix needs special treatment Unless a backward pointer is also provided which is winindex
        if size(winindex, 1) > 0
            # work only when data are there


            # If you want to change another alphabc, make sure to replace it in the arguments, not adding them since it already might have a value
            # Verify if a direct solver was requested from the demain decomposer
            if sum(csteps) > 0
                fw, s = DIVAndjog(
                    mask[windowpoints...],
                    pmniw,
                    xiw,
                    xinwin,
                    finwin,
                    Labsw,
                    epsinwin,
                    csteps,
                    lmask;
                    alphapc = alphanormpc,
                    moddim = moddim,
                    MEMTOFIT = MEMTOFIT,
                    QCMETHOD = QCMETHOD,
                    RTIMESONESCALES = RTIMESONESCALES,
                    velocity = velocity,
                    mean_Labs = mean_Labs,
                    otherargs...,
                )

                fi[windowpointsstore...] = fw[windowpointssol...]
                # Now need to look into the bounding box of windowpointssol to check which data points analysis are to be stored

                finwindata = DIVAnd_residual(s, fw)

                if doqc
                    # If you are reading this part of the code and want to implement a better version with
                    # a single random vector GCV approach, you would need to
                    #   run again DIVAndjog replacing the data with a random array to calculate an estimate of Kii
                    # and create a new method if DIVAnd_qc passing that value
                    @warn "QC not fully implemented in jogging, using rough estimate of Kii"
                    finwinqc = DIVAnd_qc(fw, s, 5)
                end

                if errormethod == :cpme
                    fw = 0
                    s = 0
                    GC.gc()
                    # Possible optimization here: use normal cpme (without steps argument but with preconditionner from previous case)
                    errw = DIVAnd_cpme(
                        mask[windowpoints...],
                        pmniw,
                        xiw,
                        xinwin,
                        finwin,
                        Labsw,
                        epsinwin;
                        csteps = csteps,
                        lmask = lmask,
                        alphapc = alphanormpc,
                        moddim = moddim,
                        MEMTOFIT = MEMTOFIT,
                        QCMETHOD = QCMETHOD,
                        RTIMESONESCALES = RTIMESONESCALES,
                        velocity = velocity,
                        mean_Labs = mean_Labs,
                        otherargs...,
                    )
                end
                # for errors here maybe add a parameter to DIVAndjog ? at least for "exact error" should be possible; and cpme directly reprogrammed here as well as aexerr ? assuming s.P can be calculated ?
            else
                # Here would be a natural place to test which error fields are demanded and add calls if the direct method is selected

                @debug "call DIVAndrun"

                fw, s = DIVAndrun(
                    mask[windowpoints...],
                    pmniw,
                    xiw,
                    xinwin,
                    finwin,
                    Labsw,
                    epsinwin;
                    moddim = moddim,
                    MEMTOFIT = MEMTOFIT,
                    QCMETHOD = QCMETHOD,
                    RTIMESONESCALES = RTIMESONESCALES,
                    velocity = velocity,
                    mean_Labs = mean_Labs,
                    otherargs...,
                )

                fi[windowpointsstore...] = fw[windowpointssol...]
                finwindata = DIVAnd_residualobs(s, fw)

                if doqc
                    finwinqc = DIVAnd_qc(fw, s, QCMETHOD)
                end

                if errormethod == :cpme
                    #@info "save CPME"
                    #@save "/tmp/CPME.jld2"  windowpoints mask pmniw xiw xinwin finwin Labsw epsinwin moddim MEMTOFIT QCMETHOD RTIMESONESCALES velocity
                    #@save "/tmp/CPME.jld2"  windowpoints mask pmniw xiw xinwin finwin Labsw epsinwin csteps lmask  alphanormpc moddim MEMTOFIT QCMETHOD RTIMESONESCALES velocity

                    errw = DIVAnd_cpme(
                        mask[windowpoints...],
                        pmniw,
                        xiw,
                        xinwin,
                        finwin,
                        Labsw,
                        epsinwin;
                        moddim = moddim,
                        MEMTOFIT = MEMTOFIT,
                        QCMETHOD = QCMETHOD,
                        RTIMESONESCALES = RTIMESONESCALES,
                        velocity = velocity,
                        mean_Labs = mean_Labs,
                        otherargs...,
                    )
                end
            end

            # residuals
            #@show size(winindex),size(finwindata),size(fidata[winindex])
            fidata[winindex] = fidata[winindex] + finwindata
            fidata_weight[winindex] = fidata_weight[winindex] .+ 1

            # quality control indicators
            if doqc
                qcdata[winindex] = qcdata[winindex] + finwinqc
            end


            # Cpme: just run and take out same window

            # AEXERR: just run and() take out same window

            if errormethod == :exact
                # EXERR: P only to points on the inner grid, not the overlapping one !
                # Initialize errw everywhere,
                errw = 0.0 * fw
                # For packing, take the stavevector returned except when sum(csteps)>n
                # in this case recreate a statevector
                if sum(csteps) == n
                    sverr = statevector_init((mask[windowpoints...],))
                else
                    sverr = s.sv
                end
                svn = size(sverr, 1)

                errv = statevector_pack(sverr, (errw,))
                # Loop over window points. From grid index to statevector index so that ve is
                # zero exect one at that index. Then calculate the error and store it in the the
                # sv representation of the error

                for gridindex in windowpoints
                    ei = zeros(svn)
                    ind = statevector_sub2ind(svn, gridindex)
                    ei[ind] = 1
                    #  HIP = HI'*ei
                    #  errv[ind]=diagMtCM(sc.P,HIP)
                end
                errw = statevector_unpack(svn, errv)
                # Maybe better fill in first HIP = HI'*[ ... ei ...]
                # then something as errfield = diagMtCM(sc.P,HIP)
                # at the end of the loop, unpack the sv error field into errw
                # End error fields
            end

            if errormethod == :none
                erri .= 1.0
            else
                erri[windowpointsstore...] = errw[windowpointssol...]
            end

        end

    end


    #fname_save = "/tmp/test_fi_ingo_$(mean(f[isfinite.(f)])).jld"
    #@show fname_save
    #FileIO.save(fname_save,Dict("fi"=>Array(fi)))

    # When finished apply an nd filtering to smooth possible edges, particularly in error fields.
    # it also makes the shared array possible to save in netCDF??


    fi_filtered = DIVAnd_filter3(fi, NaN, filteranom)
    erri_filtered = DIVAnd_filter3(erri, NaN, filtererr)

    #FileIO.save("/tmp/test_fi_filtered_ingo_$(mean(f[isfinite.(f)])).jld",Dict("fi_filtered" => Array(fi_filtered)))

    #@show size(fidata)
    # compute residuals and qcdata
    # where fidata_weight is zero fidata will be zero too
    # and their ratio is NaN

    fidata .= fidata ./ fidata_weight
    qcdata .= qcdata ./ fidata_weight

    ongrid = findall(x -> !isnan(x), fidata)

    # Add desroziers type of correction
    scalefactore = DIVAnd_adaptedeps2(f, fidata, epsilon2, isnan.(fidata))

    return fi_filtered, erri_filtered, fidata, qcdata, scalefactore
end

# Copyright (C) 2008-2017 Alexander Barth <barth.alexander@gmail.com>
#                         Jean-Marie Beckers   <JM.Beckers@ulg.ac.be>
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, see <http://www.gnu.org/licenses/>.

# LocalWords:  fi DIVAnd pmn len diag CovarParam vel ceil moddim fracdim
