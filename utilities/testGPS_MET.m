function b = testGPS_MET( s )
% Quick function used by WAVE (via ListFmts_GPS.m) to test whether a given
% single line from a file indicates that the file is a processed MET file
% created by the cwave::ProcessSIOMETFiles() function.
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
% See also ListFmts_GPS, readGPS_MET, ProcessSIOMETFiles, MET2Table

try
    % Format is from writetable() of a table made by MET2Table.m
    % The first line is a header line
    c = strsplit( s, ',' );
    b = any(strcmpi(c,'Time')) & any(strcmpi(c,'Latitude')) & any(strcmpi(c,'Longitude'));
    
catch
    b = false;
end

return;
end % testGPS_MET
