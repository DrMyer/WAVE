function AtmPEdit( oWave )
% cwave::AtmPEdit( oWave )
%
% Public method of the cwave class. Manage editing tableAtmPres on multiple tabs
%
% Parameters:
%   oWave - the controlling cwave instance
% Returns:
%-------------------------------------------------------------------------------
% Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
%-------------------------------------------------------------------------------

% Call the general table edit UI
[bOK, table] = UITableEdit( oWave.tableAtmPres, oWave.hFig ...
    , 'Avg Atmospheric Pressure', {
    ['Enter dates and average atmospheric pressure in millibars ' ...
    'at sea-level for dates of the cruise. If you have the ship''s ' ...
    'meteorological data, you can let WAVE process this itself. ' ...
    'Otherwise enter the data here. These will be used in a linear ' ...
    'interpolation across time as tare values for the Valeport''s ' ...
    'pressure readings to convert them to depth more accurately. ']
    ' '
    'IF YOU DO NOT KNOW THE AVG PRESSURE, you can enter 1000.'
    ' '
    ['(NB: You can ignore the Std column. It''s for reference if you''ve ' ...
    'used the automatic process.)']
    }, @cwave.ValidateAtmPTable, @sub_Reset ...
    , {'Add', 'Delete'} ... Add Row & Del Row are allowed on this table
    );
if ~bOK
    return;
end

% User updated the table. Log & update
oWave.AddLog( cwave.LogOK, cwave.sLog_AtmPres, 'User edited avg atm pressures.' );
oWave.tableAtmPres = sortrows( table, 'Date' );     % SORT by date

return;
end % AtmPEdit

%-------------------------------------------------------------------
% "Reset" function for UITableEdit on tableAtmPres
function sub_Reset( hTable )
hTable.Data = cwave.GetDfltFor( 'tableAtmPres' );
return;
end % sub_Reset
