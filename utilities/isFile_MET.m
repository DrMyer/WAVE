function bIs = isFile_MET( cFile )
% bIs = isFile_MET( cFile )
%
% Utility to determine if the given file(s) is/are ship MET files (i.e.
% meteorological data).
%
% Params:
%   cFile   - string or cell array of path+filenames to validate
% Returns:
%   bIs     - boolean of same size as cFile with true/false 
%-------------------------------------------------------------------------------
% Copyright (C) 2022 David Myer
% 
% This program is free software: you can redistribute it and/or modify it under
% the terms of the GNU General Public License as published by the Free Software
% Foundation, version 3. This program is distributed in the hope that it will be
% useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. To view the GNU General
% Public License see <https://www.gnu.org/licenses/>
%-------------------------------------------------------------------------------

% If the input is a single file, make it a cell array for convenience
if ~iscell( cFile )
    cFile = {cFile};
end

% Default the return
bIs = false( size( cFile ) );

% Check each file
for i = 1:numel(cFile)
    if isfile( cFile{i} )
        fid = fopen( cFile{i}, 'r' );
        if fid > -1
            fgetl( fid );
            fgetl( fid );
            s = fgetl( fid );
            bIs(i) = contains( s, 'Met Data', 'IgnoreCase', true );
            fclose( fid );
        end
    end
end

return;
end % isFile_MET
