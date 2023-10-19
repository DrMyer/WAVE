function [nSamp,nA] = decodeSUESITXTiming( sTiming, bBrief )
% [nSamp,nA] = decodeSUESITXTiming( sTiming, bBrief )
%
% Utility to accompany decodeSUESI.m which will decode the text after a SUESI
% transmitter timing line. Examples:
% -- TRANSMITTER TIMING:  H:2000 L:2000
% -- TRANSMITTER TIMING:  H:160 L:160 H:80 L:80 H:160 L:320 H:160 L:80 H:80 L:160 H:160
%
% Params:
%   sTiming - the timing string AFTER the "-- TRANSMITTER TIMING:" heading
%   bBrief - T/F ('B'rief, any other char) if F, gives entire time series at
%           SUESI's 400 Hz sampling rate. If T, just gives the times of the
%           transitions between 1 & -1.
% Returns:
%   nSamp,nA - the sample number and amplitude (in -1 & 1 values) of the
%           idealized waveform. Time = nSamp / 400 (SUESI switches at 400 Hz)
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
% See also decodeSUESI, encodeSUESITXTiming

if ischar( bBrief )
    bBrief = strncmpi( bBrief, 'B', 1 );
end

c       = strsplit( sTiming, {' ', ':'} );
t       = -1;
a       = 1;
nSamp   = [];
nA      = [];
for i = 1:numel(c)
    if isempty(c{i})
        continue;
    end
    if c{i}(1) == 'H'
        a = 1;
        continue;
    elseif c{i}(1) == 'L'
        a = -1;
        continue;
    elseif c{i}(1) == 'E'   % in older SUESI this signaled the end
        break;
    end
    n = str2double( c{i} );
    if bBrief
        tAdd = [1 n].' + t;
    else
        tAdd = (1:n).' + t;
    end
    t = t + n;
    
    aAdd    = ones(size(tAdd)) * a;
    nSamp   = [nSamp;tAdd];
    nA      = [nA;aAdd];
end

return;
end % decodeSUESITXTiming
