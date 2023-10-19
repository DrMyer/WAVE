function nD = Cvt_degminfrac( nDDDMM, cHemi )
% nD = Cvt_degminfrac( nDDDMM, cHemi )
%
% Utility to convert lat,lon numbers imported from files where they are stored
% as DDDMM.fraction into decimal degrees. (BTW, this is a DUMB format. How hard
% is it to store as decimal degrees? Sheesh.)
%
% Works with both latitudes & longitudes.
%
% Params:
%   nDDDMM  - the imported numeric data
%   cHemi   - the E/W or N/S indicator
% Returns:
%   nD      - lat or lon in decimal degrees
%
%-------------------------------------------------------------------------------
% Copyright (C) 2023 David Myer
%
% This program is free software: you can redistribute it and/or modify it under
% the terms of the GNU General Public License as published by the Free Software
% Foundation, version 3. This program is distributed in the hope that it will be
% useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. To view the GNU General
% Public License see <https://www.gnu.org/licenses/>
%-------------------------------------------------------------------------------
    
    % Separate the pieces
    nD = floor( nDDDMM / 100 );   % just degrees; slide decimal up 2 places
    nD = nD + (nDDDMM - nD * 100) / 60;  % fractional minutes --> fractional degrees
    
    % Should these be negative?
    n  = cellfun( @(s)iif(s=='S'|s=='W',-1,1), cHemi );
    nD = nD .* n;
    
    return;
end % Cvt_degminfrac