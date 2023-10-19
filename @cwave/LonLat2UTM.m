function [nE,nN] = LonLat2UTM( oWave, sLog, nLon, nLat )
    % [nE,nN] = cwave::LonLat2UTM( oWave, sLog, nLon, nLat )
    %
    % Wrapper for converting Lon,Lat to E,N which respects the cwave object's
    % current ellipsoid and "locked UTM zone" settings. Will also change those
    % settings, if unlocked, while creating the correct log entries.
    %
    %---------------------------------------------------------------------------
    % Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
    %---------------------------------------------------------------------------
    arguments
        oWave cwave
        sLog char
        nLon double
        nLat double
    end
    
    % If no data passed in, don't crash
    if isempty( nLon )
        [nE,nN] = deal([]);
        return;
    end
    
    % What UTM zone are we dealing with?
    if ~oWave.bUTMLock
        % Are the data all in the same hemisphere?
        nMinSign  = sign( min(nLat,[],'all') );
        bBothHemi = nMinSign ~= sign( max(nLat,[],'all') );
        if bBothHemi
            sMsg = 'Latitudes are in both North & South hemispheres';
            oWave.AddLog( cwave.LogError, sLog, sMsg );
            % disp( [sLog ' :: ' sMsg] );
        end
        
        % Are the data all in the same zone?
        nZ1 = 1 + fix( (mod( min(nLon,[],'all') + 180, 360 ) ) / 6 );
        nZ2 = 1 + fix( (mod( max(nLon,[],'all') + 180, 360 ) ) / 6 );
        if nZ1 ~= nZ2
            sMsg = sprintf( 'Longitudes span zones %d - %d', nZ1, nZ2 );
            oWave.AddLog( cwave.LogError, sLog, sMsg );
            % disp( [sLog ' :: ' sMsg] );
        end
        
        % If there is confusion, get the user to choose
        if bBothHemi || nZ1 ~= nZ2
            % Force user to choose. Note the disparity and error out of whatever
            % process we're in.
            disp( 'Set the UTM zone on the "Configuration" tab and "Lock" it' );
            error( 'Lon,Lat data span multiple zones and/or hemispheres. See command window.' );
        end
        
        % Set the values in the oWave object (can trigger listeners)
        nZone   = nZ1;
        bSHemi  = nMinSign < 0;
        oWave.SetUTMInfo( nZone, bSHemi );
    end
    
    % Convert the data
    [nE,nN] = LonLat2UTM( nLon, nLat, oWave.nUTMZone, char(oWave.sEllipsoid) );
    
    return;
end % LonLat2UTM
