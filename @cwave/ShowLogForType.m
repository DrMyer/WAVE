function ShowLogForType( o, sType )
% cwave:ShowLogForType( oWave, sType )
%
% cwave utility to show the log for a specific log type
%
% Parameters:
%   oWave - the controlling cwave instance
%   sType - type of log entry to show. If empty, shows entire log.
% Returns:
%-------------------------------------------------------------------------------
% Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
%-------------------------------------------------------------------------------

% Are there any log entries of this type?
if ~exist( 'sType', 'var' ) || isempty( sType )
    cSubsetLog  = o.cLog;
    sTitle      = 'Show All Log Entries';
    bAll        = true;
else
    cSubsetLog  = o.GetLogOfType( sType );
    sTitle      = ['Show Log Entries for "' sType '"'];
    bAll        = false;
    if isempty( cSubsetLog )
        uialert( o.hFig, ['There are no log entries of type "' sType '"'], 'Show Log' );
        return;
    end
end

% Construct the UI
hFig = uifigure( 'Name', sTitle ...
    , 'Visible', false, 'WindowStyle', 'modal', 'Resize', true ...
    , 'Units', 'pixels', 'Position', [1 1 1000 900] ...
    );
figCenter( o.hFig, hFig );
nLSz    = cwave.BtnHt - 4;  % make uilamps square & slightly smaller than btnht

hG = uigridlayout( hFig );
hG.RowHeight    = {cwave.BtnHt, '1x', cwave.BtnHt};
hG.ColumnWidth  = [{50}, repmat({nLSz, cwave.BtnWd},1,3), {'1x', cwave.BtnWd, cwave.BtnWd}];

uilabel( 'Parent', hG, 'Text', 'Show:', 'FontSize', 14 ...
    , 'HorizontalAlignment', 'right' );

hNLamp  = uilamp( 'Parent', hG, 'Enable', true, 'Color', cwave.nClrOK );
hNorm   = uibutton( hG, 'state', 'Text', 'Normal' ...
    , 'Value', 1, 'ValueChangedFcn', @sub_ChgOption, 'FontSize', 12 ...
    );

hWLamp  = uilamp( 'Parent', hG, 'Enable', true, 'Color', cwave.nClrWarn );
hWarn   = uibutton( hG, 'state', 'Text', 'Warnings' ...
    , 'Value', 1, 'ValueChangedFcn', @sub_ChgOption, 'FontSize', 12 ...
    );

hELamp  = uilamp( 'Parent', hG, 'Enable', true, 'Color', cwave.nClrError );
hError  = uibutton( hG, 'state', 'Text', 'Errors' ...
    , 'Value', 1, 'ValueChangedFcn', @sub_ChgOption, 'FontSize', 12 ...
    );

uilabel( 'Parent', hG, 'Text', '' ); % dummy fill gap
hEntire = uibutton( hG, 'state', 'Text', 'Entire Log' ...
    , 'Value', bAll, 'ValueChangedFcn', @sub_ChgOption ...
    , 'FontSize', 12, 'Visible', ~bAll ...
    );
uibutton( 'Parent', hG, 'FontSize', cwave.FontSize, 'Text', 'Save' ...
    , 'Icon', w_IconLib('Save'), 'ButtonPushedFcn', @sub_Save );

hTable = uitable( 'Parent', hG, 'FontSize', 12 ...
    , 'ColumnWidth', {120 140 60 1500} ...
    , 'ColumnSortable', true ...
    , 'ColumnEditable', false ...
    , 'RowName', {} ...
    );
hTable.Layout.Column = [1 numel( hG.ColumnWidth )];

h = uibutton( 'Parent', hG, 'Text', 'Close', 'FontSize', 12 ...
    , 'ButtonPushedFcn', @sub_Close );
h.Layout.Column = numel( hG.ColumnWidth );

% Fill the table
sub_ChgOption();

% Make the figure visible and run the MODAL figure
hFig.Visible = true;
hFig.CloseRequestFcn = @sub_Close;
waitfor( hFig );
return;

    %---------------------------------------------------------------------------
    function sub_Close(~,~)
        delete( hFig );
        return;
    end
    
    %---------------------------------------------------------------------------
    % Change to one of the options controlling *which* log entries display
    function sub_ChgOption(~,~)
        % Which log list - just this type or entire?
        if hEntire.Value
            cLog = o.cLog;
        else
            cLog = cSubsetLog;
        end
        
        % Make sure the appropriate lamps are on/off
        hNLamp.Enable = hNorm.Value;
        hWLamp.Enable = hWarn.Value;
        hELamp.Enable = hError.Value;
        
        % Remove by status
        nStat = cell2mat( cLog(:,cwave.colLog.Status) );
        bDrop = false(size(nStat));
        if ~hNorm.Value
            bDrop = bDrop | nStat == cwave.LogOK;
        end
        if ~hWarn.Value
            bDrop = bDrop | nStat == cwave.LogWarn;
        end
        if ~hError.Value
            bDrop = bDrop | nStat == cwave.LogError;
        end
        if all( bDrop )
            hTable.Data = {};
            return;
        end
        if any( bDrop )
            cLog(bDrop,:) = [];
            nStat(bDrop) = [];
        end
        
        % Prep for the uitable & put into the obj
        tbl = cell2table( cLog(:,[cwave.colLog.Type cwave.colLog.Date cwave.colLog.User cwave.colLog.Desc]) ...
            , 'VariableNames', {'Type', 'Date', 'User', 'Description'} );
        hTable.Data = tbl;
        
        % Color the warnings & errors
        removeStyle( hTable );
        b = (nStat == cwave.LogWarn);
        if any( b )
            addStyle( hTable, uistyle('FontColor',cwave.nClrWarn) ...
                , 'row', reshape( find( b ), 1, [] ) );
        end
        b = (nStat == cwave.LogError);
        if any( b )
            addStyle( hTable, uistyle('FontColor',cwave.nClrError) ...
                , 'row', reshape( find( b ), 1, [] ) );
        end
        
        return;
    end % sub_ChgOption
    
    %---------------------------------------------------------------------------
    % Save the log to a file of fixed name & location
    function sub_Save(~,~)
        sFile = fullfile( o.sLogDir, ['_Log_' o.sFileName '.txt'] );
        hProg = uiprogressdlg( hFig, 'Title', 'Save Event Log' ...
            , 'Message', ['Writing to ' sFile], 'Indeterminate', 'on' );
        
        % Convert the cell array to a table (for better writing)
        tbl = cell2table( o.cLog, 'VariableNames', fieldnames( cwave.colLog ) );
        tbl.Status = categorical( tbl.Status ...
            , [cwave.LogOK cwave.LogWarn cwave.LogError] ...
            , {'OK', 'Warning', 'Error'} );
        
        % Write
        writetable( tbl, sFile, 'FileType', 'text', 'WriteVariableNames', true ...
            , 'WriteMode', 'overwrite', 'Delimiter', ',', 'QuoteStrings', true );
        
        % Drop the progress dialog (if the user hasn't closed it already)
        if isvalid( hProg )
            delete( hProg );
        end
        
        % Tell the user what occurred. Also dump the filename to the command
        % window for easier reference once the msg is cleared
        disp( 'Wrote entire event log to the following file:' );
        disp( sFile );
        uialert( hFig, {
            'Wrote entire event log to the following file:'
            sFile
            }, 'Saved Event Log', 'Icon', 'info' );
        
        return;
    end % sub_Save
end % ShowLogForType
