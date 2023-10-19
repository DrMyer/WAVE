function [bChgd,tData,cChgLog] = UITablePlot( tData, sX, sY, hParent, sTitle, sPlotDir, sPlotSubtitle )
% Generic utility to plot a table; allows the user to interactively change the X
% and Y plot variables to investigate relationships between table data.
%
% Params:
%   tData    - table to plot. Note that EVERY numeric variable must be a single
%               column of data not a matrix.
%   sX,sY    - starting "X" and "Y" table variables to plot. If empty will use
%               the first & second numeric fields
%   hParent  - handle of uifigure to center over
%   sTitle   - figure title
%   sPlotDir - (opt; dflt []) folder to default addPlotMenu to for figures
%   sPlotSubtitle - (opt; dflt '') sub-title to put on the extracted figures
%
% Returns:
%   bChgd   - True if changes were made. If the caller doesn't request ANY
%           return values then changes are NOT allowed
%   tData   - table passed in with any changes the user has made. 
%   cChgLog - cell array of descriptions of the changes the user has made
%
%-------------------------------------------------------------------------------
% Copyright (C) 2023 David Myer
% 
% This program is free software: you can redistribute it and/or modify it under
% the terms of the GNU General Public License as published by the Free Software
% Foundation, version 3. This program is distributed in the hope that it will be
% useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. To view the GNU General
% Public License see <https://www.gnu.org/licenses/>
%-------------------------------------------------------------------------------
% See also UITableEdit, UITableImport

    % Fill in optional params
    if ~exist( 'sPlotDir', 'var' )
        sPlotDir = [];
    end
    if ~exist( 'sPlotSubtitle', 'var' ) || ~ischar( sPlotSubtitle )
        sPlotSubtitle = '';
    end
    
    % Are changes allowed?
    bChgOK  = (nargout() > 0);
    bChgd   = false;
    cChgLog = {};
    
    % Accumulate info about the table
    stWarn = warning( 'off', 'MATLAB:table:ModifiedVarnames' );
    stSum  = summary( tData );
    warning( stWarn );
    
    % Set up the default "all data" filter
    bFilter     = true(height(tData),1);
    sFiltDesc   = '';
    
    % Create the list of plotable variables (numeric & datetime types only).
    % Also find the user's preferred X & Y variables (if specified)
    iX1st  = 1;
    iY1st  = 2;
    cFld   = {};
    cDescX = {};
    cDescY = {}; % y-axis descr also includes [min,max] limits for info
    cUnit  = {};
    for iFld = 1:numel(tData.Properties.VariableNames)
        sFld = tData.Properties.VariableNames{iFld};
        try
            sUnit = tData.Properties.VariableUnits{iFld};
        catch
            sUnit = '';
        end
        
        if isnumeric( tData.(sFld) ) || isdatetime( tData.(sFld) )
            % Plotable so save it to the list
            % NB: uilistbox wants a single row of strings...
            cFld{1,end+1}  = sFld;
            cUnit{1,end+1} = sUnit;
            if isempty( sUnit )
                cDescX{1,end+1} = strrep( sFld, '_', ' ' );
            else
                cDescX{1,end+1} = [strrep( sFld, '_', ' ' ) ' (' sUnit ')'];
            end
            cDescY{1,end+1} = cDescX{1,end};
            
            % Put (min:max) in the description
            try %#ok<TRYNC>
                if strcmpi( stSum.(sFld).Type, 'datetime' )
                    sMinMax = [' [' datestr(stSum.(sFld).Min,26) ',' datestr(stSum.(sFld).Max,26) ']'];
                else
                    sMinMax = [' [' num2str(stSum.(sFld).Min) ',' num2str(stSum.(sFld).Max) ']'];
                end
                cDescY{end} = [cDescY{end} sMinMax];
            end
            
            % Is this one of the requested X or Y fields?
            if strcmpi( sX, sFld )
                iX1st = numel(cFld);
            elseif strcmpi( sY, sFld )
                iY1st = numel(cFld);
            end
        end
    end % loop through the table's variables
    
    % Build the UI
    hFig = uifigure( 'Name', sTitle ...
        , 'Visible', false, 'WindowStyle', 'modal', 'Resize', true ...
        , 'Units', 'pixels', 'Position', [1 1 1400 1020] ...
        );
    figCenter( hParent, hFig );
    
    % General grid for all the zones
    hG = uigridlayout( hFig );
    hG.RowHeight    = {'fit','1x', cwave.BtnHt};
    hG.ColumnWidth  = {'fit', '1x'};
    hG.ColumnSpacing= 15;
    hG.RowSpacing   = 15;
    hG.Padding      = [10 10 10 20];
    
    % Instructions at the top
    h = uilabel( 'Parent', hG, 'Wordwrap', 'on', 'FontSize', cwave.FontSize + 2 ...
        , 'Text', [
        'INSTRUCTIONS: Select the X-axis using the dropdown below the plot. ' ...
        'Select ONE OR MORE Y-axis values in the list at the left. Use CTRL ' ...
        'and/or SHIFT + MOUSE to select multiple values.  If you want a figure ' ...
        'suitable for dressing up for publication or presentation, use the ' ...
        '"Make Figure" button then modify the resulting figure to your heart''s ' ...
        'content.'
        ] );
    h.Layout.Column = [1 2];
    
    % Y-axis variable list
    hYAxis = uilistbox( 'Parent', hG ...
        , 'Items', cDescY, 'ItemsData', 1:numel(cDescY) ...
        , 'Value', iY1st, 'FontSize', cwave.FontSize, 'Multiselect', true ...
        , 'ValueChangedFcn', @sub_AxisChg );
    
    % Plot and it's option controls for filtering, changing, deleting
    hGP = uigridlayout( hG );
    if bChgOK
        hGP.RowHeight       = {cwave.BtnHt, cwave.BtnHt, cwave.BtnHt, cwave.BtnHt,'1x'};
    else
        hGP.RowHeight       = {cwave.BtnHt, cwave.BtnHt,'1x'};
    end
    hGP.ColumnWidth     = {'fit', 'fit', cwave.BtnWd, 2*cwave.BtnWd, 1.5*cwave.BtnWd, '1x', cwave.BtnWd};
    hGP.ColumnSpacing   = 5;
    hGP.RowSpacing      = 0;
    hGP.Padding         = [0 0 0 0];
    
    uilabel( 'Parent', hGP, 'FontSize', cwave.FontSize, 'HorizontalAlignment', 'right' ...
        , 'Text', 'Color by unique values in:' );
    hColorBy = uidropdown( 'Parent', hGP, 'Items', [' ' cDescX], 'ItemsData', 0:numel(cDescX) ...
        , 'Value', 0, 'FontSize', cwave.FontSize, 'ValueChangedFcn', @sub_AxisChg );
    
    h = uilabel( 'Parent', hGP, 'FontSize', cwave.FontSize, 'HorizontalAlignment', 'right' ...
        , 'Text', 'Only plot data when:' );
    h.Layout.Row    = 2;
    h.Layout.Column = 1;
    hFilterFld = uidropdown( 'Parent', hGP ...
        , 'Items', [' ', cDescX], 'ItemsData', 0:numel(cDescX) ...
        , 'Value', 0, 'FontSize', cwave.FontSize ...
        , 'ValueChangedFcn', @sub_FiltFldChg );
    hFilterOp = uidropdown( 'Parent', hGP ...
        , 'Items', {'==', '~=', '<', '<=', '>', '>=', 'one of', 'is NaN', 'isn''t NaN'} ...
        , 'Value', '==', 'FontSize', cwave.FontSize );
    hFilterVal = uieditfield( 'Parent', hGP, 'Value', '', 'FontSize', cwave.FontSize );
    % NB: hFilterVal is a NOT numeric edit field on purpose. Having it be text
    % allows for the user to enter a LIST of values (for 'one of') or an
    % expression to evaluate which may include function calls (sneaky user).
    
    uibutton( 'Parent', hGP, 'FontSize', cwave.FontSize, 'Text', 'Apply' ...
        , 'ButtonPushedFcn', @sub_Filter );
    hFilterCnt = uilabel( 'Parent', hGP, 'FontSize', cwave.FontSize ...
        , 'Text', sprintf( '(%d of %d rows)', sum( bFilter ), numel( bFilter ) ) );
    
    if bChgOK
        h = uilabel( 'Parent', hGP, 'FontSize', cwave.FontSize ...
            , 'HorizontalAlignment', 'right', 'Text', '(Subset) Set:' );
        h.Layout.Row    = 3;
        h.Layout.Column = 1;
        hSetFld = uidropdown( 'Parent', hGP ...
            , 'Items', [' ', cDescX], 'ItemsData', 0:numel(cDescX) ...
            , 'Value', 0, 'FontSize', cwave.FontSize, 'Enable', 'off' );
        uilabel( 'Parent', hGP, 'FontSize', cwave.FontSize ...
            , 'HorizontalAlignment', 'center', 'Text', 'to' );
        hSetVal = uieditfield( 'Parent', hGP, 'Value', '' ...
            , 'FontSize', cwave.FontSize, 'Editable', 'off' );
        hSetBtn = uibutton( 'Parent', hGP, 'FontSize', cwave.FontSize ...
            , 'Text', 'Change Subset' ...
            , 'ButtonPushedFcn', @sub_ChangeFld, 'Enable', 'off' );
        
        h = uilabel( 'Parent', hGP, 'FontSize', cwave.FontSize ...
            , 'HorizontalAlignment', 'right', 'Text', '-OR-' );
        h.Layout.Row    = 4;
        h.Layout.Column = 1;
        hDelBtn = uibutton( 'Parent', hGP, 'FontSize', cwave.FontSize ...
            , 'Text', 'Delete showing, keep rest' ...
            , 'ButtonPushedFcn', @(~,~)sub_DeleteSubset(false), 'Enable', 'off' );
        hDelBtn.Layout.Column = [2 3];
        
        hKeepBtn = uibutton( 'Parent', hGP, 'FontSize', cwave.FontSize ...
            , 'Text', 'Keep showing, delete rest' ...
            , 'ButtonPushedFcn', @(~,~)sub_DeleteSubset(true), 'Enable', 'off' );
        
        h = uibutton( 'Parent', hGP, 'FontSize', cwave.FontSize ...
            , 'WordWrap', 'on', 'Text', 'Delete using the Mouse' ...
            , 'ButtonPushedFcn', @sub_DelByMouse ...
            , 'ToolTip', 'Click opposing corners of a rectangle to delete enclosed data' );
        h.Layout.Row    = [1 3];
        h.Layout.Column = numel(hGP.ColumnWidth);
        
    end
    
    % The plotting axes
    hPlot = uiaxes( 'Parent', hGP, 'FontSize', cwave.FontSize, 'Box', 'on' );
    hPlot.Layout.Row    = numel(hGP.RowHeight);
    hPlot.Layout.Column = [1 numel(hGP.ColumnWidth)];
    hLnList = [];  % list of plot handles for lines (if any)
    
    % Grid up the space under the axis for the next bits
    hGB = uigridlayout( hG );
    hGB.Layout.Column   = [1 2];
    hGB.RowHeight       = {'1x'};
    cSymCols            = {cwave.BtnWd, cwave.BtnWd, cwave.BtnWd, '1x'};
    hGB.ColumnWidth     = [cSymCols, 'fit', fliplr(cSymCols)];
    hGB.ColumnSpacing   = 0;
    hGB.RowSpacing      = 0;
    hGB.Padding         = [0 0 0 0];
    
    hGB2 = uigridlayout( hGB );
    hGB2.Layout.Column  = [1 numel(cSymCols)];
    hGB2.RowHeight      = {'1x'};
    hGB2.ColumnWidth    = { cwave.BtnWd/2, cwave.BtnWd/2, 5 ...
                          , cwave.BtnWd/2, cwave.BtnWd/2, 5 ...
                          , cwave.BtnWd/2, cwave.BtnWd*2/3, 5 ...
                          , cwave.BtnWd,   cwave.BtnWd*2/3, 5 ...
                          , '1x' };
    hGB2.ColumnSpacing  = 0;
    hGB2.RowSpacing     = 0;
    hGB2.Padding        = [0 0 0 0];
    
    hLogX = uibutton( hGB2, 'state', 'Text', 'Log(X)', 'Value', 0 ...
        , 'FontSize', cwave.FontSize, 'ValueChangedFcn', @sub_AxisChg );
    hLogY = uibutton( hGB2, 'state', 'Text', 'Log(Y)', 'Value', 0 ...
        , 'FontSize', cwave.FontSize, 'ValueChangedFcn', @sub_AxisChg );
    uilabel( 'Parent', hGB2, 'Text', '' ); % placeholder
    
    hFlipX = uibutton( hGB2, 'state', 'Text', 'Flip X', 'Value', 0 ...
        , 'FontSize', cwave.FontSize, 'ValueChangedFcn', @(~,~)sub_FlipXY );
    hFlipY = uibutton( hGB2, 'state', 'Text', 'Flip Y', 'Value', 0 ...
        , 'FontSize', cwave.FontSize, 'ValueChangedFcn', @(~,~)sub_FlipXY );
    uilabel( 'Parent', hGB2, 'Text', '' ); % placeholder
    
    hLine = uibutton( hGB2, 'state', 'Text', 'Line', 'Value', 0 ...
        , 'FontSize', cwave.FontSize, 'ValueChangedFcn', @(~,~)sub_LineMarker(true) );
    hMark = uibutton( hGB2, 'state', 'Text', 'Marker', 'Value', 1 ...
        , 'FontSize', cwave.FontSize, 'ValueChangedFcn', @(~,~)sub_LineMarker(false) );
    uilabel( 'Parent', hGB2, 'Text', '' ); % placeholder
    
    hAxEq = uibutton( hGB2, 'state', 'Text', 'Axis Equal', 'Value', 0 ...
        , 'FontSize', cwave.FontSize, 'ValueChangedFcn', @(~,~)sub_AxisEq );
    hAxExp = uibutton( hGB2, 'state', 'Text', 'No Exp' ...
        , 'Value', 1 ... strncmpi(sX,'East',4) || strncmpi(sX,'Ship_East',9) ...
        , 'FontSize', cwave.FontSize, 'ValueChangedFcn', @(~,~)sub_AxisExp ...
        , 'ToolTip', 'Turn off the annoying exponent in X,Y tick labels' );
    uilabel( 'Parent', hGB2, 'Text', '' ); % placeholder
    
    hXAxis = uidropdown( 'Parent', hGB ...
        , 'Items', ['Datum #' cDescX], 'ItemsData', 0:numel(cDescX) ...
        , 'Value', iX1st, 'FontSize', cwave.FontSize ...
        , 'ValueChangedFcn', @sub_AxisChg );
    uilabel( 'Parent', hGB, 'Text', '' ); % placeholder
    if bChgOK
        uibutton( 'Parent', hGB, 'FontSize', cwave.FontSize, 'Text', 'Make Figure' ...
            , 'ButtonPushedFcn', @sub_MakeFig );
        uibutton( 'Parent', hGB, 'FontSize', cwave.FontSize, 'Text', 'Save' ...
            , 'ButtonPushedFcn', @(~,~)sub_Close(true) );
        hbtnCancel = uibutton( 'Parent', hGB, 'FontSize', cwave.FontSize, 'Text', 'Close' ...
            , 'ButtonPushedFcn', @(~,~)sub_Close(false) );
    else
        uilabel( 'Parent', hGB, 'Text', '' ); % placeholder
        uibutton( 'Parent', hGB, 'FontSize', cwave.FontSize, 'Text', 'Make Figure' ...
            , 'ButtonPushedFcn', @sub_MakeFig );
        uibutton( 'Parent', hGB, 'FontSize', cwave.FontSize, 'Text', 'Close' ...
            , 'ButtonPushedFcn', @(~,~)sub_Close(false) );
    end
    
    % Now that everything is created, cause the first plot
    sub_AxisChg();
    
    % Make the figure visible and run the MODAL figure
    hFig.Visible = true;
    hFig.CloseRequestFcn = @(~,~)sub_Close(false);
    waitfor( hFig );
    return;
    
    %---------------------------------------------------------------------------
    function sub_Close(bSave)
        % If the user has made changes but is canceling, warn
        if ~bSave && ~isempty( cChgLog )
            sChoice = uiconfirm( hFig, {
                'You have made changes to the data.'
                'Do you really want to cancel and lose those changes?'
                }, 'Cancel?' ...
                , 'Options', {'Yes', 'No'} ...
                , 'DefaultOption', 2, 'CancelOption', 2 );
            if ~strcmpi( sChoice, 'Yes' )
                return;
            end
        end
        
        % Exit, appropriately setting the "changes were made" flag
        bChgd = bSave && ~isempty( cChgLog );
        delete( hFig );
        return;
    end % sub_Close
    
    %---------------------------------------------------------------------------
    % The Line or Marker state button was pressed
    function sub_LineMarker( bLine )
        % If the only active line/marker state is turned off, automatically turn
        % on the other one. There must be at least one at all times.
        if bLine
            if ~hLine.Value
                hMark.Value = 1;
            end
        else
            if ~hMark.Value
                hLine.Value = 1;
            end
        end
        
        % Don't cause an entire replot (it can be slow and will kill the user's
        % current zoom/pan state). Just update the lines
        if ~isempty( hLnList )
            % Scatter objects only have Markers and never Lines
            bScatter = isa( hLnList, 'matlab.graphics.chart.primitive.Scatter' );
            
            set( hLnList(~bScatter) ...
                , 'Marker', iif( hMark.Value, '.', 'none' ) ...
                , 'LineStyle', iif( hLine.Value, '-', 'none' ) );
            set( hLnList(bScatter), 'Marker', '.' );
        end
        
        return;
    end
    
    %---------------------------------------------------------------------------
    % X or Y axis control has changed. Plot the new selections
    function sub_AxisChg(~,~, hAx )
        % Fill optional params
        if ~exist('hAx','var') || isempty( hAx )
            hAx = hPlot;
            bMain = true;
        else
            bMain = false;
        end
        
        % If there is a "color by" option, then only one Yaxis value can be
        % selected and I break that up by the unique values in the given field,
        % unless there are too many
        iYList   = hYAxis.Value;
        iColorBy = hColorBy.Value;
        bColorTm = iColorBy > 0 && isdatetime( tData{1,cFld{iColorBy}} );
        if bColorTm
            iColorBy        = 0;    % spoof for plotting code
            iYList(2:end)   = [];   % trim down to just ONE Y value
            hYAxis.Value    = iYList;
        elseif iColorBy > 0
            % If there are too many, complain & blank out the field selection
            [nUval,~,iC] = unique( tData.(cFld{iColorBy}) );
            nUcnt = numel(nUval);
            if nUcnt > 25
                uialert( hFig, {
                    'Too many unique values.'
                    ' '
                    sprintf( 'Field %s has %d unique values', cDescX{iColorBy}, nUcnt );
                    }, 'Plot Table' );
                
                % Turn off the "color by unique values" & proceed normally
                iColorBy        = 0;
                hColorBy.Value  = 0;
            else
                % OK so trim down to just ONE Y value
                iYList(2:end) = [];
                hYAxis.Value  = iYList;
            end
        end
        
        % Get the X data to plot
        iX = hXAxis.Value;
        if iX == 0
            nX = onecol( 1:height(tData) );
        else
            nX = tData{:,cFld{iX}};
        end
        bXIsDate = isdatetime( nX );
        
        % Check the possibly multiple Y axis fields. Cannot mix date & non-date
        bYIsDate = isdatetime( tData{1,cFld{iYList(1)}} );
        for iY = onerow( iYList )
            if bYIsDate ~= isdatetime( tData{1,cFld{iY}} )
                uialert( hFig, [
                    'The Y-axis cannot plot both DATE and NUMERIC ' ...
                    'columns at the same time.'
                    ], 'Plot Table' );
                iYList(2:end) = [];
                hYAxis.Value  = iYList;
            end
        end
        
        % LineStyle and/or Marker
        sLineStyle = iif( hLine.Value, '-', 'none' );
        sMarker    = iif( hMark.Value, '.', 'none' );
        
        % Plot log10 or untouched data?
        if hLogX.Value && ~bXIsDate
            nX = safeLog10( nX );
        else
            hLogX.Value = false;
        end
        if hLogY.Value && ~bYIsDate
            fcnY = @safeLog10;
        else
            fcnY = @(y)y;
            hLogY.Value = false;
        end
        
        % Track lines plotted
        iClr = 0;
        hLns = [];
        
        % Plot every Y selected
        if iColorBy > 0
            nClrs   = DavesDiscreteColors( nUcnt );
            iY      = iYList(1);
            for iUval = 1:nUcnt
                b    = (iC == iUval) & bFilter;
                nCnt = sum(b);
                if nCnt == 0
                    continue;
                end
                iClr = iClr + 1;
                hLns(iClr) = plot( hAx, nX(b), fcnY( tData{b,cFld{iY}} ) ...
                    , 'Marker', sMarker, 'LineStyle', sLineStyle ...
                    , 'Color', nClrs(iClr,:) ...
                    , 'DisplayName', [cDescX{iColorBy} ' = ' num2str(nUval(iUval)) ' (' num2str(nCnt) ')'] );
                hold( hAx, 'on' );
            end
            ylabel( hAx, cDescX{iY} );  % use the text withOUT "[min,max]"
            
        elseif any(bFilter) % If filter excludes all, don't issue *any* plot cmds
            
            % If coloring by time, need to use scatter() with a count vector for
            % unique coloring. And NB: numel(iYList) forced to == 1
            if bColorTm
                iClr = 1; % for legend code further down
                hLns(iClr) = scatter( hAx ...
                    , nX(bFilter), fcnY( tData{bFilter,cFld{iY}} ) ...
                    , [], 1:sum(bFilter), 'Marker', '.' );
            else
                nClrs = DavesDiscreteColors( numel(iYList) );
                for iY = onerow( iYList )
                    iClr = iClr + 1;
                    hLns(iClr) = plot( hAx, nX(bFilter) ...
                        , fcnY( tData{bFilter,cFld{iY}} ) ...
                        , 'Marker', sMarker, 'LineStyle', sLineStyle ...
                        , 'Color', nClrs(iClr,:), 'DisplayName', cDescX{iY} );
                    hold( hAx, 'on' );
                end
            end
        end
        hold( hAx, 'off' );
        
        % If this is the main plot, save the list of line objects for quick
        % changes
        if bMain
            try delete(hLnList); end %#ok<TRYNC>
            hLnList = hLns;
        end
        
        % Finish up the plot
        hAx.XDir = iif( hFlipX.Value, 'reverse', 'normal' );
        hAx.YDir = iif( hFlipY.Value, 'reverse', 'normal' );
        if hAxEq.Value && ~bXIsDate && ~bYIsDate
            axis( hAx, 'equal' );
        else
            axis( hAx, 'normal' );
            hAxEq.Value = false;
        end
        axisTight( hAx );
        sub_AxisExp();
        if iClr == 0    % nothing plotted (empty filter)
            cla( hAx );
        elseif iClr > 1
            legend( hAx, 'Location', 'best' );
        else
            legend( hAx, 'off' );
            ylabel( hAx, cDescX{iY} );  % use the text withOUT "[min,max]"
        end
        
        return;
    end % sub_AxisChg
    
    %---------------------------------------------------------------------------
    function sub_FlipXY()
        hPlot.XDir = iif( hFlipX.Value, 'reverse', 'normal' );
        hPlot.YDir = iif( hFlipY.Value, 'reverse', 'normal' );
        return;
    end % sub_FlipXY
    
    %---------------------------------------------------------------------------
    function sub_AxisEq()
        try
            axis( hPlot, iif( hAxEq.Value, 'equal', 'normal' ) );
        catch Me
            axis( hPlot, 'normal' );
            hAxEq.Value = false;
            uialert( hFig, {
                'Error attempting "axis equal":'
                ' '
                Me.identifier
                Me.message
                }, 'Plot Table - "Axis Equal" button' );
        end
        return;
    end % sub_AxisEq
    
    %---------------------------------------------------------------------------
    function sub_AxisExp()
        bXDate = isdatetime( hPlot.XTick );
        bYDate = isdatetime( hPlot.YTick );
        if hAxExp.Value     % no exponent in tick label display
            if ~bXDate
                hPlot.XAxis.Exponent        = 0;
                hPlot.XAxis.TickLabelFormat = '%d';
            end
            if ~bYDate
                hPlot.YAxis.Exponent        = 0;
                hPlot.YAxis.TickLabelFormat = '%d';
            end
        else                % exponent OK, let MatLab decide
            if ~bXDate
                hPlot.XAxis.ExponentMode    = 'auto';
                hPlot.XAxis.TickLabelFormat = '%g';
            end
            if ~bYDate
                hPlot.YAxis.ExponentMode    = 'auto';
                hPlot.YAxis.TickLabelFormat = '%g';
            end
        end
        return;
    end % sub_AxisExp

    %---------------------------------------------------------------------------
    % A log10 wrapper that won't blow up on data which can't be displayed in log
    function n = safeLog10(n)
        try %#ok<TRYNC>
            n = log10(n);
            if ~isreal(n)
                n = real(n);
            end
        end
        return;
    end % safeLog10
    
    %---------------------------------------------------------------------------
    % Extract the current plot and put it in its own window so the user can
    % save, etc... as they like
    function sub_MakeFig(~,~)
        % If we're coloring by unique values in one field, then there are NEVER
        % multiple y-axis selections. Set that up here
        if hColorBy.Value > 0
            iY = hYAxis.Value(1);
        else
            iY = hYAxis.Value;
        end
        
        % What is the X variable? Might be just datum #
        if hXAxis.Value == 0
            sXVar   = 'DatumNo';
            sXDesc  = 'Datum #';
        else
            sXVar   = cFld{hXAxis.Value};
            sXDesc  = cDescX{hXAxis.Value};
        end
        
        % If there is more than one Y-value, ask if the user wants a stacked
        % plot (ugh - not great in R2020b) or all together (yay)
        switch( numel( iY ) )
        case 0
            return;
        case 1
            bStacked = false;
        otherwise
            sChoice = uiconfirm( hFig, [
                'You have selected multiple data curves. Do you want to plot ' ...
                'them stacked (separate plots stacked vertically) or overlaid ' ...
                '(all in one plot axes)?'
                ], 'Which type of figure?' ...
                , 'Options', {'Overlaid', 'Stacked', 'Cancel'} ...
                , 'DefaultOption', 1, 'CancelOption', 3 );
            switch( sChoice )
            case 'Stacked',     bStacked = true;
            case 'Overlaid',    bStacked = false;
            otherwise
                return;
            end
        end
        
        % Get a plain old plot figure & plot the selection(s) on it
        hFigToGo = figCenter( hFig, 'ppt' );
        if bStacked
            if hXAxis.Value == 0
                hAx = stackedplot( hFigToGo, tData(bFilter,:), cFld(iY) ...
                    , 'Marker', iif( hMark.Value, '.', 'none' ) ...
                    , 'LineStyle', iif( hLine.Value, '-', 'none' ) ...
                    );
            else
                hAx = stackedplot( hFigToGo, tData(bFilter,:), cFld(iY) ...
                    , 'XVariable', sXVar ...
                    , 'Marker', iif( hMark.Value, '.', 'none' ) ...
                    , 'LineStyle', iif( hLine.Value, '-', 'none' ) ...
                    );
            end
        else
            hAx = axes( hFigToGo );
            sub_AxisChg([],[], hAx );
            xlabel( hAx, sXDesc );
        end
        set( hAx, 'FontSize', cwave.FontSize );
        
        % Build filename & title strings
        sFile = sXVar;
        if numel( iY ) == 1
            % NB: for the title, use the text withOUT "[min,max]"
            sT    = {[sXDesc ' vs ' cDescX{iY}]};
            sFile = [sFile '_vs_' cFld{iY}];
        else
            sT    = {[sXDesc ' vs Many']};
            sFile = [sFile '_vs_Many'];
        end
        if ~isempty( sFiltDesc )
            sT{2,1} = sFiltDesc;
        end
        if ~isempty( sPlotSubtitle )
            title( hAx, [sT; {sPlotSubtitle}] );
        else
            title( hAx, sT );
        end
        addPlotMenu( hFigToGo, fullfile( sPlotDir, sFile ) );
        
        return;
    end % sub_MakeFig
    
    %---------------------------------------------------------------------------
    % The "filter on this field" dropdown has changed. Clean the UI
    function sub_FiltFldChg(~,~)
        iFiltFld = hFilterFld.Value;
        if iFiltFld == 0    % user has cleared the selection. Don't require 'Apply'
            sub_Filter();
        else
            % Clear the edit field for a new entry
            hFilterVal.Value = '';
        end
        
        return;
    end % sub_FiltFldChg
    
    %---------------------------------------------------------------------------
    % User wants to apply a filter to the data. Set it up
    function sub_Filter(~,~)
        % Build the filter expression and validate that it works
        try
            sFiltDesc = '';
            iFiltFld = hFilterFld.Value;
            if iFiltFld == 0
                bFilter = true(height(tData),1);
                hFilterVal.Value = '';
            else
                % datetime vars req special handling
                bDate   = isdatetime( tData{1,cFld{iFiltFld}} );
                bOneOf  = strcmpi( hFilterOp.Value, 'one of' );
                if bDate && bOneOf
                    error( 'Cannot use "one of" with datetime fields.' );
                end
                
                % A few special types don't need a value
                if ~ismember( hFilterOp.Value, {'is NaN', 'isn''t NaN'} )
                    % Get the filter value
                    
                    if bDate
                        nFiltVal = datetime( hFilterVal.Value );
                    else
                        nFiltVal = str2num( hFilterVal.Value );
                        if numel(nFiltVal) == 0
                            error( 'The filter value does not evaluate to a numeric.' );
                        elseif numel(nFiltVal) > 1 && ~bOneOf
                            error( 'The filter value evaluates to a vector but you did not choose "one of"' );
                        end
                    end
                end
                
                % Apply the filter
                switch( hFilterOp.Value )
                case '=='
                    bFilter = tData.(cFld{iFiltFld}) == nFiltVal;
                case '~='
                    bFilter = tData.(cFld{iFiltFld}) ~= nFiltVal;
                case '<'
                    bFilter = tData.(cFld{iFiltFld}) <  nFiltVal;
                case '<='
                    bFilter = tData.(cFld{iFiltFld}) <= nFiltVal;
                case '>'
                    bFilter = tData.(cFld{iFiltFld}) >  nFiltVal;
                case '>='
                    bFilter = tData.(cFld{iFiltFld}) >= nFiltVal;
                case 'one of'
                    bFilter = ismember( tData.(cFld{iFiltFld}), nFiltVal );
                case 'is NaN'
                    if bDate
                        bFilter = isnat( tData.(cFld{iFiltFld}) );
                    else
                        bFilter = isnan( tData.(cFld{iFiltFld}) );
                    end
                case 'isn''t NaN'
                    if bDate
                        bFilter = ~isnat( tData.(cFld{iFiltFld}) );
                    else
                        bFilter = ~isnan( tData.(cFld{iFiltFld}) );
                    end
                otherwise
                    error( 'BUG: Uncoded filter operator %s', hFilterOp.Value );
                end
                sFiltDesc = [cDescX{iFiltFld} ' ' hFilterOp.Value ' "' hFilterVal.Value '"'];
            end
        catch Me
            uialert( hFig, {
                'Invalid filter.'
                ''
                Me.identifier
                Me.message
                }, 'Plot Table' );
            bFilter = true(height(tData),1);
        end
        
        % Update the display
        nCntFilter      = sum( bFilter );
        hFilterCnt.Text = sprintf( '(%d of %d rows)', nCntFilter, numel( bFilter ) );
        sub_AxisChg();
        
        % En/disable the set/delete controls based on whether or not there's
        % actually a filter in place
        if bChgOK
            sEditable = iif( nCntFilter > 0 & nCntFilter < height(tData), 'on', 'off' );
            hSetFld.Enable   = sEditable;
            hSetVal.Editable = sEditable;
            hSetBtn.Enable   = sEditable;
            hDelBtn.Enable   = sEditable;
            hKeepBtn.Enable  = sEditable;
        end
        
        return;
    end % sub_Filter
    
    %---------------------------------------------------------------------------
    % Delete (or keep) all data in the current filtered subset
    function sub_DeleteSubset(bKeep)
        if all( bFilter )
            uialert( hFig, {
                'There is no filter in place.'
                'Apply a filter first then select delete'
                }, 'Plot Table', 'Icon', 'info' );
            return;
        elseif ~any( bFilter )
            uialert( hFig, {
                'The current subset is empty.'
                'Your filter criteria have excluded all data.'
                }, 'Plot Table', 'Icon', 'info' );
            return;
        end
        
        % Confirm with the user that they want to delete
        nCntFilt = sum( bFilter );
        if bKeep
            sOccur = sprintf( 'If you continue, %d rows will be deleted.', height(tData)-nCntFilt );
        else
            sOccur = 'If you continue, those rows will be deleted.';
        end
        sChoice = uiconfirm( hFig, {
            sprintf( 'The current filter contains %d of %d data.' ...
                    , nCntFilt, height( tData ) )
            ' '
            sOccur
            }, 'Delete the subset of data?' ...
            , 'Options', {'Delete Subset', 'Cancel'} ...
            , 'DefaultOption', 1, 'CancelOption', 2 );
        if ~strcmpi( sChoice, 'Delete Subset' )
            return;
        end
        
        % Make the changes
        cChgLog{end+1,1} = sprintf( 'Deleted %d rows meeting condition "%s"' ...
            , nCntFilt, sFiltDesc );
        if bKeep
            tData(~bFilter,:) = [];
        else
            tData(bFilter,:) = [];
        end
        hbtnCancel.Text = 'Cancel'; % starts as 'Close' but data has now been chgd
        
        % Now that the filter is empty, clear the selection
        hFilterFld.Value = 0;
        sub_Filter();   % Also refreshes the plot
        
        return;
    end % sub_DeleteSubset
    
    %---------------------------------------------------------------------------
    % The user wants to Set field X = value Y for some filter
    function sub_ChangeFld(~,~)
        % is there a valid field selected? 
        iSetFld = hSetFld.Value;
        if iSetFld == 0
            uialert( hFig, {
                'Select a field to change, enter a value,'
                'then press the button to apply the change.'
                }, 'Plot Table', 'Icon', 'info' );
            return;
        end
        
        % Does the "set to" value evaluate to a number or datetime without
        % crashing? (& is it a scalar only?)
        try
            if isdatetime( tData{1,cFld{iSetFld}} )
                nSetVal = datetime( hSetVal.Value );
            else
                nSetVal = str2num( hSetVal.Value );
            end
            assert( numel(nSetVal) == 1, 'Value must be a scalar' );
        catch Me
            uialert( hFig, {
                'The value you entered cannot be converted to'
                'the proper data type.'
                ''
                Me.identifier
                Me.message
                }, 'Plot Table' );
            return;
        end
        
        % Confirm the user wants to do this
        nCntFilt = sum( bFilter );
        sChoice = uiconfirm( hFig, {
            sprintf( 'The current filter contains %d of %d data.' ...
                    , nCntFilt, height( tData ) )
            ' '
            'If you continue, the change will be made to those rows'
            }, 'Change a subset of data?' ...
            , 'Options', {'Change Subset', 'Cancel'} ...
            , 'DefaultOption', 1, 'CancelOption', 2 );
        if ~strcmpi( sChoice, 'Change Subset' )
            return;
        end
        
        % Make the changes & create a log entry
        % Doesn't work: tData(bFilter,cFld{iSetFld}) = nSetVal;
        tData.(cFld{iSetFld})(bFilter) = nSetVal;
        cChgLog{end+1,1} = sprintf( 'Set "%s" = "%s" where "%s" (%d rows affected)' ...
            , cDescX{iSetFld}, hSetVal.Value, sFiltDesc, nCntFilt );
        hbtnCancel.Text = 'Cancel'; % starts as 'Close' but data has now been chgd
        
        % If the filter field and the set field are the same, then clear the
        % filter otherwise just do a simple replot
        if iSetFld == hFilterFld.Value
            hFilterFld.Value = 0;
            sub_Filter(); % will also cause a replot
        else
            % Refresh the display
            sub_AxisChg();
        end
        
        return;
    end % sub_ChangeFld
    
    %---------------------------------------------------------------------------
    % Allow the user to drag across some data & delete them using the mouse
    function sub_DelByMouse(~,~)
        % You can only delete by mouse if ONE y-axis variable is plotted
        if numel(hYAxis.Value) ~= 1
            uialert( hFig, {
                'You can only delete using the mouse if '
                'exactly one Y-axis variable is selected.'
                }, 'Delete using the Mouse' );
            return;
        end
        
        % Currently ginput() returns really weird values for datetime axes if
        % the user has zoomed in at all (which is common). I haven't figured out
        % what this is in R2020b but it's weird. Maybe it's broken?
        %%//%% fix "Delete by mouse" when datetime in one of the axes
        
        % What variables are we selecting on?
        sFldY = cFld{hYAxis.Value};
        nDataY = tData.(sFldY);
        if hXAxis.Value == 0
            sFldX  = 'Datum';
            nDataX = onecol( 1:height(tData) );
        else
            sFldX  = cFld{hXAxis.Value};
            nDataX = tData{:,sFldX};
        end
        if isdatetime( nDataX(1) ) || isdatetime( nDataY(1) )
            uialert( hFig, {
                'Cannot delete by mouse when a datetime variable '
                'is selected in one of the axes. Try Datum instead.'
                ' '
                'NB: This is a MATLAB problem. ginput() does not '
                'work consistently with datetime data types.'
                }, 'Delete using the Mouse' );
            return;
        end
        
        % Give the user help the first time they do this in the current session
        persistent bHelped
        if isempty( bHelped )
            bHelped = true;
            % NB: uialert always returns immediately without waiting for OK even
            % when set Modal. Must use uiconfirm and collect the result, even if
            % you don't look at the result.
            s = uiconfirm( hFig, {
                'INSTRUCTIONS'
                ' '
                'Click opposing corners of a rectangle'
                'to delete all the data points it contains.'
                ' '
                'Use single clicks. DO NOT CLICK-AND-DRAG.'
                ' '
                'Press ENTER to cancel selection.'
                }, 'Delete using the Mouse', 'Icon', 'info', 'Options', {'OK'} ); %#ok<NASGU>
        end
        
        % For now use the easy ginput() function. May need to go to the more
        % complicated ButtonDownFcn control if this isn't acceptable.
        sOldTitle = hPlot.Title.String;
        nOldColor = hPlot.Title.Color;
        hPlot.Title.String = 'Select opposing corners of a rectangle.';
        hPlot.Title.Color = 'r';
        
        % Get two mouse clicks (NB: need hidden handles revealed for ginput() to
        % work on uifigure windows)
        hRoot = groot();
        bSHH = hRoot.ShowHiddenHandles;
        hRoot.ShowHiddenHandles = true;
        axes( hPlot );    % make this axes current now that it's not hidden
        oZoom = zoom(  hFig );  sZ = oZoom.Enable;  oZoom.Enable  = 'off';
        oPan  = pan(   hFig );  sP = oPan.Enable;   oPan.Enable   = 'off';
        oBrush= brush( hFig );  sB = oBrush.Enable; oBrush.Enable = 'off';
        nXLim = hPlot.XLim;  % save current zoom limits
        nYLim = hPlot.YLim;
        
        try %#ok<TRYNC>
            [nX,nY] = ginput( 2 );
        end
        
        % Restore previous settings
        hRoot.ShowHiddenHandles = bSHH;
        if strcmpi( sZ, 'on' )
            oZoom.Enable = 'on';
        elseif strcmpi( sP, 'on' )
            oPan.Enable = 'on';
        elseif strcmpi( sB, 'on' )
            oBrush.Enable = 'on';
        end
        clear oZoom oPan oBrush
        
        % Restore settings
        hPlot.Title.String = sOldTitle;
        hPlot.Title.Color = nOldColor;
        
        % If there aren't two points, then the user canceled
        if numel(nX) ~= 2
            return;
        end
        nX = sort(nX);
        nY = sort(nY);
        
        % ginput() and datetime axes interact very weirdly... 
        %
        % NB: Had to turn off all support for ginput() and datetime axes because
        % it does not consistently return the same type of numbers.
        %
        if isdatetime( nDataX(1) )
            % nX is the number of DAYS relative to the DAY of the first plotted
            % datapoint (not XLim). Yes this is weird. Hopefully it doesn't change
            % in a different MATLAB version. That would be awkward.
            nX = dateshift( min( nDataX(bFilter) ), 'start', 'day' ) + days(nX);
            sX1 = char(nX(1));
            sX2 = char(nX(2));
        else
            sX1 = num2str(nX(1));
            sX2 = num2str(nX(2));
        end
        if isdatetime( nDataY(1) )
            nY = dateshift( min( nDataY(bFilter) ), 'start', 'day' ) + days(nY);
            sY1 = char(nY(1));
            sY2 = char(nY(2));
        else
            sY1 = num2str(nY(1));
            sY2 = num2str(nY(2));
        end
        
        % How many data are enclosed? If none, msg & exit
        bDelMe = bFilter & btwn( nX, nDataX ) & btwn( nY, nDataY );
        nCntDel = sum( bDelMe );
        if nCntDel == 0
            uialert( hFig, {
                'No data were enclosed in the rectangle.'
                'Nothing to delete.'
                }, 'Delete using the Mouse', 'Icon', 'info' );
            return;
        end
        
        % Draw a rectangle enclosing the data
        % NB: rectangle() does not support datetime unless it is both X & Y
        hold( hPlot, 'on' );
        hRect = plot( hPlot, nX([1 1 2 2 1]), nY([1 2 2 1 1]), '-r', 'LineWidth', 2 );
        hold( hPlot, 'off' );
        
        % Confirm deletion
        sChoice = uiconfirm( hFig, {
            sprintf( 'You''ve selected to delete %d of %d data.' ...
                    , nCntDel, height( tData ) )
            ' '
            'If you continue, those rows will be deleted.'
            }, 'Delete the subset of data?' ...
            , 'Options', {'Delete Subset', 'Cancel'} ...
            , 'DefaultOption', 1, 'CancelOption', 2 );
        delete(hRect); % delete the selection rectangle regardless of answer
        if ~strcmpi( sChoice, 'Delete Subset' )
            return;
        end
        
        % Log the data that were deleted including the corner limits and
        % whatever filter is in place at the time
        if isempty( sFiltDesc )
            cChgLog{end+1,1} = sprintf( 'Deleted %d rows between(%s,%s,%s) and between(%s,%s,%s)' ...
                , nCntDel, sX1, sFldX, sX2, sY1, sFldY, sY2 );
        else
            cChgLog{end+1,1} = sprintf( 'Deleted %d rows between(%s,%s,%s) and between(%s,%s,%s) with filter:"%s"' ...
                , nCntDel, sX1, sFldX, sX2, sY1, sFldY, sY2, sFiltDesc );
        end
        hbtnCancel.Text = 'Cancel'; % starts as 'Close' but data has now been chgd
        
        % Delete the data
        tData(bDelMe,:) = [];
        bFilter(bDelMe) = [];
        
        % Refresh the plot. If the user deleted everything in the current
        % filter, then clear that as well
        if nCntDel == numel(bFilter)
            hFilterFld.Value = 0;
            sub_Filter();   % Also refreshes the plot
        else
            sub_AxisChg();
        end
        
        % Restore previous zoom, but only if it was zoomed IN compared to what
        % we have now. If user has deleted extraneous points that are way out of
        % bounds, allow plot to automatically get smaller.
        drawnow();
        zoom( hFig, 'reset' ); % save the current zoom window as "max" before zooming in
        hPlot.XLim = [max(nXLim(1),hPlot.XLim(1)) min(nXLim(2),hPlot.XLim(2))];
        hPlot.YLim = [max(nYLim(1),hPlot.YLim(1)) min(nYLim(2),hPlot.YLim(2))];
        
        return;
    end % sub_DelByMouse
    
end % UITablePlot
