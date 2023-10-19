function TowedCSEM( oWave, sScope )
% Calculate & stack CSEM data for Towed receivers
%
% Params:
%   oWave   - the cwave object with all the data
%   sScope  - "New" or "All" - which log files to process
%-------------------------------------------------------------------------------
% Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
%-------------------------------------------------------------------------------
    arguments
        oWave cwave
        sScope string
    end
    
    % Options
    bAll = strcmpi( sScope, "All" );
    
    % Only process tow vehicles whose configuration is complete. This allows the
    % user to process CSEM as data are recovered then just use "Run New" each
    % time they complete another site
    bChkRx = cwave.ValidateTowRxCfg( oWave.tableTowRxCfg, oWave.tableTowRxCh, oWave.sDir_Calib );
    
    % Confirm that we have all the pieces we need
    if ~sub_CheckPieces( oWave, bChkRx )
        return;
    end
    
    % For every data file, create separate output files for each tow whose
    % start/end times overlap with the data file's operation times
    tProc = sub_BuildProcList( oWave, bAll, bChkRx );
    if isempty( tProc )
        return;
    end
    
    % Get rid of all the old statuses if we're doing "All"
    if bAll
        oWave.ClearLogOfType( cwave.sLog_Towed_CSEM );
    end
    
    % Walk the to-be-processed list
    oProg = uiprogressdlg( oWave.hFig, 'Title', 'Towed CSEM', 'Cancelable', true ...
        , 'Message', 'Processing Towed CSEM ...' );
    cOutList = {};
    tStart   = tic();
    for iProc = 1:height(tProc) % NB: do NOT parfor this loop
        % Update the progress bar & handle user cancel
        if oProg.CancelRequested
            break;
        end
        if iProc > 1
            nRemain = toc(tStart) * (height(tProc) - (iProc-1)) / (iProc-1);
            nHr     = floor( nRemain / 3600 );
            nMin    = floor( mod( nRemain, 3600 ) / 60 );
            nSec    = floor( mod( nRemain, 60 ) );
            sRemain = sprintf( 'Est time remaining: %d:%02d:%02d', nHr, nMin, nSec );
        else
            sRemain = 'Est time remaining: <calculating>';
        end
        oProg.Value     = (iProc-1) / height(tProc);
        oProg.Message   = {'Processing Towed CSEM ...';sRemain};
        
        % Process one Rx + Tow
        cMsgs = sub_CSEM( tProc(iProc,:) ...
            , oWave.nWindowLen, oWave.nStackLen ...
            , oWave.tableHarmonics, oWave.tableSDM ...
            , oWave.tableTxNav, oWave.tableCTET ...
            , oWave.tableVulcan );
        for i = 1:numel(cMsgs)
            oWave.AddLog( cwave.LogOK, cwave.sLog_Towed_CSEM, cMsgs{i} );
        end
        
        % If a file was made, save it to the list & plot it
        if isfile( char(tProc.OutFile(iProc)) )
            cOutList{end+1,1} = char(tProc.OutFile(iProc));
            oWave.PlotTowedCSEM( char(tProc.OutFile(iProc)) );
        end
        
    end % to-be-processed list
    close( oProg );
    
    % Update the output file list. This will fire off any listeners
    if bAll || isempty( oWave.cFiles_TowedCSEM )
        oWave.cFiles_TowedCSEM = sort( cOutList );
    else
        oWave.cFiles_TowedCSEM = unique( [oWave.cFiles_TowedCSEM; cOutList] );
    end
    
    % Finally, tell how long it took
    nDur = seconds( toc(tStart) );
    nDur.Format = 'hh:mm:ss';
    oWave.AddLog( cwave.LogOK, cwave.sLog_Towed_CSEM, ['Process time: ' char(nDur)] );
    
    % Put up a "done" message
    uialert( oWave.hFig, {
        sprintf( 'Processed %d Rx+Tow Line combinations.', height(tProc) )
        }, 'Calculate Towed CSEM', 'Icon', 'success' );
    
    return;
end % TowedCSEM

