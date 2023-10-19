function bIs = isFile_BarracudaLog( cFile )
% bIs = isFile_BarracudaLog( cFile )
%
% Utility to determine if the given file(s) is/are Barracuda GPS log files
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
        fid = fopen( cFile{iFile}, 'r' );
        if fid > -1
            % Barracuda GPS logs have only a few types of lines in them. Check
            % for one of these
            for iLine = 1:10
                s = fgetl( fid );
                if strncmpi( s, '*$GPGL', 6 ) ...
                || strncmpi( s, ')2NAV', 5 ) ...
                || strncmpi( s, '*1Relay', 7 ) ...
                || strncmpi( s, '*1Sync', 6 )
                    bIs(iFile) = true;
                    break;
                end
                if feof(fid)
                    break;
                end
            end
            fclose( fid );
        end
    end
end

return;
end % isFile_BarracudaLog
