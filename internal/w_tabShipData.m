classdef w_tabShipData < w_tab
    % w_tabShipData( cwave, oTabGrp )
    %
    % Class for the "Ship Data" tab of the WAVE project
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
        pfileGPS        % filelist: Ship GPS
        pfileWinch      % filelist: Ship winch wire-out
        pfileGyro       % filelist: Ship Gyrocompass
        
        pactMergeShip   % action: merge above into one time series
        
        ptblShipTS      % table: Ship Data time series
        plinkSuesi      % link: SUESI Logs
        
        pfileMET        % filelist: simple atm pressure
        pactMET         % action: process atm pressure files 
        ptblAvgPres     % table: avg'd atmospheric pressure (Valeport TARE)
        
        pfileSIOMET     % filelist: Meteorological files
        pactSIOMET      % action: process MET files into shipTS & avg atm pres
        
    end % protected properties
    
    methods( Access = public )
        function o = w_tabShipData( oWave, oTabGrp )
            % Call the superclass constructor
            o@w_tab( oWave, oTabGrp, w_tab.sTabShipData );
            return;
        end
        
        function MakeUI(o)
            o.bUIMade = true;
            oProg = uiprogressdlg( o.oWave.hFig ...
                , 'Title',  ['First time accessing tab: ' o.sTitle] ...
                , 'Message', 'Creating UI elements & filling with data ...' ...
                , 'Indeterminate', 'on' ); %#ok<NASGU>
            
            %----- Create & connect the workbench panels -----%
            cPosMap = o.GetPanelGrid( 4, 4 );
            
            %-- Ship disparate file lists --%
            % NB: MOST ship data will be processed this way
            o.pfileGPS = w_panelFile( o, cPosMap{1,1} ...
                , cwave.sLog_ShipGPS, 'Ship GPS Files', 'cFiles_ShipGPS' ...
                , {'*', 'Ship GPS Files'} ...
                , o.oWave.sSubShipGPS ...
                , @(c)isFile_FromTable(c,ListFmts_GPS()), 'View', [] ...
                );
            o.pfileGPS.EnableEditableFormats( 'GPS' );
            
            o.pfileGyro = w_panelFile( o, cPosMap{1,2} ...
                , cwave.sLog_ShipGyro, 'Ship GYRO Files', 'cFiles_Gyro' ...
                , {'*', 'Ship GYRO Files'} ...
                , o.oWave.sSubShipGyro ...
                , @(c)isFile_FromTable(c,ListFmts_Gyro()), 'View', [] ...
                );
            o.pfileGyro.EnableEditableFormats( 'Gyro' );
            
            % Put a help annotation pointing at the 3-line menu
            nPos = o.pfileGyro.Position();
            annotation( o.hTab, 'textarrow', 'String', {
                'Create customized or ship-specific'
                'import formats with this 3-line menu.'
                }, 'TextColor', 'b', 'TextEdgeColor', 'b', 'Color', 'b' ...
                , 'TextBackgroundColor', cwave.nClrBkgd ...
                , 'Interpreter', 'none', 'FontSize', cwave.FontSize ...
                , 'Units', 'pixels', 'HorizontalAlignment', 'center' ...
                , 'X', nPos(1)+nPos(3) + [w_panel.nSpcH 0] ...
                , 'Y', nPos(2)+nPos(4) - [10 10] ...
                );
            
            o.pfileWinch = w_panelFile( o, cPosMap{2,1} ...
                , cwave.sLog_ShipWinch, 'Ship Winch Files', 'cFiles_Winch' ...
                , {'*', 'Ship Winch Files'} ...
                , o.oWave.sSubShipWinch ...
                , @(c)isFile_FromTable(c,ListFmts_Winch()), 'View', [] ...
                );
            o.pfileWinch.EnableEditableFormats( 'Winch' );
            
            o.pactMergeShip = w_panelAction( o, cPosMap{2,2} ...
                , cwave.sLog_ShipData, 'Merge Ship Data' ...
                , @()o.oWave.MergeShipData, [], [] ...
                , [
                'Merge various shipboard data into a ship time series of ' ...
                'GPS, COG, and winch wire-out. These are required for the ' ...
                'proper navigation of all towfish using the iLBL method.'
                ] );
            
            o.ptblShipTS = w_panelTable( o, cPosMap{2,3} ...
                , cwave.sLog_ShipData, 'Ship Data Time Series' ...
                , 'tableShipTS', [], @(~,~)o.oWave.PlotShipTS, 'ClearTable', [] ...
                , {'Longitude', 'Latitude', {'DataAspectRatio', [1 1 1]} } );
            
            % Put a help annotation pointing at the 3-line menu
            nPos = o.ptblShipTS.Position();
            annotation( o.hTab, 'textarrow', 'String', {
                'The 3-line menu on data tables allows you'
                'to export & re-import so you can do more'
                'advanced data manipulation for the '
                'inevitable survey-specific weirdnesses.'
                }, 'TextColor', 'b', 'TextEdgeColor', 'b', 'Color', 'b' ...
                , 'TextBackgroundColor', cwave.nClrBkgd ...
                , 'Interpreter', 'none', 'FontSize', cwave.FontSize ...
                , 'Units', 'pixels', 'HorizontalAlignment', 'center' ...
                , 'X', nPos(1)+nPos(3) + [w_panel.nSpcH 0] ...
                , 'Y', nPos(2)+nPos(4) + [w_panel.nSpcV 0] ...
                );
            annotation( o.hTab, 'textarrow', 'String', {
                'The generic data plot UI also allows'
                'you to edit datasets so you can visually'
                'remove outliers or alter sets of values'
                'when things go wrong.'
                }, 'TextColor', 'b', 'TextEdgeColor', 'b', 'Color', 'b' ...
                , 'TextBackgroundColor', cwave.nClrBkgd ...
                , 'Interpreter', 'none', 'FontSize', cwave.FontSize ...
                , 'Units', 'pixels', 'HorizontalAlignment', 'center' ...
                , 'X', nPos(1)+cwave.BtnWd/2 + [20 10] ...
                , 'Y', nPos(2)+nPos(4) + [w_panel.nSpcV 0] ...
                );
            
            o.plinkSuesi = w_panelLink( o, cPosMap{2,4} + w_panel.nHalfD ...
                , w_tab.sTabSUESI ...
                , {
                '. Ship Data time series for GPS position, Wire-out, etc...'
                ' '
                '. Atmospheric pressure TARE value for Valeport processing'
                } );
            
            %-- Atm Pressure --%
            o.pfileMET = w_panelFile( o, cPosMap{3,1} ...
                , cwave.sLog_ShipWinch, 'Ship MET (atm pressure) Files', 'cFiles_MET' ...
                , {'*', 'Ship MET Files'} ...
                , o.oWave.sSubShipMET ...
                , @(c)isFile_FromTable(c,ListFmts_MET()), 'View', [] ...
                );
            o.pfileMET.EnableEditableFormats( 'MET' );
            
            o.pactMET= w_panelAction( o, cPosMap{3,2} ...
                , cwave.sLog_ProcMET, 'Process Atm Pressure' ...
                , @()o.oWave.ProcessMETFiles, [], [] ...
                , [
                'Process meteorological (MET) data to calculate an ' ...
                'average barometric pressure per day. This is used ' ...
                'for Valeport calibration.'
                ] );
            
            o.ptblAvgPres = w_panelTable( o, cPosMap{3,3} ...
                , cwave.sLog_AtmPres, 'Avg Atmospheric Pressure' ...
                , 'tableAtmPres', @(~,~)o.oWave.AtmPEdit, @(~,~)o.oWave.PlotAtmPressure ...
                , 'ClearTable', @cwave.ValidateAtmPTable, {'Date','Mean'} ...
                );
            
            %-- Revelle (SIO?) MET file processing --%
            % MET processing provides avg atm pressure for Valeport calibration
            % and, 2ndarily, back-fill files for GPS, Gyro, and/or Winch data
            % that the user doesn't have from the ship logs directly.
            %
            % NB: MET files only exist on a few of the SIO managed ships like
            % Revelle, Melville, New Horizon, Sproul. Maybe on Sally Ride, don't
            % know. 
            o.pfileSIOMET = w_panelFile( o, cPosMap{4,1}, cwave.sLog_ShipSIOMET ...
                , 'SIO (R/V Revelle) MET Files', 'cFiles_SIOMET' ...
                , {'*.met', 'MET Files';'*', 'All Files'} ...
                , o.oWave.sSubShipMET ...
                , @isFile_MET, 'Plot', @o.PlotSIOMET ...
                );
            o.pactSIOMET = w_panelAction( o, cPosMap{4,2} ...
                , cwave.sLog_ProcSIOMET, 'Process SIO MET Data' ...
                , @()o.oWave.ProcessSIOMETFiles, [], [] ...
                , [
                'Calculate avg barometric pressure per day for Valeport ' ...
                'calibration. Also provide backup GPS, Gyro, and Winch ' ...
                'wire-out files in case you don''t have those directly ' ...
                'from other ship log files.'
                ] );
            hBackfill = annotation( o.hTab, 'textbox', 'FontSize', cwave.FontSize ...
                , 'Units', 'pixels', 'Position', [cPosMap{4,3} w_panel.nWd w_panel.nHt] ...
                , 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle' ...
                , 'String', ['Back-fill file for GPS, Gyro, and/or Winch ' ...
                'data you don''t have from other ship log files.' ...
                ] );
            
            %----- Connect the various panels -----%
            o.ConnectH3( o.pfileGPS, 3, 3, o.pactMergeShip, 1, 1, 1/2 );
            o.ConnectV(  o.pfileGyro, 1, 1, o.pactMergeShip, 1, 1 );
            o.ConnectH(  o.pfileWinch, 1, 1, o.pactMergeShip, 1, 1 );
            o.ConnectH(  o.pactMergeShip, 1, 1, o.ptblShipTS, 1, 1 );
            o.ConnectH3( o.ptblShipTS, 1, 1, o.plinkSuesi, 1, 1, 1/2 );
            
            o.ConnectH(  o.pfileMET, 1, 1, o.pactMET, 1, 1 );
            o.ConnectH(  o.pactMET, 1, 2, o.ptblAvgPres, 1, 2 );
            o.ConnectH3( o.ptblAvgPres, 1, 1, o.plinkSuesi, 1, 1, 1/2 );
            
            o.ConnectH(  o.pfileSIOMET, 1, 1, o.pactSIOMET, 1, 1 );
            o.ConnectH(  o.pactSIOMET, 1, 1, hBackfill, 1, 1 );
            o.ConnectH3( o.pactSIOMET, 1, 1, o.ptblAvgPres, 2, 2, 1/2 );
            
            %----- Setup listeners to cascade changes down dependencies -----%
            addlistener( o.oWave, 'cFiles_MET',     'PostSet', @(~,~)o.Event_UpdateMETCnts() );
            addlistener( o.oWave, 'cFiles_SIOMET',  'PostSet', @(~,~)o.Event_UpdateSIOMETCnts() );
            addlistener( o.oWave, 'cFiles_ShipGPS', 'PostSet', @(~,~)o.Event_UpdateMergeCnts() );
            addlistener( o.oWave, 'cFiles_Winch',   'PostSet', @(~,~)o.Event_UpdateMergeCnts() );
            addlistener( o.oWave, 'cFiles_Gyro',    'PostSet', @(~,~)o.Event_UpdateMergeCnts() );
            addlistener( o.oWave, 'tableShipTS',    'PostSet', @(~,~)o.EnablePanels() );
            
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
            o.pfileGPS.UpdateUI();
            o.pfileGyro.UpdateUI();
            o.pfileWinch.UpdateUI();
            o.pactMergeShip.UpdateUI();
            o.ptblShipTS.UpdateUI();
            
            o.pfileMET.UpdateUI();
            o.pactMET.UpdateUI();
            o.ptblAvgPres.UpdateUI();
            
            o.pfileSIOMET.UpdateUI();
            o.pactSIOMET.UpdateUI();
            
            % En/Disable panels based on loaded data
            o.EnablePanels();
            
            return;
        end % LoadUI
        
        %-----------------------------------------------------------------------
        % En/disable panels based on whether their prereqs are ready
        function EnablePanels( o )
            o.pactMergeShip.Enable( ...
                   ~isempty( o.oWave.cFiles_ShipGPS ) ...
                && ~isempty( o.oWave.cFiles_Gyro ) ...
                && ~isempty( o.oWave.cFiles_Winch ) ...
                );
            o.pactMET.Enable( ~isempty( o.oWave.cFiles_MET ) );
            o.pactSIOMET.Enable( ~isempty( o.oWave.cFiles_SIOMET ) );
            o.ptblShipTS.Enable( ~isempty( o.oWave.tableShipTS ) );
            return;
        end % EnablePanels
        
    end % public methods
    
    
    methods( Access = protected )
        %-----------------------------------------------------------------------
        % listener for changes to the SIO MET file list
        function Event_UpdateSIOMETCnts( o )
            o.pactSIOMET.UpdateUI();    % Reset the log counts on the action panel
            o.EnablePanels();           % En/Disable panels appropriately
            return;
        end % Event_UpdateSIOMETCnts
        
        %-----------------------------------------------------------------------
        % listener for changes to the MET file list
        function Event_UpdateMETCnts( o )
            o.pactMET.UpdateUI();   % Reset the log counts on the action panel
            o.EnablePanels();       % En/Disable panels appropriately
            return;
        end % Event_UpdateMETCnts
        
        %-----------------------------------------------------------------------
        % Ship GPS or Winch file list has changed. Reset the "merge" events &
        % output table
        function Event_UpdateMergeCnts( o )
            o.pactMergeShip.UpdateUI(); % Reset the log counts on the action panel
            o.EnablePanels();           % En/Disable panels appropriately
            return;
        end % Event_UpdateMergeCnts
        
        %-----------------------------------------------------------------------
        % Allow user to select SIO MET file(s) and shunt them to the generic
        % table plotting utility
        function PlotSIOMET( o )
            if isempty( o.oWave.cFiles_SIOMET )
                uialert( o.oWave.hFig, {
                    'The MET file list is empty.'
                    'There is nothing to plot.'
                    }, 'Plot MET files', 'Icon', 'error' );
                return;
            end
            
            % Let the user select
            [iFile,bOK] = listdlg( 'ListString', o.oWave.cFiles_SIOMET ...
                , 'ListSize', [400 300] ...
                , 'Name', 'Plot MET files', 'PromptString', { ...
                'Select one or more MET files to plot together in'
                'the generic plotting utility. You will be able to'
                'select the X & Y values to plot interactively.'
                }, 'SelectionMode', 'multiple', 'OKString', 'Plot' ...
                );
            if ~bOK     % user cancel
                return;
            end
            
            % Read the MET files
            try
                [nMet,colMet] = readMET( o.oWave.cFiles_SIOMET(iFile), 'Quiet', o.oWave.hFig, 'UseNaNs' );
            catch Me
                % If there are variations in the file formats, then isFile_MET.m
                % and readMET.m need to be updated.
                o.oWave.AddLog( cwave.LogError, cwave.sLog_ProcSIOMET ...
                    , sprintf( 'Error in readMET.m. Invalid file?? %s %s', Me.identifier, Me.message ) ...
                    );
                return;
            end
            
            % Convert to a table & run plot UI
            tbl = MET2Table( nMet, colMet );
            
            % Pass off to the generic table plot routine with a suggestion about
            % which fields should be X & Y by default
            if ismember( 'Time', tbl.Properties.VariableNames )
                sX = 'Time';
            else
                sX = tbl.Properties.VariableNames{1};
            end
            if ismember( 'Barometric_Pressure', tbl.Properties.VariableNames )
                sY = 'Barometric_Pressure';
            else
                sY = tbl.Properties.VariableNames{2};
            end
            
            % Launch the generic table-plotting UI
            UITablePlot( tbl, sX, sY, o.oWave.hFig, 'Plot MET Data' ...
                , o.oWave.sPlotDir, o.oWave.sPlotSubtitle );
            
            return;
        end % PlotSIOMET
        
    end % protected methods
    
end % w_tabShipData
