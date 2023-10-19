function [tMET,stSumMET] = MET2Table( nData, colMET )
% [tMET,stSumMET] = MET2Table( nData, colMET )
%
% Convert MET data ("meteorological" data) from a data block and colstruct into
% a MatLab table. Translate the 2-letter codes into readable column names.
%
% DGM Jan 2023
%
% Params:
%   nMet    - matrix of MET data. Columns depend on the files loaded.
%   colMet  - names of the columns of nMet. These names are taken directly
%           from the MET file's header and are usually 2-char codes (such as
%           GY for Gyro compass, CR for GPS Course-over-ground) sometimes
%           with a "_1" or "_2" ....  The full list of these codes is found
%           in the "MetAcq.pdf" which accompanies the data.  See appendix A.
%           All column names assumed to be FORCED TO UPPERCASE.
% Returns:
%   tMET - a MatLab table with appropriately named columns - not 2-char but
%           actual descriptive names
%   stSumMet - returns the summary(tMET) result with the stupid ModifiedVarnames 
%           warning suppressed
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
% See also readMET

    % Create the list of readable names from the 2-char abbreviations
    cVars = {};
    cUnit = {};
    cFlds = fieldnames( colMET );
    for i = 1:numel(cFlds)
        sFld = cFlds{i};
        if sFld(end-1) == '_'   % for '_2' fields
            sSuffix = sFld(end-1:end);
            sFld(end-1:end) = [];
        else
            sSuffix = '';
        end
