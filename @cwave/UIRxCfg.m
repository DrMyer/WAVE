function UIRxCfg( oWave )
% cwave::UIRxCfg( oWave )
%
% UI for editing nodal receiver configuration info
%
% NB: Due to legacy bullshit, the mag channels are always called Hx & Hy
% throughout all the old codes despite the fact that they are actually Bx, By. I
% am adhering to the incorrect naming for maximum backwards compatibility of
% data from WAVE going into DataMan, MARE2DEM, etc etc...
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
    
    % Get the tables of receivers & channels. Prompt the user to auto-fill from
    % the RxNav list
    [bContinue, tblRxCfg, tblRxCh] = sub_GetTables( oWave.hFig, oWave ...
        , oWave.tableRxCfg, oWave.tableRxCh );
    if ~bContinue
        return;
    end
    
    % Build the UI
    hFig = uifigure( 'Name', 'Edit Nodal RX Config', 'WindowStyle', 'modal' ...
        , 'Visible', false, 'Resize', true, 'Units', 'pixels' ...
        , 'Position', [1 1 1200 800] );
    figCenter( oWave.hFig, hFig );
    
    % General grid for all the zones
    hG = uigridlayout( hFig );
    hG.RowHeight        = {'fit','1x',cwave.BtnHt};
    hG.ColumnWidth      = {'1x','2x'};
    hG.ColumnSpacing    = 5;
    hG.RowSpacing       = 5;
    hG.Padding          = [10 10 10 20];
    
    % Instructions line
    h = uilabel( 'Parent', hG, 'WordWrap', 'on', 'FontSize', cwave.FontSize + 2 ...
        , 'Text', [
        'INSTRUCTIONS: Select a receiver in the list on the left to edit ' ...
        'its configuration in the fields on the right. Changes are recorded ' ...
        'as you enter them.'
        ]);
    h.Layout.Column     = [1 numel(hG.ColumnWidth)];
    
    %% Left zone: Table listing the receivers with add / del / reset btns
    hGZ = uigridlayout( hG );
    hGZ.RowHeight        = {cwave.BtnHt,'1x'};
    hGZ.ColumnWidth      = {cwave.BtnWd,cwave.BtnWd,'1x',cwave.BtnWd};
    hGZ.ColumnSpacing    = 0;
    hGZ.RowSpacing       = 0;
    hGZ.Padding          = [0 0 0 0];
    uibutton( 'Parent', hGZ, 'FontSize', cwave.FontSize, 'Text', 'Add' ...
        , 'Icon', w_IconLib('AddRow'), 'ButtonPushedFcn', @sub_AddRx );
    uibutton( 'Parent', hGZ, 'FontSize', cwave.FontSize, 'Text', 'Delete' ...
        , 'Icon', w_IconLib('DelRow'), 'ButtonPushedFcn', @sub_DelRx );
    uilabel( 'Parent', hGZ, 'Text', '' ); % dummy fill
    uibutton( 'Parent', hGZ, 'FontSize', cwave.FontSize, 'Text', 'Reset' ...
        , 'Icon', w_IconLib('Reset'), 'ButtonPushedFcn', @sub_ResetRx );
    
    % The table needs a little special handling
    hRxList = uitable( 'Parent', hGZ, 'FontSize', cwave.FontSize ...
        , 'Data', sub_InitRxList( tblRxCfg, tblRxCh, oWave.sDir_Calib ) ...
        , 'ColumnName', {'Status','Name','Error Message'} ...
        , 'ColumnWidth', {'1x','1x','5x'} ...
        , 'ColumnEditable', false, 'ColumnSortable', false ...
        , 'RowName', {}, 'CellSelectionCallback', @sub_TrackSlctn );
    addStyle( hRxList, uistyle('FontColor',cwave.nClrError), 'Column', 3 );
    hRxList.Layout.Column = [1 numel(hGZ.ColumnWidth)];
    
    
    %% Right zone: receiver config fields for ONE receiver
    hGZ = uigridlayout( uipanel( hG, 'Title', 'Receiver Configuration', 'FontSize', cwave.FontSize ) );
    hGZ.RowHeight       = [repmat({cwave.BtnHt},1,10) {'1x',cwave.BtnHt}];
    hGZ.ColumnWidth     = {'1x'};
    hGZ.ColumnSpacing   = 0;
    hGZ.RowSpacing      = 5;
    hGZ.Padding         = [10 10 10 10];
    
    hGL = uigridlayout( hGZ, [1 4], 'Padding', [0 0 0 0] );
    uilabel( hGL, 'Text', 'Rx Name:', 'FontSize', cwave.FontSize, 'HorizontalAlignment', 'right' );
    hRxName = uieditfield( hGL, 'FontSize', cwave.FontSize, 'Editable', 'off' );
    uilabel( hGL, 'Text', 'Depth:', 'FontSize', cwave.FontSize, 'HorizontalAlignment', 'right' );
    hDepth = uieditfield( hGL, 'numeric', 'Limits', [0 Inf], 'FontSize', cwave.FontSize ...
        , 'ValueDisplayFormat', '%.1f m' );
    
    hGL = uigridlayout( hGZ, 'Padding', [0 0 0 0], 'RowHeight', {'1x'} ...
        , 'ColumnWidth', {'fit','1x','fit','1x'} );
    uilabel( hGL, 'Text', 'Easting:', 'FontSize', cwave.FontSize, 'HorizontalAlignment', 'right' );
    hEasting = uieditfield( hGL, 'numeric', 'Limits', [0 Inf], 'FontSize', cwave.FontSize ...
        , 'ValueDisplayFormat', '%.1f m', 'ValueChangedFcn', @sub_EditUTM );
    uilabel( hGL, 'Text', 'Northing:', 'FontSize', cwave.FontSize, 'HorizontalAlignment', 'right' );
    hNorthing = uieditfield( hGL, 'numeric', 'Limits', [0 Inf], 'FontSize', cwave.FontSize ...
        , 'ValueDisplayFormat', '%.1f m', 'ValueChangedFcn', @sub_EditUTM );
    
    hGL = uigridlayout( hGZ, 'Padding', [0 0 0 0], 'RowHeight', {'1x'} ...
        , 'ColumnWidth', {'fit','fit','1x','fit','1x'} );
    uilabel( hGL, 'Text', '-- OR --', 'FontSize', cwave.FontSize, 'HorizontalAlignment', 'center' );
    uilabel( hGL, 'Text', 'Longitude:', 'FontSize', cwave.FontSize, 'HorizontalAlignment', 'right' );
    hLon = uieditfield( hGL, 'numeric', 'Limits', [-360 360], 'FontSize', cwave.FontSize ...
        , 'ValueDisplayFormat', '%.5f', 'ValueChangedFcn', @sub_EditLL );
    uilabel( hGL, 'Text', 'Latitude:', 'FontSize', cwave.FontSize, 'HorizontalAlignment', 'right' );
    hLat = uieditfield( hGL, 'numeric', 'Limits', [-90 90], 'FontSize', cwave.FontSize ...
        , 'ValueDisplayFormat', '%.5f', 'ValueChangedFcn', @sub_EditLL );
    
    hGL = uigridlayout( hGZ, 'Padding', [0 0 0 0], 'RowHeight', {'1x'} ...
        , 'ColumnWidth', {'2x','1x','1x','1x','1x','1x','1x','1x','1x','3x'} );
    uilabel( hGL, 'Text', 'Sync:', 'FontSize', cwave.FontSize, 'HorizontalAlignment', 'right' );
    hSync(1) = uieditfield( hGL, 'numeric', 'Limits', [1 12] ...
        , 'RoundFractionalValues', 'on', 'FontSize', cwave.FontSize ...
        , 'ValueChangedFcn', @sub_UpdtDrift );
    hSync(2) = uieditfield( hGL, 'numeric', 'Limits', [1 31] ...
        , 'RoundFractionalValues', 'on', 'FontSize', cwave.FontSize ...
        , 'ValueChangedFcn', @sub_UpdtDrift );
    hSync(3) = uieditfield( hGL, 'numeric', 'Limits', [2000 2100] ...
        , 'RoundFractionalValues', 'on', 'FontSize', cwave.FontSize ...
        , 'ValueChangedFcn', @sub_UpdtDrift );
    uilabel( hGL, 'Text', 'X', 'FontSize', cwave.FontSize, 'HorizontalAlignment', 'center' );
    hSync(4) = uieditfield( hGL, 'numeric', 'Limits', [0 23] ...
        , 'RoundFractionalValues', 'on', 'FontSize', cwave.FontSize ...
        , 'ValueChangedFcn', @sub_UpdtDrift );
    hSync(5) = uieditfield( hGL, 'numeric', 'Limits', [0 59] ...
        , 'RoundFractionalValues', 'on', 'FontSize', cwave.FontSize ...
        , 'ValueChangedFcn', @sub_UpdtDrift );
    hSync(6) = uieditfield( hGL, 'numeric', 'Limits', [0 59] ...
        , 'RoundFractionalValues', 'on', 'FontSize', cwave.FontSize ...
        , 'ValueChangedFcn', @sub_UpdtDrift );
    uilabel( hGL, 'Text', 'Tag:', 'FontSize', cwave.FontSize, 'HorizontalAlignment', 'right' );
    hSync(7) = uieditfield( hGL, 'numeric', 'Limits', [0 2], 'FontSize', cwave.FontSize ...
        ... , 'ValueDisplayFormat', '%.7f' ... in R2020b this makes the entry field act weird
        , 'ValueChangedFcn', @sub_UpdtDrift );
    
    hGL = uigridlayout( hGZ, 'Padding', [0 0 0 0], 'RowHeight', {'1x'} ...
        , 'ColumnWidth', {'2x','1x','1x','1x','1x','1x','1x','1x','1x','3x'} );
    uilabel( hGL, 'Text', 'Shift:', 'FontSize', cwave.FontSize, 'HorizontalAlignment', 'right' );
    hShift(1) = uieditfield( hGL, 'numeric', 'Limits', [1 12] ...
        , 'RoundFractionalValues', 'on', 'FontSize', cwave.FontSize ...
        , 'ValueChangedFcn', @sub_UpdtDrift );
    hShift(2) = uieditfield( hGL, 'numeric', 'Limits', [1 31] ...
        , 'RoundFractionalValues', 'on', 'FontSize', cwave.FontSize ...
        , 'ValueChangedFcn', @sub_UpdtDrift );
    hShift(3) = uieditfield( hGL, 'numeric', 'Limits', [2000 2100] ...
        , 'RoundFractionalValues', 'on', 'FontSize', cwave.FontSize ...
        , 'ValueChangedFcn', @sub_UpdtDrift );
    uilabel( hGL, 'Text', 'X', 'FontSize', cwave.FontSize, 'HorizontalAlignment', 'center' );
    hShift(4) = uieditfield( hGL, 'numeric', 'Limits', [0 23] ...
        , 'RoundFractionalValues', 'on', 'FontSize', cwave.FontSize ...
        , 'ValueChangedFcn', @sub_UpdtDrift );
    hShift(5) = uieditfield( hGL, 'numeric', 'Limits', [0 59] ...
        , 'RoundFractionalValues', 'on', 'FontSize', cwave.FontSize ...
        , 'ValueChangedFcn', @sub_UpdtDrift );
    hShift(6) = uieditfield( hGL, 'numeric', 'Limits', [0 59] ...
        , 'RoundFractionalValues', 'on', 'FontSize', cwave.FontSize ...
        , 'ValueChangedFcn', @sub_UpdtDrift );
    uilabel( hGL, 'Text', 'Tag:', 'FontSize', cwave.FontSize, 'HorizontalAlignment', 'right' );
    hShift(7) = uieditfield( hGL, 'numeric', 'Limits', [0 100], 'FontSize', cwave.FontSize ...
        ... , 'ValueDisplayFormat', '%.7f' ...
        , 'ValueChangedFcn', @sub_UpdtDrift );
    % NB: On Scarborough, had at least one instrument (Land2) that was off from
    % GPS by 1 MINUTE (yes, minute)
    
    hGL = uigridlayout( hGZ, 'Padding', [0 0 0 0], 'RowHeight', {'1x'} ...
        , 'ColumnWidth', {'1x', 'fit', cwave.BtnWd/2} );
    uilabel( hGL, 'Text', '' );
    hLagSec = uicheckbox( hGL, 'Text', '"Shift" seconds are lagging', 'Value', 0 ...
        , 'FontSize', cwave.FontSize, 'ValueChangedFcn', @sub_UpdtDrift );
    uibutton( 'Parent', hGL, 'FontSize', cwave.FontSize, 'Text', '' ...
        , 'Icon', w_IconLib('Help'), 'ButtonPushedFcn' ...
        , @(~,~)uialert( hFig, [
        'If the "shift" seconds are lagging behind the GPS unit''s seconds ' ...
        'then the receiver''s clock is slow. The shift tag is typically ' ...
        '> 0.5 in that case. However the system usually interprets a high ' ...
        'shift tag as meaning that the clock is fast (and the receiver''s ' ...
        'clock is ticking over the seconds just ahead of the GPS unit). ' ...
        'Check this option if someone OBSERVED the receiver lagging behind ' ...
        'the GPS unit.'
        ], 'Lagging Shift Seconds', 'Icon', 'info' ) );
    
    hGL = uigridlayout( hGZ, [1 3], 'Padding', [0 0 0 0] );
    uilabel( hGL, 'Text', '-- OR --', 'FontSize', cwave.FontSize, 'HorizontalAlignment', 'center' );
    uilabel( hGL, 'Text', 'Drift Rate:', 'FontSize', cwave.FontSize, 'HorizontalAlignment', 'right' );
    hDrift = uieditfield( hGL, 'numeric', 'FontSize', cwave.FontSize ...
        , 'ValueDisplayFormat', '%g s/s' );
    
    hGL = uigridlayout( hGZ, [1 6], 'Padding', [0 0 0 0] );
    uilabel( hGL, 'Text', 'Compass:', 'FontSize', cwave.FontSize, 'HorizontalAlignment', 'right' );
    hCompass = uieditfield( hGL, 'numeric', 'Limits', [-360 360], 'FontSize', cwave.FontSize ...
        , 'ValueDisplayFormat', '%g', 'ValueChangedFcn', @sub_UpdtCompass );
    uilabel( hGL, 'Text', 'Pitch:', 'FontSize', cwave.FontSize, 'HorizontalAlignment', 'right' );
    hPitch = uieditfield( hGL, 'numeric', 'Limits', [-90 90], 'FontSize', cwave.FontSize ...
        , 'ValueDisplayFormat', '%g', 'ValueChangedFcn', @sub_UpdtPitch );
    uilabel( hGL, 'Text', 'Roll:', 'FontSize', cwave.FontSize, 'HorizontalAlignment', 'right' );
    hRoll = uieditfield( hGL, 'numeric', 'Limits', [-90 90], 'FontSize', cwave.FontSize ...
        , 'ValueDisplayFormat', '%g', 'ValueChangedFcn', @sub_UpdtRoll );
    
    hGL = uigridlayout( hGZ, 'Padding', [0 0 0 0], 'RowHeight', {'1x'} ...
        , 'ColumnWidth', {'fit','1x'} );
    uilabel( hGL, 'Text', 'Binary data file:', 'FontSize', cwave.FontSize, 'HorizontalAlignment', 'right' );
    hBinFile = uidropdown( hGL, 'FontSize', cwave.FontSize ...
        , 'Items', [{''} onerow( oWave.cFiles_Bin )] );
    
    cRSPList = sort( getFileList( oWave.sDir_Calib, '*.rsp', 'NoTrace', 'NoPath' ) );
    hChList = uitable( 'Parent', hGZ, 'FontSize', cwave.FontSize ...
        , 'ColumnSortable', false, 'RowName', {} ...
        , 'ColumnName', {'Ch', 'OutOrder', 'Type', 'Orient', 'Tilt' ...
                        , 'Calibration', 'Dip Len', 'Gain'} ...
        , 'ColumnEditable', [false, true(1,7)] ...
        , 'ColumnFormat', {'numeric', 'numeric', 'char', 'numeric', 'numeric' ...
                        , cRSPList, 'numeric', 'numeric', 'numeric'} ...
        , 'CellEditCallback', @sub_ChEdit ...
        );
    hChList.Layout.Row = numel(hGZ.RowHeight) - 1;
    
    hGL = uigridlayout( hGZ, 'Padding', [0 0 0 0], 'RowHeight', {'1x'} ...
        , 'ColumnWidth', {'1x',cwave.BtnWd,cwave.BtnWd,'1x'} );
    hGL.Layout.Row = numel(hGZ.RowHeight);
    uilabel( hGL, 'Text', '' );
    uibutton( hGL, 'FontSize', cwave.FontSize, 'Text', '<< Prev', 'ButtonPushedFcn', @sub_PrevRx );
    uibutton( hGL, 'FontSize', cwave.FontSize, 'Text', 'Next >>', 'ButtonPushedFcn', @sub_NextRx );
    
    
    %% Bottom zone: dialog control buttons
    hGB = uigridlayout( hG );
    hGB.Layout.Column   = [1 numel(hG.ColumnWidth)];
    hGB.Layout.Row      = numel(hG.RowHeight);
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
    
    % Select the first row of the rx table (if any) and fill the entry fields
    iTblSelect = 1;
    sub_FillFields();
    
    % Make the figure visible and run the MODAL figure
    hFig.Visible = true;
    hFig.CloseRequestFcn = @sub_Cancel;
    waitfor( hFig );
    return;

    %---------------------------------------------------------------------------
    % Track selection events because the stupid uitable class does NOT give you
    % a way to find out what is currently selected. How dumb is that?
    function sub_TrackSlctn(~,st)
        % Save current values back to the tables
        sub_SaveFields();
        
        % Change the selection
        iTblSelect = st.Indices;
        if ~isempty(iTblSelect)
            iTblSelect = iTblSelect(1,1);   % only want the first selected row
        end
        
        % Load the new values into the entry fields
        sub_FillFields();
        
        return;
    end % sub_TrackSlctn
    
    %---------------------------------------------------------------------------
    function sub_Cancel(~,~)
        delete( hFig );
        return;
    end % sub_Cancel
    
    %---------------------------------------------------------------------------
    function sub_Save(~,~)
        % Make sure data in the current entry fields is pushed into the list
        sub_SaveFields();
        
        % Validate all receiver configurations
        [bOK,cErrMsg] = cwave.ValidateRxCfg( tblRxCfg, tblRxCh, oWave.sDir_Calib );
        if ~all(bOK)
            % Ensure there is a message (r.n. ValidateRxCfg always rtns one if
            % there's an error, but who knows what the future holds...)
            if isempty( cErrMsg )
                cErrMsg{1} = 'Invalid configuration';
            end
            
            % Update the error messages in the Rx List
            c           = hRxList.Data;
            c(:,1)      = num2cell( bOK );
            c(:,3)      = repmat({''},size(c,1),1);
            c(~bOK,3)   = cErrMsg(1);
            hRxList.Data= c;
            
            % Even though everything is not OK, allow the user to save and go
            % back to the main UI. The process of entering Rx info can be long
            % and tedious and may even be done piecemeal as sites are recovered
            % from the seafloor. Allow that. cwave::NodalCSEM protects itself
            % against unfinished RxCfg info
            sBtn = uiconfirm( hFig, {
                'The OBEM receiver configurations are not complete.'
                sprintf( '%d of %d have incomplete info.', sum(~bOK), numel(bOK) )
                ['Current error: ' cErrMsg{1}]
                ''
                'Do you want to save and return to WAVE anyway?'
                }, 'Save Anyway?', 'Options', {'Yes', 'Cancel'} );
            if ~strcmpi( sBtn, 'Yes' )
                return;
            end
        end
        
        % NB: Because reprocessing ALL csem can take time, I need to record
        % which RXs were deleted or changed. Then I remove these from the output
        % CSEM list so that the "Run New" on NodalCSEM will do them again.
        if ~isempty( oWave.cFiles_NodalCSEM )
            bDrop = false( height( oWave.cFiles_NodalCSEM ), 1 );
            
            % Look for deleted RXs
            bDel = ~ismember( oWave.tableRxCfg.RxName, tblRxCfg.RxName );
            if any( bDel )
                for i = reshape(find(bDel),1,[])
                    sPat = strcat( '_', oWave.tableRxCfg.RxName{i}, '.csem.mat' );
                    bDrop = bDrop | contains( oWave.cFiles_NodalCSEM, sPat );
                end
            end
            
            % Look for changed RXs
            bDel = false(1,height(tblRxCfg));
            for iNew = 1:height(tblRxCfg)
                iOld = find( strcmpi( tblRxCfg.RxName{iNew}, oWave.tableRxCfg.RxName ), 1 );
                if isempty( iOld ) % ignore added RXs
                    continue;
                end
                if ~isequal( tblRxCfg(iNew,:), oWave.tableRxCfg(iOld,:) )
                    bDel(iNew) = true;
                else
                    bChNew = strcmpi( tblRxCfg.RxName(iNew), tblRxCh.RxName );
                    bChOld = strcmpi( tblRxCfg.RxName(iNew), oWave.tableRxCh.RxName );
                    bDel(iNew) = ~isequal( tblRxCh(bChNew,:), oWave.tableRxCh(bChOld,:) );
                end
            end
            if any( bDel )
                for i = reshape(find(bDel),1,[])
                    sPat = strcat( '_', tblRxCfg.RxName{i}, '.csem.mat' );
                    bDrop = bDrop | contains( oWave.cFiles_NodalCSEM, sPat );
                end
            end
            
            % Make the changes
            if any( bDrop )
                oWave.cFiles_NodalCSEM(bDrop) = [];
            end
        end
        
        % If everything is OK, add to the log & update the main tables
        oWave.AddLog( cwave.LogOK, cwave.sLog_Nodal_CSEM, 'User edited nodal RX configurations' );
        oWave.tableRxCh     = tblRxCh;  % no listeners on this table
        oWave.tableRxCfg    = tblRxCfg; % listeners on this table
        
        % Close the dialog
        delete( hFig );
        
        return;
    end % sub_Save
    
    %---------------------------------------------------------------------------
    % Fill the RX edit fields from the currently selected Rx
    function sub_FillFields()
        % Clear any previous row selection styling
        if height(hRxList.StyleConfigurations) > 1
            removeStyle( hRxList, 2 );
        end
        
        % Make a block of blank channels to be used to fluff out any existing
        % channels to the max number allowed. Because of the settings on the
        % uitable object, NaNs aren't allowed.
        tTheseCh = cwave.GetDfltFor( 'tableRxCh', cwave.MaxRxCh );
        tTheseCh.RxName(:)        = "";
        tTheseCh.ChanNo(:)        = 1:cwave.MaxRxCh;
        tTheseCh.Type(:)          = "";
        tTheseCh.CalibFile(:)     = "";
        tTheseCh.Orient(:)        = 0;
        tTheseCh.Tilt(:)          = 0;
        tTheseCh.DipLen(:)        = 1;
        tTheseCh.Gain(:)          = 1;
        tTheseCh.MTOutputOrder(:) = 0;
        
        if ~isempty( iTblSelect ) && between( 1, iTblSelect, height( tblRxCfg ) )
            iRow = iTblSelect;
            hRxName.Value   = tblRxCfg.RxName(iRow);
            hDepth.Value    = tblRxCfg.Depth(iRow);
            hEasting.Value  = tblRxCfg.East(iRow);
            hNorthing.Value = tblRxCfg.North(iRow);
            hLon.Value      = tblRxCfg.Longitude(iRow);
            hLat.Value      = tblRxCfg.Latitude(iRow);
            hSync(1).Value  = month(tblRxCfg.SyncTime(iRow));
            hSync(2).Value  = day(tblRxCfg.SyncTime(iRow));
            hSync(3).Value  = year(tblRxCfg.SyncTime(iRow));
            hSync(4).Value  = hour(tblRxCfg.SyncTime(iRow));
            hSync(5).Value  = minute(tblRxCfg.SyncTime(iRow));
            hSync(6).Value  = second(tblRxCfg.SyncTime(iRow));
            hSync(7).Value  = tblRxCfg.SyncTag(iRow);
            hShift(1).Value = month(tblRxCfg.ShiftTime(iRow));
            hShift(2).Value = day(tblRxCfg.ShiftTime(iRow));
            hShift(3).Value = year(tblRxCfg.ShiftTime(iRow));
            hShift(4).Value = hour(tblRxCfg.ShiftTime(iRow));
            hShift(5).Value = minute(tblRxCfg.ShiftTime(iRow));
            hShift(6).Value = second(tblRxCfg.ShiftTime(iRow));
            hShift(7).Value = tblRxCfg.ShiftTag(iRow);
            hLagSec.Value   = 0;
            hDrift.Value    = tblRxCfg.DriftRate(iRow);
            hCompass.Value  = tblRxCfg.Compass(iRow);
            hPitch.Value    = tblRxCfg.Pitch(iRow);
            hRoll.Value     = tblRxCfg.Roll(iRow);
            hBinFile.Value  = fullfile( tblRxCfg.BinPath(iRow), tblRxCfg.BinFile(iRow) );
            
            % Find all the channels for this receiver. Then fluff out to the max
            % number of allowed channels
            bChs = strcmpi( tblRxCh.RxName, tblRxCfg.RxName(iRow) );
            if any(bChs)
                tTheseCh(tblRxCh.ChanNo(bChs),:) = [];
                tTheseCh = sortrows( [tTheseCh; tblRxCh(bChs,:)], 'ChanNo' );
            end
            tTheseCh.RxName(:) = tblRxCfg.RxName(iRow);
            
            % Because it's not always easy to tell which row is selected, color
            % the RxName
            scrollR2020b( hRxList, 'row', iTblSelect );
            addStyle( hRxList, uistyle( 'FontColor', 'w', 'BackgroundColor', 'k' ) ...
                , 'cell', [iRow 2] );
            
        else
            hRxName.Value   = '';
            hDepth.Value    = 0;
            hEasting.Value  = 1;
            hNorthing.Value = 1;
            hLon.Value      = 0;
            hLat.Value      = 0;
            hSync(1).Value  = 1;
            hSync(2).Value  = 1;
            hSync(3).Value  = 2000;
            hSync(4).Value  = 0;
            hSync(5).Value  = 0;
            hSync(6).Value  = 0;
            hSync(7).Value  = 0;
            hShift(1).Value = 1;
            hShift(2).Value = 1;
            hShift(3).Value = 2000;
            hShift(4).Value = 0;
            hShift(5).Value = 0;
            hShift(6).Value = 0;
            hShift(7).Value = 0;
            hLagSec.Value   = 0;
            hDrift.Value    = 0;
            hCompass.Value  = 0;
            hPitch.Value    = 0;
            hRoll.Value     = 0;
            hBinFile.Value  = '';
        end
        
        % Set the channel table
        hChList.Data = TblCh2Cell( tTheseCh );
        
        return;
    end % sub_FillFields
    
    %---------------------------------------------------------------------------
    % Convert a channel table to the cell array needed by the uitable object -
    % where I'm using a ColumnFormat that will be ignored if I just pass the
    % table directly.
    function c = TblCh2Cell( tTheseCh )
        % NB: <sigh> uitable doesn't like 'string' types for 'char' columns ...
        % despite the fact that it is find with 'string' types in tables that
        % are passed directly. However, if I pass a table in directly, then
        % 'ColumnFormat' is ignored. I use ColumnFormat for the list of known
        % calibration files so the user doesn't screw up those super-complicated
        % names.
        c = table2cell( tTheseCh(:,{'ChanNo', 'MTOutputOrder', 'Type'...
            , 'Orient', 'Tilt', 'CalibFile', 'DipLen', 'Gain'}) );
        c = cellfun( @(c)iif(isstring(c),char(c),c), c, 'UniformOutput', false );
        return;
    end % TblCh2Cell
    
    %---------------------------------------------------------------------------
    % Convert the cell array from the channel uitable back into an actual table
    % object. (See note on TblCh2Cell for why I don't just assign the table
    % directly to the uitable.)
    function tCh = Cell2TblCh( c, bDropEmpty )
        % Remove any channels without type info
        if bDropEmpty
            c(cellfun( @isempty, c(:,3) ),:) = [];
        end
        c = sortrows( c, 1 );   % Sort
        
        % Create the add table
        tCh                 = cwave.GetDfltFor( 'tableRxCh', size(c,1) );
        tCh.ChanNo(:)       = cell2mat( c(:,1) );
        tCh.MTOutputOrder(:)= cell2mat( c(:,2) );
        tCh.Type(:)         = string(   c(:,3) );
        tCh.Orient(:)       = cell2mat( c(:,4) );
        tCh.Tilt(:)         = cell2mat( c(:,5) );
        tCh.CalibFile(:)    = string(   c(:,6) );
        tCh.DipLen(:)       = cell2mat( c(:,7) );
        tCh.Gain(:)         = cell2mat( c(:,8) );
        return;
    end % Cell2TblCh
    
    %---------------------------------------------------------------------------
    % Move data from the entry fields back into the associated tables
    function sub_SaveFields()
        if isempty( iTblSelect ) || ~between( 1, iTblSelect, height( tblRxCfg ) )
            return;
        end
        
        iRow = iTblSelect;
        tblRxCfg.RxName(iRow)       = hRxName.Value;
        tblRxCfg.Depth(iRow)        = hDepth.Value;
        tblRxCfg.East(iRow)         = hEasting.Value;
        tblRxCfg.North(iRow)        = hNorthing.Value;
        tblRxCfg.Longitude(iRow)    = hLon.Value;
        tblRxCfg.Latitude(iRow)     = hLat.Value;
        tblRxCfg.SyncTime(iRow)     = ...
            datetime( hSync(3).Value, hSync(1).Value, hSync(2).Value ...
                    , hSync(4).Value, hSync(5).Value, hSync(6).Value );
        tblRxCfg.SyncTag(iRow)      = hSync(7).Value;
        tblRxCfg.ShiftTime(iRow)    = ...
            datetime( hShift(3).Value, hShift(1).Value, hShift(2).Value ...
                    , hShift(4).Value, hShift(5).Value, hShift(6).Value );
        tblRxCfg.ShiftTag(iRow)     = hShift(7).Value;
        tblRxCfg.DriftRate(iRow)    = hDrift.Value;
        tblRxCfg.Compass(iRow)      = hCompass.Value;
        tblRxCfg.Pitch(iRow)        = hPitch.Value;
        tblRxCfg.Roll(iRow)         = hRoll.Value;
        [tblRxCfg.BinPath(iRow), sF, sX] = fileparts( hBinFile.Value );
        tblRxCfg.BinFile(iRow) = [sF sX];
        
        % Remove all the channels for this receiver from the current table
        bChs = strcmpi( tblRxCh.RxName, tblRxCfg.RxName(iRow) );
        if any(bChs)
            tblRxCh(bChs,:) = [];
        end
        
        % Pull the channel data from the entry fields. Note that it is a cell
        % array because of a ColumnFormat I want to use in uitable.
        tCh = Cell2TblCh( hChList.Data, true );
        tCh.RxName(:) = tblRxCfg.RxName(iRow);  % field not in the uitable
        
        % Add to the master list
        tblRxCh(end+1:end+height(tCh),:) = tCh;
        
        % Validate just this one receiver and update its status in the Rx List
        % uitable
        [bOK,cErrMsg] = cwave.ValidateRxCfg( tblRxCfg(iRow,:), tCh, oWave.sDir_Calib );
        hRxList.Data{iRow,1} = bOK;
        if isempty( cErrMsg )
            hRxList.Data{iRow,3} = '';
        else
            hRxList.Data{iRow,3} = cErrMsg{1};
        end
        
        return;
    end % sub_SaveFields
    
    %---------------------------------------------------------------------------
    % Add a new receiver to the list & make it the one in the edit window
    function sub_AddRx(~,~)
        % Save any current edits
        sub_SaveFields();
        
        % Ask for a RX name. Name MUST BE UNIQUE
        stAsk.hFig = hFig;
        stAsk.sRxName = '';
        stAsk.stVarInfo = struct( ...
            'sRxName', struct( ...
                  'sDesc', 'Receiver name' ...
                , 'fcnValid', @emb_ChkRxName ...
                , 'sSpecialBtn', '' ...
                , 'sHelp', ['The receiver name must be unique and can only ' ...
                            'contain letters, numbers, and a limited list ' ...
                            'of symbols. It may not contain spaces or any ' ...
                            'symbol not allowed in a filename on some OS.' ...
                           ] ...
                ) );
        [bOK,stAsk] = UIEditVars( stAsk, 'Enter New Receiver Name', {'sRxName'} );
        if ~bOK
            return;
        end
        
        % Add a new row with that name & the typical 4 channels. Note that
        % various entry fields complain if values are out of limits
        iAt = height( tblRxCfg ) + 1;
        tblRxCfg{iAt,:}             = missing();
        tblRxCfg.RxName(iAt)        = string(stAsk.sRxName);
        tblRxCfg.Compass(iAt)       = 0;
        tblRxCfg.Pitch(iAt)         = 0;
        tblRxCfg.Roll(iAt)          = 0;
        tblRxCfg.SyncTime(iAt)      = datetime('now') - days(1);    % just dummy something up
        tblRxCfg.SyncTag(iAt)       = 0.0;
        tblRxCfg.ShiftTime(iAt)     = datetime('now');
        tblRxCfg.ShiftTag(iAt)      = 0.0;
        tblRxCfg.DriftRate(iAt)     = 0;
        
        % If this site is in the Rx Nav list, pull its location info and plug it
        % in automatically
        iNav = find( strcmpi( oWave.tableRxNav.RxName, tblRxCfg.RxName(iAt) ), 1, 'first' );
        if isempty( iNav )
            tblRxCfg.Latitude(iAt)  = 0;
            tblRxCfg.Longitude(iAt) = 0;
            tblRxCfg.Depth(iAt)     = 0;
            tblRxCfg.East(iAt)      = 0;
            tblRxCfg.North(iAt)     = 0;
        else
            tblRxCfg.RxName(iAt)    = oWave.tableRxNav.RxName(iNav);    % match the case in that table
            tblRxCfg.Latitude(iAt)  = oWave.tableRxNav.Latitude(iNav);
            tblRxCfg.Longitude(iAt) = oWave.tableRxNav.Longitude(iNav);
            tblRxCfg.Depth(iAt)     = oWave.tableRxNav.Depth(iNav);
            tblRxCfg.East(iAt)      = oWave.tableRxNav.East(iNav);
            tblRxCfg.North(iAt)     = oWave.tableRxNav.North(iNav);
        end
        tblRxCh = [tblRxCh
            sub_TypicalCh( tblRxCfg, iAt, 'Hx' )
            sub_TypicalCh( tblRxCfg, iAt, 'Hy' )
            sub_TypicalCh( tblRxCfg, iAt, 'Ex' )
            sub_TypicalCh( tblRxCfg, iAt, 'Ey' )
            ];
        
        % Update the Rx list data
        c           = hRxList.Data;
        [b,cErr]    = cwave.ValidateRxCfg( tblRxCfg(iAt,:), tblRxCh(end-3:end,:), oWave.sDir_Calib );
        c{end+1,1}  = b;
        c{end,2}    = char( tblRxCfg.RxName(iAt) ); % uitable doesn't like string in a cell array
        c{end,3}    = iif( isempty( cErr ), '', cErr{1} );
        
        % Sort by RxName
        [~,iSort]       = sort( upper( tblRxCfg.RxName ) );
        tblRxCfg        = tblRxCfg(iSort,:);
        hRxList.Data    = c(iSort,:);
        iAt             = iSort(iAt);
        
        % Select the row and make it show up in the edit window
        iTblSelect = iAt;
        scrollR2020b( hRxList, 'row', iAt );
        sub_FillFields();
        
        return;
        
        %-----------------------------------------------------------------------
        % UIEditVars wants the validation function to throw an error
        function emb_ChkRxName( sRx )
            assert( cwave.ChkRxName( sRx ), 'Name contains invalid characters.' );
            assert( ~any(strcmpi(sRx,tblRxCfg.RxName)), 'Name already exists in the receiver list.' );
        end
    end % sub_AddRx
    
    %---------------------------------------------------------------------------
    % Delete currently selected receivers
    function sub_DelRx(~,~)
        % Have to have a row selected
        if isempty( iTblSelect )
            uialert( hFig, 'Select a receiver in the list first. Then delete.' ...
                , 'Delete Receiver' );
            return;
        end
        
        % Confirm before deleting
        sRxName = tblRxCfg.RxName(iTblSelect);
        if ~strcmpi( 'Yes', uiconfirm( hFig, {
            ['Delete receiver ' char(sRxName) '?']
            }, 'Delete Receiver?', 'Options', {'Yes', 'No'} ...
            , 'DefaultOption', 1, 'CancelOption', 2 ) )
            return;
        end
        
        % Delete the receiver from the list & the tables
        c = hRxList.Data;
        c(iTblSelect,:) = [];
        hRxList.Data = c;
        
        tblRxCfg(iTblSelect,:) = [];
        tblRxCh(strcmpi(tblRxCh.RxName,sRxName),:) = [];
        
        % Select a new item
        if iTblSelect > height(tblRxCfg)
            iTblSelect = height(tblRxCfg);
        end
        sub_FillFields();
        
        return;
    end % sub_DelRx
    
    %---------------------------------------------------------------------------
    % Handle the "Reset" button for the list of Receivers
    function sub_ResetRx(~,~)
        % Confirm the user really wants to reset
        if ~strcmpi( 'Yes', uiconfirm( hFig, {
            'Delete all receivers from the list?'
            }, 'Reset Receiver List?', 'Options', {'Yes', 'No'} ...
            , 'DefaultOption', 1, 'CancelOption', 2 ) )
            return;
        end
        
        % Clear everything
        iTblSelect      = [];
        hRxList.Data    = cell(0,3);
        tblRxCfg        = cwave.GetDfltFor( 'tableRxCfg' );
        tblRxCh         = cwave.GetDfltFor( 'tableRxCh' );
        if height(hRxList.StyleConfigurations) > 1 % Clear any previous row selection styling
            removeStyle( hRxList, 2 );
        end
        
        % After reset ask if they want to re-import from the RxNav table
        [bOK, tblRxCfg, tblRxCh] = sub_GetTables( hFig, oWave, tblRxCfg, tblRxCh );
        if bOK
            hRxList.Data = sub_InitRxList( tblRxCfg, tblRxCh, oWave.sDir_Calib );
            iTblSelect   = 1;
        end
        sub_FillFields();
        
        return;
    end % sub_ResetRx
    
    %---------------------------------------------------------------------------
    function sub_PrevRx(~,~)
        sub_SaveFields();   % move fields back into table
        if iTblSelect == 1
            beep;
        else
            iTblSelect = iTblSelect - 1;
            scrollR2020b( hRxList, 'row', iTblSelect );
            sub_FillFields();
        end
        return;
    end % sub_PrevRx
    
    %---------------------------------------------------------------------------
    function sub_NextRx(~,~)
        sub_SaveFields();   % move fields back into table
        if iTblSelect == height(tblRxCfg)
            beep;
        else
            iTblSelect = iTblSelect + 1;
            scrollR2020b( hRxList, 'row', iTblSelect );
            sub_FillFields();
        end
        return;
    end % sub_NextRx
    
    %---------------------------------------------------------------------------
    % User is editing the UTM entries - so generate Lon,Lat
    function sub_EditUTM(~,~)
        try %#ok<TRYNC>
            [hLon.Value, hLat.Value] = oWave.UTM2LonLat( hEasting.Value, hNorthing.Value );
        end
        return;
    end % sub_EditUTM
    
    %---------------------------------------------------------------------------
    % User is editing Lon,Lat - so generate UTM
    function sub_EditLL(~,~)
        try %#ok<TRYNC>
            [hEasting.Value,hNorthing.Value] ...
                = oWave.LonLat2UTM( cwave.sLog_Nodal_CSEM, hLon.Value, hLat.Value );
        end
        return;
    end % sub_EditLL
    
    %---------------------------------------------------------------------------
    % User is sync and shift fields -- calculate drift rate
    function sub_UpdtDrift(~,~)
        try %#ok<TRYNC>
            dSync = datetime( hSync(3).Value, hSync(1).Value, hSync(2).Value ...
                            , hSync(4).Value, hSync(5).Value, hSync(6).Value );
            dShift = datetime( hShift(3).Value, hShift(1).Value, hShift(2).Value ...
                             , hShift(4).Value, hShift(5).Value, hShift(6).Value );
            
            % NB: When the logger's second counter is lagging behind the GPS
            % unit's counter (i.e. the GPS clock ticks over the second THEN the
            % logger ticks over) then the logger's clock is running slow enough
            % that the tag value needs a whole second added to it
            nSyncTag  = hSync(7).Value;
            nShiftTag = hShift(7).Value;
            if hLagSec.Value 
                nShiftTag = nShiftTag + 1;
            elseif nShiftTag > 0.5 % arbitrary!
                % When the shift tag is in the upper range then it is typically
                % running fast. If it is actually running slow, then the user
                % will have to calc the drift rate and enter it manually. This
                % has been this way since 2009.
                nShiftTag = nShiftTag - 1;
            end
            
            % Calculate the clock drift rate in seconds per second
            nDrift = (nShiftTag - nSyncTag) / seconds(dShift - dSync);
            assert( ~isinf(nDrift) );
            hDrift.Value = nDrift;
        end
        return;
    end % sub_UpdtDrift
    
    %---------------------------------------------------------------------------
    % Compass has been updated. Update the channel orientations
    function sub_UpdtCompass(~,~)
        nCompass = hCompass.Value;
        tCh = Cell2TblCh( hChList.Data, false );
        for iCh = 1:height(tCh)
            switch( tCh.Type(iCh) )
            case "Hx"
                tCh.Orient(iCh) = nCompass + 90;
            case "Hy"
                tCh.Orient(iCh) = nCompass + 180;
            case "Ex"
                tCh.Orient(iCh) = nCompass + 90 - 3;
            case "Ey"
                tCh.Orient(iCh) = nCompass + 180 - 2.6;
            otherwise
                tCh.Orient(iCh) = nCompass;
            end
        end
        hChList.Data = TblCh2Cell( tCh );
        return;
    end % sub_UpdtCompass
    
    %---------------------------------------------------------------------------
    function sub_UpdtPitch(~,~)
        nPitch = hPitch.Value;
        tCh = Cell2TblCh( hChList.Data, false );
        for iCh = 1:height(tCh)
            switch( tCh.Type(iCh) )
            case {"Hy","Ey"}
                tCh.Tilt(iCh) = nPitch;
            end
        end
        hChList.Data = TblCh2Cell( tCh );
        return;
    end % sub_UpdtPitch
    
    %---------------------------------------------------------------------------
    function sub_UpdtRoll(~,~)
        nRoll = hRoll.Value;
        tCh = Cell2TblCh( hChList.Data, false );
        for iCh = 1:height(tCh)
            switch( tCh.Type(iCh) )
            case {"Hx","Ex"}
                tCh.Tilt(iCh) = nRoll;
            end
        end
        hChList.Data = TblCh2Cell( tCh );
        return;
    end % sub_UpdtRoll
    
    %---------------------------------------------------------------------------
    % User has edit something in the channel table
    function sub_ChEdit(~,oChg)
        cChList = {'Hx','Hy','Ex','Ey','Ez'};
        
        % Which column has been edited?
        switch( oChg.Indices(2) )
        case 3  % Channel type
            % For known types, enforce <upper><lower>
            if any( strcmpi( oChg.NewData, cChList ) )
                % NB: cannot change oChg.NewData. It is read-only
                hChList.Data{oChg.Indices(1),3} = [upper(oChg.NewData(1)) lower(oChg.NewData(2))];
            end
            
            % Special handling for vertical channels
            if strcmpi( oChg.NewData, 'Ez' )
                % Ez channels on SIO instruments are usually upside down
                % (electrically) and need a negative to flip them. Use the
                % amplifier gain since tilt is not used in the CSEM processing
                hChList.Data{oChg.Indices(1),4} = 0;    % orientation
                hChList.Data{oChg.Indices(1),5} = 90;   % tilt
                hChList.Data{oChg.Indices(1),7} = 1.5;  % dipole length
                hChList.Data{oChg.Indices(1),8} = -1;   % amplifier gain
            elseif strcmpi( oChg.PreviousData, 'Ez' )
                % Was Ez now something else. Remove any negative from gain
                hChList.Data{oChg.Indices(1),8} = abs(hChList.Data{oChg.Indices(1),8});
            end
            
        case 6  % Calibration file
            % If the calibration selected contains _ch?_ where ? is the channel
            % number, then fill all the other non-empty calibration rows with
            % companions in the calibration set. (Standard SIO .rsp naming)
            sFindMe = sprintf( '_ch%d_', oChg.Indices(1) );
            if contains( oChg.NewData, sFindMe, 'IgnoreCase', true )
                for iCh = 1:cwave.MaxRxCh
                    if iCh == oChg.Indices(1) || ~isempty( hChList.Data{iCh,6} )
                        continue;
                    end
                    sNew = replace( oChg.NewData, sFindMe, sprintf( '_ch%d_', iCh ) );
                    if ismember( sNew, cRSPList )
                        hChList.Data{iCh,6} = sNew;
                        
                        % If the row doesn't have a channel type yet, assign it
                        % from the default standard list
                        if iCh <= numel(cChList) && isempty( hChList.Data{iCh,3} )
                            % NB: changing the uitable's data does NOT call the
                            % update function. Do that manually
                            hChList.Data{iCh,3} = cChList{iCh};
                            sub_ChEdit( [], struct( 'NewData', cChList{iCh} ...
                                , 'PreviousData', '', 'Indices', [iCh 3] ) );
                        end
                    end
                end
            end
        end
        return;
    end % sub_ChEdit
    
