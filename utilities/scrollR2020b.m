function scrollR2020b( hTable, sType, nWhere )
% scrollR2020b( hTable, sType, nWhere )
%
% MatLab added the scroll() functionality to uitable in R2021a. I need something
% similar in R2020b which is my minimum supported version. The typical solution
% found on MathWork's forum involving using findjobj() does not work on uifigure
% children because uifigure does not use java at all. So there's no way to
% implement this that I know of.
%
% Params:
%   hTable - uitable object
%   sType  - 'row', 'column', 'cell', 'top', 'bottom', 'left', 'right'
%   nWhere - [nRow] [nCol] [nRow nCol], n/a for rest
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

% R2021a adds scroll() on uitable
if verLessThan( 'matlab', '9.10' )
    % No solution to this problem
    return;
end
if nargin() == 3
    scroll( hTable, sType, nWhere );
else
    scroll( hTable, sType );
end

end % scrollR2020b
