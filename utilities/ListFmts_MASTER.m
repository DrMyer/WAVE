function tblList = ListFmts_MASTER( sType )
% Internal function called by WAVE which contains the master list of
% configurable file formats approved by David Myer (ONLY - DO NOT ADD TO THIS! I
% LOOKING AT YOU KJK. DON'T DO IT). Use WAVE's internal "user customization"
% feature to add your own formats. Feel free to send those codes to me and I'll
% check them out for inclusion in the standard set.
%
% DO NOT MODIFY THIS FILE. I'M SERIOUS. DON'T.
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

tblList = table( 'Size', [0 5] ...  
            , 'VariableNames', {'Name', 'HeaderLines', 'fcnTest', 'fcnRead', 'Example'} ...
            , 'VariableTypes', {'string', 'double', 'cell', 'cell', 'string'} ...
            );
% NB: If the table format changes, also change w_panelFile.CustomizeFormats
        
switch( sType )
    case 'GPS'
        tblList(1,:) = {'NMEA GPS',         0, @(s)strncmpi(s,'$GP',3), @readGPS_NMEA,  '$GPGLL,1947.4933,S,11305.6682,E,235600,A*3F'};
        tblList(2,:) = {'GGA Raw',          0, @testGPS_GGA_Raw,  @readGPS_GGA_Raw, '02/03/2022,00:00:01.989,$GPGGA,000002.00,0434.537407,S,10557.934254,W,2,16,0.8,12.723,M,-14.0,M,4.0,0402*56'};
        tblList(3,:) = {'EMAGE (Sikuliaq)', 8, @testGPS_EMAGE,    @readGPS_EMAGE, 'ins_seapath_position	2019-05-23T16:28:47.9614Z	$GPGLL,6005.888550,N,14926.530479,W,162847.78,A,D*70'};
        tblList(4,:) = {'MET2Table.m',      0, @testGPS_MET,      @readGPS_MET,   'Time,Latitude,Longitude'};
        tblList(5,:) = {'RV Thompson simple', 0, @testGPS_GOFAR,  @readGPS_GOFAR, '02/03/2022,00:02:00.220,0434.53921,S,10557.91892,W'};
    case 'Gyro'
        tblList(1,:) = {'HEHDT raw',        0, @testGyro_HEHDT,   @readGyro_HEHDT,   '01/14/2022,15:41:08.400,$HEHDT,175.21,T*1F'};
        tblList(2,:) = {'EMAGE (Sikuliaq)', 8, @testGyro_EMAGE,   @readGyro_EMAGE,   'gyro_1	2019-05-23T16:28:50.0134Z	$HEHDT,137.19,T*12'};
        tblList(3,:) = {'MET2Table.m',      0, @testGyro_MET,     @readGyro_MET,     'Time,Gyrocompass'};
        tblList(4,:) = {'RV Thompson simple',0,@testGyro_GOFAR,   @readGyro_GOFAR,   '02/03/2022,13:53:01.541,114.49'};
    case 'Winch'
        tblList(1,:) = {'Raw',              0, @testWinch_Raw,     @readWinch_Raw,   '02/03/2022,14:26:51.173,03RD,2022-02-03T14:52:49.403,00000123,000000.0,000000.0,2818'};
        tblList(2,:) = {'TRAWL (Revelle)',  0, @testWinch_Revelle, @readWinch_Revelle, '1243955314	146	S 1573V 30T 2234X 3837:'};
        tblList(3,:) = {'EMAGE (Sikuliaq)', 8, @testWinch_EMAGE,   @readWinch_EMAGE,   'winch_rapp	2019-05-24T19:30:56.2012Z	@RCWD,6,0,0.55,0.720,9.65,0,0,0.000000*3b'};
        tblList(4,:) = {'MET2Table.m',      0, @testWinch_MET,     @readWinch_MET,     'Time,Wire_Out'};
        tblList(5,:) = {'RV Thompson simple',0,@testWinch_GOFAR,   @readWinch_GOFAR,   '02/03/2022,17:39:08.012,000027.7,000511.1'};
    case 'MET'
        tblList(1,:) = {'Raw',              0, @testMET_Raw,       @readMET_Raw, '01/14/2022,18:50:05.219,$METED,008.9,044.2,015.75,083.8,1018.8,'};
        tblList(2,:) = {'EMAGE (Sikuliaq)', 24,@testMET_EMAGE,     @readMET_EMAGE, 'met_ptu307	2019-05-23T16:28:37.0805Z	h    40 P=  1013.9 hPa   T=  7.3 ''C RH= 84.7 %RH'};
end

return;
end % ListFmts_MASTER
