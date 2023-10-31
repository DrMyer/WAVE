function PlotBinaries( oWave )
% cwave::PlotBinaries( oWave )
%
% Plot RX binary files
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

% Must have something to plot
if isempty( oWave.cFiles_Bin )
    uialert( oWave.hFig, {
        'The RX binary file list is empty.'
        'There is nothing to plot.'
        }, 'Plot Spectrograms', 'Icon', 'error' );
    return;
end

% There are SO MANY spectrograms that I put them in a sub-dir of the plot folder
% to get them out of the way - and to make it easy for the user to select-all
% and bind into one PDF.
sPlotDir = fullfile( oWave.sPlotDir, 'Spectrograms' );
if ~isfolder( sPlotDir )
    [bOK,sMsg,sMsgID] = mkdir( sPlotDir );
    if ~bOK
        uialert( o.oWave.hFig, {
            'Unable to create spectrogram folder:'
            sPlotDir
            ''
            ['Error ID: ' sMsgID]
            ['Error: ' sMsg]
            }, 'Create Spectrogram Folder' );
        return;
    end
end

% How many of the binaries already have spectrograms plotted?
cExistList      = getFileList( sPlotDir, '*_spectrogram.png', 'NoTrace', 'NoPath' );
[~,cBinName]    = fileparts( oWave.cFiles_Bin );
bExist = false( size(cBinName) );
for i = 1:numel(cBinName)
    bExist(i) = any( strncmpi( cBinName{i}, cExistList, length(cBinName{i}) ) );
end

% Plotting spectrograms can take a while. Ask about it
if all( bExist )
    sBtn = uiconfirm( oWave.hFig, {
        sprintf( 'All %d binaries have spectrograms.', numel(bExist) )
        ''
        'Replot them anyway?'
        }, 'Plot RX Spectrograms' ...
        , 'Options', {'Plot All', 'Cancel'}, 'CancelOption', 2 );
elseif any( bExist )
    sBtn = uiconfirm( oWave.hFig, {
        sprintf( '%d of %d binaries already have spectrograms.', sum(bExist), numel(bExist) )
        ''
        'Do you want to plot just the new binaries'
        'or do you want to (re)plot everything?'
        }, 'Plot RX Spectrograms' ...
        , 'Options', {'Plot New', 'Plot All', 'Cancel'}, 'CancelOption', 3 );
else
    sBtn = uiconfirm( oWave.hFig, {
        sprintf( '%d binaries ready to plot.', numel(bExist) )
        ''
        'Continue?'
        }, 'Plot RX Spectrograms' ...
        , 'Options', {'Plot All', 'Cancel'}, 'CancelOption', 2 );
end
switch( sBtn )
case 'Plot New'
    iRxPlot = find( ~bExist );
case 'Plot All'
    iRxPlot = 1:numel(oWave.cFiles_Bin);
otherwise
    return;
end


% Options
%
% NB: rather than demean, detrend, welch, etc... I'm using a first-difference
% pre-whitenener (as is used in CSEM processing) and FFT with band-averaging.
% The PW takes care of demean & detrend, and the band avgg obviates the need for
% Welch or PMTM.
%
% NB: unlike the older spectrogram codes which have many user-configurable
% options, I'm hardcoding them to what is generally used. If you want different,
% then the old codes still work on the binaries directly. Knock yourself out. 
%
% Do NOT change my code. Looking at you, KK.
nWindSec    = 1000;
nFreqPerDec = 7;   % band averaging: frequencies per decade
nSubPerPlot = 4;

