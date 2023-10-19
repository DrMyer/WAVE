function TxNav( oWave )
% Inverted Long-baseline navigation
%
% The algorithm here is one I developed on my own. It is different in a number
% of key ways from the one outlined in the paper by Key & Constable and improved
% on by Chesley in her dissertation. See notes throughout, especially in the
% smoothing function.
%
% Params:
%   oWave   - the cwave object with all the data
%-------------------------------------------------------------------------------
% Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
%-------------------------------------------------------------------------------
arguments
    oWave cwave
end

% All of the Barracuda configurations need to be valid
if ~all( oWave.ValidateCudaCfg( oWave.tableCudaCfg, oWave.hFig, false ) )
    uialert( oWave.hFig, [
        'Not all of the entries in the barracuda configuration ' ...
        'table are valid. Edit the table and fix the entries ' ...
        'before attempting to run navigation.' 
        ], 'iLBL Barracuda Nav' );
    return;
end


% Clear the logs & output tables
oWave.ClearLogOfType( cwave.sLog_TxNavAction );
oWave.tableTxNav = cwave.GetDfltFor( 'tableTxNav' );
oWave.tableCTET  = cwave.GetDfltFor( 'tableCTET' );

% Create convenience variables
sCancel = 'User canceled the process';

% Show progress and allow cancel
tStart = tic();
oProg = uiprogressdlg( oWave.hFig, 'Cancelable', true, 'Indeterminate', true ...
    , 'Title', 'iLBL Barracuda Nav' );
