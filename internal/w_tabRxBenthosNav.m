classdef w_tabRxBenthosNav < w_tab
    % w_tabRxBenthosNav( cwave, oTabGrp )
    %
    % Class for the "RX Benthos Nav" tab of the WAVE project
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
        ptblGPS2Ducer   % table: GPS to transducer offset
        puiRxNav        % UI: UI nav settings
        ptblRxDrop      % table: RX Drop location & ping frequency list
        pfilePings      % filelist: Benthos pinger file(s)
        ptblVel         % table (of tables): Velocity Profiles over time
        ptblShipTS      % table: Ship Data time series (see Ship Data tab)
        plinkShipData   % link: Ship Data tab
        
        pactRxNav       % action: Nav RXs
        
        ptblRxNav       % table: Navigated RX locations
        
    end % protected properties
    
    methods( Access = public )
        function o = w_tabRxBenthosNav( oWave, oTabGrp )
            % Call the superclass constructor
            o@w_tab( oWave, oTabGrp, w_tab.sTabRxNav );
        end
        
        function MakeUI(o)
            o.bUIMade = true;
            oProg = uiprogressdlg( o.oWave.hFig ...
                , 'Title',  ['First time accessing tab: ' o.sTitle] ...
                , 'Message', 'Creating UI elements & filling with data ...' ...
                , 'Indeterminate', 'on' ); %#ok<NASGU>
            
            %----- Create & connect the workbench panels -----%
            cPosMap = o.GetPanelGrid( 4, 3 );
            
            o.ptblGPS2Ducer = w_panelTable( o, cPosMap{1,1} ...
                , cwave.sLog_GPS2Ducer, 'GPS to Transducer offset' ...
                , 'tableGPS2Ducer', @o.DucerEdit, [], 'ClearTable' ...
                , @cwave.ValidateGPS2Ducer, [] );
            o.puiRxNav = w_panelInput( o, cPosMap{1,2} ...
                , cwave.sLog_RxN_UI, 'User Config for RX Navigation' ...
                , 'RxNavTab_VarChg' ... event to trigger when variables chg
                , {'nRxNavMaxTWTT', 'nRxNavMaxRange', 'nRxNavTransDelay'} );
            
            o.ptblRxDrop = w_panelTable( o, cPosMap{2,1} ...
                , cwave.sLog_RxDrop, 'RX Drop Location & Frequency List' ...
                , 'tableRxDrop', @o.RxDropEdit, @(~,~)o.oWave.PlotRxDropMaps ...
                , 'ClearTable', @cwave.ValidateRxDrop ...
                , {'Longitude', 'Latitude', {'DataAspectRatio', [1 1 1]} } );
            
            o.pfilePings = w_panelFile( o, cPosMap{3,1} ...
                , cwave.sLog_RxPings, 'Benthos RX Ping files', 'cFiles_RxBenthos' ...
                , {'*', 'Benthos Ping Files'} ...
                , o.oWave.sSubBPings ...
                , @isFile_Benthos, 'View', [] ...
                );
            
            o.ptblVel = w_panelTable( o, cPosMap{4,1} ...
                , cwave.sLog_RxVProfile, 'Velocity Profiles over Time' ...
                , 'tableVProfile', @(~,~)o.oWave.UIVProfiles, @(~,~)o.oWave.PlotVelProfiles ...
                , @(~,~)o.oWave.VelProfReset, @cwave.ValidateVelProfile, [] );
            
            o.ptblShipTS = w_panelTable( o, cPosMap{4,2} ...
                , cwave.sLog_ShipData, 'Ship Data Time Series' ...
                , 'tableShipTS', [], @(~,~)o.oWave.PlotShipTS, [], [] ...
                , {'Time', 'Gyro'} );
            o.plinkShipData = w_panelLink( o, cPosMap{4,3} ...
                , w_tab.sTabShipData ...
                , {
                ['. Ship Data time series for gyroscopic heading. ' ...
                'Necessary to properly account for the offset between ' ...
                'the ship''s GPS mast and transducer head.'
                ]} );
            
            o.pactRxNav = w_panelAction( o, cPosMap{2,2} + w_panel.nHalfD ...
                , cwave.sLog_RxNavAction, 'Navigate Receivers' ...
                , @()o.oWave.RxNav, [], @o.ViewRxNavDumpLog ...
                , [
                'Use shipboard Benthos ping & reply info to navigate ' ...
                'seafloor nodal receivers.'
                ] );
            
            o.ptblRxNav = w_panelTable( o, cPosMap{2,3} + w_panel.nHalfD ...
                , cwave.sLog_RxTable, 'Navigated RX Locations' ...
                , 'tableRxNav', @o.RxNavEdit, @o.RxNavPlot ...
                , 'ClearTable', @cwave.ValidateRxNav ... 
                , {'Longitude', 'Latitude', {'DataAspectRatio', [1 1 1]} } );
            
            %----- Connect the various panels -----%
            o.ConnectV(  o.puiRxNav,        1, 1, o.pactRxNav, 1, 1 );
            o.ConnectH3( o.ptblGPS2Ducer,   1, 1, o.pactRxNav, 1, 1, 1/2 );
            o.ConnectH3( o.ptblRxDrop,      1, 1, o.pactRxNav, 1, 1, 1/2 );
            o.ConnectH3( o.pfilePings,      1, 1, o.pactRxNav, 1, 1, 1/2 );
            o.ConnectH3( o.ptblVel,         1, 1, o.pactRxNav, 1, 1, 1/2 );
            o.ConnectV(  o.pactRxNav,      1, 1, o.ptblShipTS, 1, 1, 'Up' );
            
            o.ConnectH(  o.ptblShipTS,      1, 1, o.plinkShipData, 1, 1, 'Left' );
            o.ConnectH(  o.pactRxNav,       1, 1, o.ptblRxNav, 1, 1 );
            
            %----- Setup listeners to cascade changes down dependencies -----%
            addlistener( o.oWave, 'RxNavTab_VarChg',             @(~,~)o.Event_UpdateRxCnts() );
            addlistener( o.oWave, 'tableGPS2Ducer',   'PostSet', @(~,~)o.Event_UpdateRxCnts() );
            addlistener( o.oWave, 'tableRxDrop',      'PostSet', @(~,~)o.Event_UpdateRxCnts() );
            addlistener( o.oWave, 'cFiles_RxBenthos', 'PostSet', @(~,~)o.Event_UpdateRxCnts() );
            addlistener( o.oWave, 'tableVProfile',    'PostSet', @(~,~)o.Event_UpdateRxCnts() );
            addlistener( o.oWave, 'tableShipTS',      'PostSet', @(~,~)o.Event_UpdateRxCnts() );
            addlistener( o.oWave, 'tableRxNav',       'PostSet', @(src,evt)o.EnablePanels() );
            
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
            o.ptblGPS2Ducer.UpdateUI();
            o.puiRxNav.UpdateUI();
            o.ptblRxDrop.UpdateUI();
            o.pfilePings.UpdateUI();
            o.ptblVel.UpdateUI();
            o.ptblShipTS.UpdateUI();
            
            o.pactRxNav.UpdateUI();
            
            o.ptblRxNav.UpdateUI();
            
            % En/Disable panels based on loaded data
            o.EnablePanels();
            
            return;
        end % LoadUI
        
        %-----------------------------------------------------------------------
        % En/disable panels based on whether their prereqs are ready
        function EnablePanels( o )
            o.pactRxNav.Enable( ...
                    o.puiRxNav.AllOK() ...
                && ~isempty( o.oWave.tableGPS2Ducer ) ...
                && ~isempty( o.oWave.tableRxDrop ) ...
                && ~isempty( o.oWave.cFiles_RxBenthos ) ...
                && ~isempty( o.oWave.tableVProfile ) ...
                && ~isempty( o.oWave.tableShipTS ) ...
                );
            o.ptblShipTS.Enable( ~isempty( o.oWave.tableShipTS ) );
            o.ptblRxNav.Enable( ~isempty( o.oWave.tableRxNav ) );
            return;
        end % EnablePanels
        
    end % public methods
    
    
    methods( Access = protected )
        
        %-----------------------------------------------------------------------
        % If any nav source data changes, full re-processing will be forced
        function Event_UpdateRxCnts( o )
            o.pactRxNav.UpdateUI(); % Update counts on panel
            o.EnablePanels();       % En/Disable panels appropriately
            return;
        end % Event_UpdateRxCnts
        
        %-----------------------------------------------------------------------
        % GPS-to-Transducer Offset panel - "Edit" UI
        function DucerEdit( o, ~, ~ )
            % Call the general table edit UI
            [bOK, tblNew] = UITableEdit( o.oWave.tableGPS2Ducer, o.oWave.hFig ...
                , 'GPS Mast to Transducer Offset', {
                ['Enter the distance in meters that a given transducer is ' ...
                'located away from the ship''s GPS mast when the ship is ' ...
                'pointed DUE NORTH. If the transducer is south or west enter negatives. ' ...
                'Enter the depth of the transducer BELOW THE SEA SURFACE, not ' ...
                'the height difference between the mast and transducer. If multiple ' ...
                'ships were used, enter the date & time range for each ship so ' ...
                'that the RX Nav can determine which offset to use for each ' ...
                'benthos data file.' ...
                ]}, @cwave.ValidateGPS2Ducer, @Ducer_Reset ...
                , {'Add', 'Delete'} ... Add Row & Del Row are allowed on this table
                );
            if ~bOK
                return;
            end
            
            % User updated the table. Log & update
            o.oWave.AddLog( cwave.LogOK, cwave.sLog_GPS2Ducer, 'User edited GPS to Transducer table.' );
            o.oWave.tableGPS2Ducer = tblNew;
            
            return;
            
            %-------------------------------------------------------------------
            % "Reset" function for UITableEdit call above
            function Ducer_Reset ( hTable )
                hTable.Data = cwave.GetDfltFor( 'tableGPS2Ducer' );
                return;
            end % Ducer_Reset 
        end % DucerEdit
        
        %-----------------------------------------------------------------------
        function RxNavEdit( o, ~, ~ )
            % Call the general table edit UI
            [bOK, tNew] = UITableEdit( o.oWave.tableRxNav, o.oWave.hFig ...
                , 'RX Benthos Navigation', {
                ['Receiver navigation is made by an automatic process and ' ...
                'should only be user edited with care.' ...
                ]}, @cwave.ValidateRxNav, @RxNav_Reset ...
                , {'Add', 'Delete'} ... Add Row & Del Row are allowed on this table
                );
            if ~bOK
                return;
            end
            
            % If the user updated E,N or Lat,Lon then we need to convert one to
            % the other to ensure they stay in sync. Look for changes and update
            % the other side of the pair
            if ~isempty( tNew )
                % Join the tables so I can compare E,N and Lon,Lat
                cVar = {'RxName','East','North','Longitude','Latitude'};
                tOld = o.oWave.tableRxNav;
                tChk = outerjoin( tOld, tNew, 'Keys', 'RxName', 'MergeKeys', true ...
                                , 'LeftVariables', cVar, 'RightVariables', cVar );
                
                % Did any Lon,Lat values change?
                bCalc = (tChk.Longitude_tOld ~= tChk.Longitude_tNew ...
                       | tChk.Latitude_tOld ~= tChk.Latitude_tNew);
                if any( bCalc )
                    bCalc = ismember( tNew.RxName, tChk.RxName(bCalc) );
                    if any( bCalc )
                        [nE,nN] = oWave.LonLat2UTM( cwave.sLog_RxTable ...
                            , tNew.Longitude(bCalc), tNew.Latitude(bCalc) );
                        tNew.East(bCalc)    = round( nE );
                        tNew.North(bCalc)   = round( nN );
                        o.oWave.AddLog( cwave.LogOK, cwave.sLog_RxTable ...
                            , sprintf( 'Updated %d E,N pairs from changes to Lon,Lat', sum(bCalc) ) );
                    end
                end
                
                % Did any E,N values change
                bCalc = (tChk.East_tOld ~= tChk.East_tNew ...
                       | tChk.North_tOld ~= tChk.North_tNew);
                if any( bCalc )
                    bCalc = ismember( tNew.RxName, tChk.RxName(bCalc) );
                    if any( bCalc )
                        [nLon,nLat] = oWave.UTM2LonLat( ...
                            tNew.East(bCalc), tNew.North(bCalc) );
                        tNew.Longitude(bCalc)   = round( nLon, 5 );
                        tNew.Latitude(bCalc)    = round( nLat, 5 );
                        o.oWave.AddLog( cwave.LogOK, cwave.sLog_RxTable ...
                            , sprintf( 'Updated %d Lon,Lat pairs from changes to E,N', sum(bCalc) ) );
                    end
                end
            end
            
            % User updated the table. Log & update
            o.oWave.AddLog( cwave.LogOK, cwave.sLog_RxTable, 'User edited RX Benthos Nav table.' );
            o.oWave.tableRxNav = tNew;
            
            return;
            
            %-------------------------------------------------------------------
            % "Reset" function for UITableEdit call above
            function RxNav_Reset( hTable )
                hTable.Data = cwave.GetDfltFor( 'tableRxNav' );
                return;
            end % Ducer_Reset 
        end % RxNavEdit
        
        %-----------------------------------------------------------------------
        function RxNavPlot( o, ~, ~ )
            % There are different ways to go here - the generic table plotting
            % routine and the specialized series of plots showing the navigation
            % data in detail complete with error ellipses. Which does the user
            % want?
            sBtn = uiconfirm( o.oWave.hFig, {
                'There are several different plotting options:'
                ''
                '1 - RX Maps including Drift'
                '2 - Generic plotting interface'
                ''
                'What would you like?'
                }, 'RX Nav Plots' ...
                , 'Options', {'1 - Maps', '2 - Generic', 'Cancel'} ...
                , 'DefaultOption', 1, 'CancelOption', 3 );
            
            switch( sBtn )
            case '1 - Maps'
                o.oWave.PlotRxNavDriftMap();
                o.oWave.PlotRxNavMaps();
            case '2 - Generic'
                UITablePlot( o.oWave.tableRxNav, 'East', 'North', o.oWave.hFig ...
                    , 'Plot RX Navigation Data', o.oWave.sPlotDir, o.oWave.sPlotSubtitle );
            otherwise
                return;
            end
            
            return;
        end % RxNavPlot
        
        %-----------------------------------------------------------------------
        function RxDropEdit( o, ~, ~ )
            % Call the general table edit UI
            [bOK, tblNew, sInFile] = UITableEdit( o.oWave.tableRxDrop, o.oWave.hFig ...
                , 'Receiver Drop Location & Pinger Frequency', {
                ['Create a table of receiver names, GPS drop locations, ' ...
                'and pinger frequencies to use with RX Benthos navigation.' ...
                ]}, @cwave.ValidateRxDrop, @RxDrop_Reset ...
                , {'Add', 'Delete', 'Import'} ...
                );
            if ~bOK
                return;
            end
            
            % User updated the table. Log & update
            if isempty( sInFile )
                o.oWave.AddLog( cwave.LogOK, cwave.sLog_RxDrop, 'User edited RX drop table.' );
            else
                o.oWave.AddLog( cwave.LogOK, cwave.sLog_RxDrop ...
                    , ['User IMPORTED RX drop table from: ' sInFile] );
            end
            o.oWave.tableRxDrop = tblNew;
            
            return;
            
            %-------------------------------------------------------------------
            % "Reset" function for UITableEdit call above
            function RxDrop_Reset ( hTable )
                hTable.Data = cwave.GetDfltFor( 'tableRxDrop' );
                return;
            end % RxDrop_Reset 
        end % RxDropEdit
        
        %-----------------------------------------------------------------------
        function ViewRxNavDumpLog( o, ~, ~ )
            sDump = fullfile( o.oWave.sLogDir, 'BenthosRxNav_Log.txt' );
            if isfile( sDump )
                edit( sDump );
            else
                uialert( o.oWave.hFig, {
                    'There is no dump log from the Benthos RX Nav'
                    'found in the log output folder: '
                    ''
                    ['     ' o.oWave.sLogDir]
                    ''
                    'Perhaps the process hasn''t been run yet?'
                    }, 'No Dump Logs', 'Icon', 'info' );
            end
            return;
        end % ViewRxNavDumpLog
    end % protected methods
    
end % w_tabRxBenthosNav