%-------------------------------------------------------------------------------
% Check that all the required setup has been done. NB: Most of the checks are
% done in w_tabTowedCSEM and keep the panel unavailable until they are met.
function bOK = sub_CheckPieces( oWave, bChkRx )
    bOK = false;
    if isempty( oWave.tableTowRxCfg )
        uialert( oWave.hFig, {
            'There are no towed receivers in the configuration list.'
            }, 'Calculate Towed CSEM' );
        return;
    end
    sList = unique( oWave.tableTowRxCfg.BinPath(bChkRx) );
    sList(isfolder(sList)) = [];
    if ~isempty( sList )
        uialert( oWave.hFig, [
            "The following binary file FOLDERS do not exist:"
            ""
            sList
            ], 'Calculate Towed CSEM' );
        return;
    end
    sList = fullfile( oWave.tableTowRxCfg.BinPath(bChkRx) ...
                    , oWave.tableTowRxCfg.BinFile(bChkRx) );
    sList(isfile(sList)) = [];
    if ~isempty( sList )
        uialert( oWave.hFig, [
            "The following binary FILES do not exist:"
            ""
            sList
            ], 'Calculate Towed CSEM' );
        return;
    end
    
    % If we make it here then all checks passed
    bOK = true;
    return;
end % sub_CheckPieces

