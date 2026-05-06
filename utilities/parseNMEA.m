function [nRtnCode, nGPS, colGPS] = parseNMEA( sIn, nInDate )
% Parse a GPS NMEA sentence - but only ones pertaining to time & position.
%
% David Myer, June 2009
% DGM: Minor overhaul 2/2023 for use with WAVE
%
% Params:
%   sIn     - a single NMEA string beginning $GP or $GN (6/29/2023 DGM)
%   nInDate - optional, passes in known date (in datenum format) to add to
%             GLL and GGA strings.
% Returns:
%   nRtnCode -  0 = string parsed OK
%               1 = sentence not used by this code
%               2 = error
%   nGPS    - a row of GPS location & time data. Fields not available from
%               the given NMEA sentence will be NaN.
%   colGPS  - a structure with the column names & numbers inside nGPS
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
    arguments
        sIn char
        nInDate double = 0
    end

%     if ~exist('nInDate','var') || isempty(nInDate)
%         nInDate = 0;
%     end
    
    nRtnCode    = 2;
    colGPS = struct( 'Date', 1, 'Lon', 2, 'Lat', 3, 'AntHt', 4 );
%     colGPS.Date = 1;    % a datenum - may not have day/mo/year in it!
%     colGPS.Lon  = 2;    % Longitude in decimal degrees and +/-
%     colGPS.Lat  = 3;    % Latitude (ditto)
%     colGPS.AntHt= 4;    % antenna height in meters
    
    % Default the return row to NaN.
    nGPS        = NaN(1,4);
    
    sIn = strtrim(sIn);     % remove leading & trailing blanks
    if length(sIn) < 6 ...
    || (~strncmpi( sIn, '$GP', 3 ) && ~strncmpi( sIn, '$GN', 3 )) 
    % $GP = GPS only
    % $GN = GPS + GLONASS (support added 6/29/2023 DGM)
        nRtnCode = 2;
        return;
    end
    
    switch( upper( sIn(4:6) ) )
        case 'ZDA'              % NMEA UTC date, time, and local zone offset
