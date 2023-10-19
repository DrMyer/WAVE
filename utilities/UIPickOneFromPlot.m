function iPick = UIPickOneFromPlot( tData, hParent, sTitle, sDesc, bCancelOK )
% Generic utility to plot a table and require the user to pick ONE of the data
% streams. The table's first column is assumed to be X and all the other columns
% are assumed to be Y_n. The user picks one of the Y_n.
%
% Params:
%   tData    - table to plot. Note that EVERY numeric variable must be a single
%               column of data not a matrix.
%   hParent  - handle of uifigure to center over
%   sTitle   - figure title
%   sDesc    - Instructions text to show. Will be word-wrapped automatically.
%   bCancelOK- (opt; dflt True) true/false/'NoCancel'/'CancelOK'
% Returns:
%   iPick   - index of the column of the chosen data in the given table. If
%               cancel is allowed, iPick == [] means the user canceled.
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

    % Default the output variables
    iPick = [];
    
    % Fill in optional params
    if ~exist( 'bCancelOK', 'var' ) || isempty( bCancelOK )
        bCancelOK = true;
    elseif ischar( bCancelOK )
        bCancelOK = strncmpi( bCancelOK, 'C', 1 );
    end
    
    % Create the UI elements
    hFig = uifigure( 'Name', sTitle ...
        , 'Visible', false, 'WindowStyle', 'modal', 'Resize', true ...
        , 'Units', 'pixels', 'Position', [1 1 800 600] ...
        );
    figCenter( hParent, hFig );
    
    % General grid for all the zones
    hG = uigridlayout( hFig );
    hG.RowHeight    = {'fit', '1x', cwave.BtnHt};
    hG.ColumnWidth  = {'1x'};
    hG.ColumnSpacing= 0;
    hG.RowSpacing   = 15;
    hG.Padding      = [10 10 10 10];
    
    % Instruction text
    uilabel( 'Parent', hG, 'FontSize', cwave.FontSize + 2, 'WordWrap', true, 'Text', sDesc );
    
    % Plot area
    hAx = uiaxes( 'Parent', hG, 'FontSize', cwave.FontSize, 'Box', 'on' );
    
    % The button row needs to be sub-divided
    hGB = uigridlayout( hG );
    hGB.RowHeight       = {'1x'};
    hGB.ColumnWidth     = repmat({'1x'},1,width(tData)-iif(bCancelOK,0,1));
    hGB.ColumnSpacing   = 0;
    hGB.RowSpacing      = 0;
    hGB.Padding         = [0 0 0 0];
    
    % Plot the curves AND make the selection buttons
    cVarList = strrep( tData.Properties.VariableNames, '_', ' ' );
    for iY = 2:width(tData)
        h = plot( hAx, tData{:,1}, tData{:,iY} ...
            , 'Marker', 'none', 'LineStyle', '-' ...
            , 'DisplayName', cVarList{iY} ...
            );
        uibutton( 'Parent', hGB, 'FontSize', cwave.FontSize ...
            , 'Text', cVarList{iY}, 'FontColor', h.Color ...
            , 'ButtonPushedFcn', @(~,~)sub_Pick(iY) ...
            );
        hold( hAx, 'on' );
    end
    hold( hAx, 'off' )
    axisTight( hAx );
    xlabel( hAx, cVarList{1} );
    if numel( tData.Properties.VariableUnits ) >= 2 ...
    && ~isempty( tData.Properties.VariableUnits{2} )
        ylabel( hAx, [cVarList{2} ' (' tData.Properties.VariableUnits{2} ')'] );
    else
        ylabel( hAx, cVarList{2} );
    end
    legend( hAx, 'Location', 'best' );
    
    % Add the cancel button if requested
    if bCancelOK
        uibutton( 'Parent', hGB, 'FontSize', cwave.FontSize, 'Text', 'Cancel' ...
            , 'ButtonPushedFcn', @sub_Cancel );
        hFig.CloseRequestFcn = @sub_Cancel;
    else
        iPick = 2;  % if cancel not allowed, don't allow iPick to be []
        hFig.CloseRequestFcn = @sub_NoCancel;
    end
    
    % Make the figure visible and run as a MODAL figure
    hFig.Visible = true;
    waitfor( hFig );
    return;
    
    %---------------------------------------------------------------------------
    function sub_Cancel(~,~)
        iPick = [];
        delete( hFig );
        return;
    end % sub_Cancel
    
    %---------------------------------------------------------------------------
    function sub_NoCancel(~,~)
        uialert( hFig, 'Cancel is not allowed. You MUST pick a curve.' ...
            , 'You''ve been Canceled' );
        return;
    end % sub_NoCancel
    
    %---------------------------------------------------------------------------
    function sub_Pick(iY)
        iPick = iY;
        delete( hFig );
        return;
    end % sub_Cancel
    
end % UIPickOneFromPlot
