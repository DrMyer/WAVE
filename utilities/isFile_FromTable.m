function [bIs,iType] = isFile_FromTable( cFile, tblFmt )
% [bIs,iType] = isFile_FromTable( cFile, tblFmt )
%
% Utility to determine if the given file(s) is/are of a format found in the
% given format table. Tables come from ListFmts_Winch, ListFmts_GPS, etc...
%
% Params:
%   cFile   - string or cell array of path+filenames to validate
%   tblFmt  - table of known formats
% Returns:
%   bIs     - boolean of same size as cFile with true/false 
%   iType   - row index into ListFmts_...'s return table as to which type of
%           file each one is. 0 indicates invalid format.
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

% If the input is a single file, make it a cell array for convenience
if ~iscell( cFile )
    cFile = {cFile};
end

% Default the return values
bIs     = false( size( cFile ) );
iType   = zeros( size( cFile ) );

% How many lines need to be read to get past known headers?
nReadPastHdr = max( tblFmt.HeaderLines ) + 1;

% Suppress certain warnings that come up often
stWarn = warning( 'off', 'MATLAB:textscan:AllNaNDurationSuggestFormat' );

% Check each file
for iFile = 1:numel(cFile)
    if isfile( cFile{iFile} )
        fid = fopen( cFile{iFile}, 'r' );
        if fid > -1
            % Get a line to test against each known type. Make sure to read
            % enough to get past known headers. Do NOT trim blank lines as
            % these may be expected by certain formats.
            iLn = 0;
            cTry = {};
            while( ~feof(fid) && iLn < nReadPastHdr )
                iLn = iLn + 1;
                cTry{iLn,1} = fgetl( fid );
            end
            fclose( fid );
            
            % Try each known format
            for iTry = 1:height(tblFmt)
                fcnTest = tblFmt.fcnTest{iTry};
                try %#ok<TRYNC>
                    if fcnTest( cTry{tblFmt.HeaderLines(iTry)+1} )
                        bIs(iFile)   = true;
                        iType(iFile) = iTry;
                        break;
                    end
                end
            end % loop through known formats
        end
    end
end % loop through files

% Turn warnings back on
warning( stWarn );

return;
end % isFile_FromTable
