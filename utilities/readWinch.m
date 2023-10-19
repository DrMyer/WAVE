function [nWTime nWireOut nVel nTension] = readWinch( sFiles )
% [nWTime nWireOut nVel nTension] = readWinch( sFiles )
%
% Read & parse one or more winch info files from ship data.
% Has only been tested against the R/V Revelle Trawl winch (used for SUESI)
% 
% David Myer, June 2009
% DGM: Minor overhaul 2/2023 for use with WAVE
%
% Params:
%   sFiles      - EITHER string folder+filename OR cell array of same
% Returns:
%   nWTime      - datenum
%   nWireOut    - wire out (m)
%   nVel        - velocity (usually in m/min)
%   nTension    - tension (usually in lbs)
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

    % If the file param is a single file, make it into a cell
    if ~iscell(sFiles)
        sFiles = {sFiles};
    end
    
    [nWTime nWireOut nVel nTension] = deal([]);
    for i = 1:length(sFiles)
        disp( ['Loading Winch data ' sFiles{i} '...'] );
        [nSec nMS nWO nV nT] ...
            = textread( sFiles{i}, '%f %f S%fV%fT%fX%*f:' );

        % Date is given as "unix seconds" which is seconds since 1/1/1970.
        % Need to figure out if this is UTC or local time.
        nWTime  = [nWTime; (datenum('1/1/1970 00:00') + nSec/86400 + nMS/86400000)];
        nWireOut= [nWireOut; nWO];
        nVel    = [nVel; nV];
        nTension= [nTension; nT];
    end

    return
end
