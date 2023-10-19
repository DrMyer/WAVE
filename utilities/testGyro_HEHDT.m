function b = testGyro_HEHDT( s )
% Quick function used by WAVE (via ListFmts_Gyro.m) to test whether a given
% single line from a file indicates that the file is a Gyrocompass file in
% the simple $HEHDT format used on many ships
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
% See also ListFmts_Gyro, readGyro_HEHDT

try
    %
    % mm/dd/yy,hh:mm:ss.millisec,$HEHDT,gyro,code
    %
    % NB: $HE can be $xx where xx indicates the provenance of the HDT data
    %
    c = textscan( s, '%{MM/dd/yyyy}D %T %q %f %*q', 'Delimiter', ',' );
    b = numel(c) == 4 ...
        && isdatetime( c{1} ) ...
        && isduration( c{2} ) ...
        && ischar( c{3}{1} ) && numel(c{3}{1}) == 6 && strcmpi( c{3}{1}(4:6), 'HDT' )...
        && isnumeric( c{4} ) ...
        ;
    
catch
    b = false;
end

return;
end % testGyro_HEHDT