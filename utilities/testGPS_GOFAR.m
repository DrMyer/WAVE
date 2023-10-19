function b = testGPS_GOFAR( s )
% Quick function used by WAVE (via ListFmts_GPS.m) to test whether a given
% single line from a file indicates that the file is a ship's GPS file in
% the format found on the GOFAR cruise
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
% See also ListFmts_GPS

try
    % This is the format from R/V Thompson in GOFAR cruise
    %
    % mm/dd/yyyy,hh:mm:ss.sss,llll.lllll,N/S,lllll.lllll,E/W
    %
    c = textscan( s, '%{MM/dd/yyyy}D %T %f %q %f %q', 'Delimiter', ',' );
    b =    numel(c) == 6 ...
        && isdatetime( c{1} ) && isduration( c{2} ) ...
        && isnumeric( c{3} ) && ischar( c{4}{1} ) ...
        && ismember( c{4}{1}, {'N', 'S'} ) ...
        && isnumeric( c{5} ) && ischar( c{6}{1} ) ...
        && ismember( c{6}{1}, {'E', 'W'} ) ...
        ;
    
catch
    b = false;
end

return;
end % testGPS_GOFAR
