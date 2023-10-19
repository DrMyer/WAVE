function RxNav( oWave )
% cwave::RxNav( oWave )
%
% Navigate seafloor receivers using Benthos data
%
% Note:
%   In recent years people have taken to doing something really really stupid
%   and having all sites on the same ping frequency. So when you ping one, you
%   get a plethora of replies. Often those replies are during rise or fall and
%   there's no way to tell when that is true. As a consequence, I've
%   restructured this code from my old NavReceivers.m so that it only takes the
%   first reply in a set of pings and so that it assumes the earliest ping is
%   from the closest RX in horizontal distance. This should work OK so long as
%   the seafloor is not too rugose. It has the side-effect of throwing away a
%   bunch of pings which might otherwise be good data. And if you circle around
%   receivers at a distance > the half distance between sites, you are totally
%   screwed because all the pings will be assigned to the wrong sites.
%       The solution is, naturally, to spend just a little time PLANNING your RX 
%   layout with unique frequencies and then pinging them specifically. It's not
%   hard, people.
%
% Parameters:
%   oWave - the controlling cwave instance
% Returns:
%   nothing     (Clearly it abides by the pirate code of conduct.)
%
%-------------------------------------------------------------------------------
% Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
%-------------------------------------------------------------------------------
    arguments
        oWave cwave
    end
    
    %% PREPARE the data --------------------------------------------------------
    
    % Clear previous log entries (this is always a "Run everything" procedure)
    oWave.ClearLogOfType( cwave.sLog_RxNavAction );
    sDump = fullfile( oWave.sLogDir, 'BenthosRxNav_Log.txt' );
    if isfile( sDump )
        delete( sDump );
    end
    fidOut      = fopen( sDump, 'w' );
    oCloseDump  = onCleanup( @()fclose(fidOut) );   % ensures file always gets closed even on crash
    fprintf( fidOut, 'Benthos RX Nav\n  Started: %s\n  User ID: %s\n' ...
        , datestr( datetime('now') ), dm_User() );
    fprintf( fidOut, '-----------------------------------------------------------\n' );
    
    % Get all the data
    [bError, tblPing] = sub_AggregateData( oWave, fidOut );
    if bError
        return;
    end
    
    % Pre-allocate the result table
    % NB: using var(:) = ... preserves default value property of var for use
    % with missing() later
    nCntRx = height( oWave.tableRxDrop );
    [nDropE, nDropN]        = oWave.LonLat2UTM( cwave.sLog_RxNavAction ...
                            , oWave.tableRxDrop.Longitude, oWave.tableRxDrop.Latitude );
    tblNav                  = cwave.GetDfltFor( 'tableRxNav', nCntRx );
    tblNav.RxName(:)        = oWave.tableRxDrop.RxName;
    tblNav.DucerFreq(:)     = oWave.tableRxDrop.DucerFreq;
    tblNav.Drop_Lon(:)      = oWave.tableRxDrop.Longitude;
    tblNav.Drop_Lat(:)      = oWave.tableRxDrop.Latitude;
    tblNav.Drop_East(:)     = nDropE;
    tblNav.Drop_North(:)    = nDropN;
    tblNav.Drop_Depth(:)    = oWave.tableRxDrop.Depth;
    tblNav.East(:)          = nDropE;     % Set drop locations as starting locations
    tblNav.North(:)         = nDropN;
    tblNav.Depth(:)         = oWave.tableRxDrop.Depth;
    sZone                   = oWave.sUTMZoneDisp;
    
    % Pre-calculate ray-path tables for each unique combination of ducer depth &
    % velocity profile time range (for many cases, there will only be one...)
    [nVPandZ,~,iRayPathNo] = unique( tblPing{:,{'iVProfile','nDucerZ'}}, 'rows' );
    tblPing = addvars( tblPing, iRayPathNo );
    oProg   = uiprogressdlg( oWave.hFig, 'Title', 'Calculating Ray Path Tables' ...
                            , 'Message', 'Table 1 of ?', 'Indeterminate', 'on' );
    cRP     = {};
    for iRP = 1:size(nVPandZ,1)
        oProg.Message   = sprintf( 'Ray path table %d of %d', iRP, size(nVPandZ,1) );
        tblVP           = oWave.cVProfile{nVPandZ(iRP,1)};
        [~,cRP{iRP}]    = FindRayPath( 0, 0, nVPandZ(iRP,2) ... transducer position
                                     , 0, 0, 6000 ... RX position - Z will be limited to max velocity profile depth
                                     , table2array( tblVP ) );
    end
    if numel(cRP) == 1
        fprintf( fidOut, '  1 ray path table calculated\n' );
    else
        fprintf( fidOut, '  %d ray path tables calculated\n', numel(cRP) );
    end
    
    
    %% Iteratively triangulate each receiver's location ------------------------
    %-------
    % tblPing contains columns:
    %   Time,Lon,Lat,E,N,nDucerZ,PingFreq,ReplyFreq,TWTT
    %   ,iRayPathNo (index into cRP{} raypath structure cell array)
    %   ,LineNo,iDucer,iVProfile (these are already used above; ignore)
    %-------
    iSite       = NaN( height(tblPing), 1 );  % index into site list - which does this ping belong to?
    TWTTmodel   = NaN( height(tblPing), 1 );
    tblPing     = addvars( tblPing, iSite, TWTTmodel );
    clear TWTTmodel
    
    % Settings that affect how the iterative process runs
    nTWTTErrFloor   = 0.01;     % 0.01s = 7.5m, consider ship riding in swell & GPS errors...
    nTWTTErrPct     = 0.01;     % Error percent
    nTimeTolList    = [0.5 0.1 0.05 0.02 0.02];
        % NOTE from original NavReceivers.m:
        %------------------------------------
        % Tolerance in sec for deciding if a point belongs to a receiver.
        % Will be stepped down for the 2nd & following iterations.  Should be
        % fairly inclusive for the first iteration.
        %   NOTE that the "double" hyperbolae that we've observed (where
        % some points are slightly longer than others and appear shifted off
        % the hyperbola) can be eliminated by this process. I've observed
        % the differences to be 0.022ish.  So having the last tolerance set
        % to something smaller helps a lot.
        %------------------------------------
    % Setup the options for the Levenburg-Marquardt solver %
    %------------------------------------------------------%
    stFit.DiffMaxChange = [500 500 50]; % Max change in each param (E,N,Down)
    stFit.bRobust       = true;
    % Step size in each direction (for my embedded Jacobian function)
    stFit.dEasting      = 1;
    stFit.dNorthing     = 1;
    stFit.dDepth        = 1;
    
    % Refinement loop - assigning pings to each site, fitting a location, then
    % iteratively discarding points too many std's away from the solution
    fprintf( fidOut, 'STARTING iterative solver for RX navigation\n' );
    dtStart     = datetime('now');
    bSolnFound  = false( nCntRx, 1 );
    for iStep = 1:numel(nTimeTolList)
        nTimeTol    = nTimeTolList(iStep);
        oProg.Title = sprintf( 'Refinement Step %d of %d: TWTT tolerance = %g s' ...
                             , iStep, numel(nTimeTolList), nTimeTol );
        fprintf( fidOut, '-----------------------------------------------------------\n' );
        fprintf( fidOut, '%s\n', oProg.Title );
        fprintf( fidOut, '-----------------------------------------------------------\n' );
        
        % Match each ping with an individual site
        oProg.Message = 'Assigning pings to sites...';
        fprintf( fidOut, '%s\n', oProg.Message );
        iSite         = sub_AssignPingsToSites( oWave, nTimeTol, tblPing, cRP, tblNav, fidOut );
        fprintf( fidOut, '   %g of %g pings assigned to sites\n' ...
            , sum(~isnan(iSite)), numel(iSite) );
        
        % If no changes have been made since the last refinement step, then
        % we're done.
        bChgd = (iSite ~= tblPing.iSite & ~isnan( iSite ));
        nChgd = sum( bChgd );
        if nChgd == 0
            fprintf( fidOut, '   No pings changed sites. Done.\n' );
            break;
        end
        if iStep > 1
            fprintf( fidOut, '   %g pings changed to new sites\n', nChgd );
        end
        
        % Only do the sites whose ping list has changed. Leave the others as
        % they are. No need to re-do the same Marquardt
        if iStep == 1
            iRxRunList = 1:nCntRx;
        else
            iRxRunList = [];
            for iRx = 1:nCntRx
                if ~isequal( iSite == iRx, tblPing.iSite == iRx )
                    iRxRunList(1,end+1) = iRx;
                end
            end
        end
        
        % Save the pings-per-site list for the next iteration
        tblPing.iSite(:) = iSite;
        
        % Run the Marquardt inversion for each site's set of pings
        oProg.Indeterminate = 'off';
        oProg.Value         = 0;
        for iRx = iRxRunList
            % Report progress
            oProg.Message = sprintf( 'Running Marquardt for site %d of %d (%s)...' ...
                , iRx, nCntRx, tblNav.RxName(iRx) );
            oProg.Value = iRx / nCntRx;
            
            % Find all the pings for this site. If too few, skip
            iPing               = (tblPing.iSite == iRx);
            nCntPing            = sum( iPing );
            tblNav.PingCnt(iRx) = nCntPing;
            if nCntPing < 3
                fprintf( fidOut, '-----\nSite %s skipped. Too few pings (%d)\n-----\n' ...
                       , tblNav.RxName(iRx), nCntPing );
                continue;
            end
            fprintf( fidOut, '-----\nSite %s (%d of %d) has %d pings\n-----\n' ...
                   , tblNav.RxName(iRx), iRx, nCntRx, nCntPing );
            
            % Set TWTT error as a percentage subject to an error floor
            nTWTT    = tblPing.TWTT(iPing);
            nTWTTErr = max( nTWTT * nTWTTErrPct, nTWTTErrFloor );
            
            % Run the solver
            [nEND, nChi2, nStd, nCov] = fLevenMarq( @emb_NavSolver ...
                , tblNav{iRx,{'East','North','Depth'}} ...
                , stFit, nTWTT, nTWTTErr, fidOut );
            
            % Did the solver succeed?
            bSolnFound(iRx) = ~isempty( nEND );
            if ~bSolnFound(iRx)
                tblPing.TWTTmodel(iPing) = NaN;
                continue;
            end
            
            % Keep the model data for this solution
            tblPing.TWTTmodel(iPing) = emb_NavSolver( nEND );
            
            % Distribute the results
            tblNav.RMS(iRx) = sqrt( nChi2 / (nCntPing - 3) );
            tblNav{iRx,{'East','North','Depth'}}            = nEND.';
            tblNav{iRx,{'East_Std','North_Std','Depth_Std'}}= nStd.';
            tblNav{iRx,{'XY_Phi', 'XY_Major', 'XY_Minor'}}  = Cov2Ell( nCov, 'XY' );
            tblNav{iRx,{'XZ_Phi', 'XZ_Major', 'XZ_Minor'}}  = Cov2Ell( nCov, 'XZ' );
            tblNav{iRx,{'YZ_Phi', 'YZ_Major', 'YZ_Minor'}}  = Cov2Ell( nCov, 'YZ' );
            
        end % loop through sites
        oProg.Indeterminate = 'on';
        
    end % master loop over refinement steps
    
    %% Finish up ---------------------------------------------------------------
    delete( oProg );
    
    % If everything is OK, log & save the result table
    nCntOK = sum( bSolnFound );
    fprintf( fidOut, 'Time Required: %s\n', string(between( dtStart, datetime('now') )) );
    fprintf( fidOut, 'Solutions found for %d of %d receivers\n', nCntOK, numel(bSolnFound) );
    if nCntOK == 0
        oWave.AddLog( cwave.LogError, cwave.sLog_RxNavAction ...
            , 'Failed to navigate ANY sites in the drop list' );
        return;
        % NB: an error will automatically bring up the event log on end
    elseif nCntOK == nCntRx
        sEndMsg = sprintf( 'Successfully navigated all %d sites in the drop list.' ...
                      , nCntRx );
        oWave.AddLog( cwave.LogOK, cwave.sLog_RxNavAction, sEndMsg );
    else
        sEndMsg = sprintf( 'Navigated only %d of %d sites in the drop list.' ...
                      , nCntOK, nCntRx );
        oWave.AddLog( cwave.LogWarn, cwave.sLog_RxNavAction, sEndMsg );
        
        % Clear the nav for those sites whose solution is not found
        tblNav{~bSolnFound,{'Latitude','Longitude','East','North','Depth' ...
                            ,'East_Std','North_Std','Depth_Std'}} ...
            = missing();
    end
    
    % Convert UTM back to lon,lat
    [tblNav.Longitude(:),tblNav.Latitude(:)] = oWave.UTM2LonLat( tblNav.East, tblNav.North );
    
    % Round to the nearest meter. Accuracy better than that is irrelevant to us.
    % NB: 1 degree Lon,Lat is very approximately 100 km so the 5th decimal is
    % very approximately 1 meter. I learned that from Hubert Staudigel many
    % moons ago.
    tblNav.East         = round( tblNav.East );
    tblNav.North        = round( tblNav.North );
    tblNav.Depth        = round( tblNav.Depth );
    tblNav.Longitude    = round( tblNav.Longitude, 5 );
    tblNav.Latitude     = round( tblNav.Latitude, 5 );
    
    % Save the table & fire off any listeners
    oWave.tableRxNav = tblNav;
    
    % Save a simplified output file with RxName, x,y,z in UTM & lon,lat. Have
    % the Zone_XX(N/S) in the file title so the user can easily find the UTM
    % zone that the sites are in.
    sFile  = fullfile( oWave.sDir_Main, ['RxNav_' strrep(sZone,' ','_') '.txt'] );
    tblOut = tblNav(:,{'RxName','East','North','Depth','Longitude','Latitude'});
    writetable( tblOut, sFile ...
        , 'FileType', 'text', 'WriteVariableNames', true ...
        , 'WriteMode', 'overwrite', 'Delimiter', ',', 'QuoteStrings', true );
    
    % Create a Google Earth KML file
    makeGoogleEarthKML( strrep( sFile, '.txt', '.kml' ) ...
        , tblOut.Longitude, tblOut.Latitude, tblOut.RxName ...
        , false, ['RX Site Nav - ' oWave.sPlotSubtitle] );
    
    % Plot drop locations & all pings, color coded by frequency
    sub_PlotPingMap();
    
    % Plot the site-drift & maps
    oWave.PlotRxNavDriftMap();
    oWave.PlotRxNavMaps();
    
    % Plot summary of fits
    sub_PlotRxNavSummary( oWave, tblNav );
    
    % Plot the panoply of TWTT fits & error ellipse stuff
    sub_PlotRxNavTWTTFits( oWave, tblNav, tblPing );
    
    % Show the final message
    uialert( oWave.hFig, sEndMsg, 'RX Benthos Nav', 'Icon', 'info' );
    
    return;
    
    %---------------------------------------------------------------------------
    % Embedded function with access to the caller's variables
    function [nTWTT, nJac] = emb_NavSolver( nEND )
        % Which ray path table should we use?
        %
        % NB: that because nav may be partially done on deployment & recovery
        % AND because that may occur on multiple ships, the ray path tables may
        % be based on multiple sets of sound velocities. This is a pain in the
        % ass. But since it's very much an edge case, just ignore it for now.
        % The assert below will blow up if it is ever encountered. I'll code up
        % that complicated case at that point
        iRayPath = unique( tblPing.iRayPathNo(iPing) );
        assert( numel(iRayPath) == 1, 'If this blows up, contact Dave Myer (davidgmyer@gmail.com)' );
        stRayPath = cRP{iRayPath};
        
        % Calculate the TWTT for the current pings. 
        nTWTT = FindRayPath( ...
            tblPing.E(iPing), tblPing.N(iPing), tblPing.nDucerZ(iPing) ...
            , nEND(1), nEND(2), nEND(3) ...
            , [], stRayPath );
        
        % If no Jacobian requested, then we're done
        if nargout() < 2
            return;
        end
        
        % Calculate the Jacobian using plain ole centered difference
        nJac   = zeros( numel(nTWTT), 3 );
        nPingE = tblPing.E(iPing);          % purely convenience variables so
        nPingN = tblPing.N(iPing);          % MatLab doesn't have to keep extracting
        nPingD = tblPing.nDucerZ(iPing);    % ranges every time
        
        nJac(:,1) = ...
          ( FindRayPath( nPingE, nPingN, nPingD ...
                       , nEND(1) + stFit.dEasting, nEND(2), nEND(3) ...
                       , [], stRayPath ) ...
          - FindRayPath( nPingE, nPingN, nPingD ...
                       , nEND(1) - stFit.dEasting, nEND(2), nEND(3) ...
                       , [], stRayPath ) ...
          ) / (2 * stFit.dEasting);
        
        nJac(:,2) = ...
          ( FindRayPath( nPingE, nPingN, nPingD ...
                       , nEND(1), nEND(2) + stFit.dNorthing, nEND(3) ...
                       , [], stRayPath ) ...
          - FindRayPath( nPingE, nPingN, nPingD ...
                       , nEND(1), nEND(2) - stFit.dNorthing, nEND(3) ...
                       , [], stRayPath ) ...
          ) / (2 * stFit.dNorthing);
        
        nJac(:,3) = ...
          ( FindRayPath( nPingE, nPingN, nPingD ...
                       , nEND(1), nEND(2), nEND(3) + stFit.dDepth ...
                       , [], stRayPath ) ...
          - FindRayPath( nPingE, nPingN, nPingD ...
                       , nEND(1), nEND(2), nEND(3) - stFit.dDepth ...
                       , [], stRayPath ) ...
          ) / (2 * stFit.dDepth);
        
        return;
    end % emb_NavSolver
    
    %---------------------------------------------------------------------------
    % Show a map of where all the pings are and color code by frequency
    function hPMap = sub_PlotPingMap()
        hPMap   = getStackedFig( 'pptHD' );
        hAx     = axes( hPMap );
        nFList  = unique( tblPing.PingFreq );
        if numel(nFList) < 2
            % User ran all RXs at ONE frequency. Not recommended but
            % unfortunately becoming more and more common. Laziness?
            iSiteList = tblPing.iSite;
            iSiteList(isnan(iSiteList)) = 0;
            nClrs     = [0 0 0;turbo(height(oWave.tableRxDrop))];
            for iPlot = 0:height(oWave.tableRxDrop)
                % Plot the pings for this site
                iPlotPing = (iSiteList == iPlot);
                hPing = plot( hAx, tblPing.E(iPlotPing) / 1000, tblPing.N(iPlotPing) / 1000 ...
                    , 'Color', nClrs(iPlot+1,:), 'Marker', '.', 'MarkerSize', 3 ...
                    , 'LineStyle', 'none' );
                legendoff( hPing );
                hold( hAx, 'on' );
                
                % Plot the site drop location
                if iPlot > 0
                    plot( hAx, nDropE(iPlot) / 1000, nDropN(iPlot) / 1000 ...
                        , 'MarkerFaceColor', nClrs(iPlot+1,:), 'MarkerEdgeColor', 'k' ...
                        , 'Marker', 'o', 'LineStyle', 'none' ...
                        , 'DisplayName', oWave.tableRxDrop.RxName(iPlot) );
                    hold( hAx, 'on' );
                    text( hAx, nDropE(iPlot) / 1000, nDropN(iPlot) / 1000 ...
                        , oWave.tableRxDrop.RxName(iPlot), 'FontSize', 8 ...
                        , 'HorizontalAlignment', 'Center', 'VerticalAlignment', 'bottom' );
                end
            end % loop through sites
        else
            nClrs   = turbo(numel(nFList));
            for iFreq = 1:numel(nFList)
                % Plot the pings for this frequency
                iPlot = (tblPing.PingFreq == nFList(iFreq));
                hPing = plot( hAx, tblPing.E(iPlot) / 1000, tblPing.N(iPlot) / 1000 ...
                    , 'Color', nClrs(iFreq,:), 'Marker', '.', 'LineStyle', 'none' );
                legendoff( hPing );
                hold( hAx, 'on' );
                
                % Plot the site drop locations for this frequency
                iPlot = (oWave.tableRxDrop.DucerFreq == nFList(iFreq));
                plot( hAx, nDropE(iPlot) / 1000, nDropN(iPlot) / 1000 ...
                    , 'MarkerFaceColor', nClrs(iFreq,:), 'MarkerEdgeColor', 'k' ...
                    , 'Marker', 'o', 'LineStyle', 'none' ...
                    , 'DisplayName', sprintf( '%.1f Hz', nFList(iFreq) ) );
                text( hAx, nDropE(iPlot) / 1000, nDropN(iPlot) / 1000 ...
                    , oWave.tableRxDrop.RxName(iPlot), 'FontSize', 8 ...
                    , 'HorizontalAlignment', 'Center', 'VerticalAlignment', 'bottom' );
            end % loop through frequencies
            
            legend( hAx, 'Location', 'best' );
        end
        hold( hAx, 'off' );
        axis( hAx, 'equal' );
        axisTight( hAx );
        axisTicksUTM( hAx );
        xlabel( hAx, ['Easting (km) - ' sZone] );
        ylabel( hAx, 'Northing (km)' );
        title( hAx, {
            'RX Nav Starting Map - Drop Sites & Pings'
            oWave.sPlotSubtitle
            } );
        addPlotMenu( hPMap, fullfile( oWave.sPlotDir, 'RxNav_PingMap_UTM' ), 'Save' );
        
        return;
    end % sub_PlotPingMap
