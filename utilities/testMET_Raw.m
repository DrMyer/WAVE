function b = testMET_Raw( s )
% Quick function used by WAVE (via ListFmts_MET.m) to test whether a given
% single line from a file indicates that the file is raw Meterological data
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
% See also ListFmts_MET, testMET_Raw

try
    %
    % mm/dd/yy,hh:mm:ss.millisec,$METED,?,?,?,?,mbars,?
    %
    % 01/14/2022,15:41:09.307,$METED,005.4,354.5,014.68,070.8,1017.8,
    %
    c = textscan( s, '%{MM/dd/yyyy}D %T %q %*f %*f %*f %*f %f %*q', 'Delimiter', ',' );
    b = numel(c) == 4 ...
        && isdatetime( c{1} ) ...
        && isduration( c{2} ) ...
        && ischar( c{3}{1} ) && numel(c{3}{1}) == 6 && strcmpi( c{3}{1}, '$METED' )...
        && isnumeric( c{4} ) ...
        ;
    
catch
    b = false;
end

return;
end % testMET_Raw