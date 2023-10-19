function MergeShipData( oWave )
% cwave::MergeShipData( oWave )
%
% Public method of the cwave class. Merge separate file sources for ship's GPS,
% COG, and winch wire-out into the ship time series table.
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
    
    % This process is always a "run all". So first clear the log of all previous
    % entries of this type
    oWave.ClearLogOfType( cwave.sLog_ShipData );
    
    
    %% Parse all the GPS position files
    tmGPS = tic();
    [bOK, tblGPS] = oWave.GetDataFromUserConfigurableTypes( ...
        oWave.cFiles_ShipGPS, ListFmts_GPS(), cwave.sLog_ShipData, 'GPS' );
    if ~bOK
        return;
    end
    tblGPS(isnat(tblGPS.Time),:) = [];
    oWave.AddLog( oWave.LogOK, cwave.sLog_ShipData ...
        , sprintf( 'Processed %d GPS lines from %d files in %d seconds' ...
                 , height(tblGPS), numel(oWave.cFiles_ShipGPS), ceil(toc(tmGPS)) ) );
    
    
    %% Parse Ship Gyrocompass files
    tmGyro = tic();
    [bOK, tblGyro] = oWave.GetDataFromUserConfigurableTypes( ...
        oWave.cFiles_Gyro, ListFmts_Gyro(), cwave.sLog_ShipData, 'gyro' );
    if ~bOK
        return;
    end
    tblGyro(isnat(tblGyro.Time),:) = [];
    oWave.AddLog( oWave.LogOK, cwave.sLog_ShipData ...
        , sprintf( 'Processed %d Gyro lines from %d files in %d seconds' ...
                 , height(tblGyro), numel(oWave.cFiles_Gyro), ceil(toc(tmGyro)) ) );
    
    
    %% Parse Ship Winch files
    tmWinch = tic();
    [bOK, tblWinch] = oWave.GetDataFromUserConfigurableTypes( ...
        oWave.cFiles_Winch, ListFmts_Winch(), cwave.sLog_ShipData, 'winch' );
    if ~bOK
        return;
    end
    tblWinch(isnat(tblWinch.Time),:) = [];
    oWave.AddLog( oWave.LogOK, cwave.sLog_ShipData ...
        , sprintf( 'Processed %d Winch lines from %d files in %d seconds' ...
                 , height(tblWinch), numel(oWave.cFiles_Winch), ceil(toc(tmWinch)) ) );
    
    
    %% Merge GPS, Winch, & Gyro data based on common time
    hWait = uiprogressdlg( oWave.hFig, 'Title', 'Merge Ship Data...' );
    
    % Sort by time & remove duplicates (assume identical lat/lon)
    hWait.Message   = 'Sorting GPS data...';
    [~,iUniq]       = unique( tblGPS.Time );
    tblGPS          = tblGPS(iUniq,:);
    
    % Typical towing speed is 2 knots (1 m/s) which is too slow for the general
    % 1 Hz sampling of GPS to be useful because the ship has hardly moved in
    % that time (so COG calcs will be unstable). Just the roll & pitch of the
    % GPS antenna will introduce error larger than that. So decimate to
    % something larger for stability in ship location estimates.
    if any(seconds( diff( tblGPS.Time ) ) < 30)
        % There may be gaps in the time series that I don't want to just
        % blithely interpolate through. Preserve the gaps (if any)
        tStart = tblGPS.Time(1);
        nSecFr = seconds( tblGPS.Time - tStart );
        nSecTo = unique( round( nSecFr / 30 ) * 30 );
        if height(tblGPS) > numel(nSecTo) % if it's not getting smaller. don't do it
            n = interp1( nSecFr, tblGPS{:,{'Lat','Lon'}}, nSecTo, 'linear', 'extrap' );
            tblGPS(numel(nSecTo)+1:end,:) = [];
            tblGPS.Time = tStart + seconds( nSecTo );
            tblGPS.Lat  = n(:,1);
            tblGPS.Lon  = n(:,2);
        end
    end
    
    hWait.Value     = 1/5;
    
    % Gyro data must be sorted & unique by date for interp1 below
    hWait.Message   = 'Sorting Gyro data...';
    [~,iUniq]       = unique( tblGyro.Time );
    tblGyro         = tblGyro(iUniq,:);
    hWait.Value     = 2/5;
    
    % Winch data must be sorted & unique by date for interp1 below
    hWait.Message   = 'Sorting Winch data...';
    [~,iUniq]       = unique( tblWinch.Time );
    tblWinch        = tblWinch(iUniq,:);
    hWait.Value     = 3/5;
    
    % Assume the ship GPS is a much longer time series than winch & gyro and is
    % also at a much finer time step. Also note that winch & gyro data OUTSIDE
    % the range of times for which we have ship GPS locations are useless
    hWait.Message       = 'Merging GPS, Gyro, & Winch data...';
    tblShip = cwave.GetDfltFor( 'tableShipTS', size(tblGPS,1) ); % preallocate
    tblShip.Time(:)     = tblGPS.Time;
    tblShip.Longitude(:)= tblGPS.Lon;
    tblShip.Latitude(:) = tblGPS.Lat;
    [ tblShip.East(:) ...
    , tblShip.North(:)] = oWave.LonLat2UTM( cwave.sLog_ShipData, tblShip.Longitude, tblShip.Latitude );
    tblShip.Wire_Out(:) = interp1( tblWinch.Time, tblWinch.WireOut, tblGPS.Time, 'linear' );
    tblShip.Gyro(:)     = interp1( tblGyro.Time,  tblGyro.Gyro,     tblGPS.Time, 'linear' );
    hWait.Value         = 4/5;
    
    % Create COG using changes in ship position
    hWait.Message       = 'Calculating COG...';
    tblShip.COG(:)      = MakeCOGfromGPS( tblGPS.Lon, tblGPS.Lat, oWave.sEllipsoid );
    
    delete( hWait );
    
    
    %% Save the final table
    % Stash in the result table all at once so that any listener only fires off
    % one time. Log the results
    oWave.AddLog( oWave.LogOK, cwave.sLog_ShipData ...
        , sprintf( 'Ship Data time series: %d rows; median time step %gs' ...
                 , height(tblShip), seconds( median( diff( tblShip.Time ) ) ) ) );
    oWave.AddLog( oWave.LogOK, cwave.sLog_ShipData ...
        , sprintf( 'Total time %d s', ceil(toc(tmGPS)) ) );
    oWave.tableShipTS = sortrows( tblShip, 'Time' );
    
    
    %% Produce a primitive cross-check plot
    hFig = getStackedFig( 'pptHD' );
    hMap = subplot(3,3,[1 4 7], 'Parent', hFig );
    hWO  = subplot(3,3,[2 3], 'Parent', hFig );
    hCOG = subplot(3,3,[5 6], 'Parent', hFig );
    hGyr = subplot(3,3,[8 9], 'Parent', hFig );
    
    nSpcg = sqrt( diff(oWave.tableShipTS.East).^2 + diff(oWave.tableShipTS.North).^2 );
    bJump = nSpcg >= 1000;
    bJump(end+1) = false;
    plot( hMap, oWave.tableShipTS.East, oWave.tableShipTS.North, '.b' );
    hold( hMap, 'on' );
    plot( hMap, oWave.tableShipTS.East(bJump), oWave.tableShipTS.North(bJump), 'or' );
    hold( hMap, 'off' );
    axis( hMap, 'equal' );
    axisTight( hMap );
    axisTicksUTM( hMap );
    xlabel( hMap, ['Easting ' oWave.sUTMZoneDisp] );
    ylabel( hMap, 'Northing' );
    title( hMap, 'Ship Path' );
    subtitle( hMap, sprintf( 'There are %d jumps of >= 1km', sum(bJump) ), 'color', 'red' );
    
    plot( hWO, oWave.tableShipTS.Time, oWave.tableShipTS.Wire_Out, '.b' );
    axisTight( hWO );
    hWO.YDir = 'reverse';
    title( hWO, 'Wire-out' );
    subtitle( hWO, sprintf( '%d missing values', sum(ismissing(oWave.tableShipTS.Wire_Out)) ), 'color', 'red' );
    
    plot( hCOG, oWave.tableShipTS.Time, oWave.tableShipTS.COG, '.b' );
    axisTight( hCOG );
    hCOG.YTick = -180:30:180;
    title( hCOG, 'COG (course over ground)' );
    subtitle( hCOG, sprintf( '%d missing values', sum(ismissing(oWave.tableShipTS.COG)) ), 'color', 'red' );
    
    plot( hGyr, oWave.tableShipTS.Time, oWave.tableShipTS.Gyro, '.b' );
    axisTight( hGyr );
    hGyr.YTick = -180:30:180;
    title( hGyr, 'Gyroscope (prow pointing direction)' );
    subtitle( hGyr, sprintf( '%d missing values', sum(ismissing(oWave.tableShipTS.Gyro)) ), 'color', 'red' );
    
    addPlotMenu( hFig, fullfile( oWave.sPlotDir, 'MergeShipData_Crosscheck' ), 'save' );
    
    return;
end % MergeShipData
