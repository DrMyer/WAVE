function SetUTMInfo( oWave, nZone, bSHemi, sEllipsoid, bLock )
% Set the UTM zone & hemisphere and notify listeners if there's a change
%
% Params:
%   oWave   - the cwave object with all the data
%   nZone, bSHemi (params as returned by LonLat2UTM)
%           bSHemi can be T/F or string "N"/"S" or char 'N'/'S'
%   sEllipsoid (opt) - string ellipsoid. If not passed, no change assumed
%   bLock (opt) - should UTM info be locked to prevent changes?
%
%-------------------------------------------------------------------------------
% Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
%-------------------------------------------------------------------------------
    % By default assume no changes
    bNotify = false;
    
    % Save the UTM zone
    if ~oWave.bUTMLock && ~isequal( oWave.nUTMZone, nZone )
        bNotify = true;
        oWave.AddLog( cwave.LogOK, cwave.sLog_Cfg ...
            , sprintf( 'UTM Zone changed to %g from %g', nZone, oWave.nUTMZone ) ...
            );
        oWave.nUTMZone = nZone;
    end
    
    % Save the UTM Hemisphere
    if ~islogical( bSHemi )
        bSHemi = strncmpi( bSHemi, 'S', 1 );
    end
    if ~oWave.bUTMLock && ~isequal( oWave.bSHemi, bSHemi )
        bNotify = true;
        sHemi   = iif( bSHemi, "South", "North" );
        oWave.AddLog( cwave.LogOK, cwave.sLog_Cfg ...
            , sprintf( 'UTM Hemisphere changed to %s from %s' ...
            , char(sHemi), char(oWave.sUTMHemi) ) ...
            );
        oWave.sUTMHemi = sHemi;
    end
    
    % Save the UTM ellipsoid, if passed (optional param)
    if ~oWave.bUTMLock && exist('sEllipsoid','var') && ~isempty(sEllipsoid) ...
    && ~isequal( oWave.sEllipsoid, sEllipsoid )
        bNotify = true;
        oWave.AddLog( cwave.LogOK, cwave.sLog_Cfg ...
            , sprintf( 'UTM Ellipsoid changed to %s from %s' ...
            , char(sEllipsoid), char(oWave.sEllipsoid) ) ...
            );
        oWave.sEllipsoid = sEllipsoid;
    end
    
    % Change lock status last (so config can set the UTM and then lock it all in
    % one call)
    if exist( 'bLock', 'var' ) && islogical( bLock ) ...
    && ~isequal( oWave.bUTMLock, bLock )
        bNotify = true;
        oWave.AddLog( cwave.LogOK, cwave.sLog_Cfg ...
            , iif( bLock, 'UTM zone locked to prevent changes', 'UTM zone unlocked' ) ...
            );
        oWave.bUTMLock = bLock;
    end
    
    % If any of the params were changed, notify listeners
    if bNotify
        notify( oWave, 'UTM_VarChg' );
    end
    
    return;
end % SetUTMInfo