% Plot
dtStart = datetime('now');
hFig    = getStackedFig( 'page' );
figure( oWave.hFig );   % bring the main window forward. I'll plot & save in the bkgd
oProg   = uiprogressdlg( oWave.hFig, 'Title', 'Plot Spectrograms', 'Cancelable', 'on' );
iCnt    = 0;
iCntMax = numel( iRxPlot );
for iRx = onerow( iRxPlot )
    % Update progress message
    if oProg.CancelRequested
        break;
    end
    oProg.Message = {
        ['Plotting ' cBinName{iRx} ' ...']
        ['Elapsed time ' char(between( dtStart, datetime('now') ))]
        };
    oProg.Value = iCnt / iCntMax;
    iCnt = iCnt + 1;
    
    %% Get the data
    % For speed, slurp up the entire time series all at once
    try
        % Get the header, then read the entire data
        stData = readBinData( oWave.cFiles_Bin{iRx}, 'KeepOpen', true );
        stData = readBinData( stData, 'SkipPts', 0, 'ReadPts', stData.nCntPerCh, 'KeepOpen', false );
    catch Me
        % Dump error to command window & skip to next
        fclose( 'all' );
        disp( ['ERROR reading: ' oWave.cFiles_Bin{iRx}] );
        disp( Me );
        disp( '    Call Stack:' );
        for iStack = 1:numel(Me.stack)
            fprintf( '      %s (%d)\n', Me.stack(iStack).name, Me.stack(iStack).line );
        end
        continue;
    end
    
    % Convert each channel from counts to units
    %  NB: SIO units B: nT/cnt; E: V/cnt
    stData.nData = stData.nData * stData.nCntConv;
    
    
    %% Calculate the power spectrum
    % Calculate the first-difference post-darkening correction A(w)
    nFFTPts    = stData.nFreq * nWindSec;    % How big will the FFT window be?
    iHarm      = onecol( 1:floor(nFFTPts/2) );
    nCntFreq   = numel(iHarm);
    nFdiffCorr = exp( 1i * 2 * pi() / nFFTPts * iHarm ) - 1;    % "forward" diff correction
    
    % How many FFT windows are there? (NB: 1st differencing requires one extra
    % data point in the time series. May need to back down one window to get it)
    nCntWind = floor( stData.nCntPerCh / nFFTPts );
    if (nCntWind * nFFTPts + 1) > stData.nCntPerCh
        nCntWind = nCntWind - 1;
    end
    
    %
    % NB: MatLab's fft() requires a 2/N normalization (except for the mean &
    % nyquist which are 1/N). See my old calcFFT.m for an explanation.
    %
    % NB: Do the work in stData.nData to preserve memory & gain speed. MatLab
    % will reuse the already allocated space.
    %
    % NB: nData(1,:) is 0 Hz. Increment iHarm variable to get actual harmonics
    %
    stData.nData = diff( stData.nData );                    % prewhiten
    stData.nData(nCntWind*nFFTPts+1:end,:) = [];            % remove extra pts
    stData.nData = reshape( stData.nData, nFFTPts, [] );    % one window per col
    stData.nData = fft( stData.nData );                     % fft -> each row = output at freq(i)
    stData.nData = stData.nData(iHarm+1,:);                 % select output freqs
    stData.nData = stData.nData * (2 / nFFTPts);            % normalize fft
    stData.nData = stData.nData ./ nFdiffCorr;              % post-darken
    stData.nData = (1/stData.nFreq) * stData.nData .* conj(stData.nData); % calculate power spectrum
    stData.nData = abs(stData.nData);                       % get rid of floating point imag crap
    
    % Reshape: ( freq, time-window, ch )
    stData.nData = reshape( stData.nData, nCntFreq, nCntWind, stData.nChanCnt );
    
    %% Band avg across the frequency axis
    % Get the frequency bins for band averaging
    nBinMM  = [floor(log10(1/nWindSec)) ceil(log10(stData.nFreq/2))];
    nDecCnt = diff( nBinMM );
    nBins   = logspace( nBinMM(1), nBinMM(2), nDecCnt * nFreqPerDec + 1 );
    nFList  = (1:nCntFreq) / nWindSec;
    
    % Band average
    nBAvg = NaN(numel(nBins)-1,nCntWind,stData.nChanCnt);
    for iBin = 2:numel(nBins)
        iAvg = nBins(iBin-1) <= nFList & nFList < nBins(iBin);
        nBAvg(iBin-1,:,:) = mean( stData.nData(iAvg,:,:), 1, 'omitnan' );
    end
    
    % Drop bins which had no frequencies (usually at the top & bottom)
    bDrop = all(isnan(nBAvg),[2 3]);
    nBAvg(bDrop,:,:) = [];
    nBins([bDrop;false]) = [];
    
    % Drop extraneous data
    stData.nData = nBAvg;
    clear nBAvg
    
    
    %% Plot
    
    % Calculate the edge times of each FFT window
    tmWind = stData.dStart + seconds( 1 : nWindSec : (nCntWind + 1) * nWindSec );
    
    % Loop through channels
    iSub = 1;
    nChL = [];
    for iCh = 1:stData.nChanCnt
        % Plot in log10. 
        nPlot = log10( squeeze( stData.nData(:,:,iCh) ) );
        
        % Set the color axes for 5-95% of the values - exclude extremals
        % NB: prctile() does this automatically but requires the stats toolbox