end % RxNav

%-------------------------------------------------------------------------------
% Work through the list of benthos pinger files. Pull out pings and make sure
% the ship positions are actually the transducer, not the GPS mast.
function [bError, tblPing] = sub_AggregateData( oWave, fidOut )
    bError = false;
    function emb_LogAndDump( nType, sMsg )
        oWave.AddLog( nType, cwave.sLog_RxNavAction, sMsg );
        switch( nType )
        case cwave.LogWarn; fprintf( fidOut, '  WARNING::%s\n', sMsg ); 
        case cwave.LogError;fprintf( fidOut, '  ERROR::%s\n', sMsg ); 
        otherwise;          fprintf( fidOut, '  %s\n', sMsg );
        end
    end
    
    % Various helper variables
    stShipTSSum = summary( oWave.tableShipTS ); % for min,max values
    
    % For each Benthos file...
    for iFile = 1:numel( oWave.cFiles_RxBenthos )
        fprintf( fidOut, 'Decoding Benthos file: %s\n', oWave.cFiles_RxBenthos{iFile} );
        
        % Read the benthos data
        [bOK,tblThis,cErrMsg] = decodeBenthosRxNav( oWave.cFiles_RxBenthos{iFile} ...
            , 'FirstOnly', oWave.hFig, 'ShortCuts', oWave.sEllipsoid, oWave.nUTMZone );
        if ~bOK
            for i = 1:numel( cErrMsg )
                emb_LogAndDump( cwave.LogError, cErrMsg{i} );
            end
            bError = true;
            continue;
        end
        
        % If the transponder has a delay in its reply, subtract that from the
        % TWTT now (ORE transponders have a 12.5 ms delay)
        if oWave.nRxNavTransDelay > 0
            tblThis.TWTT = tblThis.TWTT - (oWave.nRxNavTransDelay / 1000); % ms --> s
        end
        
        % Log entry
        emb_LogAndDump( cwave.LogOK, sprintf( '%d pings found in: %s' ...
                     , height(tblThis), oWave.cFiles_RxBenthos{iFile} ) );
        
        % Drop any spurious points outside TWTT tolerances
        bDrop = tblThis.TWTT > oWave.nRxNavMaxTWTT;
        if all( bDrop )
            emb_LogAndDump( cwave.LogWarn ...
                , sprintf( 'TWTT for ALL pings > user entered max of %g s' ...
                         , oWave.nRxNavMaxTWTT ) );
            continue;
        elseif any( bDrop )
            emb_LogAndDump( cwave.LogOK ...
                , sprintf( 'TWTT for %d of %d pings > user entered max of %g s' ...
                         , sum(bDrop), numel(bDrop), oWave.nRxNavMaxTWTT ) );
            tblThis(bDrop,:) = [];
        end
        
        % For info, mention the span of time covered by the pings. Affects
        % things like how many days to put in the ShipTS etc...
        emb_LogAndDump( cwave.LogOK ...
            , ['Pings span ' char(min(tblThis.Time)) ' to ' char(max(tblThis.Time))] );
        
        % If the Gyro time series doesn't cover this file, WARN. Offset biases
        % will occur in the solutions. C'est la vie. Some people don't collect
        % all the ship data they need before they get off the ship.
        %
        % NB: datetime class has it's own between() function which overrides
        % mine. Sigh.
        bOut = (tblThis.Time < stShipTSSum.Time.Min | tblThis.Time > stShipTSSum.Time.Max);
        if any(bOut)
            emb_LogAndDump( cwave.LogWarn ...
                , sprintf( '%d of %d pings are outside the times covered by the ship''s gyro data' ...
                         , sum(bOut), numel(bOut) ) );
        end
        
        % Identify GPS-to-Ducer offset for each ping
        iDucer = cwave.IndexIntoTimeTable( oWave.tableGPS2Ducer, tblThis.Time );
        if any( isnan(iDucer) )
            emb_LogAndDump( cwave.LogError ...
                , sprintf( '%d of %d pings are outside the times covered by the GPS-to-Transducer table' ...
                         , sum(isnan(iDucer)), numel(iDucer) ) );
            bError = true;
            continue;
        end
        nDucerZ = oWave.tableGPS2Ducer.Depth_Below_Sea(iDucer);
        
        % Identify velocity profile for each ping
        iVProfile = cwave.IndexIntoTimeTable( oWave.tableVProfile, tblThis.Time );
        if any( isnan(iVProfile) )
            emb_LogAndDump( cwave.LogError ...
                , sprintf( '%d of %d pings are outside the times covered by the velocity profile table' ...
                         , sum(isnan(iVProfile)), numel(iVProfile) ) );
            bError = true;
            continue;
        end
        
        % Aggregate into a single table of ping TWTTs
        tblThis = addvars( tblThis, nDucerZ, iDucer, iVProfile );
        if ~exist( 'tblPing', 'var' )
            tblPing = tblThis;
        else
            tblPing = [tblPing; tblThis];
        end
        clear tblThis nDucerZ iDucer iVProfile bOut
        
    end % loop through benthos files
    if ~exist( 'tblPing', 'var' ) || isempty( tblPing )
        tblPing = [];
        bError = true;
        emb_LogAndDump( cwave.LogError ...
            , 'All data were removed. See previous log entries.' );
    end
    if bError   % if any of the files failed or all warned, bail
        return;
    end
    
    % Find the ship's GYRO heading at each benthos time
    % NB: unwrap gyro so interpolation between 1 & 359 degrees works
    nGyro = unwrap( pi() / 180 * oWave.tableShipTS.Gyro );  % --> radians
    nGyro = interp1( oWave.tableShipTS.Time, nGyro, tblPing.Time, 'linear', NaN );
    
    % Rotate the GPS-to-Ducer offset into the correct frame of reference and
    % move every GPS antenna location to the ducer's location.
    % NB: GYRO is degrees E of N (i.e. clockwise)
    nSkipped = 0;
    for i = 1:height(tblPing)
        if isnan( nGyro(i) )
            nSkipped = nSkipped + 1;
            continue;
        end
        nRot = [cos(nGyro(i)) -sin(nGyro(i)); sin(nGyro(i)) cos(nGyro(i))];
        nAdj = oWave.tableGPS2Ducer{tblPing.iDucer(i),{'East_Offset','North_Offset'}} * nRot;
        tblPing.E(i) = tblPing.E(i) + nAdj(1);
        tblPing.N(i) = tblPing.N(i) + nAdj(2);
    end
    if nSkipped > 0
        emb_LogAndDump( cwave.LogWarn ...
            , sprintf( '%d of %d TOTAL pings are outside the times covered by the ship''s gyro data' ...
                     , nSkipped, height(tblPing) ) );
        emb_LogAndDump( cwave.LogWarn ...
            , 'Position errors for sites using these data can be the size of the GPS-to-transducer offset.' );
    end
    
    return;