%% NOTE
% Please do NOT change any of the sName values below. They are used throughout
% the WAVE project.
%%
        switch( sFld )
        case 'TIME'; sName = 'Time';                    cUnit{i} = '';
        case 'AT'; sName = 'Air_Temp';                  cUnit{i} = 'C';
        case 'BP'; sName = 'Barometric_Pressure';       cUnit{i} = 'mb';
        case 'BC'; sName = 'Baro_Pres_Temp';            cUnit{i} = 'C';
        case 'SW'; sName = 'Short_Wave_Radiation';      cUnit{i} = 'W/m^2';
        case 'LW'; sName = 'Long_Wave_Radiation';       cUnit{i} = 'W/m^2';
        case 'LD'; sName = 'LWR_Dome_Temp';             cUnit{i} = 'K';
        case 'LB'; sName = 'LWR_Body_Temp';             cUnit{i} = 'K';
        case 'LT'; sName = 'LWR_Thermopile';            cUnit{i} = 'V';
        case 'PR'; sName = 'Precipitation';             cUnit{i} = 'mm';
        case 'PT'; sName = 'Precip_Rate';               cUnit{i} = 'mm/hr';
        case 'RH'; sName = 'Relative_Humidity';         cUnit{i} = 'Pct';
        case 'RT'; sName = 'Air_Temp_RHModule';         cUnit{i} = 'C';
        case 'DP'; sName = 'Dew_Point';                 cUnit{i} = 'C';
        case 'WS'; sName = 'Rel_Wind_Spd_mps';          cUnit{i} = 'm/s';
        case 'WK'; sName = 'Rel_Wind_Spd_kts';          cUnit{i} = 'kts';
        case 'TW'; sName = 'True_Wind_Spd_mps';         cUnit{i} = 'm/s';
        case 'TK'; sName = 'True_Wind_Spd_kts';         cUnit{i} = 'kts';
        case 'WD'; sName = 'Rel_Wind_Dir';              cUnit{i} = 'degrees';
        case 'TI'; sName = 'True_Wind_Dir';             cUnit{i} = 'degrees';
        case 'ST'; sName = 'Sea_Surf_Temp';             cUnit{i} = 'C';
        case 'TT'; sName = 'Thermosalinograph_Temp';    cUnit{i} = 'C';
        case 'TC'; sName = 'Thermosalinograph_Cond';    cUnit{i} = 'mS/cm';
        case 'SA'; sName = 'Salinity';                  cUnit{i} = 'PSU';
        case 'SD'; sName = 'Sigma_t';                   cUnit{i} = 'kg/m^2';
        case 'SV'; sName = 'Sound_Velocity';            cUnit{i} = 'm/s';
        case 'OX'; sName = 'Oxygen_mlpl';               cUnit{i} = 'ml/l';
        case 'OG'; sName = 'Oxygen_mgpl';               cUnit{i} = 'mg/l';
        case 'OC'; sName = 'Oxygen_Current';            cUnit{i} = 'ua';
        case 'OT'; sName = 'Oxygen_Temp';               cUnit{i} = 'C';
        case 'OS'; sName = 'Oxygen_Saturation';         cUnit{i} = 'ml/l';
        case 'PH'; sName = 'pH';                        cUnit{i} = '';
        case 'FL'; sName = 'Fluorometer';               cUnit{i} = 'ug/l';
        case 'TB'; sName = 'Turbidity';                 cUnit{i} = 'ntu';
        case 'TR'; sName = 'Transmissometer';           cUnit{i} = 'Pct';
        case 'BA'; sName = 'Beam_Attenuation';          cUnit{i} = '';
        case 'PA'; sName = 'Surface_PAR';               cUnit{i} = 'uE/s/m^2';
        case 'FM'; sName = 'USW_Flow_Meter_GPM';        cUnit{i} = 'g/min';
        case 'FI'; sName = 'USW_Flow_Meter_LPM';        cUnit{i} = 'l/min';
        case 'VT'; sName = 'Volts';                     cUnit{i} = 'V';
        case 'MA'; sName = 'Current';                   cUnit{i} = 'mA';
        case 'WT'; sName = 'Aux_Water_Temp';            cUnit{i} = 'C';
        case 'AX'; sName = 'Aux_Air_Temp';              cUnit{i} = 'C';
        case 'PS'; sName = 'Pressure';                  cUnit{i} = 'psi';
        case 'XX'; sName = 'Unspecified';               cUnit{i} = '';
        case 'LA'; sName = 'Latitude';                  cUnit{i} = '';
        case 'LO'; sName = 'Longitude';                 cUnit{i} = '';
        case 'CR'; sName = 'COG';                       cUnit{i} = 'degrees';
        case 'SP'; sName = 'Ship_Speed_kts';            cUnit{i} = 'kts';
        case 'SL'; sName = 'Ship_Speed_Longitudinal';   cUnit{i} = 'kts';
        case 'SX'; sName = 'Ship_Speed_Transverse';     cUnit{i} = 'kts';
        case 'GY'; sName = 'Gyrocompass';               cUnit{i} = 'degrees';
        case 'GT'; sName = 'GPS_Time_of_Day';           cUnit{i} = 'GMT';
        case 'TS'; sName = 'Time_Server_Time_of_Day';   cUnit{i} = 'GMT';
        case 'ZD'; sName = 'GPS_DateTime';              cUnit{i} = 'sec since 1970';
        case 'GA'; sName = 'GPS_Altitude';              cUnit{i} = 'm';
        case 'GS'; sName = 'GPS_Status';                cUnit{i} = '';
        case 'SY'; sName = 'System_DateTime';           cUnit{i} = 'sec since 1970';
        case 'BT'; sName = 'Bottom_Depth';              cUnit{i} = 'm';
        case 'SH'; sName = 'Ashtech_Heading';           cUnit{i} = 'degrees';
        case 'SM'; sName = 'Ashtech_Pitch';             cUnit{i} = 'degrees';
        case 'SR'; sName = 'Ashtech_Roll';              cUnit{i} = 'degrees';
        case 'ZO'; sName = 'Wire_Out';                  cUnit{i} = 'm';
        case 'ZS'; sName = 'Winch_Speed';               cUnit{i} = 'm/min';
        case 'ZT'; sName = 'Winch_Tension';             cUnit{i} = 'lbs';
        case 'VP'; sName = 'VRU_Pitch';                 cUnit{i} = 'degrees';
        case 'VR'; sName = 'VRU_Roll';                  cUnit{i} = 'degrees';
        case 'VH'; sName = 'VRU_Heave';                 cUnit{i} = 'm';
        case 'VY'; sName = 'Ship_List';                 cUnit{i} = 'degrees';
        case 'VX'; sName = 'Ship_Trim';                 cUnit{i} = 'degrees';
        case 'RX'; sName = 'Accel_X';                   cUnit{i} = 'm/s';
        case 'RY'; sName = 'Accel_Y';                   cUnit{i} = 'm/s';
        case 'RZ'; sName = 'Accel_Z';                   cUnit{i} = 'm/s';
        case 'IP'; sName = 'CTD_Depth';                 cUnit{i} = 'm';
        case 'IT'; sName = 'CTD_Temp';                  cUnit{i} = 'C';
        case 'IS'; sName = 'CTD_Salinity';              cUnit{i} = 'psu';
        case 'IA'; sName = 'CTD_Altimeter';             cUnit{i} = 'm';
        case 'IV'; sName = 'CTD_Velocity';              cUnit{i} = 'm/s';
        case 'IX'; sName = 'Instrument_Aux';            cUnit{i} = '';
        otherwise; sName = sFld;                        cUnit{i} = '';
        end
        cVars{i} = [sName sSuffix];
    end
    
    % Create the table
    tMET = array2table( nData, 'VariableNames', cVars );
    tMET.Properties.VariableUnits = cUnit;
    tMET.Time = datetime( tMET.Time, 'ConvertFrom', 'datenum' );
    
    % Does the caller want the summary table too?
    if nargout() > 1
        % Turn off the dumb (& often spurious) warning about name changes
        stWarn = warning( 'off', 'MATLAB:table:ModifiedVarnames' );
        stSumMET = summary( tMET );
        warning( stWarn );
    end
    
    return;
end % MET2Table