%-------------------------------------------------------------------------------
% For every data file, create separate output files for each tow whose start/end
% times overlap with the data file's operation times
function tProc = sub_BuildProcList( oWave, bAll, bChkRx )
    arguments
        oWave cwave
        bAll logical
        bChkRx logical
    end
    
    % Create the return table that will hold all info necessary for processing
    tProc = table( 'Size', [0 15] ...
        , 'VariableNames', {'RxName', 'TowNo', 'DirEofN' ...
                           , 'DateFrom', 'DateTo', 'TowFrom', 'TowTo' ...
                           , 'SyncTime', 'DriftRate', 'TxLag', 'TxPhShift' ...
                           , 'DeviceNo', 'TrailingDist' ...
                           , 'InFile', 'OutFile' ...
                           } ...
        , 'VariableTypes', [{'string','double','double'} repmat({'datetime'},1,5) ...
                            repmat({'double'},1,5) repmat({'string'},1,2)] ... 
        );
    
    % Show progress because every file has to be opened and its header read
    oProg = uiprogressdlg( oWave.hFig, 'Title', 'Towed CSEM', 'Cancelable', true ...
        , 'Message', 'Reading data headers...' );
    cErr    = {};
    ccCalib = {};   % cell array of string arrays to add to tProc at the end
    for iRx = 1:height(oWave.tableTowRxCfg)
        % Update the progress bar & handle user cancel
        if oProg.CancelRequested
            tProc(:,:) = []; % preserve table config, delete all data
            return;
        end
        oProg.Value = (iRx-1) / height(oWave.tableTowRxCfg);
        
        % If the config isn't complete for this Rx, just quietly skip
        if ~bChkRx(iRx)
            continue;
        end
        
        % Get the data times for this input file
        sInFile = fullfile( oWave.tableTowRxCfg.BinPath(iRx), oWave.tableTowRxCfg.BinFile(iRx) );
        try
            stData = readBinData( sInFile );
        catch Me
            cErr{end+1,1} = sprintf( '%s: Error %s' ...
                , oWave.tableTowRxCfg.RxName(iRx), Me.message );
            continue;
        end
        
        % Does the channel count match that in the user's receiver config?
        bCh = strcmpi( oWave.tableTowRxCfg.RxName(iRx), oWave.tableTowRxCh.RxName );
        nChCnt = sum( bCh );
        if stData.nChanCnt ~= nChCnt
            cErr{end+1,1} = sprintf( '%s: has %d channels but %d are configured' ...
                , oWave.tableTowRxCfg.RxName(iRx), stData.nChanCnt, nChCnt );
            continue;
        end
        
        % Get the list of channel calibration files to apply IN ORDER
        tCh = sortrows( oWave.tableTowRxCh(bCh,:), 'ChanNo' );
        
        % Read the calibrations per-channel and build frequency-dependent
        % corrections to apply in the frequency domain
        cCh = {};
        for iCh = 1:nChCnt
            sCalibFile = fullfile( oWave.sDir_Calib, tCh.CalibFile(iCh) );
            if ~isfile( sCalibFile )
                cErr{end+1,1} = sprintf( '%s: Channel %d''s calibration file not found' ...
                    , oWave.tableTowRxCfg.RxName(iRx), iCh );
                cCh = {};
                break;
            end
            nZ = getCalib( sCalibFile, oWave.tableHarmonics.Frequency );
            cCh{iCh,1} = nZ;
        end
        if isempty(cCh)
            continue;
        end
        tCh = addvars( tCh, cCh, 'NewVariableNames', {'cCalibTable'} );
        
        % For each tow line, check to see if there is overlap with this data
        % file and, if not "run all", whether the output file already exists
        nMinOverlap = seconds( oWave.nStackLen * 10 );  % need at least SOME data overlap
        for iTow = 1:height(oWave.tableTow)
            if stData.dEnd <= oWave.tableTow.DateFrom(iTow) + nMinOverlap ...
            || stData.dStart >= oWave.tableTow.DateTo(iTow) - nMinOverlap
                continue;
            end
            
            % Form the output file name and see if it is in the output list. Do
            % NOT check to see if it's on the disk. When the user does something
            % that requires a re-run, I only clear cwave.cFiles_TowedCSEM. I
            % don't delete the files on disk (just in case).
            sOutFile = fullfile( oWave.sCSEMDir, sprintf( 'Line%g_%s.towedcsem.mat' ...
                , oWave.tableTow.TowNo(iTow), oWave.tableTowRxCfg.RxName(iRx) ) );
            if ~bAll && ismember( sOutFile, oWave.cFiles_TowedCSEM )
                continue;
            end
            
            % Always start at a full minute boundary. There's a reason for
            % this buried deep in the bowels of the old codes. I no longer
            % remember what it is.
            dStart  = max( stData.dStart, oWave.tableTow.DateFrom(iTow) );
            d2      = dateshift( dStart, 'end', 'minute' );
            % NB: if it shifted exactly 60s, it was already at a min boundary
            if ~isequal( d2 - dStart, seconds(60) )
                dStart = d2;
            end
            
            % Add to the to-be-processed list
            tProc{end+1,:}          = missing();
            tProc.RxName(end)       = oWave.tableTowRxCfg.RxName(iRx);
            tProc.TowNo(end)        = oWave.tableTow.TowNo(iTow);
            tProc.DirEofN(end)      = oWave.tableTow.DirEofN(iTow);
            tProc.TowFrom(end)      = oWave.tableTow.DateFrom(iTow);
            tProc.TowTo(end)        = oWave.tableTow.DateTo(iTow);
            tProc.DateFrom(end)     = dStart;
            tProc.DateTo(end)       = min( stData.dEnd, oWave.tableTow.DateTo(iTow) );
            tProc.TxLag(end)        = oWave.tableTow.Lag(iTow);
            tProc.TxPhShift(end)    = oWave.tableTow.PhaseShift(iTow);
            tProc.SyncTime(end)     = oWave.tableTowRxCfg.SyncTime(iRx);
            tProc.DriftRate(end)    = oWave.tableTowRxCfg.DriftRate(iRx);
            tProc.DeviceNo(end)     = oWave.tableTowRxCfg.DeviceNo(iRx);
            tProc.TrailingDist(end) = oWave.tableTowRxCfg.TrailingDist(iRx);
            tProc.InFile(end)       = string( sInFile );
            tProc.OutFile(end)      = string( sOutFile );
            
            ccCalib{end+1,1}        = tCh;
            
        end % loop over tow lines
    end % loop over receivers
    close( oProg );
    
    % If there are any errors, show them and abort
    if ~isempty( cErr )
        uialert( oWave.hFig, [
            {'The following errors occurred:';''}
            cErr
            ], 'Process Towed CSEM', 'Icon', 'error' );
        tProc(1:end,:) = [];
        return;
    end
    
    % If there are no files to process, msg & abort
    if isempty( tProc )
        uialert( oWave.hFig, {
            'Nothing to process.'
            ''
            ['Either (a) none of the receiver data overlaps with the tow times, ' ...
            '(b) you''ve selected "Run New" but each Rx + tow already has ' ...
            'an output file, or (c) RX configuration is not complete.']
            }, 'Process Towed CSEM', 'Icon', 'error' );
        tProc(1:end,:) = [];
        return;
    end
    
    % Add the channel calibrations to the table. I don't do this as I go because
    % missing() doesn't work on variables of type cell.
    tProc = addvars( tProc, ccCalib, 'NewVariableNames', {'cCh'} );
    
    return;
