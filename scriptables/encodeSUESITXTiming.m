function sTiming = encodeSUESITXTiming( nSamp, nA )
% sTiming = encodeSUESITXTiming( nSamp, nA )
%
% Utility paired with decodeSUESITXTiming to take an idealized waveform and 
% encode it into the text to give to SUESI. Examples:
% -- TRANSMITTER TIMING:  H:2000 L:2000
% -- TRANSMITTER TIMING:  H:160 L:160 H:80 L:80 H:160 L:320 H:160 L:80 H:80 L:160 H:160
%
% Params:
%   nSamp,nA - the 400 Hz sample number and amplitude (in -1 & 1 values) of the
%           idealized waveform.
% Returns:
%   sTiming - the timing string AFTER the "-- TRANSMITTER TIMING:" heading
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
% See also decodeSUESI, decodeSUESITXTiming

    % First ensure the amplitudes are idealized
    nA(nA>0) = 1;
    nA(nA<0) = -1;
    assert( ~any(nA==0), 'Zero amplitudes not supported' );
    
    % NB: This waveform MIGHT be in "brief" format so not every single 400 Hz
    % sample is included, just the transitions. Be mindful
    
    % Find the transitions
    iTo     = [find( diff(nA) ~= 0 ); numel(nA)];
    iFrom   = 1;
    sTiming = '';
    while iFrom < numel(nSamp)
        if nA(iFrom) > 0
            sTiming = [sTiming ' H:'];
        else
            sTiming = [sTiming ' L:'];
        end
        n = nSamp(iTo(1)) - nSamp(iFrom) + 1;
        sTiming = [sTiming num2str(n)];
        
        iFrom = iTo(1) + 1;
        iTo(1) = [];
    end
    
    % Remove any buffer spaces & return
    sTiming = strtrim( sTiming );
    return;
end % encodeSUESITXTiming