try
    
    %% Assemble the wire-0 & approximate SUESI locations based on ship data
    %
    % tWire0 = {'Time', 'Ewire', 'Nwire', 'WireOut', 'Gyro' ...
    %          , 'AlongTrack', 'Rsuesi', 'Esuesi', 'Nsuesi', 'Zsuesi' ...
    %          , 'Alt', 'COG', 'Dip'} ...
    oProg.Message = 'Calculating rough est of TX position...';
    
    tWire0 = sub_GetWire0( oWave );
    
    assert( ~oProg.CancelRequested, sCancel );
    
    
    %% Get the ping data for each barracuda
    % NB: barracudas can be pulled in and changed mid-tow (e.g. Scarborough) so
    % there may be many different "NAVx" entries and differing reply channels
    % (also Scarborough). There is no longer a sense of "port" and "starboard".
    %
    % NB: limit the max horizontal range the sound velocity ray tables are
    % created for in order to save a lot of calc time
    nMaxR = max( tWire0.WireOut ) + oWave.nCDist;   % wire straight out + CTET dist behind SUESI
    nMaxR = nMaxR * 1.10;    % add a x% buffer
    
    % tCuda = {'Time', 'iCuda', 'TWTT', 'Range', 'East', 'North' ...
    %         [ fields below interpolated from tWire0 ]
    %        , 'Ewire', 'Nwire', 'Rsuesi', 'Esuesi', 'Nsuesi', 'Zsuesi' ...
    %        , 'Alt', 'COG', 'Dip', 'WireOut'};
    %
    cRayTbl = cell(0,3);    % NB: cRayTbl cols: iVel, pinger depth, struct
    cCuda   = cell( height( oWave.tableCudaCfg ), 1 );
    for iCuda = 1:height( oWave.tableCudaCfg )
        oProg.Message = sprintf( 'Pre-processing Barracuda #%d pings...', iCuda );
        
        [tCuda,cRayTbl] = sub_GetCudaPings( oWave, iCuda, cRayTbl, nMaxR, tWire0 );
        
        assert( ~oProg.CancelRequested, sCancel );
        cCuda{iCuda} = tCuda;
    end
    
    
    %% Triangulate replies from two barracudas
    oProg.Message = 'Triangulating SUESI using Barracuda pairs...';
    tNavEst = cwave.GetDfltFor( 'tableTxNav' );
    for i1st = 1:size(cCuda,1)-1
        if height( cCuda{i1st} ) < 1
            continue;
        end
        for i2nd = (i1st+1):size(cCuda,1)
            % Find simultaneous pings
            tCuda1 = cCuda{i1st}; % must transfer to var for naming in innerjoin()
            tCuda2 = cCuda{i2nd};
            if height( tCuda2 ) < 1
                continue;
            end
            [tB2B,iFrom1,iFrom2] = innerjoin( tCuda1, tCuda2 ...
                , 'Keys', 'Time' ...
                , 'RightVariables', {'East', 'North', 'Range'} );
            if isempty( tB2B )
                continue;
            end
            
            % Remove the used pings so I don't use them again with wire-out
            tCuda1(iFrom1,:) = [];
            tCuda2(iFrom2,:) = [];
            cCuda{i1st}      = tCuda1;
            cCuda{i2nd}      = tCuda2;
            
            % Triangulate
            [nENEN,nFix1,nFix2,nFix3] = Triangulate( ...
                  tB2B{:,{'East_tCuda1','North_tCuda1'}}, tB2B.Range_tCuda1 ... barracuda1 to suesi
                , tB2B{:,{'East_tCuda2','North_tCuda2'}}, tB2B.Range_tCuda2 ... barracuda2 to suesi
                , 'both', 'both', 'both' );
            
            % Report various fixes applied by the triangulation code
            if nFix1 > 0
                oWave.AddLog( cwave.LogOK, cwave.sLog_TxNavAction ...
                    , sprintf('B2B: %d of %d pings had Cuda%d inside Cuda%d''s circle. Adjusted both' ...
                    , nFix1, height(tB2B), i2nd, i1st ) );
            end
            if nFix2 > 0
                oWave.AddLog( cwave.LogOK, cwave.sLog_TxNavAction ...
                    , sprintf('B2B: %d of %d pings had Cuda%d inside Cuda%d''s circle. Adjusted both' ...
                    , nFix2, height(tB2B), i1st, i2nd ) );
            end
            if nFix3 > 0
                oWave.AddLog( cwave.LogOK, cwave.sLog_TxNavAction ...
                    , sprintf('B2B: %d of %d pings had cuda%d & %d TWTT range too short. Adjusted both' ...
                    , nFix3, height(tB2B), i1st, i2nd ) );
            end
            
            % If any solutions are still imaginary, drop them. This shouldn't
            % happen because of the fixes Triangulate() applies, but what the
            % heck. Be safe
            bDrop = any(imag(nENEN),2);
            if any(bDrop)
                oWave.AddLog( cwave.LogOK, cwave.sLog_TxNavAction ...
                    , sprintf('B2B: %d of %d pings between Cuda%d & %d dropped - invalid triangulation' ...
                    , sum(bDrop), numel(bDrop), i1st, i2nd ) );
                tB2B(bDrop,:) = [];
                nENEN(bDrop,:) = [];
            end
            assert( ~oProg.CancelRequested, sCancel );
            
            % Add the points to the nav list
            tNavEst = sub_AddToNav( tB2B, nENEN, tNavEst );
            
        end % inner loop over all cuda tables
    end % outer loop over all cuda tables
    clear tCuda1 tCuda2 tB2B iFrom1 iFrom2 nENEN nFix1 nFix2 nFix3 bDrop
    
    
    %% Triangulate one barracuda & wire-out
    % NB: The idea here is that I can triangulate using (wire-out + SUESI depth)
    % to yield one horizontal range and the barracuda ping to yield the other
    % horizontal range. Both have GPS anchored center points so whereever their
    % circles overlap is a valid nav estimate
    %
    % NB: It is no longer relevant which barracuda is which so join the tables
    % for simplicity
    %
    oProg.Message = 'Triangulating SUESI using Barracuda & Wire-out ...';
    tPings = cCuda{1};
    for iCuda = 2:numel(cCuda)
        tPings = [tPings; cCuda{iCuda}];
    end
    tPings = sortrows( tPings, 'Time' );
    clear cCuda
    
    % Triangulate 
    [nENEN,nFix1,nFix2,nFix3] = Triangulate( ...
          tPings{:,{'Ewire','Nwire'}}, tPings.Rsuesi ... wire range to SUESI
        , tPings{:,{'East','North'}}, tPings.Range ... barracuda range to SUESI
        , 'shrinkA', 'shrinkB', 'growB' );
    
    % Report various fixes applied by the triangulation code
    if nFix1 > 0
        oWave.AddLog( cwave.LogOK, cwave.sLog_TxNavAction ...
            , sprintf('B2S: %d of %d pings had SUESI range too long. Adjusted downward' ...
            , nFix1, height(tPings) ) );
    end
    if nFix2 > 0
        oWave.AddLog( cwave.LogOK, cwave.sLog_TxNavAction ...
            , sprintf('B2S: %d of %d pings had TWTT range too long. Adjusted downward' ...
            , nFix2, height(tPings) ) );
    end
    if nFix3 > 0
        oWave.AddLog( cwave.LogOK, cwave.sLog_TxNavAction ...
            , sprintf('B2S: %d of %d pings had SUESI or TWTT range too short. Adjusted TWTT up' ...
            , nFix3, height(tPings) ) );
    end
    
    % Drop imaginaries (if any)
    bDrop = any(imag(nENEN),2);
    if any(bDrop)
        oWave.AddLog( cwave.LogOK, cwave.sLog_TxNavAction ...
            , sprintf('B2S: %d of %d pings dropped - invalid triangulation' ...
            , sum(bDrop), numel(bDrop) ) );
        tPings(bDrop,:) = [];
        nENEN(bDrop,:)  = [];
    end
    assert( ~oProg.CancelRequested, sCancel );
    
    % Add to the nav table
    tNavEst = sub_AddToNav( tPings, nENEN, tNavEst );
    clear tPings tW0 bDrop stRP oInterp nR nENEN iFromTo bFirst
    
    % Identify each tow
    iTowIdx = cwave.IndexIntoTimeTable( oWave.tableTow, tNavEst.Time );
    bDrop = isnan(iTowIdx);
    if any(bDrop) % this condition should never occur, but just in case...
        tNavEst(bDrop,:) = [];
        iTowIdx(bDrop) = [];
    end
    tNavEst.TowNo(:) = oWave.tableTow.TowNo(iTowIdx);
    
    
    %% Add points for short wire-out when SUESI is nailed to the ship-track
    % Wire-out is < minimum (e.g. surface tow near ship)
    iTowIdx = cwave.IndexIntoTimeTable( oWave.tableTow, tWire0.Time );
    bAdd = ~isnan( iTowIdx ) & tWire0.WireOut <= oWave.nMinWireLBL;
    
    % Add all wire-out points for those tows whose IgnoreNav flag is set. Also
    % remove all pings for those tows
    for iTow = 1:height(oWave.tableTow)
        if round(oWave.tableTow.IgnoreNav(iTow)) == 0     % damn floating point
            continue;
        end
        bDrop = tNavEst.TowNo == oWave.tableTow.TowNo(iTow);
        bWire = iTowIdx == iTow;
        oWave.AddLog( cwave.LogOK, cwave.sLog_TxNavAction ...
            , sprintf('Tow %d set by user to ignore iLBL nav. Drop %d pings. Add %d ship positions.' ...
                     , oWave.tableTow.TowNo(iTow), sum(bDrop), sum(bWire) ) );
        tNavEst(bDrop,:) = [];
        bAdd = bAdd | bWire;
    end
    
    % Add the forced nav points
    tNavEst.Forced(:) = false;
    if any( bAdd )
        iFromTo                     = (1:sum(bAdd)) + height(tNavEst);
        tNavEst{iFromTo,:}          = missing();    % allocate
        tNavEst.Forced(iFromTo)     = true;
        tNavEst.Time(iFromTo)       = tWire0.Time(bAdd);
        tNavEst.Altitude(iFromTo)   = tWire0.Alt(bAdd);
        tNavEst.Depth(iFromTo)      = tWire0.Zsuesi(bAdd);
        tNavEst.COG(iFromTo)        = mod( tWire0.COG(bAdd), 360 );
        tNavEst.Dip(iFromTo)        = tWire0.Dip(bAdd);
        tNavEst.Wire0_E(iFromTo)    = tWire0.Ewire(bAdd);
        tNavEst.Wire0_N(iFromTo)    = tWire0.Nwire(bAdd);
        tNavEst.ShipTrack_E(iFromTo)= tWire0.Esuesi(bAdd); % estimated position using ship pos, ship COG, wire-out, & Suesi Z
        tNavEst.ShipTrack_N(iFromTo)= tWire0.Nsuesi(bAdd);
        tNavEst.Ping_E(iFromTo)     = tWire0.Esuesi(bAdd);
        tNavEst.Ping_N(iFromTo)     = tWire0.Nsuesi(bAdd);
        
        oWave.AddLog( cwave.LogOK, cwave.sLog_TxNavAction ...
            , sprintf('Added total of %d positions for wire-out < %g & tow set to ignore nav' ...
                     , sum(bAdd), oWave.nMinWireLBL ) );
    end
    
    
    %% Average together points that occur at the same time (& sort by time)
    oProg.Message = 'Averaging contemporaneous points...';
    nHtB4 = height( tNavEst );
    tNavEst = sub_AvgByTime( tNavEst );
    if height( tNavEst ) ~= nHtB4
        oWave.AddLog( cwave.LogOK, cwave.sLog_TxNavAction ...
            , sprintf('Averaged %d of %d contemporaneous nav locations' ...
                     , nHtB4-height(tNavEst), nHtB4 ) );
    end
    assert( ~oProg.CancelRequested, sCancel );
    
    
    %% Smooth SUESI's path (it needs it. Trust me. iLBL is not very good.)
    oProg.Message = 'Smoothing SUESI''s path...';
    tNav = sub_SmoothPath( oWave, tNavEst, oProg );
    assert( ~oProg.CancelRequested, sCancel );
    
    
    %% Plot SUESI loc (not antenna mid-point): est, pings, smoothed track
    sub_PlotSUESIPingMap( oWave, tWire0, tNav );
    
    
    %% Plot the uncertainties for each tow line
    sub_PlotTowUncert( oWave, tNav );
    
    
    %% Navigate the CTET path (if any)
    oProg.Message = 'Navigating the CTET...';
    tTet = sub_NavTET( oWave, tNav, cRayTbl, nMaxR, oProg );
    assert( ~oProg.CancelRequested, sCancel );
    
    
    %% Use SUESI & CTET locations to find the midpoint of the antenna
    %
    % NB: If no CTET, put the midpoint in SUESI's track behind it and use the
    % CTET depth (if I have it from the w=[] lines in SUESI's log) to set the
    % dip
    oProg.Message = 'Finding the antenna mid-point...';
    if isempty( tTet )
        % Place the antenna mid-point(E,N) behind SUESI along a line from
        % wire0(E,N) through Smooth(E,N) but at SUESI's depth (level flight)
        nTheta      = atan2( tNav.Smooth_N - tNav.Wire0_N, tNav.Smooth_E - tNav.Wire0_E );
        tNav.East   = tNav.Smooth_E + oWave.nTxCtrOffset .* cos( nTheta );
        tNav.North  = tNav.Smooth_N + oWave.nTxCtrOffset .* sin( nTheta );
        tNav.Depth  = tNav.Suesi_Z;
    else
        % Place the antenna mid-point(E,N,Z) behind SUESI along a line from
        % Smooth(E,N,Z) through TET(E,N,Z)
        nENZ        = interp1( tTet.Time, tTet{:,{'East','North','Depth'}} ...
                             , tNav.Time, 'linear', 'extrap' );
        nTheta      = atan2( nENZ(:,2) - tNav.Smooth_N, nENZ(:,1) - tNav.Smooth_E );
        tNav.East   = tNav.Smooth_E + oWave.nTxCtrOffset .* cos( nTheta );
        tNav.North  = tNav.Smooth_N + oWave.nTxCtrOffset .* sin( nTheta );
        
        % Calculate the dip
        nTheta      = atan2( nENZ(:,3) - tNav.Suesi_Z, oWave.nCDist );
        tNav.Depth  = tNav.Suesi_Z + oWave.nTxCtrOffset .* sin( nTheta );
        tNav.Depth(tNav.Depth < 0) = 0;
        
    end
    assert( ~oProg.CancelRequested, sCancel );
    
    
    %% Final cleanup stuff
    % Convert E,N to Lon,Lat
    [tNav.Longitude, tNav.Latitude] = oWave.UTM2LonLat( tNav.East, tNav.North );
    [tTet.Longitude, tTet.Latitude] = oWave.UTM2LonLat( tTet.East, tTet.North );
    
catch Me
    % Catch any catastrophic errors - mostly this will be user cancel
    if isempty( Me.identifier ) % one of my assert() messages
        oWave.AddLog( cwave.LogError, cwave.sLog_TxNavAction, Me.message );
    else
        oWave.AddLog( oWave.LogError, cwave.sLog_TxNavAction ...
            , sprintf( 'Error :: %s:%s', Me.identifier, Me.message ) );
        sStack = '';
        for iStack = 1:numel(Me.stack)
            sStack = [sStack sprintf( ';%s (%d)', Me.stack(iStack).name, Me.stack(iStack).line )];
        end
        oWave.AddLog( oWave.LogError, cwave.sLog_TxNavAction, sStack(2:end) );
    end
    close( oProg );
    return;
end

% Clear the progress window
close( oProg );

% Log what's happened and how long it took
oWave.AddLog( cwave.LogOK, cwave.sLog_TxNavAction, sprintf( '%d SUESI nav points', height(tNav) ) );
oWave.AddLog( cwave.LogOK, cwave.sLog_TxNavAction, sprintf( '%d CTET nav points', height(tTet) ) );
nDur = seconds( toc(tStart) );
nDur.Format = 'hh:mm:ss';
oWave.AddLog( cwave.LogOK, cwave.sLog_TxNavAction, ['Process time: ' char(nDur)] );

% Get rid of any extra columns I added along the way for processing
cVars = tNav.Properties.VariableNames;
cVars(ismember(cVars,oWave.tableTxNav.Properties.VariableNames)) = [];
if ~isempty( cVars )
    tNav = removevars( tNav, cVars );
end

% Update the internal variables - firing off listeners
oWave.tableTxNav = tNav;
oWave.tableCTET = tTet;

return;
end % TxNav

%-------------------------------------------------------------------------------
% Assemble a table of ship data but with ship's loc moved to the winch wire-0
% location. Use ship info & SUESI depth to estimate SUESI's location at each
% ship time
%
% NB: wire-0 is the generally right under the A-frame of the ship when it is
% extended for towing. It's important to move the ship's location from the GPS
% mast to this location because it will introduce a bias in all SUESI navigation
% that is NON-LINEAR because of a constantly changing crab angle of the ship.
%
function tWire0 = sub_GetWire0( oWave )
    arguments
        oWave cwave
    end
    
    % Build the table
    tWire0 = table( 'Size', [height(oWave.tableSDM) 13] ...
        , 'VariableNames', {'Time', 'Ewire', 'Nwire', 'WireOut', 'Gyro' ...
                        , 'AlongTrack', 'Rsuesi', 'Esuesi', 'Nsuesi', 'Zsuesi' ...
                        , 'Alt', 'COG', 'Dip'} ...
        , 'VariableTypes', [{'datetime'} repmat({'double'},1,12)] ...
        );
    
    % NB: "(:)" below is to preserve the VariableType info. MatLab erases it if
    % you don't use (:)
    tWire0.Time(:)      = oWave.tableSDM.Time;
    tWire0.Ewire(:)     = oWave.tableSDM.Ship_East;
    tWire0.Nwire(:)     = oWave.tableSDM.Ship_North;
    tWire0.WireOut(:)   = oWave.tableSDM.Wire_Out;
    tWire0.Gyro(:)      = oWave.tableSDM.Ship_Gyro;
    tWire0.Zsuesi(:)    = oWave.tableSDM.Depth;
    tWire0.Alt(:)       = oWave.tableSDM.Altitude;
    tWire0.Dip(:)       = oWave.tableSDM.Dip;
    tWire0.COG(:)       = 180/pi() * unwrap( pi()/180 * oWave.tableSDM.Ship_COG ); % unwrap for interpolation later
    % NB: using Ship's COG instead of SUESI's because sometimes it is off from
    % ship by 90 or 180 degrees and sometimes it's just missing altogether
    
    % Get the wire-out tare value - which can be different for each tow if SUESI
    % is recovered & redeployed (this happened on Scarborough). If it happens
    % mid-tow, then that must be treated as TWO SEPARATE TOWS. Usually the ship
    % turns around and retows the line anyway as the new or repaired SUESI is
    % lowered back to depth.
    % 
    % NB: "Tare" always gets subtracted because of the definition of tare
    %
    iTow = cwave.IndexIntoTimeTable( oWave.tableTow, tWire0.Time );
    bFill = ~isnan(iTow);
    tWire0.WireOut(bFill) = tWire0.WireOut(bFill) - oWave.tableTow.WireOutTare(iTow(bFill));
    
    % Eliminate any row in which winch wire-out is <= depth. This sort of
    % weirdness occurs when SUESI is being deployed or reeled in quickly and the
    % Valeport's pressure readings haven't equilibrated
    bDrop = tWire0.WireOut < tWire0.Zsuesi & tWire0.WireOut > oWave.nMinWireLBL;
    if any(bDrop)
        oWave.AddLog( cwave.LogWarn, cwave.sLog_TxNavAction ...
            , sprintf( '%d of %d wire-out <= suesi depth & > %g m. Ignoring them.' ...
                     , sum(bDrop), height(tWire0), oWave.nMinWireLBL ) );
        tWire0(bDrop,:) = [];
    end
    
    % At very close ranges (e.g. surface towing near wire0) the suesi depth is
    % not accurate. The valeport doesn't react well to air vs water pressure and
    % sea-swell or chop. 
    bFix = tWire0.Zsuesi > tWire0.WireOut;
    if any(bFix)
        oWave.AddLog( cwave.LogWarn, cwave.sLog_TxNavAction ...
            , sprintf( '%d of %d suesi depth > wire-out. Fixing them.' ...
                     , sum(bFix), height(tWire0) ) );
        tWire0.Zsuesi(bFix) = tWire0.WireOut(bFix);
    end
    
    % Turn ship location into wire-out-zero location
    nENOffset = [oWave.nGPStoWireZeroE oWave.nGPStoWireZeroN];
    if isequal( nENOffset, [0 0] )
        oWave.AddLog( cwave.LogWarn, cwave.sLog_TxNavAction ...
            , 'No ship GPS-to-Wire0 offsets have been entered.' );
        oWave.AddLog( cwave.LogWarn, cwave.sLog_TxNavAction ...
            , ['MINIMUM position errors for SUESI will be proportionate ' ...
              'the size of the GPS-to-A-frame offset.'] );
    else
        % This loop takes a lot of time. Parallelize it by extracting from the
        % table to individual vars then returning afterwards. parfor doesn't
        % like dealing with tables, structs, or objects.
        bSkipped = false(height(tWire0),1);
        nGyro    = tWire0.Gyro;
        nE       = tWire0.Ewire;
        nN       = tWire0.Nwire;
        parfor i = 1:height(tWire0)
            if isnan( nGyro(i) )
                bSkipped(i) = true;
                continue;
            end
            % NB: GYRO is degrees E of N (i.e. clockwise)
            nAdj = nENOffset * [cosd(nGyro(i)) -sind(nGyro(i))
                                sind(nGyro(i))  cosd(nGyro(i))];
            nE(i) = nE(i) + nAdj(1);
            nN(i) = nN(i) + nAdj(2);
        end
        tWire0.Ewire = nE;
        tWire0.Nwire = nN;
        if any(bSkipped)
            oWave.AddLog( cwave.LogWarn, cwave.sLog_TxNavAction ...
                , sprintf( '%d of %d ship locations have no gyro data' ...
                         , sum( bSkipped ), height(tWire0) ) );
            oWave.AddLog( cwave.LogWarn, cwave.sLog_TxNavAction ...
                , ['MINIMUM position errors for SUESI will be proportionate ' ...
                  'the size of the GPS-to-A-frame offset.'] );
        end
        clear nE nN bSkipped
    end
    
    % AFTER ship E,N has been turned into wire E,N, calculate along-track
    % distance. It must be after because the E,N locations will be shifted in
    % different directions as the GYRO angle changes
    tWire0 = sortrows( tWire0, 'Time' );
    tWire0.AlongTrack(:)= cumsum( [0; sqrt( diff(tWire0.Ewire).^2 + diff(tWire0.Nwire).^2 )] );
    [~,iUniq] = unique( tWire0.AlongTrack );
    tWire0 = tWire0(iUniq,:);
    
    % Get the horizontal range to SUESI assuming that the tow wire is straight.
    % It probably isn't (perhaps a catenary of some sort?) but at this point I
    % just need an *approximate* range
    tWire0.Rsuesi(:) = sqrt( (tWire0.WireOut).^2 - (tWire0.Zsuesi).^2 );
    
    % Get an approximate location for SUESI in the ship track at <Range> meters
    % behind the ship. Extrapolation off the beginning of the tow is OK. The
    % run-in is almost always a straight line and SUESI data usually begin
    % collection once SUESI is a few meters in the water and range is nearly 0
    nEN = interp1( tWire0.AlongTrack, tWire0{:,{'Ewire','Nwire'}} ...
                 , tWire0.AlongTrack - tWire0.Rsuesi, 'linear', 'extrap' );
    tWire0.Esuesi(:) = nEN(:,1);
    tWire0.Nsuesi(:) = nEN(:,2);
    
    % Eliminate any positions outside the tow start-end times configured by the
    % user. This must be done AFTER the AlongTrack is calculated or placing
    % SUESI behind the ship at the start of each tow line will be bonkers wrong.
    %
    % No. Leave the entire track. It doesn't save any time and it's helpful on
    % the plot of ship track vs navigated SUESI location
    %
    %     bDrop = isnan(cwave.IndexIntoTimeTable( oWave.tableTow, tWire0.Time ));
    %     if any(bDrop)
    %         oWave.AddLog( cwave.LogOK, cwave.sLog_TxNavAction ...
    %             , sprintf( '%d of %d ship positions outside of tow start-end times. Ignoring them.' ...
    %                      , sum(bDrop), height(tWire0) ) );
    %         tWire0(bDrop,:) = [];
    %     end
    
    return;
end % sub_GetWire0

%-------------------------------------------------------------------------------
% Retrieve the pings for a specific barracuda & return them in a table along
% with the position of the barracuda at that time
function [tCuda,cRayTbl] = sub_GetCudaPings( oWave, iCuda, cRayTbl, nMaxR, tWire0 )
    arguments
        oWave   cwave
        iCuda   double
        cRayTbl cell
        nMaxR   double
        tWire0  table
    end
    
    %% Create the table
    %
    % NB: More fields will be added from tWire0 below
    %
    tCuda = table( 'Size', [0 7] ...
        , 'VariableNames', {'Time',    'iCuda', 'TWTT',  'Range',  'East',  'North', 'PingNo'} ...
        , 'VariableTypes', {'datetime','double','double','double','double','double','double'} ...
        );
    
    %% Find the appropriate pings. 
    % The ping freq must ALWAYS match to distinguish direct pings on the
    % barracudas from those by the CTET's reply. Then we match either the
    % barracuda's reply frequency or it's reply channel. There are some surveys
    % where the reply freq changes midway through (e.g. Scarborough)
    nDevNo  = oWave.tableCudaCfg.DeviceNo(iCuda);
    nZ      = oWave.tableCudaCfg.DucerDepth(iCuda);
    if isnan( oWave.tableCudaCfg.ReplyFreq(iCuda) )
        b = oWave.tableBenthos.PingFreq == oWave.tableCudaCfg.ListenFreq(iCuda) ...
          & oWave.tableBenthos.ReplyCh  == oWave.tableCudaCfg.ReplyCh(iCuda) ...
          & oWave.tableBenthos.ReplyTWTT < oWave.nBPingLimit;
    else
        b = oWave.tableBenthos.PingFreq  == oWave.tableCudaCfg.ListenFreq(iCuda) ...
          & oWave.tableBenthos.ReplyFreq == oWave.tableCudaCfg.ReplyFreq(iCuda) ...
          & oWave.tableBenthos.ReplyTWTT < oWave.nBPingLimit;
    end
    
    % If this cuda has a "valid times" range, constrain the pings it can get
    if ~isnat(oWave.tableCudaCfg.DateFrom(iCuda))
        b = b & btwn( oWave.tableCudaCfg.DateFrom(iCuda) ...
                    , oWave.tableBenthos.Time ...
                    , oWave.tableCudaCfg.DateTo(iCuda) );
    end
    
    % Cut off any pings outside the tow times configured by the user. We don't
    % care about those pings
    b = b & ~isnan(cwave.IndexIntoTimeTable( oWave.tableTow, oWave.tableBenthos.Time ));
    
    % Pre-allocate the table
    tCuda{1:sum(b),:}   = missing();
    
    % Get the easy stuff
    tCuda.Time(:)       = oWave.tableBenthos.Time(b);
    tCuda.iCuda(:)      = iCuda;
    tCuda.TWTT(:)       = oWave.tableBenthos.ReplyTWTT(b);
    tCuda.PingNo(:)     = oWave.tableBenthos.PingNo(b);     % for debugging
    
    % Eliminate multiple replies per ping. These are bounces off the seasurface
    % or seafloor
    % NB: This is now done in SyncSUESILogs.m but I've left this code here
    % because it doesn't hurt anything
    [~,iKeep] = unique( tCuda.PingNo, 'rows', 'first' );
    if numel(iKeep) < height(tCuda)
        oWave.AddLog( cwave.LogOK, cwave.sLog_TxNavAction ...
            , sprintf('Barracuda %d: Deleted %d of %d pings as multiples' ...
                     , iCuda, height(tCuda)-numel(iKeep), height(tCuda) ) );
        tCuda = tCuda(iKeep,:);
    end
    clear b iKeep
    
    % Ensure pings are sorted by time
    tCuda = sortrows( tCuda, 'Time' );
    
    
    %% Get rid of the spurious scattered TWTT points
    %
    % NB: mad() vs std(): For these data, the distributions are generally very
    % far from gaussian so median & mad seem more appropriate than mean & std.
    % Note that mad() tends to be smaller than std() because of the broad
    % distribution of noisy TWTT points.
    %
    nMed    = median( tCuda.TWTT );
    nMult   = oWave.nMADfactor;
    nPM     = nMed + [-1 1] * nMult * mad( tCuda.TWTT );
    bDrop   = ~between( nPM, tCuda.TWTT );
    
    % Create a plot showing the distribution of ping data & what we're cutting
    % off through the use of median & mad
    sTitle = sprintf( 'Barracuda %d TWTT - keeping %d of %d data' ...
                    , iCuda, height(tCuda)-sum(bDrop), height(tCuda) );
    hFig = getStackedFig( [400 400], 'Name', sTitle );
    hAx  = axes( hFig );
    histogram( hAx, tCuda.TWTT, 'DisplayName', sprintf( '%g median TWTT', nMed ) );
    hold( hAx, 'on' );
    xline( hAx, nPM(1), 'LineWidth', 3, 'Color', 'k' ...
                      , 'DisplayName', sprintf('-%g*mad (%g s)', nMult, nPM(1)) );
    xline( hAx, nPM(2), 'LineWidth', 3, 'Color', 'k' ...
                      , 'DisplayName', sprintf('+%g*mad (%g s)', nMult, nPM(2)) );
    xlabel( 'TWTT (s)' );
    ylabel( 'Count' );
    title( hAx, {sTitle; oWave.sPlotSubtitle} );
    legend( hAx, 'Location', 'best' );
    addPlotMenu( hFig, fullfile( oWave.sPlotDir, sprintf( 'TxNav_Hist_Cuda%d', iCuda) ), 'Save' );
    delete( hFig ); % don't leave it up. User can look at it in plots folder.
    
    % Drop the data AFTER the plot
    if sum(bDrop) > 0
        oWave.AddLog( cwave.LogOK, cwave.sLog_TxNavAction ...
            , sprintf('Barracuda %d: %d of %d pings dropped: TWTT > (median +/- %g*MAD)' ...
                     , iCuda, sum(bDrop), numel(bDrop), nMult ) );
        tCuda(bDrop,:) = [];
    end
    
    
    %% Get the location of the barracuda at each time (ensure time is unique)
    tEN     = oWave.tableCudaGPS(oWave.tableCudaGPS.DeviceNo == nDevNo,{'Time','East','North'});
    nHtB4   = height( tEN );
    tEN     = sub_AvgByTime( tEN ); % sorts by time & avgs coeval GPS pts
    if height( tEN ) ~= nHtB4
        oWave.AddLog( cwave.LogOK, cwave.sLog_TxNavAction ...
            , sprintf('Barracuda %d: Averaged %d of %d contemporaneous GPS locations' ...
                     , iCuda, nHtB4-height(tEN), nHtB4 ) );
    end
    nEN = interp1( tEN.Time, tEN{:,{'East','North'}}, tCuda.Time, 'linear', NaN );
    tCuda.East(:)       = nEN(:,1); % Barracuda GPS location
    tCuda.North(:)      = nEN(:,2);
    tCuda(ismissing(tCuda.East) | ismissing(tCuda.North),:) = [];
    
    
    %% Interpolate SUESI & wire-zero info at each ping time
    % The following fields are being added to table tCuda
    cFlds = { 'Ewire', 'Nwire', 'Rsuesi', 'Esuesi', 'Nsuesi', 'Zsuesi' ...
            , 'Alt', 'COG', 'Dip', 'WireOut'};
        
    tCuda = [tCuda array2table( ...
        interp1( tWire0.Time, tWire0{:,cFlds}, tCuda.Time, 'linear', NaN ) ...
        , 'VariableNames', cFlds )];
    
    bDrop = isnan(tCuda.Zsuesi);
    if any(bDrop)
        oWave.AddLog( cwave.LogOK, cwave.sLog_TxNavAction ...
            , sprintf('Barracuda %d: %d of %d pings dropped - no SUESI depth' ...
                     , iCuda, sum(bDrop), numel(bDrop) ) );
        tCuda(bDrop,:) = [];
    end
    
    
    %% Drop points which are inside the "use ship-track" wire-out range
    bDrop = tCuda.WireOut <= oWave.nMinWireLBL;
    if any(bDrop)
        oWave.AddLog( cwave.LogOK, cwave.sLog_TxNavAction ...
            , sprintf('Barracuda %d: %d of %d pings dropped - wire-out < %g, using ship-track' ...
                     , iCuda, sum(bDrop), numel(bDrop), oWave.nMinWireLBL ) );
        tCuda(bDrop,:) = [];
    end
    
    
    %% Estimated horizontal range between the barracuda & suesi
    % Generate the sound velocity ray table(s) as needed
    iVelList = cwave.IndexIntoTimeTable( oWave.tableVProfile, tCuda.Time );
    for iVel = onerow( unique( iVelList ) )
        % Get the appropriate velocity table (make one if not there)
        [cRayTbl,iAt] = sub_GetRayTable( cRayTbl, oWave.cVProfile, iVel, nZ, nMaxR );
        
        % Prep the ray table for use along a different axis than normal
        %
        % stTable.nDepth  = z1 + [1:10 15:5:45 50:10:90 100:50:(ceil(max(v(:,1))/100)*100)];
        % stTable.nRange  = 0:50:maxR;    % 10s TWTT ~7500m.  Usually only get up to ~5 or 6s TWTT on Benthos....
        % stTable.nTWTT   = zeros(numel(stTable.nDepth), numel(stTable.nRange));
        %
        stRP        = cRayTbl{iAt,3};
        stRP.nDepth = repmat( onecol( stRP.nDepth ), 1, size(stRP.nTWTT,2) );
        stRP.nRange = repmat( stRP.nRange, size(stRP.nTWTT,1), 1 );
        
        % Calc horizontal range between the cuda & SUESI via table look up
        %
        % NB: the ray finding routine will go weird at around 10s and bunches of
        % entries at far ranges will have identical TWTT. I *think* this is
        % because we reach angles at which the sound waves totally reflect
        % within a layer so we're not reaching those longer horizontal ranges.
        % For the really deep tows (5-6km) the horizontal offsets should be
        % short enough to be OK but perhaps not. Not checking this right now.
        %
        % NB: Don't let the interpolator complain about duplicate points.
        %
        stWarn  = warning( 'off', 'MATLAB:scatteredInterpolant:DupPtsAvValuesWarnId' );
        oInterp = scatteredInterpolant( stRP.nTWTT(:), stRP.nDepth(:), stRP.nRange(:) );
        oInterp.ExtrapolationMethod = 'none';
        b = (iVelList == iVel);
        if all(b)
            tCuda.Range = oInterp( tCuda.TWTT, tCuda.Zsuesi );
        else
            tCuda.Range(b) = oInterp( tCuda.TWTT(b), tCuda.Zsuesi(b) );
        end
        warning( stWarn );
        
    end % loop through velocity-over-time tables
    
    %% Trim invalid horizontal ranges
    % The benthos system is actually rather crappy and returns many spurious
    % data points. In Scarborough phase 1, this was something like half of all
    % pings. In order to constrain this I need to impose some sort of limit on
    % the ranges obtainable. Arbitrarily I choose: Don't allow calculated
    % horizontal range between barracuda & SUESI to be larger than the wire-out
    % plus some percentage buffer to allow for slop in range. Don't allow this
    % to occur when SUESI is close to the ship (i.e. surface towing) because
    % then wire-out will be miniscule and horizontal range several hundred
    % meters
    bDrop = isnan(tCuda.Range) | (tCuda.Range > max(400,tCuda.WireOut * 1.05));
    
    % Drop pings outside the times covered or valid ranges
    if any(bDrop)
        oWave.AddLog( cwave.LogOK, cwave.sLog_TxNavAction ...
            , sprintf('Barracuda %d: %d of %d pings dropped - horizontal range > wire-out' ...
            , iCuda, sum(bDrop), numel(bDrop) ) );
        tCuda(bDrop,:) = [];
    end
    
    %% Log
    if isempty(tCuda)
        oWave.AddLog( cwave.LogWarn, cwave.sLog_TxNavAction ...
            , sprintf( 'Barracuda %d: no data', iCuda ) );
    else
        oWave.AddLog( cwave.LogOK, cwave.sLog_TxNavAction ...
            , sprintf( 'Barracuda %d: %d pings inside tow line start-stop times', iCuda, height(tCuda) ) );
    end
    
    return;
end % sub_GetCudaPings

%-------------------------------------------------------------------------------
function tblOut = sub_AvgByTime( tblIn )
    % Get the unique table (this also sorts by time)
    [~,iA,iC] = unique( tblIn.Time );
    
    % Early return if no duplicates
    if numel(iA) == numel(iC)
        tblOut = tblIn;
        return;
    end
    tblOut = tblIn(iA,:);
    
    % Avg all numeric variables
    cVars = tblOut.Properties.VariableNames( ...
        varfun( @isnumeric, tblOut, 'OutputFormat', 'uniform' ) );
    
    % Walk through the sets and average each
    nCnt = accumarray( iC, 1 );
    for iDest = onerow( find( nCnt > 1 ) )
        tblOut{iDest,cVars} = mean( tblIn{iC == iDest,cVars} );
    end
    
    return;
end % sub_AvgByTime

%-------------------------------------------------------------------------------
% Add a block of triangulation data to the nav estimate table
function tNav = sub_AddToNav( tIn, nENEN, tNav )
    arguments
        tIn         table
        nENEN (:,4) double
        tNav        table
    end
    
    if isempty( tIn )
        return;
    end
    
    % Add the valid items to the table
    iFromTo                     = (1:height(tIn)) + height(tNav);
    tNav{iFromTo,:}             = missing();
    tNav.Time(iFromTo)          = tIn.Time;
    tNav.Altitude(iFromTo)      = tIn.Alt;
    tNav.Depth(iFromTo)         = tIn.Zsuesi;
    tNav.COG(iFromTo)           = mod( tIn.COG, 360 );
    tNav.Dip(iFromTo)           = tIn.Dip;
    tNav.Wire0_E(iFromTo)       = tIn.Ewire;
    tNav.Wire0_N(iFromTo)       = tIn.Nwire;
    tNav.ShipTrack_E(iFromTo)   = tIn.Esuesi; % estimated position using ship pos, ship COG, wire-out, & Suesi Z
    tNav.ShipTrack_N(iFromTo)   = tIn.Nsuesi;
    
    % Which of the two triangulation points returned is closet to the
    % approximate SUESI location along the ship track? Pick that one of each
    % pair
    %
    % NB: These are SUESI locations, NOT the antenna mid-point
    %
    % NB: don't need to use sqrt() because I don't care about the actual
    % distance just which is closer. Save some time by ignoring sqrt() on both
    % numbers.
    %
    bFirst = ((nENEN(:,1) - tIn.Esuesi).^2 + (nENEN(:,2) - tIn.Nsuesi).^2) ...
           < ((nENEN(:,3) - tIn.Esuesi).^2 + (nENEN(:,4) - tIn.Nsuesi).^2);
       
    % 1st pt is closer to ship-track
    tNav.Ping_E(iFromTo(bFirst)) = nENEN(bFirst,1);
    tNav.Ping_N(iFromTo(bFirst)) = nENEN(bFirst,2);
    
    % 2nd pt is closer to ship-track
    bFirst = ~bFirst;   % negate this once instead of 4 times below
    tNav.Ping_E(iFromTo(bFirst)) = nENEN(bFirst,3);
    tNav.Ping_N(iFromTo(bFirst)) = nENEN(bFirst,4);
    
    return;
end % sub_AddToNav

%-------------------------------------------------------------------------------
% Smooth the given path, being aware that there may be jumps in time
%
% I (DGM) developed the following smoothing procedure after a lot of
% experimentation & examination of data. One thing that happens all the time is
% that pings end up in front of and behind their neighbor pings along track as
% if SUESI is jumping forward and backward in the water. Sometimes this is only
% a meter or two, sometimes it is 100s of meters. There're a lot of trash pings
% and more uncertainty in the TWTT than people admit.
%
% I found that I can get rid of most of the trash pings by looking at the vector
% angle from wire0 to the ping and excluding those which fall outside of
% median+/-MAD. This ASSUMES the towline is relatively straight but allows for
% some curvature and for SUESI to be pushed off to the side by bottom currents.
%
% Once I've eliminated the bulk of the outliers, there are still smaller
% annoying outliers which are harder to eliminate. So, rather than trying to
% smooth the ping E,N (with, e.g. smoothdata()), which will expand or contract
% the line in the inline direction (which is bad), I rotate the initial estimate
% locations (which were put in the ship track) around poles set by the wire0
% locations. This is valid because SUESI is connected to the ship by a wire
% whose upper end is at wire0. At each point in time, SUESI will be somewhere on
% the arc scribed by the end of the wire rotating on wire0. Yes, the cable may
% sag (especially in very deep tows) but it will be straight enough that for
% most tows such that the range error will be a handful of meters.
%
% Also, the original est points are already constrained by the motion of the
% ship because they are derived from the ship's GPS, which is highly accurate.
% So I don't have to worry about something like smoothdata shifting points along
% the line and giving invalid velocities (see Chesley's PhD dissertation and the
% difficulties she had with that).
%
% I use a brute-force method for finding the optimal smoothing window length -
% where "optimal" = minimizes the point-to-point rotation angle differences in
% order to reduce jaggies. This is better than rotating the data to inline &
% crossline and smoothing the crossline because it gets a solution that more
% closely follows the arc of pings over time.
%
function tNav = sub_SmoothPath( oWave, tAllPing, oProg )
    arguments
        oWave       cwave
        tAllPing    table
        oProg       matlab.ui.dialog.ProgressDialog
    end
    
    % Does the user have the stats toolbox? If not, heave a big sigh
    bStatsToolbox = license('test','statistics_toolbox');
    
    % Create the figure for the smoothing-window solver's results. I don't keep
    % them all up on the screen because it can be a bunch of clutter. Results
    % can easily be loaded from the _Plots folder.
    sCancel = 'User canceled the process';
    hFigSearch = getStackedFig('pptHD');
    hAx1 = subplot(2,1,1, 'Parent', hFigSearch);
    hAx2 = subplot(2,1,2, 'Parent', hFigSearch );
    
    % Create the output table
    tNav = cwave.GetDfltFor( 'tableTxNav' );
    
    % Use the tow table so that smoothing doesn't have to deal with the sudden
    % change in direction that occurs between different tows.
    %
    % NB: pings outside of all tow times have already been deleted
    %
    iTowIdx = cwave.IndexIntoTimeTable( oWave.tableTow, tAllPing.Time );
    iIdxList = onerow( unique( iTowIdx ) );
    iIdxList(isnan(iIdxList)) = [];
    assert( ~isempty( iIdxList ), 'No data within tow times' );
    
    % Do each tow independently - their directions may vary wildly and I don't
    % want a sliding window to catch the end of one and the beginning of another
    for iWhichTow = iIdxList
        assert( ~oProg.CancelRequested, sCancel );
        
        tPing = tAllPing(iTowIdx == iWhichTow,:);
        tPing = sortrows( tPing, 'Time' );
        tPing.TowNo(:)  = oWave.tableTow.TowNo(iWhichTow);
        nFixedWind      = oWave.tableTow.SmoothSec(iWhichTow);
        
        % What are the vectors from wire0 to SUESI's ping-triangulated location?
        nTheta = atan2d( tPing.Ping_N - tPing.Wire0_N, tPing.Ping_E - tPing.Wire0_E );
        
        % Run a filter through the theta angles and eliminate points
        % which are outside +/-MAD from the median of the difference between
        % theta and the median filter of theta. (NB: median( th - medfilt(th) )
        % s/b close to zero if the line is relatively straight & the median
        % filter length is short)
        %
        % nThDiff = phaseDiff( nTheta, runFilt( nTheta, nFiltSize, @median ), 'Deg' );
        % nMed    = median( nThDiff );
        % nMAD    = mad( nThDiff );
        % bDrop   = ~between( nMed + [-nMAD nMAD], nThDiff );
        %
        % NB: It works better to fit a line and look at deviation from that line
        % than to use a filter. Filters are susceptible to filter length
        % problems and bias from sections of the line where, say, there is only
        % one cuda+ship instead of 2 cudas.
        %
        nSec  = seconds(tPing.Time - tPing.Time(1));
        if bStatsToolbox
            nBMx  = robustfit( nSec, nTheta );
            nTh2  = [ones(size(nSec)) nSec] * nBMx;
        else
            nSec(:,2) = 1;  % form Vandermonde matrix for: theta = time * m + b
            nMxB      = nSec \ nTheta;
            nTh2      = nSec * nMxB;
            nSec(:,2) = [];
        end
        nDiff = phaseDiff( nTh2, nTheta, 'D' );
        bDrop = ~between( median(nDiff) + [-2 2]*mad(nDiff), nDiff );
        
        if any(bDrop)
            tPing(bDrop,:) = [];
            nTheta(bDrop)  = [];
            nSec(bDrop,:)  = [];
            
            oWave.AddLog( cwave.LogOK, cwave.sLog_TxNavAction ...
                , sprintf( 'Tow %d - dropped %d of %d points --> wire0 angle > 2*(median +/- MAD)' ...
                         , oWave.tableTow.TowNo(iWhichTow), sum(bDrop), numel(bDrop) ) );
        end
        clear nThDiff nMed nMAD bDrop
        
        % How many degrees should each vector from wire0 to ship-track-suesi-est
        % be rotated to line it up (approximately) with the wire0-to-ping vec?
        nThEst = atan2d( tPing.ShipTrack_N - tPing.Wire0_N, tPing.ShipTrack_E - tPing.Wire0_E );
        nThCh1 = nThEst - nTheta;
        
        % Rather than applying a fixed length smoothing window, search for one
        % which minimizes the point-to-point differences in the angle of
        % rotation. This is, recall, the angle that will rotate the smooth
        % ship-track estimate towards the pings. Minimizing differences will
        % minimize jaggies in the final path.
        %
        % NB: smoothdata() leaves a lot of jaggies in for some reason. My simple
        % running mean filter does much better
        %
        bForced = logical(tPing.Forced);
        if ~all(bForced)
            % NB: tableTow allows for the user to choose a particular window
            % width. Run the solver anyway (it's fast) so that they can see how
            % their chosen length stacks up with the rest
            nWindList = 120:60:7200; % hard-coded window half-widths to try
            if ~isnan(nFixedWind)
                nWindList = unique( [nWindList nFixedWind] );   % make sure it's in the list
            end
            nPctOut = [];
            for nWindSec = nWindList
                % nThChg = smoothdata( nThCh1, 'rlowess', nWindSec, 'SamplePoints', nSec );
                nThChg = runFiltNonUniform( nSec, nThCh1, nWindSec, @mean, false );
                dt = diff(nThChg);
                nPctOut(1,end+1) = sum( abs(dt - mean(dt)) > std(dt) ) / numel(dt) * 100;
            end
            if isnan(nFixedWind)
                [~,iMin] = min(nPctOut);
            else
                iMin = find( nWindList == nFixedWind, 1, 'first' );
            end
            nWindSec = nWindList(iMin);
            fprintf( 'Tow %d - Smoothing window %d s yields %.1f %% of angle variance within 1 std\n' ...
                , tPing.TowNo(1), nWindSec, nPctOut(iMin) );
            % nThChg = smoothdata( nThCh1, 'rlowess', nWindSec, 'SamplePoints', nSec );
            nThChg = runFiltNonUniform( nSec, nThCh1, nWindSec, @mean, false );
            
            plot( hAx1, nWindList, nPctOut, '.', nWindSec, nPctOut(iMin), 'o' );
            title( hAx1, sprintf( 'Tow %d - Half-width smoothing window', tPing.TowNo(1) ) );
            xlabel( hAx1, 'Filter Width (s)' );
            ylabel( hAx1, 'Pct |diff(d)-mean(d)| > std(diff(d))' );
            axisTight( hAx1 );
            axisTicksUTM( hAx1, 'x' );
            
            plot( hAx2, nSec, nThCh1, '.', nSec, nThChg, '.' );
            ylabel( hAx2, 'Angle change' );
            xlabel( hAx2, 'Seconds along tow' );
            title( hAx2, sprintf( 'Filter = %d s', nWindSec ) );
            axisTight( hAx2 );
            axisTicksUTM( hAx2, 'x' );
            
            addPlotMenu( hFigSearch ...
                , fullfile( oWave.sPlotDir, sprintf( 'TxNav_WindowSearch_Tow%02d', tPing.TowNo(1) ) ) ...
                , 'Save' );
        end
        
        % Don't change those pts which are supposed to be affixed to the
        % shiptrack by the min wire-out length or tableTow.IgnoreNav flag
        nThChg(bForced) = 0; 
        
        % Rotate the initial guesstimates (SUESI in the ship-track) around each
        % wire0 to line up with pings
        nENwire     = tPing{:,{'Wire0_E', 'Wire0_N'}};
        nENStart    = tPing{:,{'ShipTrack_E', 'ShipTrack_N'}};
        nENest      = nENStart - nENwire;
        parfor i = 1:size(nENest,1)
            d           = nThChg(i);
            nENest(i,:) = nENest(i,:) * [cosd(d) -sind(d);sind(d) cosd(d)];
        end
        nENest      = nENest + nENwire;
        
        % Store the smoothed location estimates
        tPing.Smooth_E = nENest(:,1);
        tPing.Smooth_N = nENest(:,2);
        
        % Copy to the output table
        iFromTo = (1:height(tPing)) + height(tNav);
        tNav(iFromTo,:) = tPing;
        
        % What is the mean dist between the solution and raw pings?
        nR_EstVsPing = sqrt( sum( (tPing{:,{'Ping_E', 'Ping_N'}} - nENest).^2, 2 ) );
        
        % Log what happened
        sMsg = sprintf( 'Tow %d (%d pts)::range(Soln - Ping) mean = %.1f m, median = %.1f m, std = %.1f m' ...
            , oWave.tableTow.TowNo(iWhichTow), height(tPing) ...
            , mean( nR_EstVsPing ), median( nR_EstVsPing ), std( nR_EstVsPing ) );
        oWave.AddLog( cwave.LogOK, cwave.sLog_TxNavAction, sMsg );
        disp( sMsg );
        
    end % Loop through tow line segments
    
    % Drop the results figure
    delete( hFigSearch );
    
    % Make sure the table is sorted
    tNav            = sortrows( tNav, 'Time' );
    tNav.Suesi_Z    = tNav.Depth;
    
    return;
end % sub_SmoothPath

%-------------------------------------------------------------------------------
% Plot SUESI (not antenna mid-point) loc: est, pings, smoothed track.
% This is a QC plot
function sub_PlotSUESIPingMap( oWave, tWire0, tNav )
    hPMap = getStackedFig( 'pptHD', 'Name', 'TX iLBL Nav - SUESI location (*not mid-antenna*)' );
    hAx = axes( hPMap );
    
    % Plot the entire ship-track (projected to wire-0) for reference
    %
    % NB: The SUESI guesstimate is back in the ship's track by a horizontal
    % distance calculated from SUESI's depth and wire-out (assuming the wire is
    % ramrod-straight). This is the entire path, not just the segments within
    % each tow time. It provides info about where the ship went during the
    % entire time and orients the user
    nClrs       = DavesDiscreteColors( height( oWave.tableTow ) + 1, @hsv );
    plot( hAx, tWire0.Esuesi, tWire0.Nsuesi, '.', 'Color', nClrs(end,:) ...
        , 'DisplayName', 'Est from Shiptrack', 'MarkerSize', 6 );
    hold( hAx, 'on' );
    
    % Plot each tow's triangulated & smoothed path in its own color
    %
    % NB: if there are a lot of tow lines then use hsv instead of turbo because
    % turbo has one end very similar to black
    iSmoothTow  = cwave.IndexIntoTimeTable( oWave.tableTow, tNav.Time );
    for iTow = 1:height( oWave.tableTow )
        bSmooth = (iSmoothTow == iTow);
        
        plot( hAx, tNav.Ping_E(bSmooth), tNav.Ping_N(bSmooth) ...
            , 'Color', nClrs(iTow,:), 'Marker', '.', 'LineStyle', 'none' ...
            , 'DisplayName', sprintf( 'Tow %d triangulations', oWave.tableTow.TowNo(iTow) ) ...
            );
        
        h = plot( hAx, tNav.Smooth_E(bSmooth), tNav.Smooth_N(bSmooth) ...
            , 'Color', 'k', 'Marker', 'none', 'LineStyle', '-' ...
            , 'DisplayName', 'Solution' );
        if iTow < height( oWave.tableTow )
            legendoff( h );
        end
    end
    
    % Cleanup
    legend( hAx, 'Location', 'best' );
    hold( hAx, 'off' );
    axis( hAx, 'equal' );
    axisTight( hAx );
    axisTicksUTM( hAx );
    xlabel( hAx, ['Easting (km) - ' oWave.sUTMZoneDisp] );
    ylabel( hAx, 'Northing (km)' );
    title( hAx, {
        'TX iLBL Nav - SUESI location (*not mid-antenna*)'
        oWave.sPlotSubtitle
        } );
    addPlotMenu( hPMap, fullfile( oWave.sPlotDir, 'TxNav_PingMap_UTM' ), 'Save' );
    
    return;
end % sub_PlotSUESIPingMap

%-------------------------------------------------------------------------------
% Create the tow uncertainty plots for each tow line as well as the composite
% plot showing inline & crossline uncertainties for each line
function sub_PlotTowUncert( oWave, tNavAll )
    % Create the per-tow figure & its sub-plots
    hFig    = getStackedFig( 'ppt' );
    hAx(1)  = subplot( 3, 6, 1:3, 'Parent', hFig );
    hAx(2)  = subplot( 3, 6, 7:9, 'Parent', hFig );
    hMap    = subplot( 3, 6, [4:6 10:12], 'Parent', hFig );
    hIn     = subplot( 3, 6, 13:14, 'Parent', hFig );
    hCr     = subplot( 3, 6, 15:16, 'Parent', hFig );
    hTx     = subplot( 3, 6, 17:18, 'Parent', hFig );
    
    % Variables to hold data for the composite figure at the end
    nErrIn  = zeros( height(oWave.tableTow), 1 );
    nErrCr  = zeros( height(oWave.tableTow), 1 );
    
    fprintf( '\n----------------------------------\nNavigation Uncertainties from iLBL\n  Tow Inline Crossline\n' );
    
    % Plot a separate figure for each tow
    iTowIdx = cwave.IndexIntoTimeTable( oWave.tableTow, tNavAll.Time );
    for iTow = 1:height(oWave.tableTow)
        bThis = (iTowIdx == iTow);
        if ~any(bThis)
            continue;
        end
        tNav = tNavAll(bThis,:);
        
        % The data need to be rotated into inline & crossline - which
        % necessarily assumes a straight towline. C'est la vie. Use a
        % counter-clockwise rotation to "undo" the line orientation
        nTowOrient  = oWave.tableTow.DirEofN(iTow);
        nRot        = [ cosd(nTowOrient) sind(nTowOrient)
                       -sind(nTowOrient) cosd(nTowOrient)];
        nCtr        = mean( tNav{:,{'Smooth_E','Smooth_N'}} );
        
        nIC         = (tNav{:,{'Ping_E','Ping_N'}} - nCtr) * nRot;
        nEstCross   = nIC(:,1);
        nEstIn      = nIC(:,2);
        nIC         = (tNav{:,{'Smooth_E','Smooth_N'}} - nCtr) * nRot;
        nNavCross   = nIC(:,1);
        nNavIn      = nIC(:,2);
        clear nRot nEN
        
        bNotForced  = ~logical(tNav.Forced);
        nDiffIn     = nNavIn(bNotForced) - nEstIn(bNotForced);
        nDiffCr     = nNavCross(bNotForced) - nEstCross(bNotForced);
        
        % NB: uncertainties calculated based on 2021 Key & Constable
        %     doi: 10.1007/s11001-021-09427-z
        nErrIn(iTow)= round( 1.4826 * mad( nDiffIn ), 1 );
        nErrCr(iTow)= round( 1.4826 * mad( nDiffCr ), 1 );
        fprintf( '  %3d %6.1f %9.1f\n', oWave.tableTow.TowNo(iTow), nErrIn(iTow), nErrCr(iTow) );
        
        % Setup strings based on tow #
        sDesc = sprintf( 'Tow %d - %.1f EofN', oWave.tableTow.TowNo(iTow) ...
                       , nTowOrient );
        sFile = sprintf( 'TxNav_Uncert_Tow%d', oWave.tableTow.TowNo(iTow) );
        
        % Crossline vs time
        plot( hAx(1), tNav.Time, nNavCross, '.' );
        axisTight( hAx(1) );
        title( hAx(1), {sDesc;'Crossline Set'} );
        ylabel( hAx(1), 'Crossline Set (m)' );
        
        % Velocity vs time
        dT     = seconds( diff(tNav.Time) );
        nVship = sqrt( diff( tNav.Wire0_E ).^2  + diff( tNav.Wire0_N ).^2 )  ./ dT;
        nVest  = sqrt( diff( tNav.Ping_E ).^2   + diff( tNav.Ping_N ).^2 )   ./ dT;
        nVnav  = sqrt( diff( tNav.Smooth_E ).^2 + diff( tNav.Smooth_N ).^2 ) ./ dT;
        nVship(end+1) = nVship(end);
        nVest(end+1)  = nVest(end);
        nVnav(end+1)  = nVnav(end);
        
        plot( hAx(2), tNav.Time, nVest, '.b', 'DisplayName', 'SUESI velocity (Pings)' );
        hold( hAx(2), 'on' );
        plot( hAx(2), tNav.Time, nVnav, '.r', 'DisplayName', 'SUESI velocity (Smoothed)' );
        plot( hAx(2), tNav.Time, nVship, '.k', 'DisplayName', 'Ship Velocity' );
        hold( hAx(2), 'off' );
        axisTight( hAx(2) );
        ylabel( hAx(2), 'Velocity (m/s)' );
        legend( hAx(2), 'Location', 'best' );
        linkaxes( hAx, 'x' );
        
        % Map
        plot( hMap, tNav.Ping_E   / 1000, tNav.Ping_N   / 1000, 'DisplayName', 'Ping' );
        hold( hMap, 'on' );
        plot( hMap, tNav.Wire0_E  / 1000, tNav.Wire0_N  / 1000, 'DisplayName', 'Wire 0' );
        plot( hMap, tNav.Smooth_E / 1000, tNav.Smooth_N / 1000, '-', 'DisplayName', 'Solution' );
        hold( hMap, 'off' );
        axis( hMap, 'equal' );
        xlabel( hMap, 'Easting (km)' );
        % ylabel( hMap, 'Northing (km)' );
        legend( hMap, 'Location', 'best' );
        
        % Uncertainty histograms & estimate
        hHist = histogram( hIn, nDiffIn );
        sub_Gaussian( hHist );
        title( hIn, 'Inline' );
        xlabel( hIn, 'Smooth - Rough' );
        ylabel( hIn, 'Count' );
        
        hHist = histogram( hCr, nDiffCr );
        sub_Gaussian( hHist );  % overlay an ideal gaussian distribution
        title( hCr, 'Crossline' );
        xlabel( hCr, 'Smooth - Rough' );
        ylabel( hCr, 'Count' );
        
        % Texts of the uncertainties
        cla( hTx ); % remove previous texts
        hTx.XLim    = [0 1];
        hTx.YLim    = [0 1];
        hTx.XTick   = [];
        hTx.YTick   = [];
        hTx.Box     = 'on';
        text( hTx, 0.5, 0.5, {
            ' '
            'Uncertainties (1.4826 * MAD)'  % see doi: 10.1007/s11001-021-09427-z
            sprintf( 'Inline: %.1f m', nErrIn(iTow) )
            sprintf( 'Crossline: %.1f m', nErrCr(iTow) )
            ' '
            }, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle' );
        
        % Finalize the figure & save a copy to disk
        addPlotMenu( hFig, fullfile( oWave.sPlotDir, sFile ), 'Save' );
        
    end % loop through tows
    fprintf( '----------------------------------\n' );
    
    % Get rid of the per-tow figure. The user can go look at the copies on disk
    delete( hFig );
    
    % Create the composite figure
    hFigAll = getStackedFig( [750 750] );
    hErrIn  = subplot( 1, 2, 1, 'Parent', hFigAll );
    sTxt    = strcat( "  ", string(num2str(nErrIn)) );
    nErrIn(isnan(nErrIn)) = 0;
    plot( hErrIn, nErrIn, oWave.tableTow.TowNo, 'or' );
    text( hErrIn, nErrIn, oWave.tableTow.TowNo, sTxt ...
        , 'FontSize', cwave.FontSize ...
        , 'Interpreter', 'none', 'HorizontalAlignment', 'left' );
    title( hErrIn, 'Inline' );
    xlabel( hErrIn, 'Uncertainties (m)' );
    ylabel( hErrIn, 'Tow Number' );
    axisTight( hErrIn );
    hErrIn.XLim(1) = 0;
    hErrIn.YTick = sort( oWave.tableTow.TowNo );
    hErrIn.YDir = 'reverse';
    
    hErrCr  = subplot( 1, 2, 2, 'Parent', hFigAll );
    sTxt    = strcat( "  ", string(num2str(nErrCr)) );
    nErrCr(isnan(nErrCr)) = 0;
    plot( hErrCr, nErrCr, oWave.tableTow.TowNo, 'or' );
    text( hErrCr, nErrCr, oWave.tableTow.TowNo, sTxt ...
        , 'FontSize', cwave.FontSize ...
        , 'Interpreter', 'none', 'HorizontalAlignment', 'left' );
    title( hErrCr, 'Crossline' );
    xlabel( hErrCr, 'Uncertainties (m)' );
    ylabel( hErrCr, 'Tow Number' );
    axisTight( hErrCr );
    hErrCr.XLim(1) = 0;
    hErrCr.YTick = sort( oWave.tableTow.TowNo );
    hErrCr.YDir = 'reverse';
    
    sgtitle( hFigAll, 'SUESI Navigation Uncertainties' );
    
    addPlotMenu( hFigAll, fullfile( oWave.sPlotDir, 'TxNav_Uncert_All' ), 'Save' );
    
    return;
end % sub_PlotTowUncert

%-------------------------------------------------------------------------------
% Overlay the given histogram plot object with an ideal gaussian made from its
% data distribution
function hLn = sub_Gaussian( hHist )
    arguments
        hHist   matlab.graphics.chart.primitive.Histogram
    end
    
    hold( hHist.Parent, 'on' );
    s = std(hHist.Data);
    m = mean(hHist.Data);
    g = exp(-(hHist.BinEdges - m).^2/(2*s^2))/sqrt(2*pi()*s^2);
    g = g * numel(hHist.Data) * diff(hHist.BinEdges(1:2));
    hLn = plot( hHist.Parent, hHist.BinEdges, g, ':', 'linewidth', 2 ...
        , 'Color', 'r' ...
        , 'DisplayName', sprintf( 'Ideal gaussian m=%g s=%g', m, s ) );
    hold( hHist.Parent, 'off' );
    return;
end % sub_Gaussian

%-------------------------------------------------------------------------------
% Navigate the CTET pings, if any
function tTet = sub_NavTET( oWave, tNavSue, cRayTbl, nMaxR, oProg )
    arguments
        oWave   cwave
        tNavSue table
        cRayTbl cell
        nMaxR   double
        oProg   matlab.ui.dialog.ProgressDialog
    end
    sCancel = 'User canceled the process';
    
    %
    % NB: "C"TET is a fixed distance behind SUESI. It is the ONLY TET which is
    %   actually a sonar transponder. The others (e.g. ATET, BTET, Vulcans) may
    %   talk to SUESI over cable and then SUESI reports their depth with the
    %   w=[]... lines.
    %
    % NB: CTET works like this: SUESI pings it on freq X, it responds on freq Y
    %   which happens to be the interrogation freq for the barracudas. The
    %   barracudas reply as if SUESI were pinging them. So SUESI hears...
    %       (a) the direct reply from the TET (TWTT)
    %       (b) the replies from the barracudas responding to the TET where the
    %       time here is circuit TT: suesi -> tet -> barracuda -> suesi
    %   To get the TWTT between the TET & barracudas, we multiply (b) * 2, then
    %   subtract (a) and the TWTT between the barracudas & SUESI
    %
    
    % Find all TET pings - they have a dedicated frequency
    tPing = oWave.tableBenthos(oWave.tableBenthos.PingFreq == oWave.nCListenFreq,:);
    oWave.AddLog( cwave.LogOK, cwave.sLog_TxNavAction ...
        , sprintf('TET: %d total direct replies', height( tPing ) ) );
    % Don't exit early. Need "forced" locations added for some tows
    %     if height(tPing) == 0
    %         return;
    %     end
    assert( ~oProg.CancelRequested, sCancel );
    
    % Drop any TET pings outside of tow times in oWave.tableTow
    %
    % Also drop pings for tows which are entirely forced into the ship track
    %
    iTowIdx = cwave.IndexIntoTimeTable( oWave.tableTow, tPing.Time );
    bDrop   = isnan(iTowIdx);
    if any(bDrop)
        tPing(bDrop,:)  = [];
        iTowIdx(bDrop)  = [];
        oWave.AddLog( cwave.LogOK, cwave.sLog_TxNavAction ...
            , sprintf('TET: dropped %d of %d pings - outside tow times' ...
            , sum(bDrop), numel(bDrop) ) );
    end
    bDrop = round(oWave.tableTow.IgnoreNav(iTowIdx)) ~= 0;
    if any(bDrop)
        tPing(bDrop,:)  = [];
        iTowIdx(bDrop)  = [];
        oWave.AddLog( cwave.LogOK, cwave.sLog_TxNavAction ...
            , sprintf('TET: dropped %d of %d pings - tows forced into shiptrack' ...
            , sum(bDrop), numel(bDrop) ) );
    end
    tPing.TowIdx = iTowIdx;
    assert( ~oProg.CancelRequested, sCancel );
    clear bDrop iTowIdx
    
    % There's a lot of garbage in barracuda nav so eliminate all pings whose
    % TWTT does not fit the KNOWN FIXED distance between SUESI & CTET. Use the
    % min & max velocities
    nMinV = Inf;
    nMaxV = -Inf;
    for iVel = 1:numel(oWave.cVProfile)
        tZV = oWave.cVProfile{iVel};
        nMinV = min( [nMinV; tZV.Velocity] );
        nMaxV = max( [nMaxV; tZV.Velocity] );
    end
    nMinTWTT = (oWave.nCDist / nMinV) * 0.95 * 2;   % back off x% to be generous about TWTT uncertainties
    nMaxTWTT = (oWave.nCDist / nMaxV) * 1.05 * 2;
    bDrop = ~btwn( nMinTWTT, tPing.ReplyTWTT, nMaxTWTT );
    if any(bDrop)
        tPing(bDrop,:)  = [];
        oWave.AddLog( cwave.LogOK, cwave.sLog_TxNavAction ...
            , sprintf('TET: dropped %d of %d - outside TWTT [%.4f,%.4f] from known range %g' ...
                    , sum(bDrop), numel(bDrop), nMinTWTT, nMaxTWTT, oWave.nCDist ) );
    end
    assert( ~oProg.CancelRequested, sCancel );
    clear nMinV nMaxV iVel nZV bDrop
    
    % Drop any pings which don't have barracuda replies
    %
    % NB: multiple replies were eliminated in the SyncSUESILogs.m
    %
    % NB2: the replies all have PingFreq == nCListenFreq. Can't filter on that
    %
    tReply = oWave.tableBenthos;
    tReply(isnan(cwave.IndexIntoTimeTable( oWave.tableTow, tReply.Time )),:) = []; % not in tow times
    tReply(~ismember( tReply.PingNo, tPing.PingNo ),:) = [];    % not replies to CTET ping
    bDrop = ~ismember( tPing.PingNo, tReply.PingNo );
    if any(bDrop)
        tPing(bDrop,:)  = [];
        oWave.AddLog( cwave.LogOK, cwave.sLog_TxNavAction ...
            , sprintf('TET: dropped %d of %d - no barracuda replies to CTET ping' ...
                    , sum(bDrop), numel(bDrop) ) );
    end
    assert( ~oProg.CancelRequested, sCancel );
    clear bDrop
    
    % Copy ping info to each reply. Don't need separate ping table below
    tPing  = renamevars( tPing,  {'ReplyTWTT'}, {'CTET_TWTT'} );
    tReply = renamevars( tReply, {'ReplyTWTT'}, {'CircuitTT'} );
    tReply = innerjoin( tReply, tPing, 'Keys', 'PingNo' ...
        , 'RightVariables', {'TowIdx', 'CTET_TWTT'} );
    clear tPing iTowIdx
    
    % Add other variables to the reply table and make sure it's sorted by time
    cNewVars = {'CudaE', 'CudaN', 'DucerZ', 'Wire0E', 'Wire0N', 'iVelList' ...
        , 'SuesiE', 'SuesiN', 'SuesiZ', 'Forced', 'TowNo' ...
        , 'RangeH', 'Suesi_TWTT' ... suesi-to-barracuda range & twtt
        , 'Range',        'TWTT' ... barracuda-to-TET range & TWTT
        , 'TetE', 'TetN', 'TetAngle' ...
        };
    tTemp  = table( 'Size', [0 numel(cNewVars)] ... don't set height here. Won't fill with missing()
                    , 'VariableNames', cNewVars ...
                    , 'VariableTypes', repmat({'double'},1,numel(cNewVars)) );
    tReply = [tReply copytable( tTemp, height(tReply)) ];
    tReply = sortrows( tReply, 'Time' );
    tReply.TowNo(:) = oWave.tableTow.TowNo(tReply.TowIdx);
    
    % For each barracuda setup (which may change over time), interpolate the
    % barracuda GPS locations
    for iCuda = 1:height( oWave.tableCudaCfg )
        % Find replies either by freq or channel and if this cuda has a finite
        % time range, constrain to only those replies within the range
        if isnan( oWave.tableCudaCfg.ReplyFreq(iCuda) )
            b = tReply.ReplyCh  == oWave.tableCudaCfg.ReplyCh(iCuda) ...
              & tReply.CircuitTT < oWave.nBPingLimit;
        else
            b = tReply.ReplyFreq == oWave.tableCudaCfg.ReplyFreq(iCuda) ...
              & tReply.CircuitTT < oWave.nBPingLimit;
        end
        if ~isnat(oWave.tableCudaCfg.DateFrom(iCuda))
            b = b & btwn( oWave.tableCudaCfg.DateFrom(iCuda) ...
                        , tReply.Time ...
                        , oWave.tableCudaCfg.DateTo(iCuda) );
        end
        if ~any(b)
            continue;
        end
        
        % Interpolate the barracuda's location
        tEN = oWave.tableCudaGPS(oWave.tableCudaGPS.DeviceNo == oWave.tableCudaCfg.DeviceNo(iCuda) ...
            , {'Time','East','North'} );
        tEN = sub_AvgByTime( tEN ); % sorts by time & avgs coeval GPS pts
        nEN = interp1( tEN.Time, tEN{:,{'East','North'}}, tReply.Time(b), 'linear', NaN );
        tReply.CudaE(b)     = nEN(:,1); % Barracuda GPS location
        tReply.CudaN(b)     = nEN(:,2);
        tReply.DucerZ(b)    = oWave.tableCudaCfg.DucerDepth(iCuda); % ducer depth doesn't vary
        
    end % loop through barracuda configurations
    assert( ~oProg.CancelRequested, sCancel );
    clear iCuda b tEN nEN tTetZ 
    
    % Points without CudaE/N data are the TET's reply. Drop them
    bDrop = ismissing( tReply.CudaE );
    if any(bDrop)
        tReply(bDrop,:)  = [];
        oWave.AddLog( cwave.LogOK, cwave.sLog_TxNavAction ...
            , sprintf('TET: dropped %d of %d - self reply' ...
                    , sum(bDrop), numel(bDrop) ) );
    end
    
    % Interpolate SUESI's navigated location & retrieve the 'Forced' flag. This
    % flag will only be set for those points whose wire-out is < the "surface
    % tow" limit. Pings for tows entirely marked "IgnoreNav" have already been
    % removed above
    nENZ = interp1( tNavSue.Time ...
        , tNavSue{:,{'Wire0_E', 'Wire0_N', 'Smooth_E','Smooth_N','Depth'}} ...
        , tReply.Time, 'linear', NaN );
    tReply.Wire0E = nENZ(:,1);
    tReply.Wire0N = nENZ(:,2);
    tReply.SuesiE = nENZ(:,3);
    tReply.SuesiN = nENZ(:,4);
    tReply.SuesiZ = nENZ(:,5);
    tReply.Forced = interp1( tNavSue.Time, tNavSue.Forced, tReply.Time, 'nearest', 0 );
    assert( ~oProg.CancelRequested, sCancel );
    
    % Drop any reply pings which don't have a cuda or suesi location - these are
    % not recognized barracuda configs
    bDrop = ismissing(tReply.CudaE) | ismissing(tReply.SuesiE);
    if any(bDrop)
        tReply(bDrop,:)  = [];
        oWave.AddLog( cwave.LogOK, cwave.sLog_TxNavAction ...
            , sprintf('TET: dropped %d of %d - no barracuda and/or SUESI location data' ...
                    , sum(bDrop), numel(bDrop) ) );
    end
    assert( ~oProg.CancelRequested, sCancel );
    clear bDrop
    
    % Calc horizontal range between SUESI and barracuda
    tReply.RangeH ...
        = sqrt( (tReply.SuesiE - tReply.CudaE).^2 ...
              + (tReply.SuesiN - tReply.CudaN).^2 );
    
    % Use the velocity tables (varying with time) to calculate the TWTT between
    % each cuda & SUESI
    stWarn  = warning( 'off', 'MATLAB:scatteredInterpolant:DupPtsAvValuesWarnId' );
    tReply.iVelList = cwave.IndexIntoTimeTable( oWave.tableVProfile, tReply.Time );
    [tVZ,~,iC] = unique( tReply(:,{'iVelList','DucerZ'}), 'rows' );
    for iRow = 1:height(tVZ)
        [cRayTbl,iAt] = sub_GetRayTable( cRayTbl, oWave.cVProfile ...
            , tVZ.iVelList(iRow), tVZ.DucerZ(iRow), nMaxR );
        stRP = cRayTbl{iAt,3};
        
        b = (iC == iRow);
        tReply.Suesi_TWTT(b) ...
            = interp2( stRP.nRange, stRP.nDepth, stRP.nTWTT ...
            , tReply.RangeH(b), tReply.DucerZ(b), 'spline' );
        
        % Calculate the barracuda-to-TET TWTT from the CircuitTT
        tReply.TWTT(b) = (tReply.CircuitTT(b) * 2) ...
            - tReply.CTET_TWTT(b) - tReply.Suesi_TWTT(b);
        
        % Re-orient the ray-table for use along a different axis
        stRP        = cRayTbl{iAt,3};
        stRP.nDepth = repmat( onecol( stRP.nDepth ), 1, size(stRP.nTWTT,2) );
        stRP.nRange = repmat( stRP.nRange, size(stRP.nTWTT,1), 1 );
        
        % Back-convert the TWTT to horizontal range between TET and barracuda
        oInterp = scatteredInterpolant( stRP.nTWTT(:), stRP.nDepth(:), stRP.nRange(:) );
        oInterp.ExtrapolationMethod = 'none';
        tReply.Range(b) = oInterp( tReply.TWTT(b), tReply.SuesiZ(b) );
        
    end
    warning( stWarn );
    bDrop = ismissing( tReply.Suesi_TWTT ) | isnan( tReply.Range );
    if any(bDrop)
        tReply(bDrop,:)  = [];
        oWave.AddLog( cwave.LogOK, cwave.sLog_TxNavAction ...
            , sprintf('TET: dropped %d of %d - calc of SUESI-barracuda TWTT yielded NaN' ...
                    , sum(bDrop), numel(bDrop) ) );
    end
    assert( ~oProg.CancelRequested, sCancel );
    clear bDrop tVZ iC iRow stRP b
    
    % Triangulate two barracuda replies
    %
    % Nope. Maybe some other time. We're already dealing with messy data and
    % messy estimates of suesi's location so the TET locations are going to be
    % weird. And I'm already WAY over time+budget on this WAVE project.
    %
    
    % Triangulate one barracuda & guesstimated CTET position from SUESI +
    % distance extended back on line between SUESI & wire0
    [nENEN,nFix1,nFix2,nFix3] = Triangulate( ...
          tReply{:,{ 'CudaE', 'CudaN'}}, tReply.Range ... barracuda to TET
        , tReply{:,{'SuesiE','SuesiN'}}, oWave.nCDist ... suesi to TET (fixed dist)
        , 'shrinkA', 'growA', 'growA' );
    if nFix1 > 0
        oWave.AddLog( cwave.LogOK, cwave.sLog_TxNavAction ...
            , sprintf('TET: %d of %d pings had TWTT too long. Shortened' ...
            , nFix1, height(tReply) ) );
    end
    if nFix2 + nFix3 > 0
        oWave.AddLog( cwave.LogOK, cwave.sLog_TxNavAction ...
            , sprintf('TET: %d of %d pings had TWTT too short. Lengthened' ...
            , nFix2 + nFix3, height(tReply) ) );
    end
    bDrop = any(imag(nENEN),2);
    if any(bDrop)
        oWave.AddLog( cwave.LogOK, cwave.sLog_TxNavAction ...
            , sprintf('TET: %d of %d pings dropped - invalid triangulation' ...
            , sum(bDrop), numel(bDrop) ) );
        tReply(bDrop,:) = [];
        nENEN(bDrop,:) = [];
    end
    assert( ~oProg.CancelRequested, sCancel );
    clear iFix1 iFix2 iFix3
    
    % Guesstimate the TETs position as being on the line running from wire0
    % through SUESI
    tReply.TetAngle = atan2( tReply.SuesiN - tReply.Wire0N, tReply.SuesiE - tReply.Wire0E );
    tReply.TetE     = tReply.SuesiE + oWave.nCDist .* cos( tReply.TetAngle );
    tReply.TetN     = tReply.SuesiN + oWave.nCDist .* sin( tReply.TetAngle );
    tReply.TetZ     = tReply.SuesiZ;
    assert( ~oProg.CancelRequested, sCancel );
    
    % Move data into tableTxNav format so that I can use the same
    % path-smoothing code as for SUESI's track
    tNav                = cwave.GetDfltFor( 'tableTxNav', height(tReply) );
    tNav.Time(:)        = tReply.Time; % NB: "(:)" preserves col properties in tNav
    tNav.Wire0_E(:)     = tReply.SuesiE;
    tNav.Wire0_N(:)     = tReply.SuesiN;
    tNav.ShipTrack_E(:) = tReply.TetE;
    tNav.ShipTrack_N(:) = tReply.TetN;
    tNav.Forced(:)      = 0;
    
    % For each pair of triangulation points, pick the one closest to the
    % estimated TET location
    bFirst = ((nENEN(:,1) - tReply.TetE).^2 + (nENEN(:,2) - tReply.TetN).^2) ...
           < ((nENEN(:,3) - tReply.TetE).^2 + (nENEN(:,4) - tReply.TetN).^2);
    tNav.Ping_E(bFirst) = nENEN(bFirst,1);
    tNav.Ping_N(bFirst) = nENEN(bFirst,2);
    bFirst = ~bFirst;   % negate this once instead of 4 times below
    tNav.Ping_E(bFirst) = nENEN(bFirst,3);
    tNav.Ping_N(bFirst) = nENEN(bFirst,4);
    assert( ~oProg.CancelRequested, sCancel );
    clear nENEN
    
    % Add all SUESI positions for tows which are forced into the shiptrack and
    % for tows which don't have ANY TET info
    iTowIdx = cwave.IndexIntoTimeTable( oWave.tableTow, tNavSue.Time );
    bAdd1   = logical(round(oWave.tableTow.IgnoreNav(iTowIdx)));    % careful of FP errors
    
    nTowList = unique( tReply.TowNo );
    bAdd2    = ~ismember( tNavSue.TowNo, nTowList );
    clear tReply % in a moment tNav may have a lot more rows than tReply then it'll get sorted
    
    if any(bAdd1)
        oWave.AddLog( cwave.LogOK, cwave.sLog_TxNavAction ...
            , sprintf('TET: Adding %d locations for tows forced into the shiptrack' ...
            , sum(bAdd1) ) );
    end
    if any(bAdd2)
        oWave.AddLog( cwave.LogOK, cwave.sLog_TxNavAction ...
            , sprintf('TET: Adding %d locations for tows with no TET information' ...
            , sum(bAdd2 & ~bAdd1) ) );
    end
    
    if any(bAdd1) || any(bAdd2)
        % Get the SUESI nav rows for the missing / replaced tows
        tAdd = tNavSue(bAdd1 | bAdd2,:);
        
        % NB: When surface towing wire-out is usually at zero in which case 
        % atan2 will return angles based on random floating point error. So when
        % the distance between SUESI and Wire0 is negligible use COG
        dN          = tAdd.Smooth_N - tAdd.Wire0_N;
        dE          = tAdd.Smooth_E - tAdd.Wire0_E;
        nTetAngle   = atan2( dN, dE );  % cartesian angle: clockwise from x-axis
        bUseCOG     = abs(dN) < 20 & abs(dE) < 20;
        % NB: cvt COG to cartesian, then flip by 180 degrees
        nTetAngle(bUseCOG) = (90 - tAdd.COG(bUseCOG) - 180) * pi / 180; % need radians, not deg
        
        % Rearrange data so that wire0 is SUESI and the other points are CTET
        tAdd.ShipTrack_E = tAdd.Smooth_E + oWave.nCDist .* cos( nTetAngle );
        tAdd.ShipTrack_N = tAdd.Smooth_N + oWave.nCDist .* sin( nTetAngle );
        tAdd.Wire0_E     = tAdd.Smooth_E;
        tAdd.Wire0_N     = tAdd.Smooth_N;
        tAdd.Ping_E      = tAdd.ShipTrack_E;
        tAdd.Ping_N      = tAdd.ShipTrack_N;
        tAdd.Forced(:)   = 1;
        assert( ~oProg.CancelRequested, sCancel );

        % Add new rows
        tNav = [tNav; tAdd];
    end
    
    % Sort & avg dups (if any; shdn't be)
    tNav = sub_AvgByTime( tNav );
    assert( ~oProg.CancelRequested, sCancel );
    
    % Smooth the path
    disp( 'Working on TET locations...' );  % sub_SmoothPath displays text to command window
    tNav = sub_SmoothPath( oWave, tNav, oProg );
    assert( ~oProg.CancelRequested, sCancel );
    
    % Make a plot of the coarse & smoothed paths
    hFig = getStackedFig( 'pptHD' );
    hAx = axes( hFig );
    plot( hAx, tNav.Ping_E, tNav.Ping_N, '.', 'LineStyle', 'none' ...
        , 'MarkerSize', 12, 'DisplayName', 'Pings' );
    hold( hAx, 'on' );
    plot( hAx, tNav.Smooth_E, tNav.Smooth_N, '.', 'LineStyle', 'none' ...
        , 'MarkerSize', 6, 'DisplayName', 'Smoothed TET path' );
    hold( hAx, 'off' );
    axis( hAx, 'equal' )
    axisTight( hAx ); 
    axisTicksUTM( hAx, 'xy' );
    title( hAx, 'CTET Navigation' );
    xlabel( hAx, ['Easting ' oWave.sUTMZoneDisp] );
    ylabel( hAx, 'Northing' );
    legend( hAx, 'location', 'best' );
    addPlotMenu( hFig, fullfile( oWave.sPlotDir, 'TxNav_CTET_Nav' ), 'Save' );
    
    % Transfer data out of tableTxNav into tableCTET
    tTet                = cwave.GetDfltFor( 'tableCTET', height(tNav) );
    tTet.Time(:)        = tNav.Time;
    tTet.TowNo(:)       = tNav.TowNo;
    tTet.East(:)        = tNav.Smooth_E;
    tTet.North(:)       = tNav.Smooth_N;
    tTet.ShipTrack_E(:) = tNav.ShipTrack_E;
    tTet.ShipTrack_N(:) = tNav.ShipTrack_N;
    tTet.Ping_E(:)      = tNav.Ping_E;
    tTet.Ping_N(:)      = tNav.Ping_N;
    tTet.Forced(:)      = tNav.Forced;
    
    % Interpolate the TET's depth
    %  NB: If we didn't get TET depth (sometimes the w= time series doesn't
    %  happen) then use SUESI's depth & assume non-dipping tow string
    tTetZ = oWave.tableVulcan(oWave.tableVulcan.DeviceNo == oWave.nCNavNo,:);
    if height(tTetZ) >= 2
        tTetZ = sub_AvgByTime( tTetZ );
        tTet.Depth = interp1( tTetZ.Time, tTetZ.Depth, tTet.Time, 'linear', NaN );
        bChg = ismissing(tTet.Depth);
        oWave.AddLog( cwave.LogOK, cwave.sLog_TxNavAction ...
            , sprintf('TET: %d of %d - assigned depth from w=[] time series' ...
                    , height(tTet) - sum(bChg), height(tTet) ) );
    else
        bChg = true(height(tTet),1);
    end
    if any(bChg)
        tTet.Depth(bChg) = interp1( oWave.tableSDM.Time, oWave.tableSDM.Depth ...
            , tTet.Time(bChg), 'nearest', 'extrap' );
        oWave.AddLog( cwave.LogOK, cwave.sLog_TxNavAction ...
            , sprintf('TET: %d of %d - assigned SUESI''s depth. No w=[] time series' ...
                    , sum(bChg), numel(bChg) ) );
    end
    
    % Ensure depths are not in the air
    bChg = tTet.Depth < 0;
    if any(bChg)
        tTet.Depth(bChg) = 0;
        oWave.AddLog( cwave.LogOK, cwave.sLog_TxNavAction ...
            , sprintf('TET: %d of %d depths were negative. Fixed.' ...
                    , sum(bChg), numel(bChg) ) );
    end
    clear bChg
    
    % Plot the TET depths compared to SUESI depths
    hFig = getStackedFig( 'pptHD' );
    hAx = axes( hFig );
    plot( hAx, tNavSue.Time, tNavSue.Suesi_Z, '.', 'LineStyle', 'none' ...
        , 'MarkerSize', 12, 'DisplayName', 'SUESI depth' );
    hold( hAx, 'on' );
    plot( hAx, tTet.Time, tTet.Depth, '.', 'LineStyle', 'none' ...
        , 'MarkerSize', 6, 'DisplayName', 'TET depth' );
    hold( hAx, 'off' );
    axisTight( hAx ); 
    title( hAx, 'CTET Depth' );
    ylabel( hAx, 'Depth (m)' );
    hAx.YDir = 'reverse';
    legend( hAx, 'location', 'best' );
    addPlotMenu( hFig, fullfile( oWave.sPlotDir, 'TxNav_CTET_Depth' ), 'Save' );
    
    return;
end % sub_NavTET

%-------------------------------------------------------------------------------
% Get a ray table made from depth vs velocity. They're time consuming to make so
% keep a stash of ones already made. 
function [cRayTbl,iAt] = sub_GetRayTable( cRayTbl, cVProfile, iVel, nZ, nMaxR )
    % Is there already a ray table calculated? If not, make & stash it
    if isempty( cRayTbl )
        iAt = [];
    else
        % Table must match the velocity profile "valid" time range and the
        % depth of the barracuda pinger. The ping head depth can be adjusted
        % during a cruise...
        iAt = find( cell2mat(cRayTbl(:,1)) == iVel & cell2mat(cRayTbl(:,2)) == nZ, 1 );
    end
    if isempty( iAt )
        iAt                 = size(cRayTbl,1) + 1;
        cRayTbl{iAt,1}      = iVel;
        cRayTbl{iAt,2}      = nZ;
        [~,cRayTbl{iAt,3}]  = FindRayPath( ...
              0, 0, nZ ...
            , 0, 0, 6000 ... NB: Z will be limited to max velocity profile depth
            , table2array( cVProfile{iVel} ), [], nMaxR );
    end
    return;
end % sub_GetRayTable