end % sub_BuildProcList

%-------------------------------------------------------------------------------
% Process CSEM for ONE Tx+Rx combo
%
% NB: MatLab's fft() produces phase lead by default. So ALL the time
% adjustments herein (Tx tag, fractional data sample, etc...) which produce a
% phase adjustment, must use a clockwise sense. E.g. [complex(cosd,-sind)]
%
function cMsgs = sub_CSEM( tProc, nWindSec, nStackSec, tHarm ...
                         , tSDM, tTxNav, tTetNav, tTowZ )
    % Default the returns
    cMsgs = {};
    
    % Get the waveform scaling factors per frequency
    iHarm       = tHarm.Harmonic;   % indices of the output FFT frequencies
    nCntFreq    = height(tHarm);
    
    % Get the per-channel calibration corrections for the target frequencies.
    % NB: There is an implicit assumption that the calibrations are in phase
    % LEAD convention. If they are not, then they will be wrong.
    tCh         = tProc.cCh{1}; % unpack the channel table
    nCntChan    = height(tCh);
    nCalib      = ones( nCntFreq, nCntChan );
    for iCh = 1:nCntChan
        nCalib(:,iCh) = tCh.cCalibTable{iCh};
    end
    
    %% Read *all* the data
    % NB: this is WAY faster than reading piecemeal, especially if
    % multi-processor work is going on. Don't worry about memory issues. A five
    % channel logger at 62.5 Hz for 8 days is about 350 Mb. Most tow lines are a
    % lot shorter than that - hours not days.
    stData = readBinData( tProc.InFile, 'DateFrom', tProc.DateFrom, 'DateTo', tProc.DateTo );
    
    % Remove amplifier gain, dipole len, and count conv from the time series
    for iCh = 1:nCntChan
        nFactor = stData.nCntConv / tCh.Gain(iCh) / tCh.DipLen(iCh);
        if strncmpi( tCh.Type(iCh), 'H', 1 )    % These are actually B channels (sigh)
            nFactor = nFactor / 1e9;            % units: nT --> T
        end
        stData.nData(:,iCh) = stData.nData(:,iCh) * nFactor;
    end
    
    %% Calculate the first-difference post-darkening correction A(w)
    %
    % Backward difference:
    %   y(n) = x(n) - x(n-1)
    %   A(w) = 1 - exp(-iw)
    % Forward difference:   <-- what I use
    %   y(n) = x(n+1) - x(n)
    %   A(w) = exp(iw) - 1
    %
    %   where w is the normalized cyclic frequency (w = 2 pi f / f_samp)
    %   and A(w) is the frequency response of the first difference operator and
    %   so needs to be divided out of the frequency response.
    %
    nFFTPts    = stData.nFreq * nWindSec;    % How big will the FFT window be?
    nFdiffCorr = exp( 1i * 2 * pi() / nFFTPts * iHarm ) - 1;
    
    %% FFT (pre-whiten, FFT, post-darken)
    % How many FFT windows are there? (NB: 1st differencing requires one extra
    % data point in the time series. May need to back down one window to get it)
    nCntWind = floor( size(stData.nData,1) / nFFTPts );
    if (nCntWind * nFFTPts + 1) > size(stData.nData,1)
        nCntWind = nCntWind - 1;
    end
    
    % NB: MatLab's fft() requires a 2/N normalization (except for the mean &
    % nyquist which are 1/N). See my old calcFFT.m for an explanation.
    %
    % NB: Do the work in stData.nData to preserve memory & gain speed. MatLab
    % will reuse the already allocated space.
    %
    stData.nData = diff( stData.nData );                    % prewhiten
    stData.nData(nCntWind*nFFTPts+1:end,:) = [];            % remove extra pts
    stData.nData = reshape( stData.nData, nFFTPts, [] );    % one window per col
    stData.nData = fft( stData.nData );                     % fft -> each row = output at freq(i)
    % NB: nData(1,:) is 0 Hz. Increment iHarm variable to get actual harmonics
    stData.nData = stData.nData(iHarm+1,:) * (2 / nFFTPts); % select output freqs & normalize fft
    stData.nData = stData.nData ./ nFdiffCorr;              % post-darken
    
    %% If this tow calls for a phase shift, apply it
    if tProc.TxPhShift ~= 0
        stData.nData = stData.nData * exp( 1i * tProc.TxPhShift * pi()/180 );
    end
    
    %% Normalize to a unit source at each frequency in the waveform
    stData.nData = stData.nData ...
        ./ (tHarm.Amplitude .* exp( 1i * tHarm.Phase * pi()/180 ));
    
    %% Apply the transmitter lag correction and any fractional data sample
    % Both are phase shifts. This latter shift is from the start time being at a
    % fractional sample instead of a full sample time
    nTxPhCorr       = tHarm.Frequency * (tProc.TxLag * 360 + stData.n1HzPhCorr);
    nTxPhCorr       = complex( cosd(nTxPhCorr), -sind(nTxPhCorr) );
    stData.nData    = stData.nData .* nTxPhCorr;
    
    %% Apply calibration & remove SDM
    % Reshape to distinguish the channels: (freq,time,ch)
    stData.nData = reshape( stData.nData, nCntFreq, nCntWind, nCntChan );
    
    % Calculate the center time of each un-stacked window
    tmWind = tProc.DateFrom + seconds( nWindSec / 2 : nWindSec : nCntWind * nWindSec );
    
    % - Apply the per-channel calibrations
    % - Remove the time-dependent source-dipole moment
    % NB: Shed data outside the valid SDM time range
    nSDM = reshape( interp1( tSDM.Time, tSDM.SDM, tmWind, 'linear', NaN ), 1, nCntWind );
    bDrop = isnan( nSDM );
    if any( bDrop )
        stData.nData(:,bDrop,:) = [];
        nSDM(1,bDrop) = [];
    end
    for iCh = 1:nCntChan
        stData.nData(:,:,iCh) = stData.nData(:,:,iCh) ./ nCalib(:,iCh);
        stData.nData(:,:,iCh) = stData.nData(:,:,iCh) ./ nSDM;
    end
    
    %% Correct for the time-dependent receiver clock drift
    dtPerWind    = seconds( tmWind - tProc.SyncTime ) * tProc.DriftRate;
    dtPerWind    = repmat( reshape( dtPerWind, 1, nCntWind ), nCntFreq, 1 );
    dtPerWind    = dtPerWind .* (2 * pi() * tHarm.Frequency);
    dtPerWind    = complex( cos(dtPerWind), -sin(dtPerWind) );
    stData.nData = stData.nData .* dtPerWind;           % (freq,time,ch)
    
    %% Stack the data
    % Rearrange to have time on the fast axis for stacking
    stData.nData = permute( stData.nData, [2 3 1] );    % ==> (time,ch,freq)
    
    % Stack the data
    nCntPerStack = nStackSec / nWindSec;
    nCntStacks   = floor( size(stData.nData,1) / nCntPerStack );
    nMaxWind     = nCntStacks * nCntPerStack;
    stData.nData(nMaxWind+1:end,:,:) = [];
    stData.nData = reshape( stData.nData, nCntPerStack, nCntStacks*nCntChan*nCntFreq );
    tmWind(nMaxWind+1:end) = [];
    tmWind = reshape( tmWind, nCntPerStack, nCntStacks );
    
    % NOTES about variance carried over from my original csemStack.m for ref:
    %{
          After lots of playing around with fitting an exponential to the time
        series to get a better fit (because of bias), I found that this CANNOT
        be done to the Re/Im because they oscillate WITHIN an exp envelope.  And
        it SHOULD NOT be done to amplitude and phase because then you gain no
        stacking benefits (there are no negative values to allow you to reach
        below the noise floor).  The lesson: use short stacking windows for
        close range (where bias is large).
          One improvement that can be made is to get a better estimate of the
        variance of each stack. At close ranges, the data decay pretty fast, so
        a simple variance is biased by the curvature.  So detrend the data
        (subtract a linear estimate) and calculate the variance of that
        residual.  Any left-over curvature SHOULD be part of the variance
        because the simple mean stacking is a linear operation.  Non-linear
        curvature is therefore part of the error.

        NB: 1/8/2013 according to math gone through by Anand (& verified by
        Kerry), since I'm not keeping a complex variance, the qty I'm looking
        for is the variance of |Z|. Adding var(Re) and var(Im) in quadrature
        isn't quite right. It needs to be divided by sqrt(2).
        sqrt(var(Re)^2+var(Im)^2) gives the diag of a rectangle with sides
        var(Re) and var(Im). That diag is *longer* than var(|z|) by exactly
        sqrt(2). Draw a diagram to see it.
    %}
    nVar    = sqrt( var( detrend( real(stData.nData) ) ).^2 ...
                  + var( detrend( imag(stData.nData) ) ).^2 ) ...
            / (nCntPerStack * sqrt(2));
    nVar    = reshape( nVar, nCntStacks, nCntChan, nCntFreq );
    nTF     = mean( stData.nData );
    nTF     = reshape( nTF, nCntStacks, nCntChan, nCntFreq );
    tmWind  = onecol( mean( tmWind ) );  % center time of each window
    stData.nData = [];
    
    %
    % NB: DO NOT ROTATE data from tow vehicles
    %
    %{
    % NB: This rotates Hx,Hy and Ex,Ey pairs such that X is in the tow
    % direction. It also corrects the slight non-orthonality of SIO instrument's
    % Ex,Ey which is caused by the positioning of the poles in the frame.
    [iEx,iEy] = sub_Rot( 'Ex', 'Ey', 1 );
    sub_Rot( 'Ex', 'Ey', 2 );
    %}
    
    %% Interpolate transmitter nav
    % NB: Need to create along-track distance for the entire tow, not just the
    % segment seen by this RX
    tTxNav(tTxNav.TowNo ~= tProc.TowNo,:) = [];
    tTxNav.AlongTrack = cumsum([0; sqrt( diff( tTxNav.East ).^2 + diff( tTxNav.North ).^2 )]);
    
    nNav = table2array( tTxNav(:,{'AlongTrack', 'Altitude', 'Depth', 'COG', 'Dip' ...
                                , 'East', 'North', 'Longitude', 'Latitude'}) );
    tNavSuesi = interp1( tTxNav.Time, nNav, tmWind, 'linear', 'extrap' );
    tNavSuesi = array2table( tNavSuesi, 'VariableNames' ...
        , {'AlongTrack', 'Altitude', 'Depth', 'COG', 'Dip', 'East', 'North', 'Lon', 'Lat'} );
    
    %% Use TET nav & trailing distance to navigate the towed RX
    tTetNav(tTetNav.TowNo ~= tProc.TowNo,:) = [];
    if height(tTetNav) > 1
        % Find the CTET location at each window time 
        tNavRx  = table2array( tTetNav(:,{'East', 'North', 'Depth'}) );
        tNavRx  = interp1( tTetNav.Time, tNavRx, tmWind, 'linear', 'extrap' );
        tNavRx  = array2table( tNavRx, 'VariableNames', {'East', 'North', 'Depth'} );
        
        % At this point, tNavRx is the CTET location. Need to derive the tow
        % vehicle location. Use a line from SUESI to CTET. Put the tow vehicle
        % on that line at the appropriate trailing distance
        nTh = atan2( tNavRx.North - tNavSuesi.North, tNavRx.East - tNavSuesi.East );
        tNavRx.North = tNavSuesi.North + tProc.TrailingDist * sin(nTh);
        tNavRx.East  = tNavSuesi.East  + tProc.TrailingDist * cos(nTh);
        
    else
        % No CTET nav so take SUESI at an earlier place in the track
        tNavRx  = interp1( tTxNav.AlongTrack, nNav(:,[6 7 3]) ... E, N, Z
                         , tNavSuesi.AlongTrack - tProc.TrailingDist ...
                         , 'linear', 'extrap' );
        tNavRx  = array2table( tNavRx, 'VariableNames', {'East', 'North', 'Depth'} );
        cMsgs{end+1,1} = sprintf( '%s Line %d - no CTET info. Using SUESI along-track minus %d m' ...
            , tProc.RxName, tProc.TowNo, tProc.TrailingDist );
    end
    
    % Change the depth of the towed RX if there is a w=[n] time series for it
    tTowZ = tTowZ( tTowZ.DeviceNo == tProc.DeviceNo, : );   % written this way to account for NaN ~= anything
    if height( tTowZ ) > 1
        tNavRx.Depth(:) = interp1( tTowZ.Time, tTowZ.Depth, tNavRx.Time, 'linear', 'extrap' );
    else
        cMsgs{end+1,1} = sprintf( '%s Line %d - no w=[] depth info' ...
            , tProc.RxName, tProc.TowNo );
    end
    
    
    %% Accrue header info
    % Include both useful and "here's what I used" historical info in the header
    stRx.sNote      = 'Data dimensions: (time,ch,freq)';
    stRx.RxName     = char(tProc.RxName);
    stRx.TowNo      = tProc.TowNo;
    stRx.InFile     = char(tProc.InFile);
    stRx.nTowOrient = tProc.DirEofN;
    stRx.nFreqList  = tHarm.Frequency;
    stRx.nCntConv   = stData.nCntConv;
    stRx.n1HzPhCorr = stData.n1HzPhCorr;% SIO file correction for partial sample
    stRx.nTxPhShift = tProc.TxPhShift;  % user-entered phase shift for TX signal (usually 0 or 180)
    stRx.nTxLag     = tProc.TxLag;      % SUESI's time lag (slight delay from GPS)
    stRx.nClockDrift= tProc.DriftRate;  % RX clock drift rate (sec per sec)
    stRx.nSyncTime  = tProc.SyncTime;   % sync time for start of clock drift
    stRx.nStackSec  = nStackSec;
    stRx.sBinType   = stData.sType;
    stRx.nBinFreq   = stData.nFreq;
    stRx.sBinDesc   = stData.sDesc;
    stRx.sBinVer    = stData.sVer;
    stRx.sRunBy     = dm_User();
    stRx.tmRunOn    = datetime('now');
    
    
    %% Save variables to the output file & exit
    % Create some convenience variables
    nAmp = abs( nTF );
    nPhs = 180 / pi() * angle( nTF );
    nAmpErr = sqrt( nVar );
    nPhsErr = 2 * asind( min(nAmpErr ./ nAmp, 1) / 2 );  % see dm_GetCSEMError.m for notes
    save( tProc.OutFile, 'stRx', 'nTF', 'nVar', 'nAmp', 'nPhs', 'nAmpErr', 'nPhsErr', 'tmWind', 'tNavSuesi', 'tNavRx', 'tCh', '-v7.3' );
    
    % Create the "success" output message to go in the log
    cMsgs{end+1,1} = sprintf( '%s Line %d saved to %s', tProc.RxName, tProc.TowNo, tProc.OutFile );
    
    return;
    
end % sub_CSEM