end % sub_AggregateData

%-------------------------------------------------------------------------------
function iSitePerPing = sub_AssignPingsToSites( oWave, nTimeTol, tblPing, cRP, tblNav, fidOut )
    % Loop through the pings assigning each to the site with the most similar
    % TWTT and the correct ping frequency, which is also within the horizontal
    % range limit
    nMaxRange    = oWave.nRxNavMaxRange;    % so oWave doesn't hurt parfor
    iSitePerPing = NaN( height( tblPing ), 1 );
    fprintf( fidOut, 'Assigning pings ...' );   % no \n on purpose so toc() is on this line
    tic();
    % NB: This parfor cuts time in half for 3 processors vs 1
    parfor iPing = 1:numel(iSitePerPing)
        % Match the frequency
        iSites = find( tblNav.DucerFreq == tblPing.PingFreq(iPing) ); %#ok<PFBNS>
        if isempty( iSites )
            continue;
        end
        
        % Within the horizontal range limit
        dH = sqrt( (tblNav.East(iSites)  - tblPing.E(iPing)).^2 ...
                 + (tblNav.North(iSites) - tblPing.N(iPing)).^2  );
        iSites(dH > (nMaxRange * 1000)) = [];
        if isempty( iSites )
            continue;
        end
        
        % TWTT to each site
        nTime = [];
        for iSite = reshape(iSites,1,[])
            nTime(end+1) = FindRayPath( ...
                  tblPing.E(iPing),   tblPing.N(iPing),    tblPing.nDucerZ(iPing) ...
                , tblNav.East(iSite), tblNav.North(iSite), tblNav.Depth(iSite) ...
                , [], cRP{tblPing.iRayPathNo(iPing)} ); %#ok<PFBNS>
        end
        
        % Which TWTT is closest to the measured TWTT within the tolerance?
        [nDiff,iDiff] = min( abs( nTime - tblPing.TWTT(iPing) ) );
        if nDiff(1) <= nTimeTol
            iSitePerPing(iPing) = iSites(iDiff(1));
        end
        
    end % loop through pings
    nSec = toc();   % must assign to a variable to prevent default output
    fprintf( fidOut, ' elapsed time is %g seconds.\n', nSec );
    
    return;