%         n       = sort( nPlot(:) );
%         nCLim   = n( [ceil(numel(n) * 0.05) floor(numel(n) * 0.95)] );
        
        % Expand the matrix so that MatLab doesn't drop the last row & column as
        % per usual
        nPlot(end+1,:) = nPlot(end,:);
        nPlot(:,end+1) = nPlot(:,end);
        
        % Plot this channel
        hAx         = subplot( nSubPerPlot, 1, iSub, 'Parent', hFig );
        pcolor( hAx, tmWind, nBins, nPlot );
        hAx.YScale  = 'log';
        hAx.YTick   = 10.^(nBinMM(1):nBinMM(2));
        hAx.Box     = 'on';
        hAx.XGrid   = 'off';
        hAx.YGrid   = 'off';
        hAx.Layer   = 'top';    % puts axes ticks on top of the data
%         hAx.CLim    = nCLim;
        shading( hAx, 'flat' );
        axis(    hAx, 'tight' );
        ylabel(  hAx, 'Frequency (Hz)' );
        colorbar( hAx );
        
        % Title the first subplot on the page
        if iSub == 1
            [sP,sF,sE] = fileparts( oWave.cFiles_Bin{iRx} );
            title( hAx, sprintf( 'File: %s%s  Channel: %d  Freq: %g Hz' ...
                               , sF, sE, iCh, stData.nFreq ) ...
                , 'Interpreter', 'none' );
            subtitle( hAx, ['Folder: ' sP], 'Interpreter', 'none' );
        else
            title( hAx, sprintf( 'Channel: %d', iCh ) );
        end
        
        % If we've filled up the subplots or finished channels, finish and save
        % this figure
        nChL(1,end+1) = iCh;
        iSub = iSub + 1;
        if iSub > nSubPerPlot || iCh == stData.nChanCnt
            % Compose the output name
            sF = cBinName{iRx};
            sOutFile = fullfile( sPlotDir, [sF '_Ch' sprintf('_%d',nChL) '_spectrogram']);
            
            % Save the .png & .fig
            addPlotMenu( hFig, sOutFile, 'Save' );
            
            % Save a PDF too
            print( hFig, '-dpdf', sOutFile );
            
            % Clear the figure for the next plot
            clf( hFig, 'reset' );
            iSub = 1;
            nChL = [];
        end
    end % loop through channels
    
end % loop through binaries

% Cleanup
delete( hFig );
delete( oProg );

sRslt = sprintf( '%d spectrograms plotted in: %s\n', iCnt, string(between( dtStart, datetime('now') )) );
disp( sRslt );
uialert( oWave.hFig, sRslt, 'Plot Spectrograms', 'Icon', 'info' );

return;
end % PlotBinaries
