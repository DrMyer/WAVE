function PlotValeport( oWave )
% cwave::PlotValeport( oWave )
%
% Plot valeport-derived depth profiles. Public method of the cwave class.
%
% Parameters:
%   oWave - the controlling cwave instance
% Returns:
%-------------------------------------------------------------------------------
% Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
%-------------------------------------------------------------------------------

    % If the table is empty, don't allow plotting
    if isempty( oWave.tableValeport )
        uialert( oWave.hFig, {
            'The Valeport Depth Profile table is empty.'
            ''
            'This table is filled by the process that syncs'
            'real time and ship data with parsed SUESI output.'
            }, 'Plot Depth Profiles' );
        return;
    end
    
    % Get a generic plot figure centered over the main window. Plot the three
    % depth profiles side-by-side with +ve Depth downward on the y-axis
    hFig = figCenter( oWave.hFig, 'pptHD' );
    
    hAxV = subplot( 1, 3, 1 );
    sub_MinMaxMed( hAxV, oWave.tableValeport, 'Velocity', 'Vmin', 'Vmax' );
    hAxC = subplot( 1, 3, 2 );
    sub_MinMaxMed( hAxC, oWave.tableValeport, 'Conductivity', 'Cmin', 'Cmax' );
    hAxT = subplot( 1, 3, 3 );
    sub_MinMaxMed( hAxT, oWave.tableValeport, 'Temp', 'Tmin', 'Tmax' );
    
    % Finish up the plots
    xlabel( hAxV, 'Velocity (m/s)' );
    xlabel( hAxC, 'Conductivity (\Omegam)', 'Interpreter', 'TeX' );
    xlabel( hAxT, 'Temperature (\circC)', 'Interpreter', 'TeX' );
    ylabel( hAxV, 'Depth (m)' );
    linkaxes( [hAxV hAxC hAxT], 'y' );
    
    % Create a title centered over the three sub-plots
    sgtitle( hFig, {
        'Valeport-derived Depth Profiles'
        oWave.sPlotSubtitle
        } );
    
    addPlotMenu( hFig, fullfile( oWave.sPlotDir, 'ValeportDepthProfiles' ), 'Save' );
    
    return;
end % PlotValeport

%-------------------------------------------------------------------------------
function sub_MinMaxMed( hAx, tblVale, sFld, sMin, sMax )
    
    % Plot a light grey patch defining the min-max range
    X = [tblVale.(sMin); flipud( tblVale.(sMax) )];
    Y = [tblVale.Depth; flipud( tblVale.Depth )];
    patch( hAx, X, Y, [0 0 0] + 0.9, 'EdgeColor', 'none', 'DisplayName', 'min-max range' );
    hold( hAx, 'on' );
    
    % Plot the data line on top
    plot( hAx, tblVale.(sFld), tblVale.Depth ...
        , 'LineStyle', '-', 'LineWidth', 1, 'Marker', 'none' ...
        , 'DisplayName', ['median ' sFld] );
    
    % Reverse the depth direction & scrunch in the axes
    hold( hAx, 'off' );
    hAx.YDir = 'reverse';
    axisTight( hAx );
    
    return;
end % sub_MinMaxMed
