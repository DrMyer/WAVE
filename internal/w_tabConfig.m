classdef w_tabConfig < w_tab
    % w_tabConfig( cwave, oTabGrp )
    %
    % Internal function to create the Config tab on the main workbench UI
    %
    % Parameters:
    %   cwave   - main cwave object
    %   oTabGrp - handle to the tab group object that this tab should live on
    %---------------------------------------------------------------------------
    % Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
    %---------------------------------------------------------------------------
    
    % Immutable properties are only set in the constructor & never changed
    properties( SetAccess = immutable, GetAccess = protected )
        % Pairs of edits and "good or bad" √ / X labels
        editFileName        % survey/project name (used for filename)
        lblFileName
        editDirMain         % main folder
        lblDirMain
        tblReqd             % uitable of required folders
        tblSugg             % uitable of suggested folders
        editDirCalib        % external / ref folder with calibrations
        lblDirCalib
        
        % UTM edit fields
        editUTMZone
        cmbUTMHemi
        cmbEllipsoid
        chkUTMLock
        
        % Misc Notes panel
        textNotes
        
        % Time-stamped Log panel
        editLog             % edit field for user entry
        tblLog              % time-stamped log table
        
    end % protected properties
    
    methods( Access = public )
        function o = w_tabConfig( oWave, oTabGrp )
            % Call the superclass constructor
            o@w_tab( oWave, oTabGrp, w_tab.sTabCfg );
            o.bUIMade = true;
            
            % Separate this tab into zones
            hZone = uigridlayout( 'Parent', o.hTab );
            hZone.RowHeight     = {'fit','fit','1x'};
            hZone.ColumnWidth   = {'fit','1x',cwave.BtnWd * 4};
            hZone.ColumnSpacing = 20;
            hZone.RowSpacing    = 20;
            hZone.Padding       = [10 10 10 20];
            
            %% ----- Project Configuration panel -----
            hPanel = uipanel( 'Parent', hZone, 'Title', 'Project Configuration' );
            hG = uigridlayout( 'Parent', hPanel ); % , 'Scrollable', true );
            hG.ColumnSpacing = 10;
            hG.RowSpacing    = 10;
            hG.Padding       = [10 10 10 10];
            hG.RowHeight     = {cwave.BtnHt, cwave.BtnHt, cwave.BtnHt, 6*cwave.BtnHt ...
                              , cwave.BtnHt, 6*cwave.BtnHt', cwave.BtnHt, cwave.BtnHt ...
                              , '1x'};
                % NB: final row needs to be '1x' or when the user makes the main
                % figure window smaller, the fields will be pushed up off the
                % top of the figure, along with the row of uitabgroup tabs.
                
            hG.ColumnWidth = {'fit', cwave.BtnWd * 3, cwave.BtnHt, cwave.BtnWd};
                % cols: text, '.\', edit, green √ or red X, action button
                % NB: using BtnHt instead of BtnWd in some places to make a
                % square-ish grid region
            
            sSlashDot = ['.' filesep()];    % filesep() is OS specific \ or /
            
            %-- Main project folder
            uilabel( 'Parent', hG, 'Text', 'Main project folder:' ...
                , 'FontSize', cwave.FontSize, 'HorizontalAlignment', 'right' );
            o.editDirMain = uieditfield( 'Parent', hG, 'FontSize', cwave.FontSize ...
                , 'ValueChangedFcn', @o.EditDirMain );
            o.lblDirMain = uilabel( 'Parent', hG, 'FontSize', cwave.FontSize+2, 'HorizontalAlignment', 'center' );
            uibutton( 'Parent', hG, 'Text', 'Select', 'Icon', w_IconLib( 'PickDir' ) ...
                , 'FontSize', cwave.FontSize, 'ButtonPushedFcn', @o.BtnDirMain );
            
            %-- Survey Name (i.e. Workbench filename)
            uilabel( 'Parent', hG, 'Text', 'Survey / Project name:' ...
                , 'FontSize', cwave.FontSize, 'HorizontalAlignment', 'right' );
            o.editFileName = uieditfield( 'Parent', hG, 'FontSize', cwave.FontSize ...
                , 'ValueChangedFcn', @o.EditFileName );
            o.lblFileName = uilabel( 'Parent', hG, 'FontSize', cwave.FontSize+2, 'HorizontalAlignment', 'center' );
            uilabel( 'Parent', hG, 'Text', '' );    % dummy-fill last column
            
            %-- Note about REQUIRED sub-folders
            h = uilabel( 'Parent', hG, 'Text', 'REQUIRED Sub-folders under the main folder:' ...
                , 'FontSize', cwave.FontSize, 'FontWeight', 'Bold' );
            h.Layout.Column = 2;
            h = uibutton( 'Parent', hG, 'Text', 'Create' ...
                , 'Icon', w_IconLib( 'Run' ) ...
                , 'FontSize', cwave.FontSize, 'FontWeight', 'bold' ...
                , 'ButtonPushedFcn', @o.BtnMakeReqdSubs ...
                );
            h.Layout.Column = [3 4];
            
            %-- uitable containing list of required folders
            o.tblReqd = uitable( 'Parent', hG, 'FontSize', cwave.FontSize - 2 ...
                , 'ColumnName', {'OK','Path','Description'} ...
                , 'ColumnFormat', {'char','char','char'} ...
                , 'ColumnWidth', { 35, 'auto', 'auto' } ...
                , 'ColumnEditable', false ...
                , 'ColumnSortable', false ...
                , 'Data', {
                ' ' [sSlashDot oWave.sDir_Plot]  'Plots created by Wave'
                ' ' [sSlashDot oWave.sDir_Suesi] 'SUESI processing output'
                ' ' [sSlashDot oWave.sDir_RxCfg] 'RX *.sp files'
                ' ' [sSlashDot oWave.sDir_CSEM]  'CSEM processing output'
                ' ' [sSlashDot oWave.sDir_Logs]  'Output text dumps'
                ' ' [sSlashDot oWave.sDir_Edit]  'Direct data editing (Advanced)'
                } );
            o.tblReqd.Layout.Column = [2 numel(hG.ColumnWidth)];
            
            %-- Note about SUGGESTED sub-folders
            h = uilabel( 'Parent', hG, 'Text', 'SUGGESTED sub-folders for survey data:' ...
                , 'FontSize', cwave.FontSize, 'FontWeight', 'Bold' );
            h.Layout.Column = 2;
            h = uibutton( 'Parent', hG, 'Text', 'Create' ...
                , 'Icon', w_IconLib( 'Run' ) ...
                , 'FontSize', cwave.FontSize, 'FontWeight', 'bold' ...
                , 'ButtonPushedFcn', @o.BtnMakeSuggSubs ...
                );
            h.Layout.Column = [3 4];
            
            %-- uitable containing list of SUGGESTED folders
            cSugg = cell(size(oWave.cSuggDir,1),3);
            for i = 1:size(cSugg,1)
                cSugg{i,1} = ' ';
                cSugg{i,2} = oWave.cSuggDir{i,1};
                cSugg{i,3} = oWave.cSuggDir{i,2};
            end
            o.tblSugg = uitable( 'Parent', hG, 'FontSize', cwave.FontSize - 2 ...
                , 'ColumnName', {'OK','Path','Description'} ...
                , 'ColumnFormat', {'char','char','char'} ...
                , 'ColumnWidth', { 35, 'auto', 'auto' } ...
                , 'ColumnEditable', false ...
                , 'ColumnSortable', false ...
                , 'Data', cSugg );
            o.tblSugg.Layout.Column = [2 numel(hG.ColumnWidth)];
            
            %-- Note about External folders
            h = uilabel( 'Parent', hG, 'Text', 'External / Reference folders:' ...
                , 'FontSize', cwave.FontSize, 'FontWeight', 'Bold' );
            h.Layout.Column = [2 numel(hG.ColumnWidth)];
            
            %-- Calibration folder
            uilabel( 'Parent', hG, 'Text', 'Calibration files folder:' ...
                , 'FontSize', cwave.FontSize, 'HorizontalAlignment', 'right' );
            o.editDirCalib = uieditfield( 'Parent', hG, 'FontSize', cwave.FontSize ...
                , 'ValueChangedFcn', @o.EditDirCalib );
            o.lblDirCalib = uilabel( 'Parent', hG, 'FontSize', cwave.FontSize+2, 'HorizontalAlignment', 'center' );
            uibutton( 'Parent', hG, 'Text', 'Select', 'Icon', w_IconLib( 'PickDir' ) ...
                , 'FontSize', cwave.FontSize, 'ButtonPushedFcn', @o.BtnDirCalib );
            
            %% ---------- UTM config panel ----------
            hPanel = uipanel( 'Parent', hZone, 'Title', 'UTM Configuration' );
            hPanel.Layout.Column = 1;
            hPanel.Layout.Row    = 2;
            
            hG = uigridlayout( 'Parent', hPanel );
            hG.ColumnSpacing = 10;
            hG.Padding       = [10 10 10 10];
            hG.RowHeight = {'1x'};
            hG.ColumnWidth = {'fit','1x'};
            
            uilabel( 'Parent', hG, 'HorizontalAlignment', 'center' ...
                , 'Text', { 
                'NB: The UTM zone & hemisphere will be set automatically any ' 
                'time lon,lat data are automatically converted to UTM inside WAVE. ' 
                'Notably this occurs in configuration or navigation of RX or TX.' 
                }, 'WordWrap', 'off', 'FontSize', cwave.FontSize );
            
            hG = uigridlayout( 'Parent', hG );
            hG.ColumnSpacing = 10;
            hG.RowSpacing    = 10;
            hG.Padding       = [0 0 0 0];
            hG.RowHeight = {cwave.BtnHt,cwave.BtnHt,cwave.BtnHt,cwave.BtnHt,'1x'};
                % NB: final row needs to be '1x' or when the user makes the main
                % figure window smaller, the fields will be pushed up off the
                % top of the figure, along with the row of uitabgroup tabs.
            hG.ColumnWidth = {'1x','fit'};
            
            uilabel( 'Parent', hG, 'Text', 'UTM Zone number:' ...
                , 'FontSize', cwave.FontSize, 'HorizontalAlignment', 'right' );
            o.editUTMZone = uieditfield( hG, 'numeric', 'Limits', [1 60] ...
                , 'RoundFractionalValues', 'on', 'FontSize', cwave.FontSize ...
                , 'ValueChangedFcn', @(~,~)o.sub_UpdtUTM );
            uilabel( 'Parent', hG, 'Text', 'UTM Hemisphere:' ...
                , 'FontSize', cwave.FontSize, 'HorizontalAlignment', 'right' );
            o.cmbUTMHemi = uidropdown( 'Parent', hG, 'FontSize', cwave.FontSize ...
                , 'Items', ["North","South"], 'Value', oWave.sUTMHemi ...
                , 'ValueChangedFcn', @(~,~)o.sub_UpdtUTM );
            uilabel( 'Parent', hG, 'Text', 'UTM Ellipsoid:' ...
                , 'FontSize', cwave.FontSize, 'HorizontalAlignment', 'right' );
            o.cmbEllipsoid = uidropdown( 'Parent', hG, 'FontSize', cwave.FontSize ...
                , 'Items', cwave.cEllList, 'Value', oWave.sEllipsoid ...
                , 'ValueChangedFcn', @(~,~)o.sub_UpdtUTM );
            o.chkUTMLock = uicheckbox( 'Parent', hG, 'FontSize', cwave.FontSize ...
                , 'Text', {'Lock UTM zone (i.e. don''t allow'
                           'imported Lat,Lon to change it)'} ...
                , 'Value', oWave.bUTMLock ...
                , 'ValueChangedFcn', @(~,~)o.sub_UpdtUTM );
            o.chkUTMLock.Layout.Column = [1 2];
            
            
            %% ---------- Free-form Notes & Time-stamped Log panels ----------
            hG               = uigridlayout( 'Parent', hZone );
            hG.Layout.Column = 2;
            hG.Layout.Row    = [1 2];
            hG.ColumnSpacing = 0;
            hG.RowSpacing    = 10;
            hG.Padding       = [0 0 0 0];
            hG.RowHeight     = {'1x', '1x'};
            hG.ColumnWidth   = {'1x'};
            
            hPanel = uipanel( 'Parent', hG, 'Title', 'Misc Notes' );
            o.textNotes = uitextarea( 'Parent', uigridlayout(hPanel,[1 1]) ...
                , 'FontName', 'Courier', 'FontSize', cwave.FontSize ...
                , 'ValueChangedFcn', @o.EditMiscNotes );
            
            hPanel          = uipanel( 'Parent', hG, 'Title', 'Time-stamped Log' );
            hGP             = uigridlayout( 'Parent', hPanel );
            hGP.RowHeight   = {cwave.BtnHt, '1x'};
            hGP.ColumnWidth = {'1x', cwave.BtnWd*1.5};
            
            o.editLog = uieditfield( 'Parent', hGP, 'FontSize', cwave.FontSize );
            uibutton( 'Parent', hGP, 'Text', 'Add TimeStamp' ...
                , 'FontSize', cwave.FontSize, 'ButtonPushedFcn', @o.BtnTimeStamp );
            o.tblLog = uitable( 'Parent', hGP, 'FontSize', cwave.FontSize - 2 ...
                , 'Data', oWave.tableStamp, 'ColumnSortable', true ...
                , 'ColumnWidth', {cwave.BtnWd*2, '1x'} );
            o.tblLog.Layout.Column = [1 2];
            
            
            %% -- Load all the data & set the "good" or "bad" indicators
            o.LoadUI();
            
            
            %% ---------- To-Do List panel ----------
            %-------------------------------------------------------------------
            % Create the tree control that will show the list of tabs & panels
            % and what the status of each one is. Pass the object off to the
            % cwave instance so that it can generate nodes for all the bits and
            % pieces that get created after this point in time
            %-------------------------------------------------------------------
            hPanel = uipanel( 'Parent', hZone, 'Title', 'To-Do List' );
            hPanel.Layout.Column = numel(hZone.ColumnWidth);
            hPanel.Layout.Row    = [1 2];
            
            hGTree              = uigridlayout( 'Parent', hPanel );
            hGTree.RowHeight    = {cwave.BtnHt,'1x'};
            hGTree.ColumnWidth  = {cwave.BtnWd,'1x',cwave.BtnWd};
            uibutton( 'Parent', hGTree, 'Text', 'Events' ...
                , 'Icon', w_IconLib( 'Log' ) ...
                , 'FontSize', cwave.FontSize, 'FontWeight', 'bold' ...
                , 'ButtonPushedFcn', @(~,~)oWave.ShowLogForType ...
                );
            uibutton( 'Parent', hGTree, 'Text', 'Make All Tabs' ...
                , 'FontSize', cwave.FontSize ...
                , 'ButtonPushedFcn', @(~,~)oWave.MakeAllTabs ...
                );
            uibutton( 'Parent', hGTree, 'Text', 'Go to Tab' ...
                , 'FontSize', cwave.FontSize, 'FontWeight', 'bold' ...
                , 'ButtonPushedFcn', @(~,~)o.GoToTreeNode ...
                );
            oWave.hTree = uitree( 'Parent', hGTree, 'FontSize', cwave.FontSize ...
                              , 'Multiselect', 'off' );
            oWave.hTree.Layout.Column = [1 numel(hGTree.ColumnWidth)];
            
            %----- Setup listeners to cascade changes down dependencies -----%
            addlistener( oWave, 'UTM_VarChg', @(~,~)o.Event_UpdateUTMVars() );
            
            return;
        end % constructor
        
        function MakeUI(~)
            % This tab's UI is always created in the constructor
        end
        
        %-----------------------------------------------------------------------
        % Load the UI from the main datastore
        function o = LoadUI( o )
            % Project name & main folders
            o.editFileName.Value    = o.oWave.sFileName;
            o.editDirMain.Value     = o.oWave.sDir_Main;
            
            % External folders
            o.editDirCalib.Value    = o.oWave.sDir_Calib;
            
            % UTM controls
            o.editUTMZone.Value     = o.oWave.nUTMZone;
            o.cmbUTMHemi.Value      = o.oWave.sUTMHemi;
            o.cmbEllipsoid.Value    = o.oWave.sEllipsoid;
            o.chkUTMLock.Value      = o.oWave.bUTMLock;
            
            % Freeform & time-stamped notes
            o.textNotes.Value       = o.oWave.sMiscNotes;
            o.tblLog.Data           = o.oWave.tableStamp;
            
            % Set the (in)valid mark next to each entry field
            o.SetMarks();
            o.EnablePanels();
            
            return;
        end % LoadUI
        
        %-----------------------------------------------------------------------
        function EnablePanels( o )
            sSet = iif( o.oWave.bUTMLock, 'off', 'on' );
            o.editUTMZone.Enable    = sSet;
            o.cmbUTMHemi.Enable     = sSet;
            o.cmbEllipsoid.Enable   = sSet;
            return;
        end % EnablePanels
        
        %-----------------------------------------------------------------------
        % Is the configuration complete enough for the rest of the UI to be
        % enabled for the user to work on stuff?
        function bOK = IsConfigComplete( o )
            bOK =  isequal( o.lblFileName.FontColor, cwave.nClrOK ) ...
                && o.DirOK( o.oWave.sDir_Main ) ...
                && o.DirOK( o.oWave.sLogDir ) ...
                && o.DirOK( o.oWave.sPlotDir ) ...
                && o.DirOK( o.oWave.sEditDir ) ...
                && o.DirOK( o.oWave.sSuesiDir ) ...
                && o.DirOK( o.oWave.sSPDir ) ...
                && o.DirOK( o.oWave.sCSEMDir ) ...
                && o.DirOK( o.oWave.sDir_Calib ) ...
                ;
            return;
        end % IsConfigComplete
        
    end % public methods
    
    
    methods( Access = protected )
        
        %-----------------------------------------------------------------------
        function b = DirOK( ~, sDir )
            b = ~isempty( sDir ) && isfolder( sDir );
            return;
        end
        
        %-----------------------------------------------------------------------
        % The UTM variables have changed - may be from editing here but can also
        % be from a conversion on some other tab. Update the edit fields.
        function Event_UpdateUTMVars( o )
            o.editUTMZone.Value     = o.oWave.nUTMZone;
            o.cmbUTMHemi.Value      = o.oWave.sUTMHemi;
            o.cmbEllipsoid.Value    = o.oWave.sEllipsoid;
            % NB: the "lock" value is ONLY set in this UI, not by things that
            % would send this event.
            return;
        end % Event_UpdateUTMVars
        
        %-----------------------------------------------------------------------
        % Set the OK/Invalid marks on all entries
        function o = SetMarks( o )
            o.MarkFileNameValid();
            o.MarkDirValid( o.editDirMain,  o.lblDirMain );
            o.MarkDirValid( o.editDirCalib,  o.lblDirCalib );
            
            sMainDir = o.editDirMain.Value;
            
            % Check the required sub-folders
            removeStyle( o.tblReqd );
            for i = 1:size(o.tblReqd.Data,1)
                if isfolder( fullfile( sMainDir, o.tblReqd.Data{i,2} ) )
                    o.tblReqd.Data{i,1} = cwave.CharChk;
                    oStyle = uistyle( 'FontColor', cwave.nClrOK, 'HorizontalAlignment', 'center' );
                else
                    o.tblReqd.Data{i,1} = cwave.CharCross;
                    oStyle = uistyle( 'FontColor', cwave.nClrError, 'HorizontalAlignment', 'center' );
                end
                addStyle( o.tblReqd, oStyle, 'cell', [i 1] );
            end
            
            % Check the suggested sub-folders
            sDataDir = fullfile( sMainDir, cwave.sSuggSub );
            removeStyle( o.tblSugg );
            for i = 1:size(o.tblSugg.Data,1)
                if isfolder( fullfile( sDataDir, o.tblSugg.Data{i,2} ) )
                    o.tblSugg.Data{i,1} = cwave.CharChk;
                    oStyle = uistyle( 'FontColor', cwave.nClrOK, 'HorizontalAlignment', 'center' );
                else
                    o.tblSugg.Data{i,1} = cwave.CharCross;
                    oStyle = uistyle( 'FontColor', cwave.nClrError, 'HorizontalAlignment', 'center' );
                end
                addStyle( o.tblSugg, oStyle, 'cell', [i 1] );
            end
            return;
        end % SetMarks
        
        %-----------------------------------------------------------------------
        % User has edited the filename / project name
        function EditFileName( o, ~, ~ )
            % Just make sure it doesn't have any invalid chars in it
            o.MarkFileNameValid();
            
            % Update the main class's obj data
            if ~strcmpi( o.oWave.sFileName, o.editFileName.Value )
                o.oWave.AddLog( cwave.LogOK, cwave.sLog_Cfg ...
                    , ['Project name chgd to: "' o.editFileName.Value ...
                       '"  from: "' o.oWave.sFileName '"'] );
                o.oWave.sFileName = o.editFileName.Value;
            end
            return;
        end % EditFileName
        
        %-----------------------------------------------------------------------
        % Button press on folder picker for the main folder 
        function BtnDirMain( o, ~, ~ )
            % Prompt
            s = uigetdir( o.editDirMain.Value, 'Select main project folder' );
            if isnumeric( s ) % user cancel
                return;
            end
            
            % Did it actually change? If not, return early
            if isequal( s, o.editDirMain.Value )
                return;
            end
            
            % Call the edit function and imitate the ValueChangedFcn call
            st = struct( 'Value', s, 'PreviousValue', o.editDirMain.Value );
            o.editDirMain.Value = s;
            EditDirMain( o, o.editDirMain, st );
            
            return;
        end % BtnDirMain
        
        %-----------------------------------------------------------------------
        % ValueChangedFcn - user is changing main folder 
        function EditDirMain( o, ~, oChg )
            % Common question / alert title
            sTitle = 'Create Primary Folder';
            
            % Trim away any spaces the user may have errantly entered
            o.editDirMain.Value = strtrim( o.editDirMain.Value );
            
            % If the folder doesn't exist, ask about creating it
            if ~isfolder( o.editDirMain.Value )
                sOpt = uiconfirm( o.oWave.hFig, {
                    'The entered folder does not exist.'
                    'Do you want to create it?'
                    ''
                    ['Folder: ' o.editDirMain.Value]
                    }, sTitle ...
                    , 'Icon', 'Question' ...
                    , 'Options', {'Yes', 'Cancel'} ...
                    );
                if ~strcmpi( sOpt, 'Yes' )
                    o.editDirMain.Value = oChg.PreviousValue; % restore old value
                    return;
                end
                
                % Create the folder. If fail, msg & restore old value
                [bOK,sMsg,sMsgID] = mkdir( o.editDirMain.Value );
                if ~bOK
                    uialert( o.oWave.hFig, {
                        'Unable to create the requested folder.'
                        'Restoring old value to the entry field.'
                        ''
                        ['Failed to create: ' o.editDirMain.Value]
                        ['Error ID: ' sMsgID]
                        ['Error: ' sMsg]
                        }, sTitle );
                    o.editDirMain.Value = oChg.PreviousValue; % restore old value
                    return;
                end
            end
            
            % Don't accept relative paths. Always get a full path
            stDir = dir( o.editDirMain.Value );
            o.editDirMain.Value = stDir(1).folder;
            
            % Committed to a change now. Log it.
            o.oWave.AddLog( cwave.LogOK, cwave.sLog_Cfg ...
                , ['Primary folder chgd to: "' o.editDirMain.Value ...
                   '"  from: "' o.oWave.sDir_Main '"'] );
            o.oWave.sDir_Main = o.editDirMain.Value;
            o.oWave.bChgd     = true;
            
            % If there are files in the old folder, tell the user that they have
            % to move that stuff themselves
            if isfolder( oChg.PreviousValue )
                stContents = dir( oChg.PreviousValue );
                if numel( stContents ) > 2 % ignore '.' and '..' entries
                    cMsg = {
                        'The old folder contains files and/or subfolders.'
                        'These will NOT be moved automatically.'
                        'If you want these in the new folder, you need'
                        'to move them yourself.'
                        ''
                        ['New Folder: ' o.editDirMain.Value]
                        ['Old Folder: ' oChg.PreviousValue]
                        sprintf( '---> Contains %d files', numel( stContents ) - 2 )
                        };
                    disp( cMsg );   % splash to command window
                    uialert( o.oWave.hFig, cMsg, sTitle, 'Icon', 'warning' );
                end
            end
            
            % If the project name is empty and there is a .wave.mat file in the
            % selected folder, automatically populate the project edit field
            if isempty( o.editFileName.Value )
                stDir = dir( fullfile( o.editDirMain.Value, '*.wave.mat' ) );
                if ~isempty( stDir )
                    % Call the edit function and imitate the ValueChangedFcn call
                    s  = strrep( stDir(1).name, '.wave.mat', '' );
                    st = struct( 'Value', s, 'PreviousValue', o.editFileName.Value );
                    o.editFileName.Value = s;
                    EditFileName( o, o.editFileName, st );
                end
            end
            
            % Update the statuses of all the UI elements. Sub-folders may now be
            % invalid or valid
            o.SetMarks();
            
            return;
        end % EditDirMain
        
        %-----------------------------------------------------------------------
        % Set the "is it valid" label next to the filename field
        function MarkFileNameValid( o )
            bOK = ~isempty( o.editFileName.Value );
            if bOK % are there invalid filename chars?
                sSafe = safeFileName( o.editFileName.Value, '*bogus*' );
                bOK = isequal( sSafe, o.editFileName.Value );
            end
            o.Mark( o.lblFileName, bOK );
            return;
        end % MarkFileNameValid
        
        %-----------------------------------------------------------------------
        % Set the "is it valid" label next to various folder fields
        function MarkDirValid( o, oEdit, oLbl )
            o.Mark( oLbl, ~isempty( oEdit.Value ) && isfolder( oEdit.Value ) );
            return;
        end % MarkDirValid
        
        %-----------------------------------------------------------------------
        % Set the √/X mark & color appropriately
        function Mark( ~, oLbl, bOK )
            if bOK
                oLbl.FontColor  = cwave.nClrOK;
                oLbl.Text       = cwave.CharChk;
            else
                oLbl.FontColor  = cwave.nClrError;
                oLbl.Text       = cwave.CharCross;
            end
        end % Mark
        
        %-----------------------------------------------------------------------
        % Make each of the REQUIRED sub-folders
        function BtnMakeReqdSubs( o, ~, ~ )
            % Walk through each sub-folder and attempt to create those that
            % don't exist. Change the status as we go.
            bOK = true;
            for i = 1:size( o.tblReqd.Data, 1 )
                bOK = bOK & o.MakeSubDir( o.tblReqd.Data{i,2}, o.tblReqd.Data{i,3}, false );
                if ~bOK
                    % NB: If one makedir fails, the others probably will too
                    break;
                end
            end
            
            % Set the OK/Invalid marks
            o.SetMarks();
            
            return;
        end % BtnMakeReqdSubs
        
        %-----------------------------------------------------------------------
        % Make each of the SUGGESTED sub-folders
        function BtnMakeSuggSubs( o, ~, ~ )
            % Walk through each sub-folder and attempt to create those that
            % don't exist. Change the status as we go.
            bOK = true;
            for i = 1:size( o.tblSugg.Data, 1 )
                bOK = bOK & o.MakeSubDir( o.tblSugg.Data{i,2}, o.tblSugg.Data{i,3}, true );
                if ~bOK
                    % NB: If one makedir fails, the others probably will too
                    break;
                end
            end
            
            % Set the OK/Invalid marks
            o.SetMarks();
            
            return;
        end % BtnMakeSuggSubs
        
        %-----------------------------------------------------------------------
        % Make a sub-folder of the main
        function bOK = MakeSubDir( o, sSub, sDesc, bData )
            % Empty is always a default failure without complaint
            bOK  = false;
            if isempty( sSub )
                return;
            end
            
            % If the main folder doesn't exist, don't continue
            if ~o.DirOK( o.oWave.sDir_Main )
                uialert( o.oWave.hFig, {
                    'There is no main project folder.'
                    'Cannot create sub-folders without a main folder.'
                    }, 'Create sub-folder' );
                return;
            end
            
            % If it doesn't exist, try to create it
            if bData
                sFull = fullfile( o.oWave.sDir_Main, cwave.sSuggSub, sSub );
            else
                sFull = fullfile( o.oWave.sDir_Main, sSub );
            end
            if o.DirOK( sFull )
                bOK = true;
            else
                % Attempt to make the folder
                [bOK,sMsg,sMsgID] = mkdir( sFull );
                if ~bOK
                    uialert( o.oWave.hFig, {
                        ['Unable to create "' sDesc '"']
                        ['Sub-folder:' sSub]
                        ''
                        ['Error ID: ' sMsgID]
                        ['Error: ' sMsg]
                        }, 'Create sub-folder' );
                end
            end
            
            return;
        end % MakeSubDir
        
        %-----------------------------------------------------------------------
        % Button press on folder picker for the calibration (.rsp) folder 
        function BtnDirCalib( o, ~, ~ )
            % Prompt
            s = uigetdir( o.editDirCalib.Value, 'Select calibration file folder' );
            if isnumeric( s ) % user cancel
                return;
            end
            
            % Did it actually change? If not, return early
            if isequal( s, o.editDirCalib.Value )
                return;
            end
            
            % Call the edit function and imitate the ValueChangedFcn call
            st = struct( 'Value', s, 'PreviousValue', o.editDirCalib.Value );
            o.editDirCalib.Value = s;
            EditDirCalib( o, o.editDirCalib, st );
            
            return;
        end % BtnDirMain
        
        %-----------------------------------------------------------------------
        function EditDirCalib( o, ~, ~ )
            % Common question / alert title
            sTitle = 'Select Calibration (.rsp) folder';
            
            % Trim away any spaces the user may have errantly entered
            o.editDirCalib.Value = strtrim( o.editDirCalib.Value );
            
            % If the folder doesn't exist, don't allow. Calibrations must be in
            % a pre-existing folder and there must be files there already.
            if ~isfolder( o.editDirCalib.Value ) ...
            || isempty( getFileList( o.editDirCalib.Value, '*.rsp', false ) )
                uialert( o.oWave.hFig, {
                    'The calibration folder does not exist or does not'
                    'contain *.rsp calibration files.'
                    ''
                    'Please point this WAVE project to a pre-existing'
                    'folder that contains the .rsp calibrations for'
                    'the receivers.'
                    ''
                    ['Invalid Folder: ' o.editDirCalib.Value]
                    }, sTitle );
                o.Mark( o.lblDirCalib, false );
                return;
            end
            
            % Don't accept relative paths. Always get a full path
            stDir = dir( o.editDirCalib.Value );
            o.editDirCalib.Value = stDir(1).folder;
            
            % Committed to a change now. Log it.
            if ~isequal( o.editDirCalib.Value, o.oWave.sDir_Calib )
                o.oWave.AddLog( cwave.LogOK, cwave.sLog_Cfg ...
                    , ['Calibration folder chgd to: "' o.editDirCalib.Value ...
                       '"  from: "' o.oWave.sDir_Calib '"'] );
                o.oWave.sDir_Calib = o.editDirCalib.Value;
                o.oWave.bChgd      = true;
            end
            
            % Update the status of this dir
            o.Mark( o.lblDirCalib, true );
            
            return;
        end % EditDirCalib
        
        %-----------------------------------------------------------------------
        % User has edited the free-form notes
        function EditMiscNotes( o, ~, ~ )
            o.oWave.sMiscNotes = o.textNotes.Value;
            o.oWave.bChgd = true;
            return;
        end % EditMiscNotes
        
        %-----------------------------------------------------------------------
        % User trying to add a time-stamped entry to the table
        function BtnTimeStamp( o, ~, ~ )
            sAdd = string( o.editLog.Value );
            if strlength( sAdd ) == 0
                uialert( o.oWave.hFig, {
                    'Enter text in the entry field, then add'
                    'it to the time-stamped log.'
                    }, 'Add to Time-stamped Log' );
                return;
            end
            
            o.oWave.tableStamp{end+1,:}  = missing();
            o.oWave.tableStamp.Time(end) = datetime('now');
            o.oWave.tableStamp.Log(end)  = sAdd;
            o.oWave.bChgd = true;
            
            o.tblLog.Data = o.oWave.tableStamp;
            
            return;
        end % BtnTimeStamp
        
        %-----------------------------------------------------------------------
        % Go to the tab that has the currently selected tree node
        function GoToTreeNode( o )
            oNode = o.oWave.hTree.SelectedNodes;
            if isempty( oNode )
                uialert( o.oWave.hFig, {
                    'First select a task in the to-do list,'
                    'then press the button to go to it.'
                    }, 'Go to Tab', 'Icon', 'info' );
                return;
            end
            if ~o.IsConfigComplete()
                uialert( o.oWave.hFig, {
                    'The configuration is not yet complete.'
                    'Cannot switch to another workflow tab.'
                    }, 'Go to Tab', 'Icon', 'info' );
                return;
            end
            if strcmpi( oNode.UserData, 'tab' )
                o.oWave.GoToTab( oNode.Text );
            else
                o.oWave.GoToTab( oNode.Parent.Text, oNode.Text );
            end
            return;
        end % GoToTreeNode
        
        %-----------------------------------------------------------------------
        % One of the UTM setup fields has changed
        function sub_UpdtUTM(o)
            o.oWave.SetUTMInfo( ...
                  o.editUTMZone.Value ...
                , o.cmbUTMHemi.Value ...
                , o.cmbEllipsoid.Value ...
                , logical( o.chkUTMLock.Value ) ...
                );
            o.EnablePanels();
            return;
        end % sub_UpdtUTM
        
    end % protected methods
    
end % w_tabConfig
