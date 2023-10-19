function b = testGyro_GOFAR( s )
% Quick function used by WAVE (via ListFmts_Gyro.m) to test whether a given
% single line from a file indicates that the file is a Gyrocompass file in
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
% See also ListFmts_Gyro, readGyro_GOFAR

try
    % This is the format from R/V Thompson in GOFAR cruise
    %
    % mm/dd/yy,hh:mm:ss.millisec,gyro
    %
    c = textscan( s, '%{MM/dd/yyyy}D %T %f', 'Delimiter', ',' );
    b = numel(c) == 3 ...
        && isdatetime( c{1} ) && isduration( c{2} ) ...
        && isnumeric( c{3} ) ...
        ;
    
catch
    b = false;
end

return;
end % testGyro_GOFAR