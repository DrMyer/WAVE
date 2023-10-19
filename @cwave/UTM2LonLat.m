function [nLon,nLat] = UTM2LonLat( oWave, nE, nN )
    % Convenience wrapper function which uses the current cwave object's UTM
    % zone info to convert the given E,N back to Lon,Lat
    %---------------------------------------------------------------------------
    % Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
    %---------------------------------------------------------------------------
    
    arguments
        oWave cwave
        nE double
        nN double
    end

    [nLon,nLat] = UTM2LonLat( nE, nN, oWave.nUTMZone, oWave.bSHemi, char(oWave.sEllipsoid) );

    return;
end % UTM2LonLat