% Example: $GPZDA,040026,02,05,2007,07,00*4D
% $GPZDA,hhmmss.ss,DD,MM,YYYY,xx,xx
% hhmmss.ss = UTC 
% DD = Day, 01 to 31 
% MM = Month, 01 to 12 
% YYYY = Year 
% xx = Local zone description, 00 to +/- 13 hours 
% xx = Local zone minutes description (same sign as hours) 
            mGPS = sscanf( sIn, '$GPZDA,%f,%f,%f,%f' );
            %%% Note: official spec calls for hhmmss.ss but it is almost
            %%% always seen as hhmmss.  But use %f just in case the .ss ever
            %%% appears in pertinent data.
            if numel(mGPS) == 4
                nRtnCode = 0;
                nGPS(colGPS.Date)   = datenum( [ mGPS( [4 3 2] )' pn_Time(1) ] );
            end
            
        case 'GGA'              % NMEA GPS fix data
% Example: $GPGGA,040030,3240.0939,N,11739.9385,W,2,9,0.4,24,M,,M,,*53
% $GPGGA,hhmmss.ss,llll.ll,a,yyyyy.yy,a,x,xx,x.x,x.x,M,x.x,M,x.x,xxxx*hh
% 1    = UTC of Position -- time only, no date
% 2    = Latitude (ddmm.mm) so 0831.15 = 8 deg 31.15 min
% 3    = N or S
% 4    = Longitude (dddmm.mm)
% 5    = E or W
% 6    = GPS quality indicator (0=invalid; 1=GPS fix; 2=Diff. GPS fix)
% 7    = Number of satellites in use [not those in view]
% 8    = Horizontal dilution of position
% 9    = Antenna altitude above/below mean sea level (geoid)
% 10   = Meters  (Antenna height unit)
% 11   = Geoidal separation (Diff. between WGS-84 earth ellipsoid and
%        mean sea level.  -=geoid is below WGS-84 ellipsoid)
% 12   = Meters  (Units of geoidal separation)
% 13   = Age in seconds since last update from diff. reference station
% 14   = Diff. reference station ID#
% 15   = Checksum
            mGPS = sscanf( sIn, '$GPGGA,%f,%f,%c,%f,%c,%f,%f,%f,%f' );
            if numel(mGPS) == 9 && mGPS(6) > 0 % ignore GPS quality = "invalid"
                nRtnCode = 0;
                
                % Parse the GPS info - no date, just time & gps location.
                nGPS(colGPS.Date)   = datenum( [0 0 0 pn_Time(1)] ) + nInDate;
                
                % GPS location
                pn_LatLon( mGPS( [2 3 4 5] ) );

                % Antenna height
                nGPS(colGPS.AntHt)   = mGPS(9);
            end
            
        case 'GLL'      % Geographic Lat Lon & time (no date)
% $GPGLL,llll.ll,a,yyyyy.yy,a,hhmmss.ss,A*hh
% 1    = Latitude (ddmm.mm) so 0831.15 = 8 deg 31.15 min
% 2    = N or S
% 3    = Longitude (dddmm.mm)
% 4    = E or W
% 5    = UTC of Position -- time only, no date
% 6    = status: 'A' = valid data
% 7    = Checksum - NB: in some cases the *hh is not present
            mGPS = sscanf( sIn, '$GPGLL,%f,%c,%f,%c,%f,%c' );
            if numel(mGPS) == 6 && strcmpi( char(mGPS(6)), 'A' )
                nRtnCode = 0;
                
                % Parse the time - no date.
                nGPS(colGPS.Date)   = datenum( [0 0 0 pn_Time(5)] )+ nInDate;
                
                % GPS location
                pn_LatLon( mGPS( [1 2 3 4] ) );
            end
            
        case 'RMC'      % Recommended Minimum specific GPS/TRANSIT data
% $GPRMC,hhmmss.ss,A,llll.ll,a,yyyyy.yy,a,x.x,x.x,ddmmyy,x.x,a,m*hh
% 1    = UTC time of fix
% 2    = Data status (A=Valid position, V=navigation receiver warning)
% 3    = Latitude of fix
% 4    = N or S of longitude
% 5    = Longitude of fix
% 6    = E or W of longitude
% 7    = Speed over ground in knots
% 8    = Track made good in degrees True
% 9    = UTC date of fix
% 10   = Magnetic variation degrees (Easterly var. subtracts from true course)
% 11   = E or W of magnetic variation
% NOTE: Field 12 added to later versions of this string. Not always present.
% 12   = Mode indicator, (A=Autonomous, D=Differential, E=Estimated, N=Data not valid)
% 13   = Checksum
            
            mGPS = sscanf( sIn, '$GPRMC,%f,%c,%f,%c,%f,%c,%f,%f,%f' );
            if numel(mGPS) == 9 && strcmpi( char(mGPS(2)), 'A' )
                nRtnCode = 0;
                
                nGPS(colGPS.Date)   = datenum( ...
                    [ 2000 + mod( mGPS(9), 100 ) ...
                    mod( floor( mGPS(9) / 100 ), 100 ) ...
                    floor( mGPS(9) / 10000 ) ...
                    pn_Time(1) ] );
                
                % GPS location
                pn_LatLon( mGPS( [3 4 5 6] ) );
            end
            
        otherwise
            nRtnCode = 1;       % ignoring this NMEA sentence
    end % switch/case for NMEA types
    
    return
    
    
    %%%%%%% INTERNAL FUNCTIONS %%%%%%% Can access all local variables of above
    function pn_LatLon( m )
        nGPS(colGPS.Lat) = floor( m(1) / 100 ) + mod( m(1), 100 ) / 60;
        if strcmpi( char(m(2)), 'S' )
            nGPS(colGPS.Lat) = -1 * nGPS(colGPS.Lat);
        end

        nGPS(colGPS.Lon) = floor( m(3) / 100 ) + mod( m(3), 100 ) / 60;
        if strcmpi( char(m(4)), 'W' )
            nGPS(colGPS.Lon) = -1 * nGPS(colGPS.Lon);
        end
        return
    end
    
    function nHMS = pn_Time( iTime )
        nHMS = [    floor( mGPS(iTime) / 10000 ) ...
                    mod( floor( mGPS(iTime) / 100 ), 100 ) ...
                    mod( mGPS(iTime), 100 ) ];
        return
    end
end
