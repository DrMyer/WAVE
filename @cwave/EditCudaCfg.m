function EditCudaCfg( oWave )
% cwave::EditCudaCfg( oWave )
%
% Manage edit dialog for iLBL Barracuda configurations
%
% Parameters:
%   oWave - the controlling cwave instance
% Returns:
%-------------------------------------------------------------------------------
% Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
%-------------------------------------------------------------------------------

% Ask the user if they want the helper plot
if strcmpi( 'Yes', uiconfirm( oWave.hFig, {
    ['Do you want me to display the helper plot ' ...
    'containing ping & GPS info for the Barracudas?']
    ' '
    ['(This plot can help you decide which NAVx device ' ...
    'belongs to which reply frequency and/or channel.)']
    }, 'Edit Barracuda Configuration', 'Options', {'Yes', 'Skip'} ...
    , 'DefaultOption', 1, 'CancelOption', 2 ) )

    oWave.PlotCudaCfg();
end

% Call the general table edit UI
[bOK, tChgd] = UITableEdit( oWave.tableCudaCfg, oWave.hFig ...
    , 'Barracuda NAVx Configurations', {
    ['Enter the configuration for each Barracuda deployment. For a typical ' ...
    'survey there will be only two entries. However if barracudas are recovered ' ...
    'and their characteristics are changed (e.g. NAVx number, reply channel, etc) ' ...
    'then you can put multiple lines here distinguished by the date/time ' ...
    'that the changes are made.']
    ' '
    'Set ReplyFreq = NaN to use ReplyCh instead.'
    ' '
    ['The DateFrom / To columns can be NaT ("not a time") for any barracuda ' ...
    'whose characteristics stayed the same for the entire deployment.']
    }, @cwave.ValidateCudaCfg, @sub_Reset ...
    , {'Add', 'Delete'} ... Add Row & Del Row are allowed on this table
    );
if ~bOK
    return;
end

% User updated the table. Log & update
oWave.AddLog( cwave.LogOK, cwave.sLog_TxN_CudaCfg, 'User edited barracuda configurations.' );
oWave.tableCudaCfg = sortrows( tChgd, 'DeviceNo' );

return;
end % EditCudaCfg

%-------------------------------------------------------------------
% "Reset" function for UITableEdit on tableAtmPres
function sub_Reset( hTable )
hTable.Data = cwave.GetDfltFor( 'tableAtmPres' );
return;
end % sub_Reset
