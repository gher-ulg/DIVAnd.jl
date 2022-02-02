# A simple example of DIVAnd in 2 dimensions
# with observations from an analytical function.
using Test
using DIVAnd
using StableRNGs

rng = StableRNG(1234567)

x = randn(rng,100)
y = randn(rng,100)
z = randn(rng,100)
t = randn(rng,100)
f = z

mask, (pm, pn, po, pq), (xi, yi, zi, ti) =
    DIVAnd_squaredom(4, range(-1, stop = 1, length = 5))

# correlation length
len = 1

# obs. error variance normalized by the background error variance
epsilon2 = 0.01;

fi, fanom = DIVAnd_averaged_bg(
    mask,
    (pm, pn, po, pq),
    (xi, yi, zi, ti),
    (x, y, z, t),
    f,
    len,
    epsilon2,
    [true, true, false, true],
);

@test fi[1, 1, 1, 1] ≈ zi[1, 1, 1, 1] atol = 0.1

fi, fanom = DIVAnd_averaged_bg(
    mask,
    (pm, pn, po, pq),
    (xi, yi, zi, ti),
    (x, y, z, t),
    f,
    len,
    epsilon2,
    [true, true, true, true],
);

@test -0.15 < fi[1, 1, 1, 1] < 0


fi, fanom = @test_logs (:warn, r".*no averaging.*") match_mode = :any DIVAnd_averaged_bg(
    mask,
    (pm, pn, po, pq),
    (xi, yi, zi, ti),
    (x, y, z, t),
    f,
    len,
    epsilon2,
    [false, false, false, false],
);

@test -1.2 < fi[1, 1, 1, 1] < -1.1

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
