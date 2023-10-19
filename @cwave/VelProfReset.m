function VelProfReset( oWave )
% cwave::VelProfReset( oWave )
%
% Utility for w_panelTable's Reset button on velocity profile time series
%
% Parameters:
%   oWave - the controlling cwave instance
% Returns:
%-------------------------------------------------------------------------------
% Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
%-------------------------------------------------------------------------------
    arguments
        oWave cwave
    end
    
    % Clear everything in the table EXCEPT the valeport entry.
    %
    % NB: Do the cell array FIRST because the listener is on the table
    % and everything needs to be done before the listener fires off
    %
    bWhich = strcmpi( oWave.tableVProfile.Name, cwave.sVProfile_Valeport );
    if all( bWhich )    % only have Valeport. No reset required
        return;
    end
    oWave.AddLog( cwave.LogOK, cwave.sLog_RxVProfile, 'User Reset velocity profile list' );
    if any(bWhich)
        oWave.cVProfile = oWave.cVProfile(bWhich);
        oWave.tableVProfile = oWave.tableVProfile(bWhich,:);
    else
        oWave.cVProfile = {};
        oWave.tableVProfile = cwave.GetDfltFor( 'tableVProfile' );
    end
    
    return;
end % VelProfReset
