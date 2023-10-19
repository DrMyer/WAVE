function b = testGPS_GGA_Raw( s )
% Quick function used by WAVE (via ListFmts_GPS.m) to test whether a given
% single line from a file indicates that the file is a ship's GPS file in
% the format found on the GOFAR cruise and others that use a raw $GPGGA or
% $INGGA format with date/time prepended
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
% See also ListFmts_GPS, readGPS_GGA_Raw

try
    % This is the format from R/V Thompson in GOFAR cruise
    %
    % mm/dd/yyyy,hh:mm:ss.sss,$GPGGA,nnnnnn.nn,llll.lllll,N/S,lllll.lllll,E/W,...
    % mm/dd/yyyy,hh:mm:ss.sss,$INGGA,nnnnnn.nn,llll.lllll,N/S,lllll.lllll,E/W,...
    %
    c = textscan( s, '%{MM/dd/yyyy}D %T %q %*f %f %q %f %q %*q %*q %*q %*q %*q %*q %*q %*q %*q', 'Delimiter', ',' );
    b =    numel(c) == 7 ...
        && isdatetime( c{1} ) ...
        && isduration( c{2} ) ...
        && ischar( c{3}{1} ) && numel(c{3}{1}) == 6 && strcmpi( c{3}{1}(4:6), 'GGA' )...
        && isnumeric( c{4} ) ...
        && ischar( c{5}{1} ) && ismember( c{5}{1}, {'N', 'S'} ) ...
        && isnumeric( c{6} ) ...
        && ischar( c{7}{1} ) && ismember( c{7}{1}, {'E', 'W'} ) ...
        ;
    
catch
    b = false;
end

return;
end % testGPS_GGA_Raw
