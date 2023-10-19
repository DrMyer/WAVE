function SNAP2Waveform( oWave )
% cwave:SNAP2Waveform( oWave )
%
% Public method of the cwave class. Runs the UI to allow the user to massage one
% or more SNAPs (waveform snapshots) measured by SUESI into a median waveform to
% use for frequency scaling. Note that the only reason we do this is because the
% SIO system does not record the TX output in realtime. All the other systems
% out there record the TX output and use that to form the CSEM transfer
% function. For SIO, we have to estimate it with waveform scaling and a
% source-dipole-moment time series (amperage output * antenna length)
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
    
    %% Prepare the data
    % This process is always a "run all". So first clear the log of all previous
    % entries of this type.
    oWave.ClearLogOfType( cwave.sLog_Wave_SNAP );
    
    % If there's nothing to do, log it as an error so the user doesn't just keep
    % pressing the button wondering why nothing is happening.
    if isempty( oWave.cFiles_SNAP )
        uialert( oWave.hFig ...
            , {
            'There are no SNAP files available.'
            ''
            '.  Did you process the SUESI logs?'
            '.  Were any SNAPs performed during the cruise?'
            '.  Are there warnings in the processing log'
            '    that show problems with the SNAP data lines?'
            }, 'Create Median Waveform from SNAPs' );
        return;
    end
    
    % Generate errors for invalid files
    bIsSNAP = isFile_SNAP( oWave.cFiles_SNAP );
    if all( ~bIsSNAP )
        oWave.AddLog( cwave.LogError, cwave.sLog_Wave_SNAP ...
            , 'None of the files in the SNAP file list are recognized as SNAP files.' );
        return;
    end
    if any( ~bIsSNAP )
        for iFile = reshape( find( ~bIsSNAP ), 1, [] )
            oWave.AddLog( cwave.LogError, cwave.sLog_Wave_SNAP ...
                , sprintf('File %d: Not a valid SNAP file: %s', iFile, oWave.cFiles_SNAP{iFile} ) ...
                );
        end
    end
    
    % Attempt to read all the valid snap files
    cSnap = cell(0,3);  % 3 columns: nFreq (scalar), nT (array), nSnap (array)
    for iFile = reshape( find( bIsSNAP ), 1, [] )
        cSnap = [cSnap
            decodeSNAP( oWave.cFiles_SNAP{iFile}, 'Normalize' )
            ];
    end
    
    % If there are no snaps recovered, abort now
    if isempty( cSnap )
        oWave.AddLog( cwave.LogError, cwave.sLog_Wave_SNAP ...
            , 'Unable to recover SNAP data from any of the files.' );
        return;
    end
    oWave.AddLog( cwave.LogOK, cwave.sLog_Wave_SNAP ...
        , sprintf( 'Found %d individual SNAP events', size( cSnap, 1 ) ) );
    
    % If there is an idealized waveform from instructions given to SUESI and
    % captured in the log, then construct it's full form now (not the
    % abbreviated form)
    if isempty( oWave.tableWaveIdeal )
        [nIdealT,nIdealA] = deal([]);
        nIdealTMax = 0;
    else
        % NB: SUESI is always at 400 Hz
        [nIdealT,nIdealA] = decodeSUESITXTiming( ...
             encodeSUESITXTiming( oWave.tableWaveIdeal.Time * 400 ...
                                , oWave.tableWaveIdeal.Amplitude ) ...
            , 'LongForm' );
        nIdealT     = nIdealT / 400;    % sample ==> time @ 400 Hz
        nIdealTMax  = nIdealT(end) + 1/400;
    end
    
    %% Build the UI
    % UI should allow the user to ...
    %   ... align each waveform at it's zero time
    %   ... median the waveforms to produce an aggregate
    %   ... allow the user to cut out waveforms entirely
    %   ... deal with differing nFreq by refusing to median & return
    %   ... plot the median & source waveforms with, perhaps, std at each data pt?
    hFig = uifigure( 'Name', 'Create Waveform from SNAPs' ...
        , 'Visible', false, 'WindowStyle', 'modal', 'Resize', true ...
        , 'Units', 'pixels', 'Position', [1 1 1200 800] ...
        );
    figCenter( oWave.hFig, hFig );
    
    % General grid for all the zones
    hG1 = uigridlayout( hFig );
    hG1.RowHeight       = {'fit', '1x', '1x', cwave.BtnHt};
    hG1.ColumnWidth     = {'2x','3x'};
    hG1.ColumnSpacing   = 10;
    hG1.RowSpacing      = 20;
    hG1.Padding         = [10 10 10 10];
    
    % Top is instruction text across both columns
    h = uilabel( 'Parent', hG1, 'FontSize', cwave.FontSize + 2, 'WordWrap', true ...
        , 'HorizontalAlignment', 'center', 'Text', [
        'INSTRUCTIONS: Select "Plot" for a group of SNAPs with the same frequency & length. ' ...
        'Adjust as necessary to align the SNAPs and truncate them to a SINGLE waveform long. ' ...
        'Harmonics for the median of the plotted waveforms will show in the bottom left. ' ...
        'When you are happy with the result, save the median waveform.'
        ] );
    h.Layout.Column     = [1 numel(hG1.ColumnWidth)];
    
    % SNAP table
    tSnap = table( 'Size', [size(cSnap,1) 5] ...
        , 'VariableNames', {'Freq',   'NumPts', 'Length', 'Plot',    'Adjust'} ...
        , 'VariableTypes', {'double', 'double', 'string', 'logical', 'logical'} ...
        );
    tSnap.Freq(:)       = cell2mat( cSnap(:,1) );
    tSnap.NumPts(:)     = cellfun( @(c)numel(c), cSnap(:,3) );
    tSnap.Length        = rowfun( @(a,b,~,~,~,~)sprintf('%.2fs',b/a), tSnap, 'OutputFormat', 'cell' );
    
    % Select the most common waveform frequency & length. NB: If there's an
    % ideal waveform, select the most common group that has the same length in
    % time as the ideal waveform (if any)
    [nGrpNo,tGrp]   = findgroups( tSnap(:,{'Freq','NumPts'}) );
    nCnt            = accumarray( nGrpNo, 1 );
    bSubset         = (tGrp.NumPts ./ tGrp.Freq == nIdealTMax);
    if any( bSubset )
        nCnt(~bSubset) = 0;
    end
    [~,iMax] = max(nCnt);
    
    tSnap.Plot(:)       = (tSnap.Freq == tGrp.Freq(iMax) & tSnap.NumPts == tGrp.NumPts(iMax));
    tSnap.Adjust(:)     = tSnap.Plot(:);
    
    hSnap = uitable( 'Parent', hG1, 'FontSize', cwave.FontSize ...
        , 'Data', tSnap ...
        , 'ColumnSortable', false, 'ColumnEditable', [false false false true true true] ...
        , 'CellEditCallback', @sub_TableChkChg ...
        );
    
    % Median Waveform harmonic amplitude plot
    hHarm = uiaxes( 'Parent', hG1, 'FontSize', cwave.FontSize, 'Box', 'on' );
    hHarm.Title.String  = 'Median Waveform Harmonics';
    hHarm.XLabel.String = 'Frequency (Hz)';
    hHarm.Layout.Column = 1;
    hHarm.Layout.Row    = 3;
    
    % Waveform plot & it's row of top buttons
    hG2 = uigridlayout( hG1 );
    hG2.Layout.Column   = 2;
    hG2.Layout.Row      = [2 3];
    hG2.RowHeight       = {cwave.BtnHt,'1x'};
    hG2.ColumnWidth     = {cwave.BtnWd/2, cwave.BtnWd/3, cwave.BtnWd/3, cwave.BtnWd/3, cwave.BtnWd/3 ...
                         , cwave.BtnWd/4, cwave.BtnWd, cwave.BtnWd, cwave.BtnWd, cwave.BtnWd ...
                         , '1x'};
    hG2.ColumnSpacing   = 0;
    hG2.RowSpacing      = 0;
    hG2.Padding         = [0 0 0 0];
    uilabel( 'Parent', hG2, 'Text', 'Shift:  ', 'HorizontalAlignment', 'right' ...
        , 'FontSize', cwave.FontSize, 'FontWeight', 'bold' );
    uibutton( 'Parent', hG2, 'Text', '<<', 'ButtonPushedFcn', @(~,~)sub_Shift(-10) );
    uibutton( 'Parent', hG2, 'Text', '<', 'ButtonPushedFcn', @(~,~)sub_Shift(-1) );
    uibutton( 'Parent', hG2, 'Text', '>', 'ButtonPushedFcn', @(~,~)sub_Shift(1) );
    uibutton( 'Parent', hG2, 'Text', '>>', 'ButtonPushedFcn', @(~,~)sub_Shift(10) );
    uilabel( 'Parent', hG2, 'Text', '' ); % dummy fill
    uibutton( 'Parent', hG2, 'Text', 'Truncate', 'ButtonPushedFcn', @sub_Truncate );
    uibutton( 'Parent', hG2, 'Text', 'Center', 'ButtonPushedFcn', @sub_Center );
    uibutton( 'Parent', hG2, 'Text', 'Align', 'ButtonPushedFcn', @sub_Align );
    uibutton( 'Parent', hG2, 'Text', 'Flip', 'ButtonPushedFcn', @sub_Flip );
    
    hWave = uiaxes( 'Parent', hG2, 'FontSize', cwave.FontSize, 'Box', 'on' );
    hWave.Layout.Column = [1 numel(hG2.ColumnWidth)];
    hWave.Layout.Row    = 2;
    
    % Dialog ending buttons
    hGB = uigridlayout( hG1 );
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
    
    % Now that the UI elements exist, plot the appropriate stuff
    sub_Plot();
    
    % Median waveform variables filled in sub_Plot for saving on exit
    [nMedTm, nMedAmp] = deal([]);
    
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
        % Has a median waveform been successfully created?
        if isempty( nMedAmp )
            uialert( hFig, {
                'No median waveform has been created.'
                ''
                ['To complete this process, you need to have at ' ...
                'least one waveform selected in the table (though ' ...
                'more are preferred for statistical reasons) and ' ...
                'the plot on the bottom left should show Fourier ' ...
                'coefficients.']
                }, 'Save Waveform' );
            return;
        end
        
        % How long is this waveform?
        nWaveT = nMedTm(end) + nMedTm(2);   % NB: times start at 0 so nMedTm(2) == dt
        
        % If there is an ideal waveform, check some stuff out
        if ~isempty( nIdealT )
            % Check waveform time length
            if nWaveT ~= nIdealTMax
                if ~strcmpi( 'Yes', uiconfirm( hFig, {[
                    'The SUESI log specified a waveform that is ' ...
                    num2str(nIdealTMax) ...
                    ' seconds long. You have selected SNAPs that are '  ...
                    num2str(nWaveT) ' seconds long.']
                    ' '
                    'Is this correct?'
                    }, 'Save Waveform', 'Options', {'Yes','Cancel'} ) )
                    return;
                end
            end
            
            % Check waveform polarity
            if sign( nIdealA(1) ) ~= sign( nMedAmp(1) )
                if ~strcmpi( 'Yes', uiconfirm( hFig, {[
                    'The polarity of your SNAP-derived waveform ' ...
                    'might be flipped wrt the ideal waveform specified ' ...
                    'in the SUESI log. If you get this ' ...
                    'wrong, your CSEM phases will be incorrect.']
                    ' '
                    'Is the polarity correct?'
                    }, 'Save Waveform', 'Options', {'Yes','Cancel'} ) )
                    return;
                end
            end
        end
        
        % Pre-allocate space for the data, then fill. This preserves the table's
        % constructed properties (esp default value). (NB: triggers listeners so
        % replace entire table at one time, not in pieces)
        t = cwave.GetDfltFor( 'tableWaveSNAP', numel(nMedAmp) );
        t.Time(:)               = nMedTm;
        t.Amplitude(:)          = nMedAmp;
        oWave.tableWaveSNAP     = t;
        
        % Log success
        oWave.AddLog( cwave.LogOK, cwave.sLog_Wave_SNAP ...
            , sprintf( 'Created %.1fs long median waveform from %d SNAPs (%d data points)' ...
                     , nWaveT, sum( hSnap.Data.Plot ), numel(nMedTm) ) );
        
        % Clear the harmonics table. It is now invalid
        oWave.tableHarmonics    = cwave.GetDfltFor( 'tableHarmonics' );
        
        % Close the dialog
        delete( hFig );
        return;
    end % sub_Save
    
    %---------------------------------------------------------------------------
    function sub_Plot()
        % If there is an idealized waveform, plot it first so the user can see
        % whether their snaps are (a) the right length in time and (b) the right
        % polarity. 
        if ~isempty( nIdealT )
            plot( hWave, nIdealT, nIdealA ...
                , 'Marker', 'none', 'LineStyle', '-', 'Color', 'k' ...
                , 'DisplayName', 'Ideal (from SUESI instructions)' );
            hold( hWave, 'on' );
        end
        
        % Plot each selected waveform, applying the colors back into the table
        % so that the association is evident between the table & plot
        removeStyle( hSnap );
        tSnap   = hSnap.Data;
        bMedOK  = true;
        nFreq   = [];
        nT      = [];
        nData   = [];
        for iSnap = 1:size(tSnap,1)
            if tSnap.Plot(iSnap)
                hLn = plot( hWave, cSnap{iSnap,2}, cSnap{iSnap,3} ...
                    , 'Marker', 'none', 'LineStyle', '-', 'UserData', iSnap );
                hold( hWave, 'on' );
                addStyle( hSnap, uistyle( 'FontColor', hLn.Color ), 'row', iSnap );
                
                % Accumulate the snaps
                if bMedOK
                    if isempty( nData )
                        nFreq = cSnap{iSnap,1};
                        nT    = reshape( cSnap{iSnap,2}, 1, [] );
                        nData = reshape( cSnap{iSnap,3}, 1, [] );
                    elseif nFreq ~= cSnap{iSnap,1}
                        bMedOK = false;
                        addStyle( hSnap, uistyle( 'FontColor', 'w', 'BackgroundColor', cwave.nClrError ) ...
                            , 'cell', [iSnap 1] );
                    elseif numel(nT) ~= numel( cSnap{iSnap,2} )
                        bMedOK = false;
                        addStyle( hSnap, uistyle( 'FontColor', 'w', 'BackgroundColor', cwave.nClrError ) ...
                            , 'cell', [iSnap 2] );
                    else
                        nData(end+1,:) = reshape( cSnap{iSnap,3}, 1, [] );
                    end
                end
            end
        end
        hold( hWave, 'off' );
        hWave.XLabel.String = 'Time (s)';
        hWave.YLabel.String = 'Normalized Amplitude';
        
        % If all the selected SNAPs are the same size & frequency sampling rate,
        % then we can create the median waveform and also plot waveform
        % harmonics. If not, drop text into the harmonic plot to tell the user
        % what's wrong.
        if bMedOK && ~isempty( nData )
            nMedTm  = nT;
            nMedAmp = median( nData, 1 );
            hold( hWave, 'on' );
            plot( hWave, nMedTm, nMedAmp, 'Color', 'k', 'Marker', 'none' ...
                , 'LineStyle', ':', 'LineWidth', 0.5 );
            hold( hWave, 'off' );
            
            [nFFT, nFreqList] = calcFFT( nMedAmp, nFreq );
            stem( hHarm, nFreqList, abs(nFFT) );
            hHarm.XScale = 'log';
            decadeTick( hHarm, 'x' );
            hHarm.XLabel.String = 'Frequency (Hz)';
            hHarm.YLabel.String = 'Amplitude';
            hHarm.Box = 'on';
        else
            [nMedTm, nMedAmp] = deal([]);
            cla( hHarm, 'reset' );
            hHarm.Box = 'on';
            hHarm.GridLineStyle = 'none';
            text( hHarm, mean(hHarm.XLim), mean(hHarm.YLim) ...
                , {
                'The selected SNAPs do not share the same frequency'
                'and/or data length. Cannot join and calculate the'
                'median waveform.'
                }, 'FontSize', cwave.FontSize ...
                , 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle' ...
                );
        end
        
        return;
    end % sub_Plot
    
    %---------------------------------------------------------------------------
    % User has changed one of the checkboxes in the table
    function sub_TableChkChg(~,ced)
        nRow = ced.Indices(1);
        nCol = ced.Indices(2);
        if nCol == 4        % "Plot" column
            % When "Plot" is toggled, make "Adjust" match
            hSnap.Data.Adjust(nRow) = hSnap.Data.Plot(nRow);
        elseif nCol == 5    % "Adjust" column
            % If Adjust is turned on but plot is off, turn it on
            if ced.NewData && ~hSnap.Data.Plot(nRow)
                hSnap.Data.Plot(nRow) = ced.NewData;
            end
        end
        
        % Refresh the display
        sub_Plot();
        return;
    end % sub_TableChkChg
    
    %---------------------------------------------------------------------------
    % Shift the time series of the selected SNAP(s) left or right
    function sub_Shift( nAmt )
        if ~any(tSnap.Adjust)
            uialert( hFig, 'Select at least one waveform for adjustment in the table on the left.' ...
                , 'Shift SNAP in Time' );
            return;
        end
        tSnap = hSnap.Data;
        for iSnap = reshape( find(tSnap.Adjust), 1, [] )
            cSnap{iSnap,3} = circshift( cSnap{iSnap,3}, nAmt );
        end
        sub_Plot();
        return;
    end % sub_Shift
    
    %---------------------------------------------------------------------------
    % Truncate the selected SNAP(s) at some given time length
    function sub_Truncate(~,~)
        sMsgTitle = 'Truncate SNAP data series';
        
        % Get the max numpts for all selected waveforms
        tSnap = hSnap.Data;
        if ~any(tSnap.Adjust)
            uialert( hFig, 'Select at least one waveform for adjustment in the table on the left.' ...
                , sMsgTitle );
            return;
        end
        nMaxPts = max(tSnap.NumPts(tSnap.Adjust));
        cAns = {num2str( nMaxPts )};
        while true
            cAns = inputdlg( {
                'Truncate to # of data points:'
                }, sMsgTitle, ones(size(cAns)), cAns ...
                , struct('Resize', 'on', 'WindowStyle', 'modal', 'Interpreter', 'none') );
            if isempty( cAns )  % user cancel
                return;
            end
            
            % Validate values
            nNewMax = str2num(cAns{1});
            if numel(nNewMax) ~= 1 || ~between( 100, nNewMax, nMaxPts )
                uialert( hFig, [
                    'The truncation value must be a positive scalar' ...
                    sprintf( 'less than %d.', nMaxPts )
                    ], sMsgTitle );
                continue;
            end
            
            % All validations passed. Go for it.
            break;
        end
        
        % Truncate selected SNAPs
        for iSnap = reshape( find(tSnap.Adjust), 1, [] )
            if tSnap.NumPts(iSnap) > nNewMax
                tSnap.NumPts(iSnap) = nNewMax;
                tSnap.Length{iSnap} = sprintf( '%.2fs', nNewMax / tSnap.Freq(iSnap) );
                cSnap{iSnap,2} = cSnap{iSnap,2}(1:nNewMax);
                cSnap{iSnap,3} = cSnap{iSnap,3}(1:nNewMax);
            end
        end
        
        % Refresh the display
        hSnap.Data = tSnap;
        sub_Plot();
        
        return;
    end % sub_Truncate
    
    %---------------------------------------------------------------------------
    % Center each selected waveform separately. Assume that the "center" of the
    % waveform is the rotationally-symmetric point (i.e. mirrored & inverted
    % like a squarewave or the Daveform).
    function sub_Center(~,~)
        % Are there any?
        bSel = hSnap.Data.Adjust;
        if ~any( bSel )
            uialert( hFig, 'Select at least one waveform for adjustment in the table on the left.' ...
                , 'Center Waveforms' );
            return;
        end
        
        % Center each
        for iSnap = reshape( find( bSel ), 1, [] )
            n     = reshape( cSnap{iSnap,3}, 1, [] );
            iCnt  = floor( numel(n) / 2 );
            iRg1  = 1:iCnt;
            iRg2  = iRg1 + iCnt;
            nDiff = NaN(iCnt,1);
            for i = 1:iCnt
                nDiff(i) = sum( abs( n(iRg1) - fliplr(n(iRg2)) ) );
                n = circshift( n, 1 );
            end
            [~,iAt] = min( nDiff );
            cSnap{iSnap,3} = circshift( cSnap{iSnap,3}, iAt-1 );
        end
        
        % Refresh the display
        sub_Plot();
        
        return;
    end % sub_Center
    
    %---------------------------------------------------------------------------
    % Align a group of waveforms so that they are not anti-correlated or off
    % cycle
    function sub_Align(~,~)
        % Are there any? There must be more than one
        iList = reshape( find( hSnap.Data.Adjust ), 1, [] );
        if numel(iList) < 2
            uialert( hFig, 'Select at least TWO waveforms for adjustment in the table on the left.' ...
                , 'Align Waveforms' );
            return;
        end
        
        % All the selected waveforms MUST have the same number of samples
        if any( diff(hSnap.Data.NumPts(iList)) ~= 0 )
            uialert( hFig, 'Selected waveforms must have the same number of data points in order to align them.' ...
                , 'Align Waveforms' );
            return;
        end
        
        % Get the first waveform. Align the others to it
        n1       = reshape( cSnap{iList(1),3}, 1, [] );
        iList(1) = [];
        
        % Center each
        for iSnap = iList
            n     = reshape( cSnap{iSnap,3}, 1, [] );
            nDiff = NaN(numel(n1),1);
            for i = 1:numel(n1)
                nDiff(i) = sum( abs( n1 - n ) );
                n = circshift( n, 1 );
            end
            [~,iAt] = min( nDiff );
            cSnap{iSnap,3} = circshift( cSnap{iSnap,3}, iAt-1 );
        end
        
        % Refresh the display
        sub_Plot();
        
        return;
    end % sub_Align
    
    %---------------------------------------------------------------------------
    % Flip the polarity of a group of waveforms
    function sub_Flip(~,~)
        % Are there any?
        bSel = hSnap.Data.Adjust;
        if ~any( bSel )
            uialert( hFig, 'Select at least one waveform for adjustment in the table on the left.' ...
                , 'Flip Waveform Polarity' );
            return;
        end
        
        % Center each
        for iSnap = reshape( find( bSel ), 1, [] )
            cSnap{iSnap,3} = cSnap{iSnap,3} * -1;
        end
        
        % Refresh the display
        sub_Plot();
        
        return;
    end % sub_Flip
    
end % SNAP2Waveform
