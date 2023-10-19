function cSnap = decodeSNAP( sFileSNAP, bNormalize )
% cSnap = decodeSNAP( sFileSNAP )
%
% Utility to parse the SNAP text lines in a *_SNAP.mat file produced by
% decodeSUESI(). Returns a cell array with one row for each snap found in the
% text output.
%
% Params:
%   sFileSNAP - path+filename of *_SNAP.mat containing cSnapList{} of text lines
%               taken from a SUESI log by decodeSUESI()
%   bNormalize - (opt; default F) T/F (or 'Normalize') if each individual SNAP 
%               should be demeaned & normalized by its RMS.
% Returns:
%   cSnap   - 3-col cell array: nFreq(scalar), nT(vector), nSnap(vector)
%               Snap values are as taken from the log. Only normalized if rqstd
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

% Handle optional parameters
if ~exist( 'bNormalize', 'var' ) || isempty( bNormalize )
    bNormalize = false;
elseif ischar( bNormalize )
    bNormalize = strncmpi( bNormalize, 'N', 1 );
end

% Load the snap data
m = matfile( sFileSNAP );
cSnapTxt = m.cSnapList;
clear m

% Parse the lines of text
cSnap = {};     % 3 columns: nFreq (scalar), nT (array), nAmp (array)
nSnap = [];
nFreq = 900;    % SUESI's default SNAP sampling rate: 900/second
for iLn = 1:numel(cSnapTxt)
    s = strtrim( cSnapTxt{iLn} );
    if isempty( s )
        continue;
    end
    
    % Try converting to numbers. Most lines are numbers
    n = sscanf( s, '%d' );  % NB: sscanf returns a single column
    
    % Didn't convert therefore it's snap start/end information line
    if isempty( n )
        % Write out previous data
        sub_SaveSnap();
        
        % One of the header lines will have the frequency on it
        i = strfind( s, 'samples/sec' );
        if ~isempty(i)
            nFreq = sscanf( s(i:end), 'samples/sec=%d' );
        else
            i = strfind( s, 'rate' );
            if ~isempty(i)
                nFreq = sscanf( s(i:end), 'rate=%d' );
            end
        end
    else
        % data
        nSnap = [nSnap; n];
    end
end
sub_SaveSnap();     % force last bit of data out (if any)

return;

    %---------------------------------------------------------------------------
    % Embedded functions with access to caller's variables
    %---------------------------------------------------------------------------
    
    function sub_SaveSnap()
        if isempty(nSnap)   % no snap data seen since last header line
            return;
        end
        
        % Demean & normalize?
        if bNormalize
            nSnap = nSnap - mean( nSnap );
            nSnap = nSnap / rms( nSnap );
        end
        
        % Save the snap
        cSnap{end+1,1}  = nFreq;
        cSnap{end,2}    = reshape( (0:length(nSnap)-1) / nFreq, [], 1 );
        cSnap{end,3}    = nSnap;
        
        % Reset variables
        nSnap   = [];
        nFreq   = 900;
        return;
    end

end % decodeSNAP