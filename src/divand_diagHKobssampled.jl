"""
Computes the diagonal terms of the so called hat-matrix HK, using the already solved analysis and it structure s. Calculates them
at the indexes provided in indexlist

This version only uses the real data (not those related to additional constraints)

diagonalterms = divand_diagHKobssampled(s,indexlist);

"""


function divand_diagHKobssampled(s,indexlist)

#


H = s.obsconstrain.H;
R = s.obsconstrain.R;



Z=zeros(size(R)[1],length(indexlist));

for i = 1:length(indexlist)
          Z[indexlist[i],i] = 1;
end 

# to be replaced later exploiting the factors of P ?
# 
   P = s.P;
#   WW=P * (H'* (R \ Z));
#   ZtHKZ =  Z'*H*WW;

# parenthesis to force the order of operations
# Maybe more offecient to LtPM
#ZtHKZ =  Z' * (H * (P * (H' * (R \ Z))));
#ZtHKZ =   Z' * (H * (P * (H' * (R \ Z))));
#diagHK = diag(ZtHKZ);

diagHK=diagLtCM((H'*Z),P,(H' * (R \ Z)))
return diagHK

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

# LocalWords:  fi divand pmn len diag CovarParam vel ceil moddim fracdim


