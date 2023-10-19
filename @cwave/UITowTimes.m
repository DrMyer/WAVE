function UITowTimes( oWave )
% cwave::UITowTimes( oWave )
%
% Edit UI for tableTow - tow number, times, TX time lag, & phase shift
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
    
    % Build the UI
        % NB: as of MatLab R2020b (thankfully WAVE's min reqd version) ginput
        % will work with uifigure children but only if you make the parent
        % figure visible within callbacks.
    hFig = uifigure( 'Name', 'Select Tow Times', 'WindowStyle', 'modal' ...
        , 'Visible', false, 'Resize', true, 'Units', 'pixels' ...
        , 'Position', [1 1 1600 900], 'HandleVisibility', 'callback' ...
        );
    figCenter( oWave.hFig, hFig );
    
    % Major zone grid
    hGzone = uigridlayout( hFig );
    hGzone.RowHeight       = {'fit','1x'};
    hGzone.ColumnWidth     = {'11x','9x'};
    hGzone.ColumnSpacing   = 5;
    hGzone.RowSpacing      = 5;
    hGzone.Padding         = [10 10 10 20];
    
    % Instructions
    uilabel( 'Parent', hGzone, 'WordWrap', 'on', 'FontSize', cwave.FontSize + 2 ...
        , 'Text', [
        'INSTRUCTIONS: Use "Auto-fill" to automatically select tows based on ' ...
        'gaps in the SDM time series. Otherwise, add or select a tow in the ' ...
        'list on the right to highlight it in the map on the left. Note the ' ...
        'tabs at the top left of the map allowing you to look at SDM and ' ...
        'towfish altitude as well. With a tow selected, you can set the ' ...
        'start & end times by selecting on the map or one of the other ' ...
        'plots. The times will automatically fill in to the table.'
        ]);
    
    % The plotting / select-on-plot section
    htgPlot = uitabgroup( 'Parent', hGzone );
    htgPlot.Layout.Row = 2;
    htgPlot.Layout.Column = 1;
    htbMap = uitab( 'Parent', htgPlot, 'Title', 'Map' );
    haxMap = MakeTabGrid( htbMap, @sub_SlctOnMap, 'Select on Map' );
    
    htbSDM = uitab( 'Parent', htgPlot, 'Title', 'Source dipole moment' );
    haxSDM = MakeTabGrid( htbSDM, @sub_SlctOnSDM, 'Select Time Range' );
    
    htbAlt = uitab( 'Parent', htgPlot, 'Title', 'SUESI Altitude' );
    haxAlt = MakeTabGrid( htbAlt, @sub_SlctOnAlt, 'Select Time Range' );
    
    % The tow table section
    hG = uigridlayout( hGzone );
    hG.RowHeight       = {cwave.BtnHt, cwave.BtnHt, '1x', cwave.BtnHt};
    hG.ColumnWidth     = {cwave.BtnWd, cwave.BtnWd, cwave.BtnWd, cwave.BtnWd, '1x'};
    hG.ColumnSpacing   = 0;
    hG.RowSpacing      = 5;
    hG.Padding         = [0 0 0 0];
    
    h = uibutton( 'Parent', hG, 'Text', 'Auto-fill', 'Icon', w_IconLib( 'AutoFill' ) ...
        , 'FontSize', cwave.FontSize, 'ButtonPushedFcn', @sub_AutoFill );
    h.Layout.Column = [1 2];
    uilabel( 'Parent', hG, 'FontSize', cwave.FontSize, 'HorizontalAlignment', 'right' ...
        , 'Text', 'Gap size (min):' );
    hedGapMin = uieditfield( hG, 'numeric', 'Value', 15, 'Limits', [1 100] ...
        , 'RoundFractionalValues', 'on', 'FontSize', cwave.FontSize );
    
    h = uibutton( 'Parent', hG, 'Text', 'Add', 'Icon', w_IconLib( 'AddRow' ) ...
        , 'FontSize', cwave.FontSize, 'ButtonPushedFcn', @sub_AddRow );
    h.Layout.Row = 2;
    h.Layout.Column = 1;
    uibutton( 'Parent', hG, 'Text', 'Delete', 'Icon', w_IconLib( 'DelRow' ) ...
        , 'FontSize', cwave.FontSize, 'ButtonPushedFcn', @sub_DelRow );
    uibutton( 'Parent', hG, 'Text', 'Reset', 'Icon', w_IconLib( 'Reset' ) ...
        , 'FontSize', cwave.FontSize, 'ButtonPushedFcn', @sub_Reset );
    
    iTblSelect = zeros(0,2);
    hTable = uitable( 'Parent', hG, 'FontSize', cwave.FontSize ...
        , 'Data', oWave.tableTow, 'RowName', [] ...
        , 'CellSelectionCallback', @sub_TrackSlctn ...
        , 'ColumnEditable', true );
    hTable.Layout.Row       = numel(hG.RowHeight) - 1;
    hTable.Layout.Column    = [1 numel(hG.ColumnWidth)];
    
    % Dialog button row needs sub-dividing
    hGB = uigridlayout( hG );
    hGB.Layout.Row      = numel(hG.RowHeight);
    hGB.Layout.Column   = [1 numel(hG.ColumnWidth)];
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
    
    % Plot all the plots
    sub_Plot();
    
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
        % Validate the table
        [bChk,cErrMsg] = oWave.ValidateTowTimes( hTable.Data, hFig, true ); % true = OK to ask questions
        if ~all( bChk )
            % Color bad rows
            removeStyle( hTable );
            addStyle( hTable, uistyle( 'FontColor', cwave.nClrError ) ...
                , 'row', reshape( find( ~bChk ), 1, [] ) );
            
            % Scroll to the first non-valid row.
            iBadRow = find( ~bChk, 1, 'first' );
            scrollR2020b( hTable, 'row', iBadRow );
            
            % Show the error message. NB: if cErrMsg is empty, then assume the
            % validation function has already explained matters to the user
            if ~isempty( cErrMsg )
                uialert( hFig, cErrMsg, 'Error', 'Icon', 'error', 'Modal', true );
            end
            
            % return early
            return;
        end
        
        % Update the main object
        oWave.tableTow = hTable.Data;
        
        % If we get here, everything is OK
        delete( hFig );
        return;
    end % sub_Save
    
    %---------------------------------------------------------------------------
    function sub_Plot()
        % If there are selected rows in the table, then set up to highlight
        % those on the various plots
        iRows   = unique( iTblSelect(:,1) );    % nx2: [row col; row col;...]
        nClrs   = DavesDiscreteColors( numel(iRows) );
        cFromTo = {};
        cName   = {};
        tTow    = hTable.Data;
        for i = 1:numel(iRows)
            cName{i}   = ['Tow ' num2str(tTow.TowNo(iRows(i)))];
            cFromTo{i} = oWave.tableSDM.Time >= tTow.DateFrom(iRows(i)) ...
                       & oWave.tableSDM.Time <= tTow.DateTo(iRows(i));
        end
        
        % Plot the map of Ship locations
        xMap    = oWave.tableSDM.Ship_Lon;
        yMap    = oWave.tableSDM.Ship_Lat;
        hold( haxMap, 'off' );
        plot( haxMap, xMap, yMap ...
            , 'Color', 'k', 'Marker', '.', 'LineStyle', 'none' ...
            , 'DisplayName', 'Ship', 'HitTest', 'off', 'Tag', 'Map' );
        hold( haxMap, 'on' );
        for i = 1:numel(iRows)
            plot( haxMap, xMap(cFromTo{i}), yMap(cFromTo{i}) ...
                , 'Color', nClrs(i,:), 'Marker', 'o', 'LineStyle', 'none' ...
                , 'DisplayName', cName{i}, 'HitTest', 'off', 'Tag', 'Tow' );
        end
        title( haxMap, 'Ship Location' );
        xlabel( haxMap, 'Longitude' );
        ylabel( haxMap, 'Latitude' );
        axisTight( haxMap );
        if isempty(iRows)
            legend( haxMap, 'off' );
        else
            legend( haxMap, 'Location', 'best' );
        end
        
        % Plot the SDM vs time
        hold( haxSDM, 'off' );
        plot( haxSDM, oWave.tableSDM.Time, oWave.tableSDM.SDM ...
            , 'Color', 'k', 'Marker', '.', 'LineStyle', 'none' ...
            , 'DisplayName', 'Ship', 'HitTest', 'off' );
        hold( haxSDM, 'on' );
        for i = 1:numel(iRows)
            plot( haxSDM, oWave.tableSDM.Time(cFromTo{i}), oWave.tableSDM.SDM(cFromTo{i}) ...
                , 'Color', nClrs(i,:), 'Marker', 'o', 'LineStyle', 'none' ...
                , 'DisplayName', cName{i}, 'HitTest', 'off', 'Tag', 'Tow' );
        end
        title( haxSDM, 'Source Dipole Moment' );
        axisTight( haxSDM );
        if isempty(iRows)
            legend( haxSDM, 'off' );
        else
            legend( haxSDM, 'Location', 'best' );
        end
        
        % Plot the altitude vs time (only useful for deep towed SUESI)
        hold( haxAlt, 'off' );
        plot( haxAlt, oWave.tableSDM.Time, oWave.tableSDM.Altitude ...
            , 'Color', 'k', 'Marker', '.', 'LineStyle', 'none' ...
            , 'DisplayName', 'Ship', 'HitTest', 'off' );
        hold( haxAlt, 'on' );
        for i = 1:numel(iRows)
            plot( haxAlt, oWave.tableSDM.Time(cFromTo{i}), oWave.tableSDM.Altitude(cFromTo{i}) ...
                , 'Color', nClrs(i,:), 'Marker', 'o', 'LineStyle', 'none' ...
                , 'DisplayName', cName{i}, 'HitTest', 'off', 'Tag', 'Tow' );
        end
        title( haxAlt, 'SUESI altimeter' );
        ylabel( haxAlt, 'Altitude above Seafloor (m)' );
        axisTight( haxAlt );
        if isempty(iRows)
            legend( haxAlt, 'off' );
        else
            legend( haxAlt, 'Location', 'best' );
        end
        
        return;
    end % sub_Plot
    
    %---------------------------------------------------------------------------
    % Track selection events because the stupid uitable class does NOT give you
    % a way to find out what is currently selected. How dumb is that?
    function sub_TrackSlctn(~,st)
        iTblSelect = st.Indices;
        sub_Plot();
        return;
    end % sub_TrackSlctn
    
    %---------------------------------------------------------------------------
    % Add a new row to the bottom of the table
    function sub_AddRow(~,~)
        hTable.Data{end+1,:} = missing();
        scrollR2020b( hTable, 'row', size(hTable.Data,1) );
        return;
    end % sub_AddRow
    
    %---------------------------------------------------------------------------
    % User wants to delete the currently selected rows
    function sub_DelRow(~,~)
        if isempty( iTblSelect )
            uialert( hFig, 'No rows selected', 'Delete Rows' );
            return;
        end
        iRows = unique( iTblSelect(:,1) );  % dim(n,2) [row col;... row col] pairs
        hTable.Data(iRows,:) = [];
        
        % Refresh the interface
        iTblSelect = zeros(0,2);
        sub_Plot();
        return;
    end % sub_DelRow
    
    %---------------------------------------------------------------------------
    % Reset the tow table entirely
    function sub_Reset(~,~)
        hTable.Data = cwave.GetDfltFor( 'tableTow' );
        
        % Refresh the interface
        iTblSelect = zeros(0,2);
        sub_Plot();
        return;
    end % sub_Reset
    
    %---------------------------------------------------------------------------
    % Figure out what the tows are automatically and fill the table
    function sub_AutoFill(~,~)
        % If the table isn't empty warn that all data will be replaced
        if ~isempty( hTable.Data )
            if ~strcmpi( 'Yes', uiconfirm( hFig, {
                    'Auto-fill will completely replace the existing'
                    'table of tow times.'
                    ''
                    'Continue?'
                }, 'Auto-fill Tow Table', 'Options', {'Yes', 'No'} ...
                , 'DefaultOption', 1, 'CancelOption', 2 ) )
                return;
            end
        end
        
        % Ideally I would look for gaps in altitude data caused by pulling SUESI
        % shallow for turns. However, for shallow towing, altitude is always
        % NaN.
        %
        % So let's just look for gaps in time in tableSDM.
        %
        % How big of a gap should I look for?
        nGapMin = minutes( hedGapMin.Value );
        tDur    = diff( oWave.tableSDM.Time );
        iGap    = onerow( find( tDur >= nGapMin ) );
        
        % If no gaps found in the time series directly, look for places where
        % the altitude is too shallow to be recorded and use those gaps
        tUse = oWave.tableSDM.Time;
        if isempty( iGap ) 
            bNoAlt = isnan(oWave.tableSDM.Altitude);
            if between( 100, sum(bNoAlt), height(oWave.tableSDM) / 3 )
                tUse(bNoAlt) = [];
                tDur    = diff( tUse );
                iGap    = onerow( find( tDur >= nGapMin ) );
            end
        end
        
        nFrom   = [1 iGap+1];
        nTo     = [iGap numel(tDur)];
        
        % Get rid of segments that don't contain many actual data points
        bDel = (nTo - nFrom) < 200;
        nFrom(bDel) = [];
        nTo(bDel) = [];
        
        % Create the table
        tTow                = cwave.GetDfltFor( 'tableTow', numel(nFrom) );
        tTow.TowNo(:)       = 1:numel(nFrom);
        tTow.DateFrom(:)    = tUse(nFrom);
        tTow.DateTo(:)      = tUse(nTo);
        tTow.IgnoreNav(:)   = 0;
        tTow.WireOutTare(:) = 0;
        tTow.PhaseShift(:)  = 0;
        
        % Find the orientation from the selected ship-track data
        tTow                = sub_FindOrient( tTow, 1:height(tTow) );
        
        % Update the table. Select every row & replot. NB: as of R2020b there's
        % no way to tell uitable to select particular rows. Fake it.
        iTblSelect = [(1:height(tTow)).' ones(height(tTow),1)];
        hTable.Data = tTow;
        sub_Plot();
        
        return;
    end % sub_AutoFill
    
    %---------------------------------------------------------------------------
    % Allow the user to select a particular tow by clicking end points on the
    % map
    function sub_SlctOnMap(~,~)
        ManageMouseSelect( haxMap, 'Map' );
        sub_Plot();
        return;
    end % sub_SlctOnMap
    
    %---------------------------------------------------------------------------
    % Allow the user to select a particular tow by selecting a time range on the
    % SDM plot
    function sub_SlctOnSDM(~,~)
        ManageMouseSelect( haxSDM, 'Time' );
        sub_Plot();
        return;
    end % sub_SlctOnSDM
    
    %---------------------------------------------------------------------------
    % Allow the user to select a particular tow by selecting a time range on the
    % altitude plot
    function sub_SlctOnAlt(~,~)
        ManageMouseSelect( haxAlt, 'Time' );
        sub_Plot();
        return;
    end % sub_SlctOnAlt

    %---------------------------------------------------------------------------
    % Manage using the mouse to select tow times on any of the plot axes
    function ManageMouseSelect( hAx, sSelType )
        % Which type of selection? Map (x,y) or time plot (x only)
        bXonly = strcmpi( sSelType, 'Time' );
        
        % Need to have just ONE row to be selecting for
        if size(iTblSelect,1) ~= 1
            uialert( hFig, ['Select exactly one row in the tow time table. ' ...
                'Then select the times for that tow in the plot.'] ...
                , 'Select Tow Times' );
            return;
        end
        
        % Get rid of any tow plots already on the axes
        hDel = findobj( hAx, 'Tag', 'Tow' );
        if ~isempty( hDel )
            delete( hDel );
        end
        
        % For now use the easy ginput() function. May need to go to the more
        % complicated ButtonDownFcn control if this isn't acceptable.
        sOldTitle = hAx.Title.String;
        nOldColor = hAx.Title.Color;
        if bXonly
            hAx.Title.String = 'Select the start and end times. <RETURN> cancels.';
        else
            hAx.Title.String = 'Click TWO points along the tow track. <RETURN> cancels.';
        end
        hAx.Title.Color = 'r';
        
        % Get input
        axes( hAx );    % make this axes current
        [nX,nY] = ginput( 2 );
        
        % Restore settings
        hAx.Title.String = sOldTitle;
        hAx.Title.Color = nOldColor;
        
        % If there aren't two points, then the user canceled
        if numel(nX) ~= 2
            return;
        end
        
        % Find the start & end of the tow
        if bXonly
            % nX is the number of DAYS relative to the DAY of the first plotted
            % datapoint (not XLim). Yes this is weird. Hopefully it doesn't change
            % in a different MATLAB version. That would be awkward.
            nRange = dateshift( min(oWave.tableSDM.Time), 'start', 'day' ) + days(nX);
        else
            % Find the closest points in the map to these x,y values
            hLn = findobj( hAx, 'Tag', 'Map' );
            for iPt = 1:2
                % NB: don't need sqrt() here. Don't care about actual distance
                % value, just which is the shortest.
                [~,iMin] = min( (hLn.XData - nX(iPt)).^2 + (hLn.YData - nY(iPt)).^2 );
                nRange(iPt) = oWave.tableSDM.Time(iMin);
            end
        end
        
        % Sort the times
        nRange = sort( nRange );
        
        % Set the time ranges in the table's data
        tTow = hTable.Data;
        tTow.DateFrom(iTblSelect(1)) = nRange(1);
        tTow.DateTo(iTblSelect(1))   = nRange(2);
        tTow = sub_FindOrient( tTow, iTblSelect(1) );
        hTable.Data = tTow;
        
        return;
    end % ManageMouseSelect
    
    %---------------------------------------------------------------------------
    % Find the approximate tow orientations of the given rows in the tow table
    function tTow = sub_FindOrient( tTow, iRows )
        stWarn = warning( 'off', 'MATLAB:rankDeficientMatrix' );
        for iRow = reshape( iRows, 1, [] )
            b = btwn( tTow.DateFrom(iRow), oWave.tableSDM.Time, tTow.DateTo(iRow) );
            n = oWave.tableSDM.Ship_North(b);
            e = oWave.tableSDM.Ship_East(b);
            
            n(:,2) = 1; % form Vandermonde matrix for East = m * North + b
            nMxB   = n \ e;
            nEofN  = atand( nMxB(1) );
            
            % Above is ambiguous by 180 degrees but more accurate than just
            % looking at the 1st & last points of the series. However, first &
            % last do give a rough estimate which I use to resolve the ambiguity
            nEst   = atan2d( diff(e([1 end])), diff(n([1 end],1)) );
            if abs( phaseDiff( nEst, nEofN, 'Degrees' ) ) > 90
                nEofN = nEofN + 180;
            end
            
            % Make it a positive angle from 0 to 359.999
            tTow.DirEofN(iRow) = mod( nEofN, 360 );
            
            % Check for a curved path and, if so, warn the user then set the
            % IgnoreNav flag
            e2 = n * nMxB;
            de = abs(e - e2);
            if median(de) > 150 % arbitrary - more than 150m median deviation
                % Dump some rudimentary stats to the command window
                fprintf('%3d %7.1f %7.1f %7.1f %7.1f %7.1f %7.1f\n' ...
                    , tTow.TowNo(iRow) ...
                    , mean(de), std(de) ...
                    , sum(abs(de - mean(de)) > std(de)) / numel(de) * 100 ...
                    , median(de), mad(de) ...
                    , sum(abs(de - median(de)) > mad(de)) / numel(de) * 100 );
                
                % NB: uialert always returns immediately without waiting for OK
                % even when set Modal. Must use uiconfirm and collect the
                % result, even if you don't look at the result.
                s = uiconfirm( hFig, {
                    'WARNING'
                    ' '
                    sprintf( 'Tow %d has too much curvature.', tTow.TowNo(iRow) )
                    'iLBL navigation requires relatively straight tow lines.'
                    'This tow will be flagged to ignore iLBL navigation and'
                    'use locations projected back into the ship track.'
                    }, 'Delete using the Mouse', 'Icon', 'warning', 'Options', {'OK'} ); %#ok<NASGU>
                tTow.IgnoreNav(iRow) = 1;
            end
            
        end % loop over selection rows
        warning( stWarn );
        
        return;
    end % sub_FindOrient
    
end % UITowTimes

%-------------------------------------------------------------------------------
% Create the plotting & selection widgets on one plotting uitab
function hAx = MakeTabGrid( hTab, fcnBtn, sBtn )
    hG = uigridlayout( hTab );
    hG.RowHeight       = {cwave.BtnHt*2, '1x'};
    hG.ColumnWidth     = {'1x',cwave.BtnWd*2};
    hG.ColumnSpacing   = 0;
    hG.RowSpacing      = 5;
    hG.Padding         = [0 0 0 0];
    
    hBtn = uibutton( 'Parent', hG, 'Text', sBtn ...
        , 'FontSize', cwave.FontSize ...
        , 'ButtonPushedFcn', fcnBtn ...
        );
    hBtn.Layout.Column  = numel(hG.ColumnWidth);
    
    hAx                 = axes( hG );
    hAx.Layout.Row      = numel(hG.RowHeight);
    hAx.Layout.Column   = [1 numel(hG.ColumnWidth)];
    hAx.FontSize        = cwave.FontSize;
    
    return;
end % MakeTabGrid
