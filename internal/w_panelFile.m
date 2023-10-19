classdef w_panelFile < w_panel
    % Class used inside WAVE to define a single "File List" panel in a workbench
    % tab. It is intentionally simple. This class mostly handles UI.
    %---------------------------------------------------------------------------
    % Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
    %---------------------------------------------------------------------------
    
    % immutable properties - only set in the constructor & never changed
    properties( SetAccess = immutable )
        sPropName       % oWave.(sPropName) cell array that keeps this file list
        cFiltSpec       % file filter spec as passed to uigetfile()
        sDfltPath       % default path for UIFileList
        fcnChk          % validation function (c.f. isFile_*.m)
        fcnPlot         % (opt) if given, called to Plot files
        
        hTable          % handle to the UI table with the file list
    end
    
    methods( Access = public )
        %-----------------------------------------------------------------------
        % Constructor
        % Params:
        %   tab         - the w_tab... object this panel lives on
        %   nLB         - [left bottom] position in hParent in PIXELS
        %   sLogType    - cwave.sLog_ for noting changes to the file list
        %   sTitle      - text to show in the top of the panel
        %   sPropName   - oWave.(sPropName) cell array of the file list
        %   cFiltSpec   - file filter spec to send to uigetfile()
        %   sDfltPath   - default path for Add button
        %   fcnChk      - handle of function to validate that each file is of 
        %                 the specified type (See e.g. isFile_MET.m)
        %   sViewType   - Perusal button to put up: 'Plot', 'View', 'Load', []
        %   fcnPlot     - if sViewType == 'Plot', this is the function to call 
        %                 when the 'Plot' button is pressed. Only called if the 
        %                 file list isn't empty
        %-----------------------------------------------------------------------
        function o = w_panelFile( tab, nLB, sLogType, sTitle ...
                                , sPropName, cFiltSpec, sDfltPath, fcnChk ...
                                , sViewType, fcnPlot )
            % Call the superclass constructor
            o@w_panel( tab, nLB, sLogType, sTitle );
            
            % Save params we need to persistently track
            o.sPropName     = sPropName;
            o.cFiltSpec     = cFiltSpec;
            o.sDfltPath     = sDfltPath;
            o.fcnChk        = fcnChk;
            
            % Add controls to the panel
            hG = uigridlayout( o.hPanel );
            hG.RowHeight    = {cwave.BtnHt,'1x'};
            hG.ColumnWidth  = {w_panel.BtnWd, w_panel.BtnWd, '1x', w_panel.BtnWd};
            hG.ColumnSpacing= 0;
            hG.RowSpacing   = 0;
            hG.Padding      = [5 5 5 5];
            
            uibutton( 'Parent', hG, 'FontSize', cwave.FontSize, 'Text', 'Add/Del' ...
                , 'Icon', w_IconLib('Pencil'), 'ButtonPushedFcn', @o.BtnSelect );
            if strcmpi( sViewType, 'Plot' )
                o.fcnPlot = fcnPlot;
                uibutton( 'Parent', hG, 'FontSize', cwave.FontSize, 'Text', 'Plot' ...
                    , 'Icon', w_IconLib('Plot'), 'ButtonPushedFcn', @o.BtnPlot );
            elseif strcmpi( sViewType, 'View' )
                uibutton( 'Parent', hG, 'FontSize', cwave.FontSize, 'Text', 'View' ...
                    , 'Icon', w_IconLib('View'), 'ButtonPushedFcn', @o.BtnView );
            elseif strcmpi( sViewType, 'Load' )
                uibutton( 'Parent', hG, 'FontSize', cwave.FontSize, 'Text', 'Load' ...
                    , 'Icon', w_IconLib('LoadMat'), 'ButtonPushedFcn', @o.BtnLoad );
            end
            h = uibutton( 'Parent', hG, 'FontSize', cwave.FontSize, 'Text', 'Reset' ...
                , 'Icon', w_IconLib('Eraser'), 'ButtonPushedFcn', @o.BtnReset );
            h.Layout.Column = 4;
            
            o.hTable = uitable( 'Parent', hG, 'FontSize', cwave.FontSize - 2 ...
                , 'ColumnName', {'OK','File','Path'} ...
                , 'ColumnFormat', {'logical','char','char'} ...
                , 'ColumnWidth', { 35, 'auto', 'auto' } ...
                , 'ColumnSortable', true ...
                , 'RowName', {} ...
                );
            o.hTable.Layout.Column = [1 numel(hG.ColumnWidth)];
            
            % Set the list
            o.UpdateUI();
            
            % Create a listener to auto-update the UI if the source list changes
            addlistener( o.oWave, sPropName, 'PostSet', @(src,evt)o.UpdateUI() );
            
            return;
        end % object constructor
        
        %-----------------------------------------------------------------------
        % Set / change / clear the file list in the UI table
        function o = UpdateUI( o )
            % Check all the files. Are they all good?
            cList       = o.oWave.(o.sPropName);
            bValidate   = o.fcnChk( cList );
            
            % Update the panel title
            nBad = sum(~bValidate);
            if nBad > 0
                o.hPanel.Title  = [' ' o.sTitle ' (' num2str(nBad) ' of ' num2str(numel(cList)) ' are bad!) '];
                o.SetPanelState( cwave.LogError );
            else
                o.hPanel.Title  = [' ' o.sTitle ' (' num2str(numel(cList)) ') '];
                if isempty( cList )
                    o.SetPanelState( cwave.LogWarn );
                else
                    o.SetPanelState( cwave.LogOK );
                end
            end
            
            % Fill the uitable
            cData = cell(0,3);
            for i = 1:numel(cList)
                [p,f,e] = fileparts( cList{i} );
                cData{i,1} = bValidate(i);
                cData{i,2} = [f e];
                cData{i,3} = p;
            end
            o.hTable.Data = cData;
            
            % Color the bad files as errors
            removeStyle( o.hTable );
            if any( ~bValidate )
                addStyle( o.hTable, uistyle( 'FontColor', cwave.nClrError ) ...
                    , 'row', reshape( find( ~bValidate ), 1, [] ) );
                
                % Scroll to the first non-valid row.
                iBadRow = find( ~bValidate, 1, 'first' );
                scrollR2020b( o.hTable, 'row', iBadRow );
            end
            return;
        end % UpdateUI
        
        %-----------------------------------------------------------------------
        % Optional setup for some file lists that use isFile_FromTable() and the
        % ListFmts_GPS/Gyro/Winch/etc.m files to allow the user to extend the
        % supported formats on the fly.
        function EnableEditableFormats( o, sType )
            % Create the 3-line menu
            hBtn = o.MakeOptionsBtn();
            hMenu = hBtn.ContextMenu;
            uimenu( 'Parent', hMenu, 'Text', 'Customize File Formats...' ...
                , 'MenuSelectedFcn', @(~,~)o.CustomizeFormats(sType) );
            return;
        end % EnableEditableFormats
        
    end % public methods
    
    methods( Access = protected )
        %-----------------------------------------------------------------------
        % Button: Select - to add new items to the file list
        function BtnSelect( o, ~, ~ )   % obj, button handle, eventdata
            [bOK,cNewList] = UIFileList( o.sTitle, o.cFiltSpec, o.sDfltPath ...
                                       , o.oWave.(o.sPropName), o.oWave.hFig, true );
            if ~bOK % user cancel
                return;
            end
            
            % What has changed?
            cOldList = o.oWave.(o.sPropName);
            if isequal( cOldList, cNewList )
                return;
            end
            bDel = ~ismember( cOldList, cNewList );
            if any( bDel )
                for iLogMe = reshape( find( bDel ), 1, [] )
                    o.oWave.AddLog( cwave.LogOK, o.sLogType, ['Deleted: ' cOldList{iLogMe}] );
                end
            end
            bAdd = ~ismember( cNewList, cOldList );
            if any( bAdd )
                for iLogMe = reshape( find( bAdd ), 1, [] )
                    o.oWave.AddLog( cwave.LogOK, o.sLogType, ['Added: ' cNewList{iLogMe}] );
                end
            end
            
            % Make the change - will engage listeners
            o.oWave.(o.sPropName) = cNewList;
            o.UpdateUI();
            return;
        end % BtnSelect
        
        %-----------------------------------------------------------------------
        % Button: Reset - clear the file list
        function BtnReset( o, ~, ~ )   % obj, button handle, eventdata
            sBtn = uiconfirm( o.oWave.hFig ...
                , 'Clear all files from the list?', o.sTitle ...
                , 'Options', {'Yes', 'No'}, 'DefaultOption', 2 );
            if ~strcmpi( sBtn, 'Yes' )
                return;
            end
            
            % Log it
            o.oWave.ClearLogOfType( o.sLogType ); % Previous entries are irrelevant now. Remove them
            o.oWave.AddLog( cwave.LogOK, o.sLogType, 'User cleared the file list entirely.' );
            
            % Make the change - will engage listeners
            o.oWave.(o.sPropName) = cwave.GetDfltFor(o.sPropName);
            o.UpdateUI();
            return;
        end % BtnReset
        
        %-----------------------------------------------------------------------
        % Button: View - view the file as a text file
        function BtnView( o, ~, ~ )
            % If there's nothing to plot, state the obvious
            if isempty( o.oWave.(o.sPropName) )
                uialert( o.oWave.hFig, {
                    'The file list is empty.'
                    'There is nothing to view.'
                    }, o.sTitle, 'Icon', 'error' );
                return;
            end
            
            % Make the user pick one, then open it in MatLab's editor
            if numel(o.oWave.(o.sPropName)) == 1
                iFile = 1;
            else
                [iFile,bOK] = listdlg( 'ListString', o.oWave.(o.sPropName) ...
                    , 'ListSize', [400 300] ...
                    , 'Name', o.sTitle, 'PromptString', { ...
                    'Select a file to view in MatLab''s text editor.'
                    'NB: if the file is very large, it might take a'
                    'moment or two to load.'
                    }, 'SelectionMode', 'single', 'OKString', 'View' ...
                    );
                if ~bOK     % user cancel
                    return;
                end
            end
            
            % Edit the file
            if isfile( o.oWave.(o.sPropName){iFile} )
                edit( o.oWave.(o.sPropName){iFile} );
            else
                uialert( o.oWave.hFig, {
                    'The selected file does not exist.'
                    ' '
                    o.oWave.(o.sPropName){iFile}
                    }, o.sTitle, 'Icon', 'error' );
            end
            
            return;
        end % BtnView
        
        %-----------------------------------------------------------------------
        % Button: Load - load a matfile into the command space
        function BtnLoad( o, ~, ~ )
            % If there's nothing to plot, state the obvious
            if isempty( o.oWave.(o.sPropName) )
                uialert( o.oWave.hFig, {
                    'The file list is empty.'
                    'There is nothing to view.'
                    }, o.sTitle, 'Icon', 'error' );
                return;
            end
            
            % Make the user pick one, then load it into MatLab's cmd window
            if numel(o.oWave.(o.sPropName)) == 1
                iFile = 1;
            else
                [iFile,bOK] = listdlg( 'ListString', o.oWave.(o.sPropName) ...
                    , 'ListSize', [400 300] ...
                    , 'Name', o.sTitle, 'PromptString', { ...
                    'Select a file to load into MatLab''s command space.'
                    'NB: if the file is very large, it might take a'
                    'moment or two to load.'
                    }, 'SelectionMode', 'single', 'OKString', 'Load' ...
                    );
                if ~bOK     % user cancel
                    return;
                end
            end
            
            % Edit the file
            if isfile( o.oWave.(o.sPropName){iFile} )
                sCmd = ['load( ''' o.oWave.(o.sPropName){iFile} ''' );'];
                disp( sCmd );
                evalin( 'base', sCmd );
                evalin( 'base', 'whos' );   % show the user the variables list
            else
                uialert( o.oWave.hFig, {
                    'File does not exist:'
                    ''
                    o.oWave.(o.sPropName){iFile}
                    }, o.sTitle, 'Icon', 'error' );
            end
            
            return;
        end % BtnLoad
        
        %-----------------------------------------------------------------------
        % Button: Plot - display interactive plotting UI
        function BtnPlot( o, ~, ~ )
            % If there's nothing to plot, state the obvious
            if isempty( o.oWave.(o.sPropName) )
                uialert( o.oWave.hFig, {
                    'The file list is empty.'
                    'There is nothing to plot.'
                    }, o.sTitle, 'Icon', 'error' );
                return;
            end
            
            % Call the given plot function
            o.fcnPlot();
            
            return;
        end % BtnPlot
        
        %-----------------------------------------------------------------------
        % Run the UI that allows the user to customize the file formats this
        % particular panel will accept
        function CustomizeFormats( o, sType )
            % Setup variables the UI
            sMainFcn    = ['ListFmts_' sType];
            sFile       = which( sMainFcn );
            fcnList     = str2func( sMainFcn );
            tblListFrom = fcnList();
            tblMstrFrom = ListFmts_MASTER( sType );
            
            % NB: change the function handles from cell(fcn) into strings. This
            % requires changing the table format so that there are only char and
            % not cell column-types.
            %
            % NB: If the table format changes, also change ListFmts_Master.m
            %
            tblList = table( 'Size', [height(tblListFrom) 5] ...
                        , 'VariableNames', {'Name', 'HeaderLines', 'fcnTest', 'fcnRead', 'Example'} ...
                        , 'VariableTypes', {'string', 'double', 'string', 'string', 'string'} ...
                        );
            tblMaster = table( 'Size', [height(tblMstrFrom) 5] ...
                        , 'VariableNames', {'Name', 'HeaderLines', 'fcnTest', 'fcnRead', 'Example'} ...
                        , 'VariableTypes', {'string', 'double', 'string', 'string', 'string'} ...
                        );
            for iRow = 1:height( tblList )
                tblList.Name(iRow)          = tblListFrom.Name(iRow);
                tblList.HeaderLines(iRow)   = tblListFrom.HeaderLines(iRow);
                tblList.fcnTest(iRow)       = func2str( tblListFrom.fcnTest{iRow} );
                tblList.fcnRead(iRow)       = func2str( tblListFrom.fcnRead{iRow} );
                tblList.Example(iRow)       = tblListFrom.Example(iRow);
            end
            for iRow = 1:height( tblMaster )
                tblMaster.Name(iRow)        = tblMstrFrom.Name(iRow);
                tblMaster.HeaderLines(iRow) = tblMstrFrom.HeaderLines(iRow);
                tblMaster.fcnTest(iRow)     = func2str( tblMstrFrom.fcnTest{iRow} );
                tblMaster.fcnRead(iRow)     = func2str( tblMstrFrom.fcnRead{iRow} );
                tblMaster.Example(iRow)     = tblMstrFrom.Example(iRow);
            end
            clear tblListFrom tblMstrFrom
            
            % Launch the UI
            [bOK, tblList] = UITableEdit( tblList, o.oWave.hFig ...
                , ['Customize ' sType ' File Formats'] ...
                , [ 'INSTRUCTIONS: To customize the file formats available ' ...
                'you need to provide TWO functions. The first function "fcnTest" ' ...
                'must accept a single line of text and return T/F if that line ' ...
                'of text fits your file format [e.g. b = test' sType '_MET( sLine )]. ' ...
                'The 2nd function "fcnRead" must accept a cell array of path+files ' ...
                'and a handle to a uifigure, then return a table matching exactly ' ...
                'the format of the other test' sType '...().m routines. I HIGHLY ' ...
                'RECOMMEND YOU COPY EXISTING ROUTINES and modify them for your ' ...
                'new format. Please name your functions consistent with the other ' ...
                'functions already in the list. Contact davidgmyer@gmail.com if you need help.' ...
                ], @emb_Validate, @emb_Reset ...
                , {'Add'} ... can add a row; canNOT delete a row 
                );
            if ~bOK % If canceled, exit early
                return;
            end
            
            % Remove the ones that are in the master list. Only the on-the-fly,
            % not-yet-officially-approved formats are in the ListFmts_... files.
            % Also, by removing the master list, this keeps the user from
            % messing those up by accident. If you have a problem with this,
            % PLEASE CALL ME AND TELL ME ABOUT IT. Don't just change the base
            % code. That's rude.
            nDelRows = height( tblMaster );
            tblList(1:nDelRows,:) = [];
            
            % Re-write the program file
            sLines = readlines( sFile );    % read the entire text file in one go
            fid = fopen( sFile, 'w' );
            for iLn = 1:numel(sLines)       % write the file header
                fprintf( fid, '%s\n', sLines(iLn) );
                if strncmpi( sLines(iLn), '%%--%% START', 12 )
                    break;
                end
            end
            for iRow = 1:height(tblList)    % write the custom format list
                fprintf( fid, 'tblList(end+1,:) = {''%s'', %d, ' ...
                    , tblList.Name(iRow), tblList.HeaderLines(iRow) );
                if strncmp( tblList.fcnTest(iRow), '@', 1 )
                    fprintf( fid, '%s, ', tblList.fcnTest(iRow) );
                else
                    fprintf( fid, '@%s, ', tblList.fcnTest(iRow) );
                end
                if strncmp( tblList.fcnRead(iRow), '@', 1 )
                    fprintf( fid, '%s, ', tblList.fcnRead(iRow) );
                else
                    fprintf( fid, '@%s, ', tblList.fcnRead(iRow) );
                end
                fprintf( fid, '''%s''};\n', tblList.Example(iRow) );
            end
            for iLn = iLn:numel(sLines)     % skip until the "END" tag
                if strncmpi( sLines(iLn), '%%--%% END', 10 )
                    break;
                end
            end
            for iLn = iLn:numel(sLines)     % write the file footer
                fprintf( fid, '%s\n', sLines(iLn) );
            end
            fclose( fid );
            
            % Update the UI. This will re-run the validation with the new file
            % formats, which also lets the user see if their new stuff works.
            rehash();   % Force MatLab to reload the changes
            o.UpdateUI();
            
            return;
            
            %-------------------------------------------------------------------
            % UITableEdit "Reset" button handler
            function emb_Reset( hTable )
                hTable.Data = tblMaster;
            end
            
            %-------------------------------------------------------------------
            % UITableEdit "Validate" handler
            function [bOK,cErrMsg] = emb_Validate( tbl, ~, ~ )
                % Check each table's test function against the example. There's
                % no way to check the read function. Fingers crossed!
                bOK     = true(height(tbl),1);
                cErrMsg = {};
                for iChk = 1:height(tbl)
                    try
                        % All texts are required
                        mustBeNonzeroLengthText( tbl.Name(iChk) );
                        mustBeNonnegative( tbl.HeaderLines(iChk) );
                        mustBeNonzeroLengthText( tbl.fcnTest(iChk) );
                        mustBeNonzeroLengthText( tbl.fcnRead(iChk) );
                        mustBeNonzeroLengthText( tbl.Example(iChk) );
                        
                        % Check the test function against the given example
                        fcnTest = str2func( char( tbl.fcnTest(iChk) ) );
                        bTest = fcnTest( tbl.Example(iChk) );
                        
                    catch Me
                        sMsg = ['Row ' num2str(iChk) ':'];
                        if ~isempty(Me.identifier)
                            sMsg = [sMsg Me.identifier ':'];
                        end
                        sMsg = [sMsg Me.message];
                        cErrMsg{end+1,1} = sMsg;
                        bOK(iChk) = false;
                        continue;
                    end
                    
                    if ~bTest
                        cErrMsg{end+1,1} = sprintf( 'Row %d: fcnTest failed to validate the example you''ve given', iChk );
                        bOK(iChk) = false;
                    end
                end
                return;
            end
        end % CustomizeFormats
        
    end % protected methods
    
end % classdef w_panelFile
