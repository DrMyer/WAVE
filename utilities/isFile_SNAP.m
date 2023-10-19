function bIs = isFile_SNAP( cFile )
% bIs = isFile_SNAP( cFile )
%
% Utility to determine if the given files are waveform SNAPSHOT files
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
            % NB: Only supports the *_SNAP.mat files created by decodeSUESI
            m = matfile( cFile{iFile} );
            if numel( who( m, 'cSnapList' ) ) == 1
                bIs(iFile) = true;
            end
        end
    end
end

return;
end % isFile_SNAP
