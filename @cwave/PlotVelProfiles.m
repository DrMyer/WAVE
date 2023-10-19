function PlotVelProfiles( oWave )
% cwave::PlotVelProfiles( oWave )
%
% Plot Velocity profiles over time
%
% Parameters:
%   oWave - the controlling cwave instance
% Returns:
%-------------------------------------------------------------------------------
% Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
%-------------------------------------------------------------------------------

    % If the table is empty, don't allow plotting
    if isempty( oWave.tableVProfile )
        uialert( oWave.hFig, {
            'The Velocity profile table is empty.'
            }, 'Plot Velocity Profiles' );
        return;
    end
    
    hFig = getStackedFig( [500 800] );
    hAx  = axes( hFig );
    
    for iVP = 1:height( oWave.tableVProfile )
        tblVP       = oWave.cVProfile{iVP};
        if isempty( tblVP )
            continue;
        end
        plot( hAx, tblVP.Velocity, tblVP.Depth ...
            , 'Marker', 'none', 'LineStyle', '-', 'LineWidth', 1 ...
            , 'DisplayName', oWave.tableVProfile.Name(iVP) ...
            );
        hold( hAx, 'on' );
    end
    
    hold( hAx, 'off' );
    hAx.YDir = 'reverse';
    grid( hAx, 'on' );
    axisTight( hAx );
    xlabel( hAx, 'Velocity (m/s)' );
    ylabel( hAx, 'Depth (m)' );
    if height( oWave.tableVProfile ) > 1
        legend( hAx, 'Location', 'best' );
        sTitle = 'Velocity Profiles';
    else
        sTitle = ['Velocity Profile ' char(oWave.tableVProfile.Name(1))];
    end
    title( hAx, {sTitle; oWave.sPlotSubtitle} );
    hFig.Name = sTitle;
    addPlotMenu( hFig, fullfile( oWave.sPlotDir, strrep(sTitle,' ','_') ), 'Save' );
    
    return;
end % PlotVelProfiles
