function bIs = isFile_Binary( cFile )
% bIs = isFile_Binary( cFile )
%
% Utility to determine if the given file(s) is/are binary RX data
%
% Params:
%   cFile   - string or cell array of path+filenames to validate
% Returns:
%   bIs     - boolean of same size as cFile with true/false 
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

% If the input is a single file, make it a cell array for convenience
if ~iscell( cFile )
    cFile = {cFile};
end

% Default the return
bIs = false( size( cFile ) );

% Check each file
for iFile = 1:numel(cFile)
    if isfile( cFile{iFile} )
        try %#ok<TRYNC>
            % Try to read the header. If we get a reasonable channel count, then
            % assume it's good
            st = readBinData( cFile{iFile} );
            bIs(iFile) = between( 1, st.nChanCnt, 12 );
        end
    end
end

return;
end % isFile_Binary