end % UIRxCfg

%-------------------------------------------------------------------------------
% Get the tables of receivers & channels. Prompt the user to auto-fill from the
% RxNav list
function [bOK, tblRxCfg, tblRxCh] = sub_GetTables( hFig, oWave, tblRxCfg, tblRxCh )
    % Default the return values
    bOK         = true;
    
    % If the nav table is empty, there's nothing else to do
    if isempty( oWave.tableRxNav )
        return;
    end
    
    % How many of the receivers in the Rx Nav table are NOT in the Rx Cfg table?
    % Ask about auto-adding with standard Bx,By,Ex,Ey channel configuration
    if isempty( tblRxCfg )
        iAdd = 1:height( oWave.tableRxNav );
        sBtn = uiconfirm( hFig, {
            'Do you want to automatically add all the receivers'
            'in the benthos navigation list?'
            ''
            '(NB: they will be added with the typical 4 channels:'
            'Hx, Hy, Ex, Ey and with no compass info.)'
            }, 'Auto-add Receivers?', 'Options', {'Yes', 'No', 'Cancel'} ...
            , 'DefaultOption', 1, 'CancelOption', 3 );
    else
        iAdd = find( ~ismember( lower(oWave.tableRxNav.RxName), lower(tblRxCfg.RxName) ) );
        if isempty( iAdd )
            sBtn = 'No';
        else
            sBtn = uiconfirm( hFig, {
                sprintf( '%d of %d navigated RXs are not in the config list.' ...
                    , numel(iAdd), height(oWave.tableRxNav) )
                'Do you want to automatically add them?'
                ''
                '(NB: they will be added with the typical 4 channels:'
                'Hx, Hy, Ex, Ey and with no compass info.)'
                }, 'Auto-add Receivers?', 'Options', {'Yes', 'No', 'Cancel'} ...
                , 'DefaultOption', 1, 'CancelOption', 3 );
        end
    end
    if ~strcmpi( sBtn, 'Yes' )  % user cancel or "no"
        bOK = strcmpi( sBtn, 'No' );
        return;
    end
    
    % Add the requested receivers from RxNav to the config tables with typical
    % configurations
    for i = reshape( iAdd, 1, [] )
        iAt = height(tblRxCfg) + 1;
        tblRxCfg{iAt,:}         = missing();
        tblRxCfg.RxName(iAt)    = oWave.tableRxNav.RxName(i);
        tblRxCfg.Compass(iAt)   = 0;
        tblRxCfg.Pitch(iAt)     = 0;
        tblRxCfg.Roll(iAt)      = 0;
        tblRxCfg.SyncTime(iAt)  = datetime('now') - days(1);    % just dummy something up
        tblRxCfg.SyncTag(iAt)   = 0.0;
        tblRxCfg.ShiftTime(iAt) = datetime('now');
        tblRxCfg.ShiftTag(iAt)  = 0.0;
        tblRxCfg.DriftRate(iAt) = 0;
        tblRxCfg.Latitude(iAt)  = oWave.tableRxNav.Latitude(i);
        tblRxCfg.Longitude(iAt) = oWave.tableRxNav.Longitude(i);
        tblRxCfg.Depth(iAt)     = oWave.tableRxNav.Depth(i);
        tblRxCfg.East(iAt)      = oWave.tableRxNav.East(i);
        tblRxCfg.North(iAt)     = oWave.tableRxNav.North(i);
        
        % Add typical channels
        % NB: See note in main header about Bx,By vs Hx,Hy
        tblRxCh = [tblRxCh
            sub_TypicalCh( tblRxCfg, iAt, 'Hx' )
            sub_TypicalCh( tblRxCfg, iAt, 'Hy' )
            sub_TypicalCh( tblRxCfg, iAt, 'Ex' )
            sub_TypicalCh( tblRxCfg, iAt, 'Ey' )
            ];
    end
    
    % Sort the output list
    tblRxCfg = sortrows( tblRxCfg, 'RxName' );
    
    return;
