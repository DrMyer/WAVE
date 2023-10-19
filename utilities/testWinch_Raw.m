function b = testWinch_Raw( s )
% Quick function used by WAVE (via ListFmts_Winch.m) to test whether a given
% single line from a file indicates that the file is a Winch wire-out file in
% the "raw" format
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
% See also ListFmts_Winch

try
    %
    % mm/dd/yy,hh:mm:ss.millisec,ignore,ignore,tension,velocity,wire-out,ignore
    %
    c = textscan( s, '%{MM/dd/yyyy}D %T %*q %*q %*f %*f %f %*q', 'Delimiter', ',' );
    b = numel(c) == 3 ...
        && isdatetime( c{1} ) ...
        && isduration( c{2} ) ...
        && isnumeric( c{3} ) ...
        ;
    
catch
    b = false;
end

return;
end % testWinch_Raw