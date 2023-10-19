classdef w_tabSUESI < w_tab
    % w_tabSUESI( cwave, oTabGrp )
    %
    % Class for the "SUESI Logs" tab of the WAVE project
    %
    % Parameters:
    %   cwave   - main cwave object
    %   oTabGrp - handle to the tab group object that this tab should live on
    %---------------------------------------------------------------------------
    % Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
    %---------------------------------------------------------------------------
    
    % Workbench objects that display / select / process data
    properties( Access = protected )
        % Panels in the flowchart
        pfileSuesi      % filelist: SUESI raw logs
        pactSuesi       % action: logs --> parsed .mat files & SNAP files
        plinkWaveform   % link: Waveform tab
        pfileSuesiMat   % filelist: SUESI logs parsed into .mat files
        ptblSyncTimes   % table: sync timestamps for each sync event in each SUESI .mat file
        
        puiSuesi        % UI: SUESI processing values
        pactTimeSync    % action: apply sync times to SUESI .mat --> valeport profiles & SDM files
        ptblSDM         % table: SUESI SDM time series
        ptblTow         % table: Tow start/stop times & transmitter time lags
        ptblBenthos     % table: Benthos time series
        ptblValeport    % table: valeport depth profiles
        ptblVulcan      % table: towed device depths (vulcan & ctet)
        plinkLBLNav     % link: iLBL Barracuda Nav
        
        plinkShipData   % link: Ship Data tab
        ptblShipTS      % table: Ship Data Time Series
        ptblAvgPres     % table: avg'd Atmospheric pressure (Valeport TARE)
        
    end % protected properties
    
    methods( Access = public )
        function o = w_tabSUESI( oWave, oTabGrp )
            % Call the superclass constructor
            o@w_tab( oWave, oTabGrp, w_tab.sTabSUESI );
        end
        
        function MakeUI(o)
            o.bUIMade = true;
            oProg = uiprogressdlg( o.oWave.hFig ...
                , 'Title',  ['First time accessing tab: ' o.sTitle] ...
                , 'Message', 'Creating UI elements & filling with data ...' ...
                , 'Indeterminate', 'on' ); %#ok<NASGU>
            
            %----- Create & connect the workbench panels -----%
            cPosMap = o.GetPanelGrid( 4, 5 );
            
            %-- Misc Config UI --%
            o.puiSuesi = w_panelInput( o, cPosMap{1,3} + w_panel.nHalfD ...
                , cwave.sLog_S_UI, 'User Config for Processing' ...
                , 'SuesiTab_VarChg' ... event to trigger when variables chg
                , {'nTxDipLen', 'nFixSuesiCOG', 'sZBins' ...
                 , 'sLimitVVel', 'sLimitVTemp', 'sLimitVCond' } );
            
            %-- SUESI Log Parsing --%
            o.pfileSuesi = w_panelFile( o, cPosMap{1,1} ...
                , cwave.sLog_S_Files, 'SUESI Raw Log Files', 'cFiles_SUESIraw' ...
                , {'*','SUESI Raw Log Files'}...
                , o.oWave.sSubSuesi ...
                , @isFile_SUESILog, 'View' );
            o.pactSuesi = w_panelAction( o, cPosMap{2,1} ...
                , cwave.sLog_S_Decode ... 
                , 'Parse SUESI Raw Log Files' ...
                , @()o.oWave.ParseSUESILogs('All'), @()o.oWave.ParseSUESILogs('New') ...
                , @o.ShowSuesiDumps, [
                'Scan the SUESI log files and extract: (a) a time series of ' ...
                'source-dipole-moment, (b) waveform snapshots, and (c) valeport ' ...
                'information for depths profiles.' ...
                ] );
            
            o.plinkWaveform = w_panelLink( o, cPosMap{3,1} ...
                , w_tab.sTabWaveform ...
                , {
                'Waveform data from the SUESI log(s):'
                '. SNAP shots'
                '. Ideal waveform entry'
                } );
            
            o.pfileSuesiMat = w_panelFile( o, cPosMap{2,2} ...
                , cwave.sLog_S_Mat, 'SUESI Parsed .mat Files', 'cFiles_SUESImat' ...
                , {'*.mat','SUESI Parsed .mat Files';'*','All Files'} ...
                , o.oWave.sSuesiDir ... default path variable for "Add" button
                , @isFile_SUESIMat, 'Load' );
            o.ptblSyncTimes = w_panelTable( o, cPosMap{3,2} ...
                , cwave.sLog_S_STime, 'SUESI sync times' ...
                , 'tableSUESISync', @o.SyncEdit, [], @o.SyncReset, @cwave.ValidateSyncTable ...
                );
            o.pactTimeSync = w_panelAction( o, cPosMap{2,3} + w_panel.nHalfD ...
                , cwave.sLog_S_Sync ...
                , 'Sync Time & Merge Ship Data' ...
                , @()o.oWave.SyncSUESILogs, [], [] ...
                , [
                'Sync SUESI''s S= time with manually entered time stamps. ' ...
                'Merge with the ship data time series (GPS, wire-out, etc).' ...
                ] );
            
            o.ptblSDM = w_panelTable( o, cPosMap{1,4} ...
                , cwave.sLog_S_SDM, 'SDM Time Series' ...
                , 'tableSDM', [] ...
                , @(~,~)o.oWave.PlotSDM ...
                , 'ClearTable', [] ...
                , {'Time', 'SDM'} ...
                );
            
            o.ptblTow = w_panelTable( o, cPosMap{1,5} ...
                , cwave.sLog_TowTime, 'Tow Times & TX Time Lags' ...
                , 'tableTow', @(~,~)o.oWave.UITowTimes, @(~,~)o.oWave.PlotTowTimeChart ...
                , 'ClearTable', @cwave.ValidateTowTimes, [] ...
                );
            
            o.ptblVulcan = w_panelTable( o, cPosMap{2,4} ...
                , cwave.sLog_S_Vulcan, 'Vulcan/TET Depth Time Series' ...
                , 'tableVulcan', [] ... 
                , @(~,~)o.oWave.PlotVulcan ...
                , 'ClearTable', [] ... 
                , {'Time', 'Depth'} ...
                );
            o.ptblValeport = w_panelTable( o, cPosMap{3,4} ...
                , cwave.sLog_S_ValeP, 'Valeport Depth Profiles' ...
                , 'tableValeport', [], @(~,~)o.oWave.PlotValeport, 'ClearTable', [] ...
                , {'Conductivity','Depth',{'ydir','reverse'}} ...
                );
            o.ptblBenthos = w_panelTable( o, cPosMap{4,4} ...
                , cwave.sLog_S_Benthos, 'SUESI Benthos Ping Time Series' ...
                , 'tableBenthos', [] ...
                , @(~,~)o.oWave.PlotBenthos ...
                , 'ClearTable', [] ...
                , {'Time', 'ReplyTWTT'} ...
                );
            o.plinkLBLNav = w_panelLink( o, cPosMap{3,5} + w_panel.nHalfD ...
                , w_tab.sTabiLBLNav ...
                , {
                'SUESI log data for iLBL Nav:'
                '. Benthos pings to barracudas & TETs'
                '. Sound velocity vs depth profile'
                } );
            
            %-- Link from Ship Data --%
            o.plinkShipData = w_panelLink( o, cPosMap{4,1} ...
                , w_tab.sTabShipData ...
                , {
                ['. Avg atmospheric pressure from the ship''s meteorological ' ...
                'data for use as the tare when converting Valeport''s pressure to depth.']
                ' '
                '. Ship Data time series with GPS location and winch wire-out.'
                } );
            o.ptblShipTS = w_panelTable( o, cPosMap{4,2} ...
                , cwave.sLog_ShipData, 'Ship Data Time Series' ...
                , 'tableShipTS', [], @(~,~)o.oWave.PlotShipTS, 'ClearTable', [] ...
                , {'Longitude', 'Latitude', {'DataAspectRatio', [1 1 1]} } );
            o.ptblAvgPres = w_panelTable( o, cPosMap{4,3} ...
                , cwave.sLog_AtmPres, 'Avg Atmospheric Pressure' ...
                , 'tableAtmPres', @(~,~)o.oWave.AtmPEdit, @(~,~)o.oWave.PlotAtmPressure ...
                , 'ClearTable', @cwave.ValidateAtmPTable, {'Date', 'Mean'} ...
                );
            
            %----- Connect the various panels -----%
            o.ConnectV( o.pfileSuesi, 1, 1, o.pactSuesi, 1, 1 );
            o.ConnectV( o.pactSuesi, 1, 1, o.plinkWaveform, 1, 1 );
            o.ConnectH( o.pactSuesi, 1, 1, o.pfileSuesiMat, 1, 1 );
            
            o.ConnectV( o.pfileSuesiMat, 1, 1, o.ptblSyncTimes, 1, 1 );
            o.ConnectH3( o.pfileSuesiMat, 3, 3, o.pactTimeSync, 1, 1, 1/2 );
            o.ConnectH3( o.ptblSyncTimes, 1, 3, o.pactTimeSync, 1, 1, 1/2 );
            o.ConnectV( o.puiSuesi, 1, 1, o.pactTimeSync, 1, 1 );
            
            o.ConnectH3( o.pactTimeSync, 1, 1, o.ptblSDM, 3, 3, 1/2 );
            o.ConnectH3( o.pactTimeSync, 1, 1, o.ptblVulcan, 1, 1, 1/2 );
            o.ConnectH3( o.pactTimeSync, 1, 1, o.ptblBenthos, 1, 3, 1/2 );
            o.ConnectH3( o.pactTimeSync, 1, 1, o.ptblValeport, 1, 3, 1/2 );
            
            o.ConnectH( o.ptblSDM, 1, 1, o.ptblTow, 1, 1 );
            o.ConnectH3( o.ptblValeport, 3, 3, o.plinkLBLNav, 1, 1, 1/2 );
            o.ConnectH3( o.ptblBenthos,  1, 3, o.plinkLBLNav, 1, 1, 1/2 );
            
            o.ConnectH( o.plinkShipData, 1, 1, o.ptblShipTS, 1, 1 );
            o.ConnectV3( o.pactTimeSync, 1, 1, o.ptblShipTS, 3, 3, 3/2, 'Up', 1.25 );
            o.ConnectV( o.pactTimeSync, 1, 1, o.ptblAvgPres, 1, 1, 'Up' );
            
            %----- Setup listeners to cascade changes down dependencies -----%
            addlistener( o.oWave, 'tableSUESISync',   'PostSet', @(~,~)o.Event_UpdateSyncCnts() );
            addlistener( o.oWave, 'tableShipTS',      'PostSet', @(~,~)o.Event_UpdateSyncCnts() );
            addlistener( o.oWave, 'tableAtmPres',     'PostSet', @(~,~)o.Event_UpdateSyncCnts() );
            addlistener( o.oWave, 'SuesiTab_VarChg',             @(~,~)o.Event_UpdateSyncCnts() );
            addlistener( o.oWave, 'cFiles_SUESIraw',  'PostSet', @(~,~)o.EnablePanels() );
            addlistener( o.oWave, 'cFiles_SUESImat',  'PostSet', @(~,~)o.EnablePanels() );
            addlistener( o.oWave, 'tableSDM',         'PostSet', @(~,~)o.EnablePanels() );
            addlistener( o.oWave, 'tableBenthos',     'PostSet', @(~,~)o.EnablePanels() );
            addlistener( o.oWave, 'tableValeport',    'PostSet', @(~,~)o.EnablePanels() );
            addlistener( o.oWave, 'tableTow',         'PostSet', @(~,~)o.EnablePanels() );
            
            % Load the data in the panel. Will en/disable based on content
            o.LoadUI();
            drawnow();  % force UI to realize before progress bar deletes
            
            % Expand the to-do list tree
            expand( o.hTNode );
            
            return;
        end % MakeUI
        
        %-----------------------------------------------------------------------
        % Load the UI from the main datastore
        function o = LoadUI( o )
            if ~o.bUIMade
                return;
            end
            
            % Get each panel to load from the datastore
            o.pfileSuesi.UpdateUI();
            o.pactSuesi.UpdateUI();
            o.pfileSuesiMat.UpdateUI();
            o.ptblSyncTimes.UpdateUI();
            
            o.puiSuesi.UpdateUI();
            o.pactTimeSync.UpdateUI();
            o.ptblSDM.UpdateUI();
            o.ptblTow.UpdateUI();
            o.ptblBenthos.UpdateUI();
            o.ptblVulcan.UpdateUI();
            o.ptblValeport.UpdateUI();
            
            o.ptblShipTS.UpdateUI();
            o.ptblAvgPres.UpdateUI();
            
            % En/Disable panels based on loaded data
            o.EnablePanels();
            
            return;
        end % LoadUI
        
        %-----------------------------------------------------------------------
        % En/disable panels based on whether their prereqs are ready
        function EnablePanels( o )
            o.pactSuesi.Enable( ~isempty( o.oWave.cFiles_SUESIraw ) );
            o.ptblSyncTimes.Enable( ...
                ~isempty( o.oWave.cFiles_SUESImat ) ...
                );
            o.pactTimeSync.Enable( ...
                   ~isempty( o.oWave.tableAtmPres ) ...
                && ~isempty( o.oWave.tableShipTS ) ...
                && ~isempty( o.oWave.cFiles_SUESImat ) ...
                && ~isempty( o.oWave.tableSUESISync ) ...
                && ~all( isnat( o.oWave.tableSUESISync.SyncTime ) ) ...
                && o.puiSuesi.AllOK() ...
                );
            o.ptblShipTS.Enable( ~isempty( o.oWave.tableShipTS ) );
            o.ptblSDM.Enable( ~isempty( o.oWave.tableSDM ) );
            o.ptblVulcan.Enable( ~isempty( o.oWave.tableVulcan ) );
            o.ptblBenthos.Enable( ~isempty( o.oWave.tableBenthos ) );
            o.ptblValeport.Enable( ~isempty( o.oWave.tableValeport ) );
            
            return;
        end % EnablePanels
        
    end % public methods
    
    
    methods( Access = protected )
        
        %-----------------------------------------------------------------------
        % listener for several tables whose change invalidates SUESI sync
        function Event_UpdateSyncCnts( o )
            o.pactTimeSync.UpdateUI();  % Update counts on the panel
            o.EnablePanels();           % En/Disable panels appropriately
            return;
        end % Event_UpdateSyncCnts
        
        %-----------------------------------------------------------------------
        % Compile a list of text dump files associated with each input suesi log
        % and created by the decode process. Allow the user to open them in the
        % editor for viewing.
        function ShowSuesiDumps( o, ~, ~ )
            % The list of dump files is always made up on the fly by looking at
            % the list of raw SUESI logs then looking for files of the same name
            % with suffix "_Log.txt" in the dump directory.
            cRawList = o.oWave.cFiles_SUESIraw;
            cDumps   = {};
            for iFile = 1:numel(cRawList)
                [~,f] = fileparts( cRawList{iFile} );
                sDump = fullfile( o.oWave.sLogDir, [f '_Log.txt'] );
                if isfile( sDump )
                    cDumps{end+1} = sDump;
                end
            end
            
            % Are there any?
            if isempty( cDumps )
                uialert( o.oWave.hFig, {
                    'There are no text dump logs from SUESI processing'
                    'found in the log output folder: '
                    ''
                    ['     ' o.oWave.sLogDir]
                    ''
                    'NB: we only look for logs corresponding to files in'
                    'the SUESI raw log file list.'
                    }, 'No Dump Logs', 'Icon', 'info' );
                return;
            end
            
            % Show a list and let the user choose all the ones to open in the
            % MatLab editor
            if numel(cDumps) == 1
                iFile = 1;
            else
                [iFile,bOK] = listdlg( 'ListString', cDumps ...
                    , 'ListSize', [400 300] ...
                    , 'Name', 'View SUESI processing dump logs', 'PromptString', { ...
                    'Select one or more dump logs to view in MatLab''s text editor.'
                    'NB: if the files are very large, it might take a moment or two'
                    'to load each.'
                    }, 'SelectionMode', 'multiple', 'OKString', 'View' ...
                    );
                if ~bOK     % user cancel
                    return;
                end
            end
            
            % Edit the file(s)
            edit( cDumps{iFile} );
            
            return;
        end % ShowSuesiDumps
        
        %-----------------------------------------------------------------------
        % SUESI Sync-times table panel - "Edit" UI
        function SyncEdit( o, ~, ~ )
            % If the table is empty, do nothing because "Add row" is not allowed
            % for this table
            if isempty( o.oWave.tableSUESISync )
                uialert( o.oWave.hFig, {
                    'The sync table is empty.'
                    ''
                    'Process some SUESI raw log files first. Then this'
                    'table will be populated with all the groups of '
                    'synchronized SUESI data which need date+time '
                    'stamps.'
                    }, 'SUESI sync times', 'Icon', 'info' );
                return;
            end
            
            % Call the general table edit UI
            [bOK, table] = UITableEdit( o.oWave.tableSUESISync, o.oWave.hFig ...
                , 'SUESI GPS synch times', {
                ['Enter date & times that SUESI was synchronized with GPS. ' ...
                'These times are found in your paper log book (sigh) and ' ...
                'should have been written down every time SUESI was sync''d. ' ...
                'Note the number of output lines in each synchronization set ' ...
                'because sometimes multiple syncs are done in a row. You can leave ' ...
                'small sets of data as "NaT" to indicate they can be ignored.']
                }, @cwave.ValidateSyncTable, @Sync_Reset ...
                , {} ... Add Row & Del Row not allowed on this table
                ... BELOW are 'name','value' pairs passed directly to uitable
                , 'ColumnEditable', [false(1,5) true true false] ... editable: 'S_Sync', 'SyncTime'
                );
            if ~bOK
                return;
            end
            
            % User updated the table. Log & update
            o.oWave.AddLog( cwave.LogOK, cwave.sLog_S_STime, 'User edited sync times.' );
            o.oWave.tableSUESISync = table;
            
            return;
            
            %-------------------------------------------------------------------
            % "Reset" function for UITableEdit on tableSUESISync
            function Sync_Reset( hTable )
                hTable.Data(:,7) = {NaT};
                return;
            end % SEUI_Reset
        end % SyncEdit
        
        %-----------------------------------------------------------------------
        % SUESI Sync-times table panel - "reset" action
        function SyncReset( o, ~, ~ )
            if isempty( o.oWave.tableSUESISync )
                return;
            end
            sBtn = uiconfirm( o.oWave.hFig ...
                , 'Clear ALL Sync times?', o.ptblSyncTimes.sTitle ...
                , 'Options', {'Yes', 'No'}, 'DefaultOption', 2 );
            if ~strcmpi( sBtn, 'Yes' )
                return;
            end
            
            % Log it
            o.oWave.AddLog( cwave.LogOK, cwave.sLog_S_STime ...
                , 'User cleared all sync times.' );
            
            % Change the table - will engage listeners
            o.oWave.tableSUESISync.SyncTime(:) = NaT;
            
            return;
        end % SyncReset
        
    end % protected methods
    
end % w_tabSUESI
