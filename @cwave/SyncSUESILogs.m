function SyncSUESILogs( oWave )
% Sync the already-parsed SUESI logs (mat files) with real time and a variety of
% other data inputs, e.g. ship GPS, atm pressure TARE, winch wire-out, etc...
%
% NB: The calling panel is supposed to disable this process if we don't have
% everything we need. Just *assume* that has been done properly and move on.
%
% Params:
%   oWave   - the cwave object with all the data
%-------------------------------------------------------------------------------
% Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
%-------------------------------------------------------------------------------
    arguments
        oWave cwave
    end

    % Create convenience variables
    tblSDM  = cwave.GetDfltFor( 'tableSDM' );
    tblPing = cwave.GetDfltFor( 'tableBenthos' );
    tblVul  = cwave.GetDfltFor( 'tableVulcan' );
    
    % Vars to hold Valeport time series for making depth profiles
    vpCol   = colstruct( 'Depth', 'Vel', 'Temp', 'Cond' );
    nValeP  = zeros(0,4);
    
    % The output tables are being completely replaced so clear all previous log
    % entries about Sync events
    oWave.ClearLogOfType( cwave.sLog_S_Sync );
    
    % Get data from the ship position time series into a form where it can be
    % easily interpolated. NB that the COG needs to be unwrapped in order for
    % interpolation to work properly
    nShipTS = oWave.tableShipTS{:,{'Latitude', 'Longitude', 'COG', 'Wire_Out', 'Gyro'}};
    nShipTS(:,3) = (180/pi()) * unwrap( (pi()/180) * nShipTS(:,3) );
    nShipTS(:,5) = (180/pi()) * unwrap( (pi()/180) * nShipTS(:,5) );
    
    % For each sync datetime entered by the user, pull that sync section's data
    % and merge it with the various other data
    oProg = uiprogressdlg( oWave.hFig, 'Title', 'Sync SUESI Time and Ship Data' ...
        , 'Message', 'Processing Sync sections...', 'Cancelable', false );
    for iRow = 1:height( oWave.tableSUESISync )
        % If no sync time given, this sync event is being skipped
        if isnat( oWave.tableSUESISync.SyncTime(iRow) )
            continue;
        end
        
        %% Extract just the data for this sync
        sFile = fullfile( oWave.tableSUESISync.Path(iRow), oWave.tableSUESISync.File(iRow) );
        if ~isfile( sFile )
            oWave.AddLog( cwave.LogError, cwave.sLog_S_Sync, ['File does not exist: ' sFile] );
            continue;
        end
        m           = matfile( sFile );
        nFromTo     = m.nSyncRange(oWave.tableSUESISync.SyncNo(iRow),:);
        nData       = m.nData(nFromTo(1):nFromTo(2),:);
        c           = m.col;
        tblBenthos  = m.tblBenthos;
        tblVulcan   = m.tblVulcan;
        clear m nFromTo;    % close the matfile object
        
        %% Pull together the SUESI data
        % Ensure the data has no NaN S= (shd already have been done)
        nData(isnan(nData(:,c.SuesiSec)),:) = [];
        
        % Calculate datetime from S= and pull over data
        secAdj  = seconds( nData(:,c.SuesiSec) - oWave.tableSUESISync.S_Sync(iRow) );
        dtSUESI = oWave.tableSUESISync.SyncTime(iRow) + secAdj;
        
        tblAdd  = cwave.GetDfltFor( 'tableSDM', size(nData,1) ); % preallocate
        tblAdd.Time(:)      = dtSUESI;
        tblAdd.SDM(:)       = nData(:,c.Amp1);  % keep in Amps for now. Cvt to SDM below
        tblAdd.Altitude(:)  = nData(:,c.Alt);
        tblAdd.COG(:)       = mod( nData(:,c.Heading) + oWave.nFixSuesiCOG, 360 );
        tblAdd.Dip(:)       = nData(:,c.Tilt2); % dip is tilt2 not tilt1
        
        % Interpolate ship position & winch wire-out from the ship data
        nShip = interp1( oWave.tableShipTS.Time, nShipTS, dtSUESI, 'linear', 'extrap' );
        tblAdd.Ship_Lat(:)      = nShip(:,1);
        tblAdd.Ship_Lon(:)      = nShip(:,2);
        tblAdd.Ship_COG(:)      = mod( nShip(:,3), 360 );
        tblAdd.Wire_Out(:)      = nShip(:,4);
        tblAdd.Ship_Gyro(:)     = mod( nShip(:,5), 360 );
        [tblAdd.Ship_East(:) ...
        , tblAdd.Ship_North(:)] = oWave.LonLat2UTM( cwave.sLog_S_Sync ...
                                    , tblAdd.Ship_Lon, tblAdd.Ship_Lat );
        
        % Use the timeseries of avg atm pressure to convert the valeport's
        % pressure into depth. 
        %
        % NB: Atm pressure from the ship data is in millibars but valeport
        % pressure is in decibars.
        %
        if height( oWave.tableAtmPres ) > 1
            nPressure = nData(:,c.ValePres) ...
                - interp1( oWave.tableAtmPres.Date, oWave.tableAtmPres.Mean / 100 ...
                         , dtSUESI, 'linear', 'extrap' );
        else
            nPressure = nData(:,c.ValePres) - oWave.tableAtmPres.Mean(1) / 100;
        end
        tblAdd.Depth(:) = cvtValeportPressureToDepth( nPressure, tblAdd.Ship_Lat );
        
        % Accrue valeport data
        nFromTo = (1:numel(dtSUESI)) + size(nValeP,1);
        nValeP(nFromTo,vpCol.Depth) = tblAdd.Depth;
        nValeP(nFromTo,vpCol.Vel)   = nData(:,c.ValeSpeed);
        nValeP(nFromTo,vpCol.Temp)  = nData(:,c.ValeTemp);
        nValeP(nFromTo,vpCol.Cond)  = nData(:,c.ValeCond);
        
        % Trim data by the minimum output current & maximum altitude UI entries
        %
        % NB: don't trim the SDM time series based on current or altitude. This
        % is unnecessary since I have tableTow which is keeping track of when
        % each actual tow line begins & ends. Keep as much of the SUESI info as
        % possible so that the iLBL navigation can be as accurate as possible.
        nCntB4Trim  = height(tblAdd);
        bDel        = isnan( tblAdd.SDM ) | isnan( tblAdd.Depth );
        nCntNaN     = sum(bDel);
        if any( bDel )
            tblAdd(bDel,:) = [];
            
            % Log that we removed stuff
            oWave.AddLog( cwave.LogWarn, cwave.sLog_S_Sync ...
                , sprintf( 'Sync(%d): Removed %d of %d rows for NaN in SDM or Depth' ...
                         , iRow, nCntNaN, nCntB4Trim ) );
        end
        
        % Deal with duplicate time entries. This can happen when an S= is
        % missing or corrupted and the rest of the status block comes through
        % (e.g. SNAPs used to cause this).
        %
        % NB: cwave::ParseSUESILogs ensures that S= does not move BACKWARDS in a
        % single syncd-to-GPS range of data.
        nSecDiff = seconds( diff( tblAdd.Time ) );
        if any( nSecDiff == 0 )
            assert( strcmpi( tblAdd.Properties.VariableNames{1}, 'Time' ) ...
                , 'First column of tableSDM is assumed by this code to be "Time". It isn''t.' );
            
            % Walk through them BACKWARDS and move the duplicate data up to the
            % previous line, then remove the duplicate.
            iAt = find( nSecDiff == 0 ) + 1;    % +1 to focus on the 2nd of the pair
            for iDup = fliplr( reshape( iAt, 1, [] ) )
                for iCol = 2:width(tblAdd)
                    if isnan( tblAdd{iDup-1,iCol} )
                        % Replace a NaN
                        tblAdd(iDup-1,iCol) = tblAdd(iDup,iCol);
                    elseif ~isnan( tblAdd{iDup,iCol} )
                        % Avg two non-NaNs
                        tblAdd{iDup-1,iCol} = mean( tblAdd{iDup-1:iDup,iCol} );
                    end
                end
                tblAdd(iDup,:) = [];
            end
            oWave.AddLog( cwave.LogWarn, cwave.sLog_S_Sync ...
                , sprintf( 'Sync(%d): Merged %d rows with duplicate times', iRow, numel(iAt) ) );
        end
        
        % Calculate the SDM from the dipole length, etc...
        tblAdd.SDM = tblAdd.SDM * oWave.nTxDipLen;
        
        % Accrue for this sync and move on
        tblSDM  = [tblSDM; tblAdd];
        
        %% Create the benthos time series
        %
        % NB: 'tableBenthos.Time' here is somewhat ambiguous. SUESI reports what
        % it knows approx every 3 seconds. That 3 second window might contain
        % both the ping and some of the reply events. It might only contain the
        % ping and the reply(ies) might occur in the next S= window, or across
        % several following S= windows depending on the distance.
        %   SO - the actual ping time is unknown up to the ambiguity of the S=
        % reporting interval, which is kinda 3 seconds but may be up to 10s. At
        % a 4 knot towing speed, the ship moves 2 m/s so this introduces
        % uncertainty into the SUESI position solutions.
        %
        % NB: ReplyCh often indicates which barracuda better than frequency
        % because the frequency can be changed during the cruise. 
        % 
        % NB: The general procedure is --EITHER-- SUESI pings on 1 freq. Both
        % barracudas listen to that one freq and respond on their own freq.
        % --OR-- SUESI pings each barracuda on a different frequency and they
        % each respond on a common freq. Both have been used (sheesh). The first
        % is more common.
        %
        % NB: Further complication. The CTET (the only tail-end-transponder with
        % a pinger) can be configured to listen on it's own unique frequency but
        % respond on the frequency which SUESI uses to ping both barracudas.
        % They hear the CTET's "reply" and reply to it. So the process is: SUESI
        % pings CTET. CTET replies. Barracudas think SUESI has pinged and also
        % reply.
        %
        
        % Trim the benthos table down using FileLine. Cannot use SuesiSec
        % because it gets reset at every sync
        tblBenthos(~between( min(nData(:,c.FileLine)) ...
            , tblBenthos.FileLine ...
            , max(nData(:,c.FileLine)) ),:) = [];
        
        % Add to the main table
        %
        % NB: ensure PingNo is unique across all sync segments
        nPingAdd = max( [1 max(tblPing.PingNo)] ) + 1;
        iFromTo = height(tblPing) + (1:height(tblBenthos));
        tblPing{iFromTo,:}          = missing(); % allocate memory one time
        tblPing.PingNo(iFromTo)     = tblBenthos.PingNo + nPingAdd;
        tblPing.PingFreq(iFromTo)   = tblBenthos.PingFreq;
        tblPing.ReplyFreq(iFromTo)  = tblBenthos.ReplyFreq;
        tblPing.ReplyCh(iFromTo)    = tblBenthos.ReplyCh;
        tblPing.ReplyTWTT(iFromTo)  = tblBenthos.ReplyTWTT;
        
        % Calculate the time for the benthos entries
        secAdj    = seconds( tblBenthos.SuesiSec - oWave.tableSUESISync.S_Sync(iRow) );
        tblPing.Time(iFromTo)       = oWave.tableSUESISync.SyncTime(iRow) + secAdj;
        
        %% Create the vulcan (towed device) time series
        % Only pull in vulcan entries that are within the sync time
        tblVulcan(~btwn(min(dtSUESI),tblVulcan.Time,max(dtSUESI)),:) = [];
        
        % Convert pressure to depth
        %
        % NB: Parosci instruments are configured, for some bizarre reason, to
        % return pressure in PSI. The conversion code expects decibars.
        %
        % NB: ship's atm pressure is in millibars
        tblVulcan.Pressure = tblVulcan.Pressure / 14.5038 * 10;
        if height( oWave.tableAtmPres ) > 1
            nPressure = tblVulcan.Pressure ...
                - interp1( oWave.tableAtmPres.Date, oWave.tableAtmPres.Mean / 100 ...
                         , tblVulcan.Time, 'linear', 'extrap' );
        else
            nPressure = tblVulcan.Pressure - oWave.tableAtmPres.Mean(1) / 100;
        end
        nShipLat = interp1( oWave.tableShipTS.Time, oWave.tableShipTS.Latitude ...
            , tblVulcan.Time, 'linear', 'extrap' );
        nVDepth = cvtValeportPressureToDepth( nPressure, nShipLat );
        
        % Add to the main table
        iFromTo = height(tblVul) + (1:height(tblVulcan));
        tblVul{iFromTo,:}           = missing();    % allocate memory one time
        tblVul.Time(iFromTo)        = tblVulcan.Time;
        tblVul.DeviceNo(iFromTo)    = tblVulcan.DeviceNo;
        tblVul.Heading(iFromTo)     = tblVulcan.Heading;
        tblVul.Pitch(iFromTo)       = tblVulcan.Pitch;
        tblVul.Roll(iFromTo)        = tblVulcan.Roll;
        tblVul.Depth(iFromTo)       = nVDepth;
        
        %% Show progress
        oProg.Value = iRow / height( oWave.tableSUESISync );
        
    end % loop through the time sync table
    delete( oProg );
    
    % For each ping, eliminate multiples. Do this by only keeping the lowest
    % TWTT for each reply frequency.
    tblPing = sortrows( tblPing, {'PingNo', 'ReplyFreq', 'ReplyTWTT'} );
    bMult   = false(height(tblPing),1);
    nSeen   = tblPing.ReplyFreq(1);
    for i = 2:height(tblPing)
        if tblPing.PingNo(i) == tblPing.PingNo(i-1)
            if ismember( tblPing.ReplyFreq(i), nSeen )
                bMult(i) = true;
            else
                nSeen(end+1) = tblPing.ReplyFreq(i);
            end
        else
            nSeen = tblPing.ReplyFreq(i);
        end
    end
    oWave.AddLog( cwave.LogOK, cwave.sLog_S_Sync ...
        , sprintf( 'Deleted %d of %d Benthos-to-Barracuda TWTT entries as multiples' ...
        , sum(bMult), height(tblPing) ) );
    tblPing(bMult,:) = [];
    
    % Make sure the various tables are sorted by time
    tblSDM  = sortrows( tblSDM, 'Time' );
    tblPing = sortrows( tblPing, 'Time' );
    tblVul  = sortrows( tblVul, 'Time' );
    
    % Log what happened & update the appropriate tables in the datastore
    oWave.AddLog( cwave.LogOK, cwave.sLog_S_Sync ...
        , sprintf( 'Created SDM time series with %d entries.', height(tblSDM) ) );
    oWave.tableSDM = tblSDM;
    
    oWave.AddLog( cwave.LogOK, cwave.sLog_S_Sync ...
        , sprintf( 'Accrued %d Benthos-to-Barracuda TWTT entries.', height(tblPing) ) );
    oWave.tableBenthos = tblPing;
    
    oWave.AddLog( cwave.LogOK, cwave.sLog_S_Sync ...
        , sprintf( 'Accrued %d Vulcan/TET heading entries.', height(tblVul) ) );
    oWave.tableVulcan = tblVul;
    
    %% Valeport depth profile handling
    % Create the Valeport-derived aggregate depth profiles - both median and
    % min/max values
    nMaxDepth   = ceil( max( tblSDM.Depth + tblSDM.Altitude ) );
    nDepths     = reshape( str2num( oWave.sZBins ), [], 1 );
    iDrop       = find( nDepths > nMaxDepth, 1, 'first' );
    if ~isempty( iDrop )
        nDepths(iDrop+1:end) = [];  % keep the first depth below the lowest SUESI saw
    end
    nEdges      = [0; nDepths(1:end-1,1) + diff(nDepths)];
    nEdges(end) = 100000;
    nSize       = [numel(nDepths) 1];
    
    % Get rid of non-sensical values. In some cruises (e.g. EMAGE), SUESI was
    % having a problem swapping digits (e.g. 4 --> 6, 1 --> 9) on various
    % entries including measurements
    nLimitVVel  = str2num( oWave.sLimitVVel );
    nLimitVTemp = str2num( oWave.sLimitVTemp );
    nLimitVCond = str2num( oWave.sLimitVCond );
    bChg = ~between( nLimitVVel, nValeP(:,vpCol.Vel) );
    if any(bChg)
        oWave.AddLog( cwave.LogWarn, cwave.sLog_S_Sync ...
            , sprintf( 'Ignored %d of %d valeport velocity values outside %d-%d m/s' ...
            , sum(bChg), numel(bChg), nLimitVVel ) );
        nValeP(bChg,vpCol.Vel) = NaN;
    end
    bChg = ~between( nLimitVTemp, nValeP(:,vpCol.Temp) );
    if any(bChg)
        oWave.AddLog( cwave.LogWarn, cwave.sLog_S_Sync ...
            , sprintf( 'Ignored %d of %d valeport temperature values outside %d-%d C' ...
            , sum(bChg), numel(bChg), nLimitVTemp ) );
        nValeP(bChg,vpCol.Temp) = NaN;
    end
    bChg = ~between( nLimitVCond, nValeP(:,vpCol.Cond) );
    if any(bChg)
        oWave.AddLog( cwave.LogWarn, cwave.sLog_S_Sync ...
            , sprintf( 'Ignored %d of %d valeport conductivity values outside %d-%d' ...
            , sum(bChg), numel(bChg), nLimitVCond ) );
        nValeP(bChg,vpCol.Cond) = NaN;
    end
    
    % Discretize by Valeport depth bin edges then eliminate any data which are
    % outside the discretization. These are almost always values *above*
    % sea-level when SUESI is sitting on the deck or right at the surface.
    iGrp = discretize( nValeP(:,vpCol.Depth), nEdges, 'IncludedEdge', 'left' );
    bNaN = isnan(iGrp);
    if any( bNaN )
        nValeP(bNaN,:)  = [];
        iGrp(bNaN)      = [];
    end
    
    tblVP               = cwave.GetDfltFor( 'tableValeport', nSize(1) );
    tblVP.Depth         = nDepths;
    tblVP.Velocity      = accumarray( iGrp, nValeP(:,vpCol.Vel),  nSize, @nanmedian, NaN );
    tblVP.Temp          = accumarray( iGrp, nValeP(:,vpCol.Temp), nSize, @nanmedian, NaN );
    tblVP.Conductivity  = accumarray( iGrp, nValeP(:,vpCol.Cond), nSize, @nanmedian, NaN );
    
    tblVP.Vmin  = accumarray( iGrp, nValeP(:,vpCol.Vel),  nSize, @min, NaN );
    tblVP.Tmin  = accumarray( iGrp, nValeP(:,vpCol.Temp), nSize, @min, NaN );
    tblVP.Cmin  = accumarray( iGrp, nValeP(:,vpCol.Cond), nSize, @min, NaN );
    
    tblVP.Vmax  = accumarray( iGrp, nValeP(:,vpCol.Vel),  nSize, @max, NaN );
    tblVP.Tmax  = accumarray( iGrp, nValeP(:,vpCol.Temp), nSize, @max, NaN );
    tblVP.Cmax  = accumarray( iGrp, nValeP(:,vpCol.Cond), nSize, @max, NaN );
    
    % Fill in the bottom of the depth profiles where there is no data but where
    % we know SUESI saw water depths.
    iLast = find( all(~isnan(tblVP{:,{'Velocity','Temp','Conductivity'}}),2), 1, 'last' );
    if ~isempty( iLast )
        tblVP.Velocity(iLast+1:end)     = tblVP.Velocity(iLast);
        tblVP.Temp(iLast+1:end)         = tblVP.Temp(iLast);
        tblVP.Conductivity(iLast+1:end) = tblVP.Conductivity(iLast);
    end
    
    % Fill in any depths which have NaNs in individual components
    assert( strcmpi( tblVP.Properties.VariableNames{1}, 'Depth' ) ...
        , 'First column of tableValeport is assumed by this code to be "Depth". It isn''t.' );
    nFixedZ = 0;
    for iCol = 2:width(tblVP)
        bNaN = isnan( tblVP{:,iCol} );
        if ~any( bNaN )
            continue;
        end
        nFixedZ = cat( 1, nFixedZ, tblVP.Depth(bNaN) );
        tblVP{bNaN,iCol} = interp1( tblVP.Depth(~bNaN), tblVP{~bNaN,iCol} ...
            , tblVP.Depth(bNaN), 'nearest', 'extrap' );
    end
    if ~isempty( nFixedZ )
        nFixedZ = unique( nFixedZ );
        oWave.AddLog( cwave.LogWarn, cwave.sLog_S_Sync ...
            , [sprintf( 'Depth Profiles: interpolated %d NaN Valeport rows at Z(m): ' ...
                     , numel(nFixedZ) ) num2str( reshape(nFixedZ,1,[]) ) ] );
    end
    
    % Update the main Valeport table & log this
    oWave.AddLog( cwave.LogOK, cwave.sLog_S_Sync ...
        , sprintf( 'Created depth profiles down to %g m', tblVP.Depth(end) ) );
    oWave.tableValeport = tblVP;
    
    % Toss up some plots the user is going to want anyway. Auto-save them to the
    % plots folder along the way
    oWave.PlotValeport();
    
    % Add/update the valeport in the velocity-profiles-over-time table
    iAt = find( strcmpi( oWave.tableVProfile.Name, cwave.sVProfile_Valeport ), 1 );
    if isempty( iAt )
        iAt = height( oWave.tableVProfile ) + 1;
    end
    % NB: Expand the valeport's coverage time both front and back because it is
    % only collected during towing but the navigation of the receivers where
    % this is needed is done outside of towing.
    dFrom   = min( tblSDM.Time ) - days(30);
    dTo     = max( tblSDM.Time ) + days(30);
    oWave.cVProfile{iAt} = tblVP(:,{'Depth','Velocity'});
    oWave.tableVProfile(iAt,:) = {cwave.sVProfile_Valeport, dFrom, dTo};
    
    
    %% Put up some debug plots to look for wonky data
    hFig = getStackedFig( 'pptHD' );
    hCOG = subplot( 3, 1, 1, 'Parent', hFig );
    hWO  = subplot( 3, 1, 2, 'Parent', hFig );
    hSDM = subplot( 3, 1, 3, 'Parent', hFig );
    
    dCOG = phaseDiff( oWave.tableSDM.Ship_COG, oWave.tableSDM.COG, 'Degrees' );
    bOff = (abs(dCOG) > 135);
    nPctOff = sum(bOff) / numel(bOff) * 100;
    plot( hCOG, oWave.tableSDM.Time,        dCOG,       '.b' ...
              , oWave.tableSDM.Time(bOff),  dCOG(bOff), 'or' );
    axisTight( hCOG );
    hCOG.YTick = -180:30:180;
    ylabel( hCOG, 'Degrees' );
    title( hCOG, 'Ship COG minus SUESI COG' );
    subtitle( hCOG, sprintf( '%d data are near 180 degrees', sum(bOff) ), 'color', 'red' );
    if nPctOff > 50
        text( hCOG, mean(hCOG.XLim), mean(hCOG.YLim) ...
            , 'Recommend adjusting the "SUESI COG correction" setting' ...
            , 'Color', 'r', 'HorizontalAlignment', 'center' ...
            );
    elseif all( isnan(oWave.tableSDM.COG) )
        text( hCOG, mean(hCOG.XLim), mean(hCOG.YLim) ...
            , 'SUESI COG (course over ground) data are NaN' ...
            , 'Color', 'r', 'HorizontalAlignment', 'center' ...
            );
    end
    
    bZbad = (oWave.tableSDM.Depth > oWave.tableSDM.Wire_Out);
    plot( hWO, oWave.tableSDM.Time, oWave.tableSDM.Wire_Out, '.' ...
        , 'Color', [0 0.6 0], 'DisplayName', 'Wire-out' );
    hold( hWO, 'on' );
    plot( hWO, oWave.tableSDM.Time, oWave.tableSDM.Depth, '.' ...
        , 'Color', 'b', 'DisplayName', 'SUESI depth' );
    plot( hWO, oWave.tableSDM.Time(bZbad), oWave.tableSDM.Depth(bZbad), 'o' ...
        , 'Color', 'r', 'DisplayName', 'Invalid SUESI depth' );
    hold( hWO, 'off' );
    axisTight( hWO );
    hWO.YDir = 'reverse';
    ylabel( hWO, 'Meters' );
    title( hWO, 'Comparison of Wire-out and SUESI Depth' );
    subtitle( hWO, sprintf( '%d SUESI depths are invalid', sum(bZbad) ), 'color', 'red' );
    legend( hWO, 'location', 'best' );
    
    nMean = mean( oWave.tableSDM.SDM );
    nStd  =  std( oWave.tableSDM.SDM );
    bOut  = (abs(oWave.tableSDM.SDM - nMean) > 2*nStd);
    plot( hSDM, oWave.tableSDM.Time, oWave.tableSDM.SDM, '.b', 'DisplayName', 'SDM' );
    hold( hSDM, 'on' );
    plot( hSDM, oWave.tableSDM.Time(bOut), oWave.tableSDM.SDM(bOut), 'or', 'DisplayName', 'Flagged' );
    hold( hSDM, 'off' );
    axisTight( hSDM );
    axisTicksUTM( hSDM, 'y' );
    ylabel( hSDM, '(A m)' );
    title( hSDM, 'Source Dipole Moment' );
    subtitle( hSDM, sprintf( '%d SUESI SDM > mean \\pm 2 \\sigma', sum(bOut)), 'color', 'red' );
    
    addPlotMenu( hFig, fullfile( oWave.sPlotDir, 'SUESI_SDM_Crosscheck' ), 'save' );
    
    return;
end % SyncSUESILogs