end % sub_AssignPingsToSites

%-------------------------------------------------------------------------------
% Plot the navigation results for each site in the nav table - error ellipses
% and TWTT fits. Code modeled after the old plotNavTWTTFits.m
function sub_PlotRxNavTWTTFits( oWave, tblNav, tblPing )
    %
    % tblNav: 
    % {'RxName','DucerFreq','Latitude','Longitude' ...
    % , 'East','North','Depth' ...
    % , 'East_Std','North_Std','Depth_Std','RMS' ...
    % , 'XY_Phi', 'XY_Major', 'XY_Minor' ...      % error ellipses
    % , 'XZ_Phi', 'XZ_Major', 'XZ_Minor' ...      % error ellipses
    % , 'YZ_Phi', 'YZ_Major', 'YZ_Minor' ...      % error ellipses
    % , 'Drop_Lat','Drop_Lon','Drop_East','Drop_North','Drop_Depth'}
    %
    % tblPing:
    % {'Time','Lon','Lat','E','N','PingFreq','ReplyFreq','TWTT','LineNo'
    %   nDucerZ, iDucer, iVProfile, iRayPathNo, iSite, TWTTmodel
    %
    
    % Setup the figure & sub-axes
    hFig    = getStackedFig( [800 600], 'Colormap', colormap('turbo') );
    hAxText = axes( 'Parent', hFig, 'OuterPosition', [0 0.8 1 0.2], 'Position', [0 0.8 1 0.2] ...
        , 'XTick', [], 'YTick', [], 'Box', 'on' );
    hUTM    = axes( 'Parent', hFig, 'OuterPosition', [0 0.3 0.5 0.5] );
    hEE(1)  = axes( 'Parent', hFig, 'OuterPosition', [  0 0 1/6 0.3] );
    hEE(2)  = axes( 'Parent', hFig, 'OuterPosition', [1/6 0 1/6 0.3] );
    hEE(3)  = axes( 'Parent', hFig, 'OuterPosition', [2/6 0 1/6 0.3] );
    hTWTT   = axes( 'Parent', hFig, 'OuterPosition', [0.5 0.3 0.5 0.5] );
    hResid  = axes( 'Parent', hFig, 'OuterPosition', [0.5 0 0.5 0.32] );
    
    for iRx = 1:height(tblNav)
        % Get / calc info about this site
        sTitle  = sprintf( 'Site %s (%.1f)', tblNav.RxName{iRx}, tblNav.DucerFreq(iRx) );
        set( hFig, 'Name', sTitle );
        
        bPing   = (tblPing.iSite == iRx);
        nCntPing= sum(bPing);
        
        %% Text about the receiver's nav
        % NB: warnings / notes from synthetic tests I did back in 2009
        cla( hAxText ); % clear any previous texts
        if isnan( tblNav.East(iRx) )
            text( hAxText, 0.5, 0, 'ERROR! Marquardt navigation FAILED.' ...
                , 'Color', [.6 0 0] ...
                , 'VerticalAlignment', 'Bottom', 'HorizontalAlignment', 'Center' );
        elseif nCntPing < 17
            text( hAxText, 0.5, 0, 'WARNING! Possibly too few data points for good error estimation!' ...
                , 'Color', [.6 0 0] ...
                , 'VerticalAlignment', 'Bottom', 'HorizontalAlignment', 'Center' );
        else
            text( hAxText, 0.5, 0, 'NOTE: 1 \sigma sometimes underestimated up to 15% by this Marquardt.' ...
                , 'Color', 'k' ...
                , 'VerticalAlignment', 'Bottom', 'HorizontalAlignment', 'Center' );
        end
        text( hAxText, 0.5, 1, ...
            sprintf( 'Locations for %s; %d data points; RMS Misfit %.5f' ...
            , sTitle, nCntPing, tblNav.RMS(iRx) ) ...
            , 'FontWeight', 'Bold' ...
            , 'VerticalAlignment', 'Top', 'HorizontalAlignment', 'Center' );
        text( hAxText, 0.25, 1, {' '; ' '
            'UTM'
            '2\sigma'
            'Lon,Lat'
            }, 'VerticalAlignment', 'Top', 'HorizontalAlignment', 'Right' );
        
        text( hAxText, 0.375, 1, {' '; 'X'
            sprintf('%.1f', tblNav.East(iRx)) 
            sprintf('%.1f', 2 * tblNav.East_Std(iRx)) 
            sprintf('%.5f', tblNav.Longitude(iRx)) 
            }, 'VerticalAlignment', 'Top', 'HorizontalAlignment', 'Center' );
        
        text( hAxText, 0.625, 1, {' '; 'Y'
            sprintf('%.1f', tblNav.North(iRx)) 
            sprintf('%.1f', 2 * tblNav.North_Std(iRx)) 
            sprintf('%.5f', tblNav.Latitude(iRx)) 
            }, 'VerticalAlignment', 'Top', 'HorizontalAlignment', 'Center' );
        
        text( hAxText, 0.875, 1, {' '; 'Z'
            sprintf('%.1f', tblNav.Depth(iRx)) 
            sprintf('%.1f', 2 * tblNav.Depth_Std(iRx)) 
            ' '
            }, 'VerticalAlignment', 'Top', 'HorizontalAlignment', 'Center' );
        
        %% Plot of drop & nav locations along with pings
        % Use scatter() to color the pings by TWTT. Also, plot in km not m
        scatter( hUTM, tblPing.E(bPing) / 1000, tblPing.N(bPing) / 1000 ...
            , [], 1:sum(bPing), '.', 'DisplayName', 'Pings' );
        hold( hUTM, 'on' );
        plot( hUTM, tblNav.Drop_East(iRx) / 1000, tblNav.Drop_North(iRx) / 1000 ...
            , 'LineStyle', 'none', 'DisplayName', 'Drop' ...
            , 'Marker', 'o', 'MarkerEdgeColor', 'r', 'MarkerFaceColor', 'r' );
        plot( hUTM, tblNav.East(iRx) / 1000, tblNav.North(iRx) / 1000 ...
            , 'LineStyle', 'none', 'DisplayName', 'Nav' ...
            , 'Marker', 's', 'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'k' );
        hold( hUTM, 'off' );
        axis( hUTM, 'equal' );
        axisTight( hUTM );
        axisTicksUTM( hUTM, 'xy' );
        title( hUTM, ['UTM Locations - ' oWave.sUTMZoneDisp] );
        xlabel( hUTM, 'Easting (km)' );
        ylabel( hUTM, 'Northing (km)' );
        grid( hUTM, 'on' );
        box( hUTM, 'on' );
        colorbar( hUTM, 'Location', 'eastoutside' );
        legend( hUTM, 'Location', 'best' );
        
        %% Error ellipses in 3 separate planes
        sub_Ellipse( hEE(1), tblNav.XY_Phi(iRx), tblNav.XY_Major(iRx), tblNav.XY_Minor(iRx) );
        sub_Ellipse( hEE(2), tblNav.XZ_Phi(iRx), tblNav.XZ_Major(iRx), tblNav.XZ_Minor(iRx) );
        sub_Ellipse( hEE(3), tblNav.YZ_Phi(iRx), tblNav.YZ_Major(iRx), tblNav.YZ_Minor(iRx) );
        nAx = cell2mat( [xlim(hEE); ylim(hEE)] );
        nAx = [-1.1 1.1] * max( abs(nAx), [], 'all' );
        axis( hEE, 'equal' );
        set( hEE, 'XLim', nAx, 'YLim', nAx );
        title( hEE(1), 'XY' );
        title( hEE(2), 'XZ' );
        title( hEE(3), 'YZ' );
        
        %% TWTT data & model
        % Plot the X-axis as ping number
        xTWTT = 1:nCntPing;
        scatter( hTWTT, xTWTT, tblPing.TWTT(bPing), [], 1:sum(bPing) ...
            , 'o', 'DisplayName', 'Data' );
        hold( hTWTT, 'on' );
        plot( hTWTT, xTWTT, tblPing.TWTTmodel(bPing), '.k' ...
            , 'DisplayName', 'Model', 'MarkerSize', 6, 'LineStyle', 'none' );
        hold( hTWTT, 'off' );
        axisTight( hTWTT );
        title( hTWTT, 'Two-way Travel Time' );
        ylabel( hTWTT, 'TWTT (s)' );
        legend( hTWTT, 'Location', 'best' );
        grid( hTWTT, 'on' );
        box( hTWTT, 'on' );
        
        %% TWTT residual
        nResid = (tblPing.TWTT(bPing) - tblPing.TWTTmodel(bPing)) * 1000; % in ms
        plot( hResid, xTWTT, nResid, '.k', 'LineStyle', 'none' );
        axisTight( hResid );
        linkaxes( [hTWTT hResid], 'x' );
        xlabel( hResid, 'Ping number' );
        ylabel( hResid, 'Residual (ms)' );
        grid( hResid, 'on' );
        box( hResid, 'on' );
        
        %% Finish up and save the plot automatically
        addPlotMenu( hFig ...
            , fullfile( oWave.sPlotDir, ['RxNav_TWTTFit_Site_' tblNav.RxName{iRx}] ) ...
            , 'SaveNow', [], 'PNGOnly' );
        
    end % loop through receivers
    
    % Get rid of this figure
    delete( hFig );
    
    return;
end % sub_PlotRxNavTWTTFits

%-------------------------------------------------------------------------------
function h = sub_Ellipse( hAx, nPhi, nMajor, nMinor )
    nAngles = pi() / 180 * (0:360);
    nX =  nMajor * cos( nPhi ) * cos(nAngles) ...
        - nMinor * sin( nPhi ) * sin(nAngles);
    nY =  nMajor * sin( nPhi ) * cos(nAngles) ...
        + nMinor * cos( nPhi ) * sin(nAngles);
    h = plot( hAx, nX, nY ...
        , 'Marker', 'none', 'Color', 'k' ...
        , 'LineStyle', '-', 'LineWidth', 0.5 );
    return;
end % sub_Ellipse

%-------------------------------------------------------------------------------
function sub_PlotRxNavSummary( oWave, tblNav )
    
    hFig = getStackedFig( 'pptHD', 'Name', 'RX Navigation RMS Misfit' );
    hRMS = subplot( 2, 1, 1, 'parent', hFig );
    hCnt = subplot( 2, 1, 2, 'parent', hFig );
    
    x = 1:height( tblNav );
    stem( hRMS, x, tblNav.RMS );
    bFailed = isnan( tblNav.RMS );
    if any( bFailed )
        y = repmat( mean( tblNav.RMS, 'omitnan' ), 1, sum(bFailed) );
        hold( hRMS, 'on' );
        text( hRMS, x(bFailed), y, repmat({'Failed'},sum(bFailed),1) ...
            , 'HorizontalAlignment', 'center' ...
            , 'FontSize', cwave.FontSize - 2, 'Rotation', 90 );
    end
    ylabel( hRMS, 'RMS misfit' );
    title( hRMS, {'RX Navigation RMS Misfit'; oWave.sPlotSubtitle} );
    
    stem( hCnt, x, tblNav.PingCnt );
    hRMS.XTick              = x;
    hRMS.XTickLabel         = tblNav.RxName;
    hRMS.XTickLabelRotation = 60;
    axisTight( hRMS, 'x' );
    % Make sure y includes RMS 1.0
    if max(hRMS.YLim) < 1.0
        hRMS.YLim(2) = 1;
    end
    
    ylabel( hCnt, 'Number of Pings' );
    hCnt.XTick              = x;
    hCnt.XTickLabel         = tblNav.RxName;
    hCnt.XTickLabelRotation = 60;
    axisTight( hCnt, 'x' );
    
    % pull together the axes
    linkaxes( [hRMS hCnt], 'x' );
    
    addPlotMenu( hFig, fullfile( oWave.sPlotDir, 'RxNav_Misfit' ), 'Save' );
    
    return;
end % sub_PlotRxNavSummary
