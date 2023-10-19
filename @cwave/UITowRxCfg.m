function UITowRxCfg( oWave )
% cwave::UITowRxCfg( oWave )
%
% UI for editing TOWED receiver configuration info
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
    
    % Get the tables of TOWED receivers & channels
    tblRxCfg = oWave.tableTowRxCfg;
    tblRxCh  = oWave.tableTowRxCh;
    
    % Build the UI
    hFig = uifigure( 'Name', 'Edit Towed RX Config', 'WindowStyle', 'modal' ...
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
    hGZ.RowHeight       = [repmat({cwave.BtnHt},1,9) {'1x',cwave.BtnHt}];
    hGZ.ColumnWidth     = {'1x'};
    hGZ.ColumnSpacing   = 0;
    hGZ.RowSpacing      = 5;
    hGZ.Padding         = [10 10 10 10];
    
    hGL = uigridlayout( hGZ, [1 3], 'Padding', [0 0 0 0], 'ColumnWidth', {'fit',2*cwave.BtnWd,'1x'} );
    uilabel( hGL, 'Text', 'Rx Name:', 'FontSize', cwave.FontSize, 'HorizontalAlignment', 'right' );
    hRxName = uieditfield( hGL, 'FontSize', cwave.FontSize, 'Editable', 'off' );
    
    hGL = uigridlayout( hGZ, [1 3], 'Padding', [0 0 0 0], 'ColumnWidth', {'fit',cwave.BtnWd,'1x'} );
    uilabel( hGL, 'Text', 'Distance trailing behind SUESI (m):' ...
        , 'FontSize', cwave.FontSize, 'HorizontalAlignment', 'right' );
    hTrailDist = uieditfield( hGL, 'numeric', 'Limits', [0 Inf], 'FontSize', cwave.FontSize ...
        , 'ValueDisplayFormat', '%.1f m' );
    
    hGL = uigridlayout( hGZ, [1 3], 'Padding', [0 0 0 0], 'ColumnWidth', {'fit','fit','1x'} );
    uilabel( hGL, 'Text', 'Get depth from device # (w=[n]):' ...
        , 'FontSize', cwave.FontSize, 'HorizontalAlignment', 'right' );
    sNoDevNo = "SUESI & CTET";
    hDevNo = uidropdown( hGL, 'FontSize', cwave.FontSize ...
        , 'Items', [sNoDevNo onerow( string( unique(oWave.tableVulcan.DeviceNo) ) )] );
    
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
    
    hGL = uigridlayout( hGZ, 'Padding', [0 0 0 0], 'RowHeight', {'1x'} ...
        , 'ColumnWidth', {'fit','1x'} );
    uilabel( hGL, 'Text', 'Binary data file:', 'FontSize', cwave.FontSize, 'HorizontalAlignment', 'right' );
    hBinFile = uidropdown( hGL, 'FontSize', cwave.FontSize ...
        , 'Items', [{''} onerow( oWave.cFiles_Bin )] );
    
    cRSPList = sort( getFileList( oWave.sDir_Calib, '*.rsp', 'NoTrace', 'NoPath' ) );
    hChList = uitable( 'Parent', hGZ, 'FontSize', cwave.FontSize ...
        , 'ColumnSortable', false, 'RowName', {} ...
        , 'ColumnName', {'Ch', 'Type', 'Orient', 'Tilt' ...
                        , 'Calibration', 'Dip Len', 'Gain'} ...
        , 'ColumnEditable', [false, true(1,6)] ...
        , 'ColumnFormat', {'numeric', 'char', 'numeric', 'numeric' ...
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
    
    % Make the figure visible
    hFig.Visible = true;
    hFig.CloseRequestFcn = @sub_Cancel;
    
    % Select the first row of the rx table (if any) and fill the entry fields
    iTblSelect = 1;
    sub_FillFields();
    
    % If there are no receivers, start with Add automatically
    if height( tblRxCfg ) == 0
        sub_AddRx();
    end
    
    % run the MODAL figure
    waitfor( hFig );
    return;

    %---------------------------------------------------------------------------
    % Track the uitable selection events because the stupid uitable class does
    % NOT give you a way to find out what is currently selected. How dumb is
    % that?
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
        [bOK,cErrMsg] = cwave.ValidateTowRxCfg( tblRxCfg, tblRxCh, oWave.sDir_Calib );
        if ~all(bOK)
            % Ensure there is a message (r.n. ValidateTowRxCfg always rtns one
            % if there's an error, but who knows what the future holds...)
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
            % and tedious and may even be done piecemeal as tow vehicles are
            % recovered. Allow that. cwave::TowedCSEM protects itself against
            % unfinished tableTowRxCfg info
            sBtn = uiconfirm( hFig, {
                'The towed receiver configurations are not complete.'
                sprintf( '%d of %d have incomplete info.', sum(~bOK), numel(bOK) )
                ['First error: ' cErrMsg{1}]
                ''
                'Do you want to save and return to WAVE anyway?'
                }, 'Save Anyway?', 'Options', {'Yes', 'Cancel'} );
            if ~strcmpi( sBtn, 'Yes' )
                return;
            end
        end
        
        % NB: Because reprocessing ALL csem can take time, I need to record
        % which RXs were deleted or changed. Then I remove these from the output
        % CSEM list so that the "Run New" on TowedCSEM will do them again.
        if ~isempty( oWave.cFiles_TowedCSEM )
            bDrop = false( height( oWave.cFiles_TowedCSEM ), 1 );
            
            % Look for deleted RXs
            bDel = ~ismember( oWave.tableTowRxCfg.RxName, tblRxCfg.RxName );
            if any( bDel )
                for i = reshape(find(bDel),1,[])
                    sPat = strcat( '_', oWave.tableTowRxCfg.RxName{i}, '.towedcsem.mat' );
                    bDrop = bDrop | contains( oWave.cFiles_TowedCSEM, sPat );
                end
            end
            
            % Look for changed RXs
            bDel = false(1,height(tblRxCfg));
            for iNew = 1:height(tblRxCfg)
                iOld = find( strcmpi( tblRxCfg.RxName{iNew}, oWave.tableTowRxCfg.RxName ), 1 );
                if isempty( iOld ) % ignore added RXs
                    continue;
                end
                if ~isequal( tblRxCfg(iNew,:), oWave.tableTowRxCfg(iOld,:) )
                    bDel(iNew) = true;
                else
                    bChNew = strcmpi( tblRxCfg.RxName(iNew), tblRxCh.RxName );
                    bChOld = strcmpi( tblRxCfg.RxName(iNew), oWave.tableTowRxCh.RxName );
                    bDel(iNew) = ~isequal( tblRxCh(bChNew,:), oWave.tableTowRxCh(bChOld,:) );
                end
            end
            if any( bDel )
                for i = reshape(find(bDel),1,[])
                    sPat = strcat( '_', tblRxCfg.RxName{i}, '.towedcsem.mat' );
                    bDrop = bDrop | contains( oWave.cFiles_TowedCSEM, sPat );
                end
            end
            
            % Make the changes
            if any( bDrop )
                oWave.cFiles_TowedCSEM(bDrop) = [];
            end
        end
        
        % If everything is OK, add to the log & update the main tables
        oWave.AddLog( cwave.LogOK, cwave.sLog_Towed_CSEM, 'User edited towed RX configurations' );
        oWave.tableTowRxCh     = tblRxCh;  % no listeners on this table
        oWave.tableTowRxCfg    = tblRxCfg; % listeners on this table
        
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
        tTheseCh = cwave.GetDfltFor( 'tableTowRxCh', cwave.MaxRxCh );
        tTheseCh.RxName(:)        = "";
        tTheseCh.ChanNo(:)        = 1:cwave.MaxRxCh;
        tTheseCh.Type(:)          = "";
        tTheseCh.CalibFile(:)     = "";
        tTheseCh.Orient(:)        = 0;
        tTheseCh.Tilt(:)          = 0;
        tTheseCh.DipLen(:)        = 1;
        tTheseCh.Gain(:)          = 1;
        
        if ~isempty( iTblSelect ) && between( 1, iTblSelect, height( tblRxCfg ) )
            iRow = iTblSelect;
            hRxName.Value   = tblRxCfg.RxName(iRow);
            if ismissing(tblRxCfg.DeviceNo(iRow))
                hDevNo.Value= sNoDevNo;
            else
                hDevNo.Value= string(tblRxCfg.DeviceNo(iRow));
            end
            hTrailDist.Value= tblRxCfg.TrailingDist(iRow);
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
            hBinFile.Value  = fullfile( tblRxCfg.BinPath(iRow), tblRxCfg.BinFile(iRow) );
            
            % Find all the channels for this receiver
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
            hDevNo.Value    = sNoDevNo;
            hTrailDist.Value= 0;
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
        % despite the fact that it is fine with 'string' types in tables that
        % are passed directly. However, if I pass a table in directly, then
        % 'ColumnFormat' is ignored. I use ColumnFormat for the list of known
        % calibration files so the user doesn't screw up those super-complicated
        % names.
        c = table2cell( tTheseCh(:,{'ChanNo', 'Type'...
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
            c(cellfun( @isempty, c(:,2) ),:) = [];
        end
        c = sortrows( c, 1 );   % Sort
        
        % Create the add table
        tCh                 = cwave.GetDfltFor( 'tableTowRxCh', size(c,1) );
        tCh.ChanNo(:)       = cell2mat( c(:,1) );
        tCh.Type(:)         = string(   c(:,2) );
        tCh.Orient(:)       = cell2mat( c(:,3) );
        tCh.Tilt(:)         = cell2mat( c(:,4) );
        tCh.CalibFile(:)    = string(   c(:,5) );
        tCh.DipLen(:)       = cell2mat( c(:,6) );
        tCh.Gain(:)         = cell2mat( c(:,7) );
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
        if strcmpi( hDevNo.Value, sNoDevNo )
            tblRxCfg.DeviceNo(iRow) = missing();
        else
            tblRxCfg.DeviceNo(iRow) = str2double( hDevNo.Value );
        end
        tblRxCfg.TrailingDist(iRow) = hTrailDist.Value;
        tblRxCfg.SyncTime(iRow)     = ...
            datetime( hSync(3).Value, hSync(1).Value, hSync(2).Value ...
                    , hSync(4).Value, hSync(5).Value, hSync(6).Value );
        tblRxCfg.SyncTag(iRow)      = hSync(7).Value;
        tblRxCfg.ShiftTime(iRow)    = ...
            datetime( hShift(3).Value, hShift(1).Value, hShift(2).Value ...
                    , hShift(4).Value, hShift(5).Value, hShift(6).Value );
        tblRxCfg.ShiftTag(iRow)     = hShift(7).Value;
        tblRxCfg.DriftRate(iRow)    = hDrift.Value;
        [tblRxCfg.BinPath(iRow), sF, sX] = fileparts( hBinFile.Value );
        tblRxCfg.BinFile(iRow)      = [sF sX];
        
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
        [bOK,cErrMsg] = cwave.ValidateTowRxCfg( tblRxCfg(iRow,:), tCh, oWave.sDir_Calib );
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
        tblRxCfg.TrailingDist(iAt)  = 1000;
        tblRxCfg.SyncTime(iAt)      = datetime('now') - days(1);    % just dummy something up
        tblRxCfg.SyncTag(iAt)       = 0.0;
        tblRxCfg.ShiftTime(iAt)     = datetime('now');
        tblRxCfg.ShiftTag(iAt)      = 0.0;
        tblRxCfg.DriftRate(iAt)     = 0;
        
        % Add default typical channel configurations
        tblRxCh = [tblRxCh
            sub_TypicalCh( tblRxCfg, iAt, 'Ex' )
            sub_TypicalCh( tblRxCfg, iAt, 'Ey' )
            sub_TypicalCh( tblRxCfg, iAt, 'Ez' )
            ];
        
        % Update the Rx list uitable
        c           = hRxList.Data;
        [b,cErr]    = cwave.ValidateTowRxCfg( tblRxCfg(iAt,:), tblRxCh(end-2:end,:), oWave.sDir_Calib );
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
        % NB: UIEditVars wants the validation function to throw an error
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
        tblRxCfg        = cwave.GetDfltFor( 'tableTowRxCfg' );
        tblRxCh         = cwave.GetDfltFor( 'tableTowRxCh' );
        if height(hRxList.StyleConfigurations) > 1 % Clear any previous row selection styling
            removeStyle( hRxList, 2 );
        end
        
        % Rebuild the rx list uitable
        hRxList.Data = sub_InitRxList( tblRxCfg, tblRxCh, oWave.sDir_Calib );
        iTblSelect   = 1;
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
    % User is editing sync and shift fields -- calculate drift rate
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
    % User has edit something in the channel table
    function sub_ChEdit(~,oChg)
        cChList = {'Ex','Ey','Ez','En'}; % towed Rx don't carry mags
        
        % Which column has been edited?
        switch( oChg.Indices(2) )
        case 2  % Channel type
            % For known types, enforce <upper><lower>
            if any( strcmpi( oChg.NewData, cChList ) )
                % NB: cannot change oChg.NewData. It is read-only
                hChList.Data{oChg.Indices(1),2} = [upper(oChg.NewData(1)) lower(oChg.NewData(2))];
            end
            
            % Special handling for vertical channels
            if strcmpi( oChg.NewData, 'Ez' )
                % Ez channels on SIO instruments are usually upside down
                % (electrically) and need a negative to flip them. Use the
                % amplifier gain since tilt is not used in the CSEM processing
                hChList.Data{oChg.Indices(1),3} = 0;    % orientation
                hChList.Data{oChg.Indices(1),4} = 90;   % tilt
                hChList.Data{oChg.Indices(1),6} = 1;    % dipole length
                hChList.Data{oChg.Indices(1),7} = -1;   % amplifier gain %%//%% true for Vulcans?
            elseif strcmpi( oChg.PreviousData, 'Ez' )
                % Was Ez now something else. Remove any negative from gain
                hChList.Data{oChg.Indices(1),7} = abs(hChList.Data{oChg.Indices(1),7});
            end
            
        case 5  % Calibration file
            % If the calibration selected contains _ch?_ where ? is the channel
            % number, then fill all the other non-empty calibration rows with
            % companions in the calibration set. (Standard SIO .rsp naming)
            sFindMe = sprintf( '_ch%d_', oChg.Indices(1) );
            if contains( oChg.NewData, sFindMe, 'IgnoreCase', true )
                for iCh = 1:cwave.MaxRxCh
                    if iCh == oChg.Indices(1) || ~isempty( hChList.Data{iCh,5} )
                        continue;
                    end
                    sNew = replace( oChg.NewData, sFindMe, sprintf( '_ch%d_', iCh ) );
                    if ismember( sNew, cRSPList )
                        hChList.Data{iCh,5} = sNew;
                        
                        % If the row doesn't have a channel type yet, assign it
                        % from the default standard list
                        if iCh <= numel(cChList) && isempty( hChList.Data{iCh,2} )
                            % NB: changing the uitable's data does NOT call the
                            % update function. Do that manually
                            hChList.Data{iCh,2} = cChList{iCh};
                            sub_ChEdit( [], struct( 'NewData', cChList{iCh} ...
                                , 'PreviousData', '', 'Indices', [iCh 2] ) );
                        end
                    end
                end
            end
        end
        return;
    end % sub_ChEdit
    
end % UITowRxCfg

%-------------------------------------------------------------------------------
% Return a tableTowRxCh row for an archetypical SIO towed receiver
function tOut = sub_TypicalCh( tblRxCfg, iWhich, sType )
    % Fill common fields
    tOut            = cwave.GetDfltFor( 'tableTowRxCh', 1 );
    tOut.RxName     = tblRxCfg.RxName(iWhich);
    tOut.Type       = string(sType);
    tOut.Gain       = 1;            % SIO instruments don't use amplifier gain
    tOut.CalibFile  = "";
    
    % Channel specific fields
    %
    % See doi: 10.1002/2015GC006174 for Mk1 & Mk2 dipole configurations
    switch( sType )
    case 'Ex'               % cross-wing
        tOut.ChanNo = 1;
        tOut.Orient = 90;
        tOut.Tilt   = 0;
        tOut.DipLen = 1;    % mk 1 = 2m, mk 2 = 1m
    case 'Ey'               % stinger through nose
        tOut.ChanNo = 2;
        tOut.Orient = 0;
        tOut.Tilt   = 0;
        tOut.DipLen = 2;
    case 'Ez'               % vertical fin
        tOut.ChanNo = 3;
        tOut.Orient = 0;
        tOut.Tilt   = 90;
        tOut.DipLen = 1;
    end
    
    return;
end % sub_TypicalCh

%-------------------------------------------------------------------------------
% Create the cell array that goes in the Rx List table
function cList = sub_InitRxList( tblRxCfg, tblRxCh, sCalibDir )
    if height( tblRxCfg ) == 0
        cList       = cell(0,3);
    else
        [b,cErr]    = cwave.ValidateTowRxCfg( tblRxCfg, tblRxCh, sCalibDir );
        cList       = num2cell( b );
        cList(:,2)  = {tblRxCfg.RxName{:}}; %#ok<CCAT1>
        cList(:,3)  = repmat({''},size(cList,1),1);
        if any(~b)
            cList(~b,3) = cErr(1);
        end
    end
    return;
end % sub_InitRxList
