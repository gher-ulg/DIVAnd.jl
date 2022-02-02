# Testing DIVAnd in 2 dimensions with advection.

using Test
using Random
import DIVAnd
using StableRNGs

rng = StableRNG(1234)

# grid of background field
mask, (pm, pn), (xi, yi) = DIVAnd.DIVAnd_squaredom(2, range(-1, stop = 1, length = 50))

x = [0.4]
y = [0.4]
f = [1.0]

a = 5;
u = a * yi;
v = -a * xi;
epsilon2 = 1 / 200
len = 0.4

fi_ref, s = DIVAnd.DIVAndrun(
    mask,
    (pm, pn),
    (xi, yi),
    (x, y),
    f,
    len,
    epsilon2;
    velocity = (u, v),
    alphabc = 0,
)

for i = 1:5
    local s
    local fi

    fi, s = DIVAnd.DIVAndjog(
        mask,
        (pm, pn),
        (xi, yi),
        (x, y),
        f,
        len,
        epsilon2,
        [2 2],
        [1 1],
        i;
        velocity = (u, v),
        alphabc = 0,
        rng = rng,
    )

    #@show i, extrema(fi - fi_ref)
    @test fi ≈ fi_ref rtol = 1e-3
end

for ii = 1:5
    local s
    local fi

    fi, s = DIVAnd.DIVAndjog(
        mask,
        (pm, pn),
        (xi, yi),
        (x, y),
        f,
        len,
        epsilon2,
        [1 1],
        [1 1],
        ii;
        velocity = (u, v),
        alphabc = 0,
        rng = rng,
    )
    @test fi ≈ fi_ref rtol = 1e-2
end


# Copyright (C) 2014, 2017 Alexander Barth <a.barth@ulg.ac.be>
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
