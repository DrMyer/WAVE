function PlotCudaGPS_QC( oWave )
% cwave::PlotCudaGPS_QC( oWave )
%
% QC plot of barracuda GPS time series
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
    
    nSigma = 6; % ad hoc parameter
    
    % Must have something to plot
    if isempty( oWave.tableCudaGPS )
        uialert( oWave.hFig, {
            'The Barracuda time series is empty.'
            'There is nothing to plot.'
            }, 'Plot Barracuda Time Series', 'Icon', 'error' );
        return;
    end
    
    % Set up the plot window
    hFig    = getStackedFig( 'pptHD', 'Name', 'Barracuda GPS QC' );
    hAx(1)  = subplot( 2, 2, 1, 'Parent', hFig );
    hAx(2)  = subplot( 2, 2, 3, 'Parent', hFig );
    hMap    = subplot( 2, 2, [2 4], 'Parent', hFig );
    
    % Get unique colors but stay away from the red family - need red to
    % highlight possible deviant points
    nClrs   = [
        0           0           1        % blue
        0        0.63           0        % green
        0.75        0        0.75        % magenta
        0.50     0.50        0.50        % grey
        0        0.90        0.90        % cyan
        0.50     0.50           0        % olive
        ];
    cMarkers = {'o', 's', 'd', 'p', 'h', '^', 'v', '>', '<'};
    
    % Are there any anomalies? This must be checked device by device
    nDevList = unique( oWave.tableCudaGPS.DeviceNo );
    if numel(nDevList) > size(nClrs,1)
        nClrs = winter( numel(nDevList) );
    end
    iClr = 0;
    nChkCnt = 0;
    for nDevNo = onerow( nDevList )
        iClr = iClr + 1;
        sName = sprintf( 'NAV %d', nDevNo );
        
        % Extract the point for this NAVx device
        tCuda = oWave.tableCudaGPS(oWave.tableCudaGPS.DeviceNo == nDevNo,:);
        
        % First plot the points from this device
        plot( hAx(1), tCuda.Time, tCuda.North, '.', 'Color', nClrs(iClr,:) ...
            , 'DisplayName', sName );
        plot( hAx(2), tCuda.Time, tCuda.East, '.', 'Color', nClrs(iClr,:) ...
            , 'DisplayName', sName );
        plot( hMap, tCuda.East, tCuda.North, '.', 'Color', nClrs(iClr,:) ...
            , 'DisplayName', sprintf( '%s (%d pts)', sName, height(tCuda) ) );
        hold( hAx(1), 'on' );
        hold( hAx(2), 'on' );
        hold( hMap, 'on' );
        
        % Now look for aberrations
        dt   = seconds( diff( tCuda.Time ) );
        dt(dt<1) = 1;
        dEdt = diff( tCuda.East ) ./ dt;
        dNdt = diff( tCuda.North ) ./ dt;
        bChk = abs( dEdt ) > (nSigma * std(dEdt)) | abs( dNdt ) > (nSigma * std(dNdt));
        
        % Did we find any? Plot red markers over them
        if any( bChk )
            sName = [sName ' > ' num2str(nSigma) ' \sigma'];
            nChkCnt = nChkCnt + sum( bChk );
            plot( hAx(1), tCuda.Time(bChk), tCuda.North(bChk), 'r' ...
                , 'Marker', cMarkers{iClr}, 'LineStyle', 'none', 'DisplayName', sName );
            plot( hAx(2), tCuda.Time(bChk), tCuda.East(bChk), 'r' ...
                , 'Marker', cMarkers{iClr}, 'LineStyle', 'none', 'DisplayName', sName );
            plot( hMap, tCuda.East(bChk), tCuda.North(bChk), 'r' ...
                , 'Marker', cMarkers{iClr}, 'LineStyle', 'none' ...
                , 'DisplayName', sprintf( '%s (%d pts)', sName, sum(bChk) ) );
        end
    end % loop through NAVn list
    
    % Finish up the plots
    axisTight( hAx(1) );
    axisTight( hAx(2) );
    axis( hMap, 'equal' );
    axisTight( hMap );
    linkaxes( hAx, 'x' );
    
    ylabel( hAx(1), 'Northing' );
    axisTicksUTM( hAx(1), 'y' );
    
    ylabel( hAx(2), 'Easting' );
    axisTicksUTM( hAx(2), 'y' );
    
    xlabel( hMap, 'Easting' );
    ylabel( hMap, 'Northing' );
    axisTicksUTM( hMap, 'xy' );
    legend( hMap, 'Location', 'best' );
    title( hMap, 'Barracuda GPS map' );
    sgtitle( sprintf( 'Barracuda GPS QC Plot - %d Suspect Points', nChkCnt ) );

    addPlotMenu( hFig, fullfile( oWave.sPlotDir, 'Barracuda_QC' ), 'Save' );
    
    return;
end % PlotCudaGPS_QC
