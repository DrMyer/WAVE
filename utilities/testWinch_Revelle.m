function b = testWinch_Revelle( s )
% Quick function used by WAVE (via ListFmts_Winch.m) to test whether a given
% single line from a file indicates that the file is a Winch wire-out file in
% the R/V Revelle TRAWL format.
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
    % This is R/V Revelle's TRAWL... file format (see readWinch.m)
    %
    % '%f %f S%fV%fT%fX%*f:'
    %
    % unix-sec msec 'S'wire-out'V'velocity'T'tension'X'unknown':'
    %
    c = textscan( s, '%f %f S%fV%fT%fX%*f:' );
    b = ~any( cellfun(@(c)isempty(c),c) );
catch
    b = false;
end

return;
end % testWinch_Revelle