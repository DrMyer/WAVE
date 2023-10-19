function nCOG = MakeCOGfromGPS( nLon, nLat, sEllipsoid )
% Utility function to make ship's course-over-ground (COG) using changes in
% latitude & longitude
%
% Params:
%   nLon - longitude (negative = west)
%   nLat - latitude (negative = south)
%   sEllipsoid - ellipsoid to use for Lon,Lat --> E,N conversion
% Returns:
%   nCOG - course-over-ground calculated from changes in lon/lat
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

    % NB: Because currents can push a ship around when it is moving slowly, I
    % would ideally use a window to approximate the COG. COG is mostly used to
    % put the wire-out "behind" the ship for iLBL navigation and that can be
    % really approximate.
    nDistWindow = 50;
    
    % Convert to UTM
    [nE,nN] = LonLat2UTM( nLon, nLat, [], sEllipsoid );
    
    % What's the median distance between two points? How many points do we need
    % to have gone about X meters?
    nPtCnt = ceil( nDistWindow / median( sqrt( diff(nN).^2 + diff(nE).^2 ) ) ) + 1;
    
    nCOG = atan2( nN(nPtCnt+1:end) - nN(1:end-nPtCnt) ...
                , nE(nPtCnt+1:end) - nE(1:end-nPtCnt) );
    nCOG = reshape( nCOG, [], 1 );
    nCOG = cat( 1, repmat( nCOG(1), floor(nPtCnt/2), 1 ) ...
                 , nCOG ...
                 , repmat( nCOG(end), ceil(nPtCnt/2), 1 ) );
    nCOG = unwrap( nCOG );
%     nCOG = smoothdata( nCOG );
    nCOG = 90 - (nCOG * 180/pi());
    nCOG = mod( nCOG, 360 );
    
    return;
end % MakeCOGfromGPS
