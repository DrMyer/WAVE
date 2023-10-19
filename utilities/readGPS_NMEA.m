function tGPS = readGPS_NMEA( cFiles, hUIFig )
% Quick function used by WAVE (via ListFmts_GPS.m) to read GPS info in NMEA fmt
%
% Params:
%   cFiles  - cell array of path+filenames to process all together
%   hUIFig  - (opt; dflt []) if given, handle to uifigure over which to use
%             uiprogressdlg to show activity.
% Returns:
%   tGPS    - table with columns: Time, Lat, Lon
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
% See also ListFmts_GPS

[nGPS,colGPS] = readPCODE( cFiles, 'ReqLatLon', 'UseMat', hUIFig );
tGPS = table( 'Size', [size(nGPS,1) 3] ...
    , 'VariableNames', {'Time', 'Lat', 'Lon'} ...
    , 'VariableTypes', {'datetime', 'double', 'double'} ...
    );
tGPS.Time = datetime( nGPS(:,colGPS.Date), 'ConvertFrom', 'datenum' );
tGPS.Lat  = nGPS(:,colGPS.Lat);
tGPS.Lon  = nGPS(:,colGPS.Lon);

return;
end % readGPS_NMEA
