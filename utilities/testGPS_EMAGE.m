function b = testGPS_EMAGE( s )
% Quick function used by WAVE (via ListFmts_GPS.m) to test whether a given
% single line from a file indicates that the file is a ship's GPS file in
% the format found on the EMAGE cruise (R/V Sikuliaq)
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
% See also ListFmts_GPS, readGPS_EMAGE

try
    % This is the format from R/V Sikuliaq in 2019 EMAGE cruise. It is Kongsberg
    % SEAPATH 320+ data but with a prefix added to every single line by the LDEO
    % Data System (LDS) pre-processor.
    %
    % <LDS Logger ID><tab><LDS time stamp><tab><Seapath data>
    % <LDS Logger ID> = 'ins_seapath_position'
    % <LDS time stamp> = 'yyyy-mm-ddThh:mm:ss.mmmmZ'
    % <Seapath data> = NMEA with $GP (GPS only) and $GN (GPS + GLONASS)
    %{
        $..ZDA,time,day,month,year,offset_hour,offset_min*checksum
        $..RMC,time,status,lat,N/S,lon,E/W,sog,cog,date,variation,E/W,mode*checksum
        $..GGA,time,lat,N/S,lon,E/W,quality,used,hdop,alt,M,separation,M,age,id*checksum
        ... others we don't need ...
    %}
    %
    c = strsplit( s, char(9) ); % tab delimited
    b = strcmpi( c{1}, 'ins_seapath_position' ) ...
     && strncmpi( c{3}, '$', 1 );    % a NMEA string of some type
    
catch
    b = false;
end

return;
end % testGPS_EMAGE
