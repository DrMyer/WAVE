classdef w_panelTable < w_panel
    % Class used inside WAVE to define a single "data table" panel for a uitab.
    % It is intentionally simple. This class mostly handles UI.
    %---------------------------------------------------------------------------
    % Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
    %---------------------------------------------------------------------------
    
    properties( Constant )
        MaxRows = 100;  % conserve memory by NOT loading entire huge tables in what is just a display
    end
    
    % immutable properties - only set in the constructor & never changed
    properties( SetAccess = immutable )
        sPropName       % oWave.(sPropName) table containing the data
        fcnEdit         % function for user-editing of the table
        fcnPlot         % plot function or [] (no plotting)
        fcnValid        % function to validate the table for coloring items as 
                        % "bad". If [], ignored.
        cPlotXY         % {'x','y',{uiaxes},{line}} field names (and name,value 
                        % pairs) for plotting in mini plot. If [], ignored.
        bPlotXY         % T if plotting is requested (convenience)
        
        hG              % gridlayout object
        hTable          % handle to the UI table showing the data
        hMiniAx         % handle of uiaxes for mini-plot
        hbtnEdit        % uibutton objects
        hbtnPlot
        hbtnShowTbl
        hbtnReset
    end
    
    methods( Access = public )
        %-----------------------------------------------------------------------
        % Constructor
        % Params:
        %   tab - the w_tab... object this panel lives on
        %   nLB - [left bottom] position in hParent in PIXELS
        %   sLogType - cwave.sLog_ type to use in the user log
        %   sTitle - text to show in the top of the panel
        %   sPropName - oWave.(sPropName) table object
        %   fcnEdit - fcn which launches user-edit dialog for this table
        %   fcnPlot - plot function or [] (no plotting)
        %   fcnReset - reset fcn, or 'ClearTable', or [] (no reset)
        %   fcnValid - bOK=fcnValid(table,hFig,bAsk) to validate table and color
        %           various lines red if invalid
        %   cPlotXY - {'xfield','yfield',{uiaxes},{line}} or []; for a uiaxis
        %           plot instead of just boring dat display. {uiaxes} and {line}
        %           are 'name','value' pairs for uiaxes and line properties.
        %-----------------------------------------------------------------------
        function o = w_panelTable( tab, nLB, sLogType, sTitle, sPropName ...
                                 , fcnEdit, fcnPlot, fcnReset, fcnValid, cPlotXY )
            % Call the superclass constructor
            o@w_panel( tab, nLB, sLogType, sTitle );
            
            if ~exist('cPlotXY','var')
                cPlotXY = [];
            end
            
            % Save params we need to persistently track
            o.sPropName = sPropName;
            o.fcnEdit   = fcnEdit;
            o.fcnPlot   = fcnPlot;
            o.fcnValid  = fcnValid;
            o.cPlotXY   = cPlotXY;
            o.bPlotXY   = ~isempty( cPlotXY );
            
            % Handle special case for 'Reset' button
            if ischar( fcnReset ) && strcmpi( fcnReset, 'ClearTable' )
                fcnReset = @o.BtnReset;
            end
            
            % If the table changes, hit the UI
            addlistener( o.oWave, sPropName, 'PostSet', @(src,evt)o.UpdateUI() );
            
            % Add controls to the panel
            hG = uigridlayout( o.hPanel );
            o.hG = hG;  % needed for uitable vs uiaxes toggle
            hG.RowHeight    = iif( o.bPlotXY, {cwave.BtnHt,0,'1x'}, {cwave.BtnHt,'1x',0} );
            hG.ColumnWidth  = {w_panel.BtnWd, w_panel.BtnWd, '1x', w_panel.BtnWd};
            hG.ColumnSpacing= 0;
            hG.RowSpacing   = 0;
            hG.Padding      = [5 5 5 5];
            
            if isa( fcnEdit, 'function_handle' )
                o.hbtnEdit = uibutton( 'Parent', hG, 'FontSize', cwave.FontSize, 'Text', 'Edit' ...
                    , 'Icon', w_IconLib('Pencil'), 'ButtonPushedFcn', o.fcnEdit );
            end
            if isa( fcnPlot, 'function_handle' )
                o.hbtnPlot = uibutton( 'Parent', hG, 'FontSize', cwave.FontSize, 'Text', 'Plot' ...
                    , 'Icon', w_IconLib('Plot'), 'ButtonPushedFcn', o.fcnPlot );
            end
            if o.bPlotXY
                % state button to toggle between uitable & uiaxes
                o.hbtnShowTbl = uibutton( hG, 'State', 'Text', '' ...
                    , 'Icon', w_IconLib('Table'), 'ValueChangedFcn', @o.TogglePlot ...
                    , 'Tooltip', 'Toggle between plot and table views' );
                o.hbtnShowTbl.Layout.Column = 3;
            end
            if isa( fcnReset, 'function_handle' )
                o.hbtnReset = uibutton( 'Parent', hG, 'FontSize', cwave.FontSize, 'Text', 'Reset' ...
                    , 'Icon', w_IconLib('Eraser'), 'ButtonPushedFcn', fcnReset );
                o.hbtnReset.Layout.Column = 4;
            end
            
            % UI table
            o.hTable = uitable( 'Parent', hG, 'FontSize', cwave.FontSize - 2 ...
                , 'ColumnName', o.oWave.(sPropName).Properties.VariableNames ...
                , 'ColumnSortable', true ...
                , 'RowName', {} ...
                , 'Data', head( o.oWave.(sPropName), w_panelTable.MaxRows ) ...
                );
            o.hTable.Layout.Row     = 2;
            o.hTable.Layout.Column  = [1 4];
            
            % ui plotting axis if this is preferred
            if o.bPlotXY
                o.hMiniAx = uiaxes( 'Parent', hG );
                o.hMiniAx.Layout.Row    = 3;
                o.hMiniAx.Layout.Column = [1 4];
            end
            
            % Create the hamburger menu with advanced options
            hBtn = o.MakeOptionsBtn();
            hMenu = hBtn.ContextMenu;
            uimenu( 'Parent', hMenu, 'Text', 'Save to text file', 'MenuSelectedFcn', @o.TextSave );
            uimenu( 'Parent', hMenu, 'Text', 'Edit text file', 'MenuSelectedFcn', @o.TextEdit );
            uimenu( 'Parent', hMenu, 'Text', 'Load from text file', 'MenuSelectedFcn', @(~,~)o.ReLoad('.txt') );
            uimenu( 'Parent', hMenu, 'Text', 'Save to .mat file', 'MenuSelectedFcn', @o.MatSave, 'Separator', 'on' );
            uimenu( 'Parent', hMenu, 'Text', 'Read .mat file into command window', 'MenuSelectedFcn', @o.MatEdit );
            uimenu( 'Parent', hMenu, 'Text', 'Load from .mat file', 'MenuSelectedFcn', @(~,~)o.ReLoad('.mat') );
            return;
        end % object constructor
        
        %-----------------------------------------------------------------------
        % Set / change / clear the file list in the UI table
        function o = UpdateUI( o )
            % Fill the uitable
            table = o.oWave.(o.sPropName);
            if isempty( table )
                % Clear the display elements
                o.hTable.Data = cwave.GetDfltFor( o.sPropName );
                if o.bPlotXY
                    % Clear the plot axis
                    cla( o.hMiniAx );
                    
                    % Since the table is empty, showing a blank plot surface can
                    % be comfusing. Show an empty table instead
                    if ~o.hbtnShowTbl.Value
                        o.hbtnShowTbl.Value = true;
                        o.TogglePlot();
                    end
                end
                
                % Disable buttons
                % NB: Never disable the Edit button in case the user is allowed
                % to populate the table by hand (c.f. MET table)
                % o.hbtnEdit.Enable   = false;
                if ishandle( o.hbtnPlot )
                    o.hbtnPlot.Enable   = false;
                end
                if ishandle( o.hbtnReset )
                    o.hbtnReset.Enable  = false;
                end
                o.SetPanelState( cwave.LogWarn );
            else
                % Reset the uitable
                bWasEmpty           = isempty( o.hTable.Data );
                o.hTable.Data       = [];
                o.hTable.ColumnName = table.Properties.VariableNames;
                o.hTable.Data       = head( table, w_panelTable.MaxRows );
                
                % Replot the uiaxes
                if o.bPlotXY
                    hLn = plot( o.hMiniAx, table.(o.cPlotXY{1}), table.(o.cPlotXY{2}) ...
                        , 'Marker', '.', 'LineStyle', 'none' );
                    if numel(o.cPlotXY) >= 3
                        % custom axes properties
                        cNmVal = o.cPlotXY{3};
                        if ~isempty( cNmVal )
                            set( o.hMiniAx, cNmVal{:} );
                        end
                        
                        % custom line properties
                        if numel(o.cPlotXY) >= 4
                            cNmVal = o.cPlotXY{4};
                            if ~isempty( cNmVal )
                                set( hLn, cNmVal{:} );
                            end
                        end
                    end
                    set( o.hMiniAx, 'Box', 'on', 'XTickLabels', [], 'YTickLabels', [] );
                    axisTight( o.hMiniAx );
                    
                    % If the table was empty but isn't now, make sure the plot
                    % is shown to the user. It's more useful than the table.
                    if bWasEmpty && o.hbtnShowTbl.Value
                        o.hbtnShowTbl.Value = false;
                        o.TogglePlot();
                    end
                end
                
                % Enable buttons
                if ishandle( o.hbtnEdit )
                    o.hbtnEdit.Enable   = true;
                end
                if ishandle( o.hbtnPlot )
                    o.hbtnPlot.Enable   = true;
                end
                if ishandle( o.hbtnReset )
                    o.hbtnReset.Enable  = true;
                end
                
                % If a validation function was given, check rows and color those
                % that are considered invalid.
                if isa( o.fcnValid, 'function_handle' )
                    bOK = o.fcnValid( table, o.oWave.hFig, false );   % false = don't ask questions
                    removeStyle( o.hTable );
                    if any( ~bOK )
                        % NB: respect the "don't load more than X" max
                        iWhich = reshape( find( ~bOK ), 1, [] );
                        iWhich( iWhich > w_panelTable.MaxRows ) = [];
                        addStyle( o.hTable, uistyle( 'FontColor', cwave.nClrError ) ...
                            , 'row', iWhich );
                        if all( ~bOK )
                            o.SetPanelState( cwave.LogError );
                        else
                            o.SetPanelState( cwave.LogWarn );
                        end
                    else
                        o.SetPanelState( cwave.LogOK );
                    end
                else
                    o.SetPanelState( cwave.LogOK );
                end
            end
            return;
        end % UpdateUI
        
    end % public methods
    
    methods( Access = protected )
        
        %-----------------------------------------------------------------------
        % Button: Reset ('ClearTable' action) - reset the table to class dflt
        function BtnReset( o, ~, ~ )   % obj, button handle, eventdata
            sBtn = uiconfirm( o.oWave.hFig ...
                , 'Clear the data table?', o.sTitle ...
                , 'Options', {'Yes', 'No'}, 'DefaultOption', 2 );
            if ~strcmpi( sBtn, 'Yes' )
                return;
            end
            
            % Log it
            o.oWave.AddLog( cwave.LogOK, o.sLogType, 'User cleared the data table manually.' );
            
            % Make the change - will engage listeners
            o.oWave.(o.sPropName) = cwave.GetDfltFor(o.sPropName);
            o.UpdateUI();
            return;
        end % BtnReset
        
        %-----------------------------------------------------------------------
        % State Button: toggle between uitable & uiaxes showing
        function TogglePlot( o, ~, ~ )
            o.hG.RowHeight = iif( o.hbtnShowTbl.Value, {cwave.BtnHt,'1x',0}, {cwave.BtnHt,0,'1x'} );
            return;
        end % TogglePlot
        
        %-----------------------------------------------------------------------
        % Full path+filename for advanced editing
        function s = EditFile( o, sExt )
            s = fullfile( o.oWave.sEditDir, [o.sPropName sExt] );
            return;
        end % EditFile
        
        %-----------------------------------------------------------------------
        % Context menu: save table to text file
        function TextSave( o, ~, ~ )
            sFile = o.EditFile('.txt');
            
            % NB: Some tables take a LONG time to write out
            hProg = uiprogressdlg( o.oWave.hFig, 'Title', 'Advanced Editing' ...
                , 'Message', ['Writing to ' sFile], 'Indeterminate', 'on' );
            
            writetable( o.oWave.(o.sPropName), sFile, 'FileType', 'text' ...
                , 'QuoteStrings', true, 'Delimiter', ',' ...
                , 'WriteVariableNames', true, 'WriteMode', 'overwrite' ...
                );
            fprintf( 'Wrote %d lines to: %s\n', height(o.oWave.(o.sPropName)), sFile );
            stDir = dir( sFile );
            fprintf( 'File is %d bytes in size.\n', stDir(1).bytes );
            
            if isvalid( hProg )
                delete( hProg );
            end
            return;
        end % TextSave
        
        %-----------------------------------------------------------------------
        % Context menu: save table to .mat file
        function MatSave( o, ~, ~ )
            sFile = o.EditFile('.mat');
            
            % NB: Some tables take a LONG time to write out
            hProg = uiprogressdlg( o.oWave.hFig, 'Title', 'Advanced Editing' ...
                , 'Message', ['Writing to ' sFile], 'Indeterminate', 'on' );
            
            st.(o.sPropName) = o.oWave.(o.sPropName);
            save( sFile, '-struct', 'st' );
            fprintf( 'Wrote table "%s" with %d rows to: %s\n' ...
                , o.sPropName, height(o.oWave.(o.sPropName)), sFile );
            stDir = dir( sFile );
            fprintf( 'File is %d bytes in size.\n', stDir(1).bytes );
            
            if isvalid( hProg )
                delete( hProg );
            end
            return;
        end % MatSave
        
        %-----------------------------------------------------------------------
        % Context menu: edit text file
        function TextEdit( o, ~, ~ )
            sFile = o.EditFile('.txt');
            if isfile( sFile )
                % NB: if the file is really large, MatLab will fail to open it.
                % I don't know what that size is, just take a guess.
                stDir = dir( sFile );
                if stDir(1).bytes > 10000000
                    disp( sFile );
                    uialert( o.oWave.hFig, {
                        ['The text file for this table is really large. ' ...
                        'It is unlikely MatLab''s editor will load it ' ...
                        'properly. You might try your favorite text editor ' ...
                        'or, alternatively, saving it as a .mat file and ' ...
                        'loading that into MatLab''s command space.']
                        ''
                        ['The path + filename has been output to the command ' ...
                        'window for your convenience.']
                        }, 'Advanced Editing' );
                else
                    edit( sFile );
                end
            else
                uialert( o.oWave.hFig, {
                    'The text file for this table does not exist.'
                    'Did you save it first?'
                    }, 'Advanced Editing' );
            end
            return;
        end % TextEdit
        
        %-----------------------------------------------------------------------
        % Context menu: load mat file to command window
        function MatEdit( o, ~, ~ )
            sFile = o.EditFile('.mat');
            if isfile( sFile )
                evalin( 'base', ['load( ''' sFile ''' );'] );
                evalin( 'base', 'whos' );   % show the user the variables list
                disp( 'If you are unfamiliar with MatLab tables, see the help: <a href="matlab:doc table">table</a>' );
                disp( ['Try typing "summary( ' o.sPropName ' )" or "head( ' o.sPropName ' )"'] );
            else
                uialert( o.oWave.hFig, {
                    'The .mat file for this table does not exist.'
                    'Did you save it first?'
                    }, 'Advanced Editing' );
            end
            return;
        end % MatEdit
        
        %-----------------------------------------------------------------------
        % Context menu: load an edited .txt/.mat file
        function ReLoad( o, sExt )
            sFile = o.EditFile( sExt );
            if ~isfile( sFile )
                uialert( o.oWave.hFig, {
                    'The external file for this table does not exist.'
                    ''
                    ['Looking for: ' sFile]
                    ''
                    'Did you save it first?'
                    }, 'Advanced Editing' );
                return;
            end
            
            % If the current table is not empty and there are log events for it
            % which are NEWER than the file on disk, warn the user that it might
            % be outdated
            bConfirmed = false;
            if ~isempty( o.oWave.(o.sPropName) )
                cLog = o.oWave.GetLogOfType( o.sLogType );
                if ~isempty( cLog )
                    t = cell2table( cLog(:,cwave.colLog.Date), 'VariableNames', {'Date'} );
                    t = max( t.Date );
                    stDir = dir( sFile );
                    if t > stDir(1).date
                        sBtn = uiconfirm( o.oWave.hFig ...
                            , {[ 'The internal table contains newer information ' ...
                            'than the file on the disk. If you continue you will ' ...
                            'be overwriting newer data with older data.' ]
                            ''
                            'Do you want to continue?'
                            }, o.sTitle ...
                            , 'Options', {'Yes', 'No'}, 'DefaultOption', 2 );
                        if ~strcmpi( sBtn, 'Yes' )
                            return;
                        end
                        bConfirmed = true;
                    end
                end
            end
            
            % Otherwise, confirm that the user really wants to do this...
            if ~bConfirmed
                sBtn = uiconfirm( o.oWave.hFig ...
                    , {[ 'You are about to import data from the disk ' ...
                    'directly into an internal table. No validations of ' ...
                    'the data will be applied. If you''ve messed up the ' ...
                    'data in the file, then the data inside WAVE will become ' ...
                    'messed up too and the system might become unstable.' ]
                    ''
                    'This is an expert level action. Are you sure you know what you''re doing?'
                    ''
                    'Do you want to continue?'
                    }, o.sTitle ...
                    , 'Options', {'Yes', 'No'}, 'DefaultOption', 2 );
                if ~strcmpi( sBtn, 'Yes' )
                    return;
                end
            end
            
            % Read the table back in and verify that it has the same columnar
            % format as it is supposed to have
            hProg = uiprogressdlg( o.oWave.hFig, 'Title', 'Advanced Editing' ...
                , 'Message', ['Reading ' sFile], 'Indeterminate', 'on' );
            if strcmpi( sExt, '.txt' )
                % NB: 'string' types that are exported to text files get read
                % back in as cell arrays of char which will cause things to blow
                % up. Get the import options and set all the 'char' variables to
                % strings.
                optRead = detectImportOptions( sFile );
                optRead.ExtraColumnsRule = 'error';
                bChg    = strcmpi( optRead.VariableTypes, 'char' );
                if any( bChg )
                    optRead = setvartype( optRead, bChg, 'string' );
                end
                st.(o.sPropName) = readtable( sFile, optRead );
            else
                m = matfile( sFile );
                st.(o.sPropName) = m.(o.sPropName);
                clear m
            end
            if isvalid( hProg )
                delete( hProg );
            end
            cNames1 = o.oWave.(o.sPropName).Properties.VariableNames;
            cNames2 = st.(o.sPropName).Properties.VariableNames;
            if ~isequal( cNames1, cNames2 )
                disp( '--------------------------------------------------' );
                disp( 'ADVANCED IMPORT OF TABLE FROM FILE' );
                disp( ['Table: ' o.sPropName] );
                disp( ['File:  ' sFile] );
                disp( '--------------------------------------------------' );
                disp( 'VARIABLES the file should have:' );
                disp( reshape( cNames1, 1, [] ) );
                disp( '--------------------------------------------------' );
                disp( 'VARIABLES the file actually has:' );
                disp( reshape( cNames2, 1, [] ) );
                disp( '--------------------------------------------------' );
                uialert( o.oWave.hFig, {
                    'The external file does not have the correct column structure.'
                    ''
                    'Column names must be exactly the same and in exactly the same order.'
                    ''
                    'See output in the command window.'
                    }, 'Advanced Editing' );
                return;
            end
            
            % Log what the user is about to do. This can REALLY screw up
            % internals so it needs to go in as a warning.
            o.oWave.AddLog( cwave.LogWarn, o.sLogType ...
                , sprintf( 'Overwriting table "%s" from file "%s"', o.sPropName, sFile ) );
            o.oWave.AddLog( cwave.LogWarn, o.sLogType ...
                , sprintf( 'Existing table has %d rows. New table has %d rows.' ...
                , height(o.oWave.(o.sPropName)), height(st.(o.sPropName)) ) );
            
            % Update the internal table. This will fire off listeners
            o.oWave.(o.sPropName) = st.(o.sPropName);
            
            return;
        end % ReLoad
        
    end % protected methods
    
end % classdef w_panelTable
