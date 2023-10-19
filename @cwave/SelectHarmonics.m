function SelectHarmonics( oWave )
% cwave:SelectHarmonics( oWave )
%
% Public method of the cwave class. Runs the UI to allow the user to select the
% waveform harmonics (and therefore the output frequencies) they want to use in
% CSEM processing.
%
% Parameters:
%   oWave - the controlling cwave instance
% Returns:
%
%-------------------------------------------------------------------------------
% Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
%-------------------------------------------------------------------------------

    %% Prepare the data
    % NB: There must be one of SNAP or Ideal. There will probably be both.
    % Always prefer SNAP over Ideal. If the user wants to use ideal, then they
    % can just clear the SNAP data from the interface.
    [nFFT, nFreqList] = deal([]);
    
    % Handle the Ideal waveform, if it exists
    if ~isempty( oWave.tableWaveIdeal )
        % The ideal waveform may be in 'brief' format. Change it to full samples
        % so I can get a proper FFT on it
        [~,nA] = decodeSUESITXTiming( ...
            encodeSUESITXTiming( oWave.tableWaveIdeal.Time * 400 ...
                               , oWave.tableWaveIdeal.Amplitude ) ...
            , 'LongForm' );
        
        % Get the harmonics
        % NB: SUESI is always 400 Hz. This is hardcoded into SUESI's firmware
        % and built into its circuits because of the power sources
        [nFFT, nFreqList] = calcFFT( nA, 400 );
        
    end
    
    % Handle the SNAP waveform, if it exists
    if ~isempty( oWave.tableWaveSNAP )
        % What's the sampling frequency?
        nSampFreq = 1 ./ median( diff( oWave.tableWaveSNAP.Time ) );
        
        % Get the harmonics
        [nFFT, nFreqList] = calcFFT( oWave.tableWaveSNAP.Amplitude, nSampFreq );
    end
    
    % If there aren't already any harmonics selected, then select the top 4
    tHarmonics = oWave.tableHarmonics;
    iSlctHarm = tHarmonics.Harmonic;
    if isempty( iSlctHarm )
        [~,iSlctHarm] = sort( abs( nFFT ), 'descend' );
        iSlctHarm = sort( iSlctHarm(1:4) );
        
        tHarmonics{1:4,:}       = missing();    % create empty rows
        tHarmonics.Harmonic(:)  = iSlctHarm;
        tHarmonics.Frequency(:) = round( nFreqList(iSlctHarm), 5 );
        tHarmonics.Amplitude(:) = abs( nFFT(iSlctHarm) );
        tHarmonics.Phase(:)     = 180 / pi() * angle( nFFT(iSlctHarm) );
    end
    
    
    %% Build the UI
    hFig = uifigure( 'Name', 'Select Waveform Harmonics' ...
        , 'Visible', false, 'WindowStyle', 'modal', 'Resize', true ...
        , 'Units', 'pixels', 'Position', [1 1 1200 800] ...
        );
    figCenter( oWave.hFig, hFig );
    
    % General grid for all the zones
    hG = uigridlayout( hFig );
    hG.RowHeight       = {'fit', '2x', '1x', cwave.BtnHt};
    hG.ColumnWidth     = {'1x','3x'};
    hG.ColumnSpacing   = 10;
    hG.RowSpacing      = 20;
    hG.Padding         = [10 10 10 20];
    
    % Top is instruction text across both columns
    h = uilabel( 'Parent', hG, 'FontSize', cwave.FontSize + 2, 'WordWrap', true ...
        , 'HorizontalAlignment', 'center', 'Text', [
        'INSTRUCTIONS: Use the mouse to select which harmonics you ' ...
        'want to use in CSEM processing. If you have both SNAP and ' ...
        'ideal waveforms, scaling from the SNAP will be preferred. ' ...
        'If you want to force use of scaling from the ideal waveform ' ...
        'then return to the Waveform tab, clear the "Waveform SNAPshot ' ...
        'Files" list, then restart this process.'
        ] );
    h.Layout.Column     = [1 numel(hG.ColumnWidth)];
    
    % Table of harmonics
    hTblHarm = uitable( 'Parent', hG, 'FontSize', cwave.FontSize ...
        , 'Data', tHarmonics ...
        , 'ColumnSortable', false, 'ColumnEditable', false ...
        );
    
    % Plot of harmonic amplitudes
    hAxAmp = uiaxes( 'Parent', hG, 'FontSize', cwave.FontSize, 'Box', 'on' ...
        , 'ButtonDownFcn', @sub_SlctHarm );
    hLnAmp = stem( hAxAmp, nFreqList, abs( nFFT ), 'Marker', '.' );
    hLnAmp.HitTest = 'off';
    hold( hAxAmp, 'on' );
    hLnSlct = plot( hAxAmp, nFreqList(tHarmonics.Harmonic), abs( nFFT(tHarmonics.Harmonic) ) ...
        , 'LineStyle', 'none', 'Marker', 'o', 'MarkerSize', 12 ...
        , 'Color', 'r', 'HitTest', 'off' );
    hold( hAxAmp, 'off' );
    hAxAmp.XScale = 'log';
    axisTight( hAxAmp, 'x' );
    decadeTick( hAxAmp, 'x' );
    hAxAmp.Title.String  = 'Waveform Harmonic Amplitudes';
    hAxAmp.XLabel.String = 'Frequency (Hz)';
    hAxAmp.YLabel.String = 'Amplitude';
    
    % Plot of the waveform(s)
    hAxWave = uiaxes( 'Parent', hG, 'FontSize', cwave.FontSize, 'Box', 'on' );
    plot( hAxWave, oWave.tableWaveSNAP.Time, oWave.tableWaveSNAP.Amplitude ...
        , 'LineStyle', '-', 'Marker', 'none' );
    hold( hAxWave, 'on' );
    plot( hAxWave, oWave.tableWaveIdeal.Time, oWave.tableWaveIdeal.Amplitude ...
        , 'LineStyle', '-', 'Marker', 'none' );
    hold( hAxWave, 'off' );
    axisTight( hAxWave );
    hAxWave.XLabel.String = 'Time (s)';
    
    % Plot of harmonic phases
    hAxPhs = uiaxes( 'Parent', hG, 'FontSize', cwave.FontSize, 'Box', 'on' );
    hLnPhi = semilogx( hAxPhs, nFreqList, 180 / pi() * angle( nFFT ) ...
        , 'LineStyle', 'none', 'Marker', '.' );
    axisTight( hAxPhs, 'x' );
    decadeTick( hAxPhs, 'x' );
    hAxPhs.YLim          = [-190 190];
    hAxPhs.YTick         = -180:90:180;
    hAxPhs.Title.String  = 'Waveform Phase';
    hAxPhs.XLabel.String = 'Frequency (Hz)';
    hAxPhs.YLabel.String = 'Phase (deg)';
    
    % Dialog control buttons
    hGB = uigridlayout( hG );
    hGB.Layout.Column   = [1 2];
    hGB.Layout.Row      = 4;
    hGB.RowHeight       = {'1x'};
    hGB.ColumnWidth     = {'1x', cwave.BtnWd, cwave.BtnWd};
    hGB.ColumnSpacing   = 0;
    hGB.RowSpacing      = 0;
    hGB.Padding         = [0 0 0 0];
    uilabel( 'Parent', hGB, 'Text', '' ); % dummy fill
    uibutton( 'Parent', hGB, 'FontSize', cwave.FontSize, 'Text', 'Save' ...
        , 'ButtonPushedFcn', @sub_Save );
    uibutton( 'Parent', hGB, 'FontSize', cwave.FontSize, 'Text', 'Cancel' ...
        , 'ButtonPushedFcn', @sub_Cancel );
    
    % Make the figure visible and run the MODAL figure
    hFig.Visible = true;
    hFig.CloseRequestFcn = @sub_Cancel;
    waitfor( hFig );
    return;
    
    %---------------------------------------------------------------------------
    function sub_Cancel(~,~)
        delete( hFig );
        return;
    end % sub_Cancel
    
    %---------------------------------------------------------------------------
    function sub_Save(~,~)
        % Must have at least one harmonic selected
        if isempty( tHarmonics )
            uialert( hFig, {
                'There must be at least one waveform harmonic selected.'
                ''
                'Click on the amplitude plot near a data point to'
                'toggle its selection. Selected points will be circled'
                'and will show up in the table on the left.'
                }, 'Select Waveform Harmonics' );
            return;
        end
        
        % Clear previous log entries
        oWave.ClearLogOfType( cwave.sLog_Wave_Harmonics );
        
        % Log the selected harmonic numbers & frequencies
        oWave.AddLog( cwave.LogOK, cwave.sLog_Wave_Harmonics ...
            , ['Selected harmonics Num:[' num2str(tHarmonics.Harmonic.') '] Hz:[' ...
            num2str(tHarmonics.Frequency.') ']' ] );
        
        % Update the harmonic table
        oWave.tableHarmonics = tHarmonics;
        
        % Close the dialog
        delete( hFig );
        
        return;
    end % sub_Save
    
    %---------------------------------------------------------------------------
    % Mouse-click on the harmonic amplitude axes. Select / unselect a specific
    % harmonic number - whichever is closest in X
    function sub_SlctHarm(~,~)
        % If the user clicked outside the axis box, do nothing
        nPt = hAxAmp.CurrentPoint;  % in axis units
        nPt = nPt(1,1:2);           % given as [x1,y1,z1;x2,y2;z2]
        if ~between( hAxAmp.XLim, nPt(1) )
            return;
        end
        
        % Find the closest frequency along X (NB: the LOG10 axis). "Closest" is
        % pixel distance - that's what the user expects to see
        sUnits          = hAxAmp.Units;
        hAxAmp.Units    = 'pixels';
        nSz             = hAxAmp.Position;              % [Left,Bott,Wd,Ht] in pixels
        hAxAmp.Units    = sUnits;
        xDAR = diff( log10( hAxAmp.XLim ) ) / nSz(3);   % data-aspect-ratio: axis units / pixel
        yDAR = diff( hAxAmp.YLim ) / nSz(4);
        [~,iFreqSel] = min( ( (log10(hLnAmp.XData) - log10(nPt(1))) / xDAR ).^2 ...
                          + ( (hLnAmp.YData - nPt(2)) / yDAR ).^2 );
        
        % Toggle selection by adding or removing from the data table
        iAt = find( iFreqSel == tHarmonics.Harmonic, 1, 'first' );
        if isempty( iAt )   % not selected already
            tHarmonics{end+1,:}         = missing();
            tHarmonics.Harmonic(end)    = iFreqSel;
            tHarmonics.Frequency(end)   = round( hLnAmp.XData(iFreqSel), 5 );
            tHarmonics.Amplitude(end)   = hLnAmp.YData(iFreqSel);
            tHarmonics.Phase(end)       = hLnPhi.YData(iFreqSel);
            tHarmonics = sortrows( tHarmonics, 'Harmonic' );
        else                % currently selected
            tHarmonics(iAt,:) = [];
        end
        
        % Update the uitable
        hTblHarm.Data = tHarmonics;
        
        % Update the selection line object
        hLnSlct.XData = hLnAmp.XData(tHarmonics.Harmonic);
        hLnSlct.YData = hLnAmp.YData(tHarmonics.Harmonic);
        
        return;
    end % sub_SlctHarm
end % SelectHarmonics
