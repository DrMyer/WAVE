classdef w_tabNodalCSEM < w_tab
    % w_tabNodalCSEM( cwave, oTabGrp )
    %
    % Class for the "Nodal CSEM" tab of the WAVE project
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
        plinkRxNav      % Link: Rx Nav tab
        plinkTxNav      % Link: USBL & iLBL nav tabs
        plinkSW         % Link: SUESI & Waveform tabs
        
        pfileBin        % filelist: input binary files
        ptblRxCfg       % table: Receiver configuration info
        puiCSEM         % UI: settings for CSEM calculation
        
        pactMakeSP      % action: make SP files from Rx Cfg info
        pactCSEM        % action: calculate CSEM transfer functions
        
        pfileCSEM       % filelist: resulting CSEM data
        
        pactDM          % action: export to DataMan
        
    end % protected properties
    
    methods( Access = public )
        function o = w_tabNodalCSEM( oWave, oTabGrp )
            % Call the superclass constructor
            o@w_tab( oWave, oTabGrp, w_tab.sTabCSEMNodal );
        end
        
        function MakeUI(o)
            o.bUIMade = true;
            oProg = uiprogressdlg( o.oWave.hFig ...
                , 'Title',  ['First time accessing tab: ' o.sTitle] ...
                , 'Message', 'Creating UI elements & filling with data ...' ...
                , 'Indeterminate', 'on' ); %#ok<NASGU>
            
            %----- Create & connect the workbench panels -----%
            cPosMap = o.GetPanelGrid( 3, 4 );
            
            o.pfileBin = w_panelFile( o, cPosMap{1,1} ...
                , cwave.sLog_CSEM_Bin, 'Receiver binaries', 'cFiles_Bin' ...
                , {'*','All Files'} ...
                , o.oWave.sSubBin ... default path variable for "Add" button
                , @isFile_Binary, 'Plot', @(~,~)o.oWave.PlotBinaries ...
                );
            
            o.plinkRxNav = w_panelLink( o, cPosMap{2,1} ...
                , w_tab.sTabRxNav ...
                , {'. Receiver navigation'} );
            
            o.plinkTxNav = w_panelLink( o, cPosMap{3,2} ...
                , w_tab.sTabUSBLNav ...
                , '. Ultra short baseline SUESI nav' ...
                , w_tab.sTabiLBLNav ...
                , '. Inverted long baseline SUESI nav' ...
                );
            
            o.ptblRxCfg = w_panelTable( o, cPosMap{1,2} ...
                , cwave.sLog_Nodal_RxCfg, 'Nodal RX Configuration' ...
                , 'tableRxCfg', @(~,~)o.oWave.UIRxCfg, [] ...
                , @(~,~)o.RxCfgClear ...
                , @o.WrapValidateRxCfg, [] );
            
            o.puiCSEM = w_panelInput( o, cPosMap{2,2} ...
                , cwave.sLog_CSEM_UI, 'User Config for CSEM' ...
                , 'CSEMUI_VarChg' ... event to trigger when variables chg
                , {'nWindowLen', 'nStackLen'} ...
                , { @(st)Chk_nWindowLen(o.oWave,st)
                    @(st)Chk_nStackLen(o.oWave,st) } );
            
            o.pactMakeSP = w_panelAction( o, cPosMap{1,3} ...
                , cwave.sLog_Nodal_MakeSP, 'Make SP files' ...
                , @()o.oWave.MakeSP, [], [] ...
                , [
                'Make *.sp files for MT processing from the nodal ' ...
                'receiver configuration information.'
                ] );
            
            o.pactCSEM = w_panelAction( o, cPosMap{2,3} ...
                , cwave.sLog_Nodal_CSEM, 'Calculate CSEM' ...
                , @()o.oWave.NodalCSEM("All"), @()o.oWave.NodalCSEM("New"), [] ...
                , [
                'Process raw signal data into stacked, trimmed, & nav-merged ' ...
                'CSEM FFT data. Time drift corrections are also applied.'
                ] );
            
            o.plinkSW = w_panelLink( o, cPosMap{3,3} ...
                , w_tab.sTabSUESI ...
                , {
                '. Transmitter source-dipole moment time series'
                '. Tow line start & end time list'
                }, w_tab.sTabWaveform ...
                , {
                '. Waveform harmonic list'
                '. Waveform length'
                } );
            
            o.pfileCSEM = w_panelFile( o, cPosMap{2,4} ...
                , cwave.sLog_Nodal_Output, 'CSEM data files', 'cFiles_NodalCSEM' ...
                , {'*.csem.mat','Nodal CSEM Files';'*','All Files'} ...
                , o.oWave.sCSEMDir ... default path variable for "Add" button
                , @isFile_NodalCSEM, 'Load', [] ...
                );
            
            o.pactDM = w_panelAction( o, cPosMap{3,4} ...
                , cwave.sLog_Nodal_DM, 'Export to DataMan' ...
                , @()o.oWave.ExportToDataMan, [], [] ...
                , [
                'Export the CSEM data to DataMan where it can be viewed, ' ...
                'trimmed, plotted, and exported to various inversion ' ...
                'routines.'
                ] );
            
            %----- Connect the various panels -----%
            o.ConnectH(  o.pfileBin,  1, 1, o.ptblRxCfg, 1, 1 );
            o.ConnectH3( o.plinkRxNav,1, 3, o.ptblRxCfg, 1, 1, 1/2 );
            o.ConnectH(  o.ptblRxCfg, 1, 2, o.pactMakeSP, 1, 2 );
            o.ConnectH3( o.ptblRxCfg, 2, 2, o.pactCSEM, 1, 1, 1/2 );
            o.ConnectH(  o.puiCSEM,   1, 1, o.pactCSEM, 1, 1 );
            o.ConnectH(  o.pactCSEM,  1, 1, o.pfileCSEM, 1, 1 );
            o.ConnectV3( o.pactCSEM,  1, 3, o.plinkTxNav, 3, 3, 1/2, 'Up' );
            o.ConnectV(  o.pactCSEM,  1, 3, o.plinkSW, 1, 3, 'Up' );
            o.ConnectV(  o.pfileCSEM, 1, 1, o.pactDM, 1, 1 );
            
            
            %----- Setup listeners to cascade changes down dependencies -----%
            addlistener( o.oWave, 'CSEMUI_VarChg',               @(~,~)o.Event_UpdateCnts() );
            addlistener( o.oWave, 'tableTow',         'PostSet', @(~,~)o.Event_UpdateCnts() );
            addlistener( o.oWave, 'tableSDM',         'PostSet', @(~,~)o.Event_UpdateCnts() );
            addlistener( o.oWave, 'tableHarmonics',   'PostSet', @(~,~)o.Event_UpdateCnts() );
            addlistener( o.oWave, 'tableTxNav',       'PostSet', @(~,~)o.Event_UpdateCnts() );
            addlistener( o.oWave, 'tableRxNav',       'PostSet', @(~,~)o.EnablePanels() );
            addlistener( o.oWave, 'tableRxCfg',       'PostSet', @(~,~)o.EnablePanels() );
            addlistener( o.oWave, 'cFiles_NodalCSEM', 'PostSet', @(~,~)o.EnablePanels() );
            addlistener( o.oWave, 'cFiles_Bin',       'PostSet', @(~,~)o.EnablePanels() );
            
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
            o.pfileBin.UpdateUI();
            o.ptblRxCfg.UpdateUI();
            o.puiCSEM.UpdateUI();
            o.pactMakeSP.UpdateUI();
            o.pactCSEM.UpdateUI();
            o.pfileCSEM.UpdateUI();
            
            % En/Disable panels based on loaded data
            o.EnablePanels();
            
            return;
        end % LoadUI
        
        %-----------------------------------------------------------------------
        % En/disable panels based on whether their prereqs are ready
        function EnablePanels( o )
            o.ptblRxCfg.Enable( ~isempty( o.oWave.cFiles_Bin ) );
            o.pactMakeSP.Enable( ~isempty( o.oWave.tableRxCfg ) );
            o.pactCSEM.Enable( ...
                    o.puiCSEM.AllOK() ...
                && ~isempty( o.oWave.tableRxCfg ) ...
                && ~isempty( o.oWave.tableRxNav ) ...
                && ~isempty( o.oWave.tableTow ) ...
                && ~isempty( o.oWave.tableSDM ) ...
                && ~isempty( o.oWave.tableHarmonics ) ...
                && ~isempty( o.oWave.tableTxNav ) ...
                );
            o.pactDM.Enable( ~isempty( o.oWave.cFiles_NodalCSEM ) );
            return;
        end % EnablePanels
        
    end % public methods
    
    
    methods( Access = protected )
        
        %-----------------------------------------------------------------------
        % Handler for event CSEMUI_VarChg - change of user setting
        function Event_UpdateCnts( o )
            o.pfileCSEM.UpdateUI(); % Update the file list panel
            o.pactCSEM.UpdateUI();  % Reset the counts on the action panel
            o.EnablePanels();       % En/Disable panels appropriately
            return;
        end % Event_UpdateCnts
        
        %-----------------------------------------------------------------------
        % Clear both tableRxCfg and tableRxCh
        function RxCfgClear( o )
            sBtn = uiconfirm( o.oWave.hFig ...
                , 'Clear the RX Config table?', 'RX Config Table' ...
                , 'Options', {'Yes', 'No'}, 'DefaultOption', 2 );
            if ~strcmpi( sBtn, 'Yes' )
                return;
            end
            
            % Log it
            o.oWave.AddLog( cwave.LogOK, cwave.sLog_Nodal_RxCfg, 'User cleared the data table manually.' );
            
            % Make the change - RxCfg will engage listeners but not RxCh
            o.oWave.tableRxCh  = cwave.GetDfltFor( 'tableRxCh' );
            o.oWave.tableRxCfg = cwave.GetDfltFor( 'tableRxCfg' );
            return;
        end % RxCfgClear
        
        %-----------------------------------------------------------------------
        % Put a wrapper around the Validate function so I can pass in the
        % channel table too. Since this is ONLY called by w_panelTable for
        % displaying "it's OK" colors, always pass the tables directly
        function [bOK,cErrMsg] = WrapValidateRxCfg( o, ~, ~, ~ ) % tbl, hUIFig, bQuery )
            [bOK,cErrMsg] = cwave.ValidateRxCfg( o.oWave.tableRxCfg, o.oWave.tableRxCh ...
                                         , o.oWave.sDir_Calib );
            return;
        end % WrapValidateRxCfg
        
    end % protected methods
    
end % w_tabNodalCSEM
