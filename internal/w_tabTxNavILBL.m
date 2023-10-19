classdef w_tabTxNavILBL < w_tab
    % w_tabTxNavILBL( cwave, oTabGrp )
    %
    % Class for the "Tx Barracuda Nav" tab of the WAVE project
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
        pfileBLogs      % filelist: Barracuda GPS logs
        pactBParse      % action: Barracuda logs --> TS
        ptblBGPS        % table: Barracuda GPS time series
        ptblBCfg        % table: Barracuda Configurations
        ptblBenthos     % table: Benthos time series
        
        puiTxNav        % UI: iLBL nav parameters
        ptblVel         % table (of tables): Velocity Profiles over time
        
        plinks          % link: Ship data & SUESI tabs
        
        pactTxNav       % action: iLBL Nav
        
        ptblTxNav       % table: Tx Nav time series
        ptblTETNav      % table: CTET Nav time series
        
    end % protected properties
    
    methods( Access = public )
        function o = w_tabTxNavILBL( oWave, oTabGrp )
            % Call the superclass constructor
            o@w_tab( oWave, oTabGrp, w_tab.sTabiLBLNav );
        end
        
        function MakeUI(o)
            o.bUIMade = true;
            oProg = uiprogressdlg( o.oWave.hFig ...
                , 'Title',  ['First time accessing tab: ' o.sTitle] ...
                , 'Message', 'Creating UI elements & filling with data ...' ...
                , 'Indeterminate', 'on' ); %#ok<NASGU>
            
            %----- Create & connect the workbench panels -----%
            cPosMap = o.GetPanelGrid( 3, 4 );
            
            o.pfileBLogs = w_panelFile( o, cPosMap{1,1} ...
                , cwave.sLog_TxN_BLogs, 'Barracuda GPS Log files', 'cFiles_TxBLogs' ...
                , {'*', 'Barracuda log Files'} ...
                , o.oWave.sSubCuda ...
                , @isFile_BarracudaLog, 'View', [] ...
                );
            
            o.pactBParse = w_panelAction( o, cPosMap{2,1} ...
                , cwave.sLog_TxN_BParse, 'Parse Barracuda GPS Logs' ...
                , @()o.oWave.ParseBarracudaLogs, [], [] ...
                , [
                'Parse the raw barracuda text logs into a time ' ...
                'series of GPS locations per paravane.'
                ] );
            
            o.ptblBGPS = w_panelTable( o, cPosMap{2,2} ...
                , cwave.sLog_TxN_CudaTS, 'Barracuda GPS Time Series' ...
                , 'tableCudaGPS', [], @(~,~)o.oWave.PlotCudaGPS ...
                , 'ClearTable', [] ...
                , {'East', 'North', {'DataAspectRatio', [1 1 1]} } );
            
            o.puiTxNav = w_panelInput( o, cPosMap{1,2} ...
                , cwave.sLog_TxN_UI, 'User Config for TX Navigation' ...
                , 'TxNavLBLTab_VarChg' ... event to trigger when variables chg
                , {'nGPStoWireZeroN', 'nGPStoWireZeroE' ...
                    , 'nTxCtrOffset', 'nMinWireLBL' ...
                    , 'nMADfactor', 'nBPingLimit' ...
                    , 'nCNavNo', 'nCDist', 'nCListenFreq' ...
                } );
            
            o.ptblVel = w_panelTable( o, cPosMap{1,3} ...
                , cwave.sLog_RxVProfile, 'Velocity Profiles over Time' ...
                , 'tableVProfile', @(~,~)o.oWave.UIVProfiles, @(~,~)o.oWave.PlotVelProfiles ...
                , @(~,~)o.oWave.VelProfReset, @cwave.ValidateVelProfile, [] );
            
            o.ptblBCfg = w_panelTable( o, cPosMap{3,1} ...
                , cwave.sLog_TxN_CudaCfg, 'Barracuda Configurations' ...
                , 'tableCudaCfg', @(~,~)o.oWave.EditCudaCfg, @(~,~)o.oWave.PlotCudaCfg ...
                , 'ClearTable', @cwave.ValidateCudaCfg, [] );
            
            o.ptblBenthos = w_panelTable( o, cPosMap{3,2} ...
                , cwave.sLog_S_Benthos, 'SUESI Benthos Ping Time Series' ...
                , 'tableBenthos', [] ...
                , @(~,~)o.oWave.PlotBenthos ...
                , 'ClearTable', [] ...
                , {'Time', 'ReplyTWTT'} ...
                );
            
            o.plinks = w_panelLink( o, cPosMap{3,3} ...
                , w_tab.sTabShipData ...
                , '. Ship GPS, gyro, COG, wire-out' ...
                , w_tab.sTabSUESI ...
                , {
                '. SUESI & TET depth time series'
                '. Tow start-stop times'
                '. Benthos pings'
                } );
            
            o.pactTxNav = w_panelAction( o, cPosMap{2,3} ...
                , cwave.sLog_TxNavAction, 'Navigate Transmitter' ...
                , @()o.oWave.TxNav, [], [] ...
                , [
                'Inverted long baseline navigation of the transmitter ' ...
                'using ship location, wire-out, & acoustic ranging on ' ...
                'paravanes (barracudas) and a tail-end transponder (TET).'
                ] );
            
            o.ptblTxNav = w_panelTable( o, cPosMap{1,4} + w_panel.nHalfD ...
                , cwave.sLog_TxN_Table, 'TX Nav Time Series' ...
                , 'tableTxNav', @(~,~)o.oWave.TxNavEdit, @(~,~)o.oWave.PlotTxNav ...
                , 'ClearTable', @cwave.ValidateTxNav ...
                , {'East', 'North', {'DataAspectRatio', [1 1 1]} } );
            o.ptblTETNav = w_panelTable( o, cPosMap{2,4} + w_panel.nHalfD ...
                , cwave.sLog_TxN_CTET, 'CTET Nav Time Series' ...
                , 'tableCTET', [], @(~,~)o.oWave.PlotCTET ...
                , 'ClearTable', [] ...
                , {'East', 'North', {'DataAspectRatio', [1 1 1]} } );
            
            %----- Connect the various panels -----%
            o.ConnectV( o.pfileBLogs, 1, 1, o.pactBParse, 1, 1 );
            o.ConnectH( o.pactBParse, 1, 1, o.ptblBGPS, 1, 1 );
            o.ConnectV( o.pactBParse, 1, 3, o.ptblBCfg, 1, 3 );
            o.ConnectV3( o.ptblBGPS, 2, 3, o.ptblBCfg, 2, 3, 1/3 );
            o.ConnectV3( o.pactTxNav, 1, 1, o.ptblBCfg, 3, 3, 2/3, 'Up' );
            o.ConnectV3( o.pactTxNav, 1, 1, o.ptblBenthos, 1, 1, 2/3, 'Up' );
            o.ConnectH( o.ptblBGPS, 1, 1, o.pactTxNav, 1, 1 );
            o.ConnectV3( o.puiTxNav, 3, 3, o.pactTxNav, 1, 1, 1/2 );
            o.ConnectV( o.ptblVel, 1, 1, o.pactTxNav, 1, 1 );
            o.ConnectV( o.pactTxNav, 1, 1, o.plinks, 1, 1, 'Up' );
            o.ConnectH3( o.pactTxNav, 1, 1, o.ptblTxNav, 1, 1, 1/2 );
            o.ConnectH3( o.pactTxNav, 1, 1, o.ptblTETNav, 1, 1, 1/2 );
            
            %----- Setup listeners to cascade changes down dependencies -----%
            addlistener( o.oWave, 'TxNavLBLTab_VarChg',          @(~,~)o.Event_UpdateTxNavCnts() );
            addlistener( o.oWave, 'tableVProfile',    'PostSet', @(~,~)o.Event_UpdateTxNavCnts() );
            addlistener( o.oWave, 'tableBenthos',     'PostSet', @(~,~)o.Event_UpdateTxNavCnts() );
            addlistener( o.oWave, 'tableSDM',         'PostSet', @(~,~)o.Event_UpdateTxNavCnts() );
            addlistener( o.oWave, 'tableVulcan',      'PostSet', @(~,~)o.Event_UpdateTxNavCnts() );
            addlistener( o.oWave, 'tableTow',         'PostSet', @(~,~)o.Event_UpdateTxNavCnts() );
            addlistener( o.oWave, 'tableCudaGPS',     'PostSet', @(~,~)o.EnablePanels() );
            addlistener( o.oWave, 'cFiles_TxBLogs',   'PostSet', @(~,~)o.EnablePanels() );
            addlistener( o.oWave, 'tableTxNav',       'PostSet', @(~,~)o.EnablePanels() );
            addlistener( o.oWave, 'tableCTET',        'PostSet', @(~,~)o.EnablePanels() );
            addlistener( o.oWave, 'tableBenthos',     'PostSet', @(~,~)o.EnablePanels() );
            
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
            o.pfileBLogs.UpdateUI();
            o.pactBParse.UpdateUI();
            o.ptblBGPS.UpdateUI();
            o.ptblBCfg.UpdateUI();
            o.ptblBenthos.UpdateUI();
            
            o.puiTxNav.UpdateUI();
            o.ptblVel.UpdateUI();
            
            o.pactTxNav.UpdateUI();
            
            o.ptblTxNav.UpdateUI();
            o.ptblTETNav.UpdateUI();
            
            % En/Disable panels based on loaded data
            o.EnablePanels();
            
            return;
        end % LoadUI
        
        %-----------------------------------------------------------------------
        % En/disable panels based on whether their prereqs are ready
        function EnablePanels( o )
            o.pactBParse.Enable( ...
                   ~isempty( o.oWave.cFiles_TxBLogs ) ...
                );
            o.pactTxNav.Enable( ...
                    o.puiTxNav.AllOK() ...
                && ~isempty( o.oWave.tableShipTS ) ...
                && ~isempty( o.oWave.tableTow ) ...
                && ~isempty( o.oWave.tableSDM ) ...
                && ~isempty( o.oWave.tableBenthos ) ...
                && ~isempty( o.oWave.tableVProfile ) ...
                && ~isempty( o.oWave.tableCudaGPS ) ...
                );
            o.ptblBenthos.Enable( ~isempty( o.oWave.tableBenthos ) );
            return;
        end % EnablePanels
        
    end % public methods
    
    
    methods( Access = protected )
        
        %-----------------------------------------------------------------------
        function Event_UpdateTxNavCnts( o )
            o.pactTxNav.UpdateUI(); % Reset the log counts on the action panel
            o.EnablePanels();       % En/Disable panels appropriately
            return;
        end % Event_UpdateTxNavCnts
        
    end % protected methods
    
end % w_tabTxNavILBL