end % sub_GetTables

%-------------------------------------------------------------------------------
% Return a tableRxCh row for an archetypical SIO OBEM channel of the type given
function tOut = sub_TypicalCh( tblRxCfg, iWhich, sType )
    % Fill common fields
    tOut            = cwave.GetDfltFor( 'tableRxCh', 1 );
    tOut.RxName     = tblRxCfg.RxName(iWhich);
    tOut.Type       = string(sType);
    tOut.Gain       = 1;            % SIO instruments don't use amplifier gain
    tOut.CalibFile  = "";
    
    % Channel specific fields
    % NB: SIO instrument electrode arms are NOT square with the magnetic
    % channels. I first pointed this out in 2009 when no one thought it would
    % matter. But 3 degrees of offset for the E channels can be significant.
    switch( sType )
    case 'Hx'
        tOut.ChanNo = 1;
        tOut.Orient = tblRxCfg.Compass(iWhich) + 90;
        tOut.Tilt   = tblRxCfg.Roll(iWhich); % Roll +ve = down on North (X)
        tOut.DipLen = 1;
    case 'Hy'
        tOut.ChanNo = 2;
        tOut.Orient = tblRxCfg.Compass(iWhich) + 180;
        tOut.Tilt   = tblRxCfg.Pitch(iWhich); % Pitch +ve = down on East (Y)
        tOut.DipLen = 1;
    case 'Ex'
        tOut.ChanNo = 3;
        tOut.Orient = tblRxCfg.Compass(iWhich) + 90 - 3;
        tOut.Tilt   = tblRxCfg.Roll(iWhich); % Roll +ve = down on North (X)
        tOut.DipLen = sqrt( 10.06^2 + 0.52^2 );
    case 'Ey'
        tOut.ChanNo = 4;
        tOut.Orient = tblRxCfg.Compass(iWhich) + 180 - 2.6;
        tOut.Tilt   = tblRxCfg.Pitch(iWhich); % Pitch +ve = down on East (Y)
        tOut.DipLen = sqrt( 10.06^2 + 0.456^2 );
    end
    tOut.MTOutputOrder  = tOut.ChanNo;
    
    return;
end % sub_TypicalCh

%-------------------------------------------------------------------------------
% Create the cell array that goes in the Rx List table
function cList = sub_InitRxList( tblRxCfg, tblRxCh, sCalibDir )
    [b,cErr]    = cwave.ValidateRxCfg( tblRxCfg, tblRxCh, sCalibDir );
    cList       = num2cell( b );
    cList(:,2)  = {tblRxCfg.RxName{:}}; %#ok<CCAT1>
    cList(:,3)  = repmat({''},size(cList,1),1);
    if any(~b)
        cList(~b,3) = cErr(1);
    end
    return;
end % sub_InitRxList
