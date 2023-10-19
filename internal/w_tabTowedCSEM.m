classdef w_tabTowedCSEM < w_tab
    % w_tabTowedCSEM( cwave, oTabGrp )
    %
    % Class for the "Towed CSEM" tab of the WAVE project
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
        plinkTxNav      % Link: USBL & iLBL nav tabs
        plinkSW         % Link: SUESI & Waveform tabs
        
        pfileBin        % filelist: input binary files
        ptblTowRxCfg    % table: Towed receiver configuration info
        puiCSEM         % UI: settings for CSEM calculation
        
        pactCSEM        % action: calculate CSEM transfer functions
        
        pfileCSEM       % filelist: resulting CSEM data
        
        pactReplot      % action: replot Vulcan line plots (for convenience)
        pactExport      % action: export to MARE2DEM
        
    end % protected properties
    
    methods( Access = public )
        function o = w_tabTowedCSEM( oWave, oTabGrp )
            % Call the superclass constructor
            o@w_tab( oWave, oTabGrp, w_tab.sTabCSEMTowed );
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
            
            o.ptblTowRxCfg = w_panelTable( o, cPosMap{2,1} ...
                , cwave.sLog_Towed_RxCfg, 'Towed RX Configuration' ...
                , 'tableTowRxCfg', @(~,~)o.oWave.UITowRxCfg, [] ...
                , @(~,~)o.RxCfgClear ...
                , @o.WrapValidateTowRxCfg, [] );
            
            o.puiCSEM = w_panelInput( o, cPosMap{1,2} ...
                , cwave.sLog_CSEM_UI, 'User Config for CSEM' ...
                , 'CSEMUI_VarChg' ... event to trigger when variables chg
                , {'nWindowLen', 'nStackLen'} ...
                , { @(st)Chk_nWindowLen(o.oWave,st)
                    @(st)Chk_nStackLen(o.oWave,st) } );
            
            o.pactCSEM = w_panelAction( o, cPosMap{2,2} ...
                , cwave.sLog_Towed_CSEM, 'Calculate CSEM' ...
                , @()o.oWave.TowedCSEM("All"), @()o.oWave.TowedCSEM("New"), [] ...
                , [
                'Process raw signal data into stacked, trimmed, & nav-merged ' ...
                'CSEM FFT data. Time drift corrections are also applied.'
                ] );
            
            o.plinkTxNav = w_panelLink( o, cPosMap{3,1} + w_panel.nHalfL ...
                , w_tab.sTabUSBLNav ...
                , {'. Ultra short baseline SUESI';'. USBL CTET nav'} ...
                , w_tab.sTabiLBLNav ...
                , {'. Inverted long baseline SUESI';'. iLBL CTET nav'} ...
                );
            
            o.plinkSW = w_panelLink( o, cPosMap{3,2} + w_panel.nHalfL ...
                , w_tab.sTabSUESI ...
                , {
                '. Transmitter source-dipole moment time series'
                '. Tow line start & end time list'
                }, w_tab.sTabWaveform ...
                , {
                '. Waveform harmonic list'
                '. Waveform length'
                } );
            
            o.pfileCSEM = w_panelFile( o, cPosMap{2,3} ...
                , cwave.sLog_Towed_Output, 'Towed CSEM data files', 'cFiles_TowedCSEM' ...
                , {'*.towedcsem.mat','Towed CSEM Files';'*','All Files'} ...
                , o.oWave.sCSEMDir ... default path variable for "Add" button
                , @isFile_TowedCSEM, 'Load', [] ...
                );
            
            o.pactReplot = w_panelAction( o, cPosMap{2,4} - w_panel.nHalfD ...
                , cwave.sLog_Towed_Export, 'Re-plot Towed Line plots' ...
                , @()o.sub_Replot, [], [] ...
                , [
                'Re-run the amp+phase line plots for selected ' ...
                'tow vehicles and tow lines, this time keeping ' ...
                'the plot windows open. (NB: plots are saved to ' ...
                'the _Plots subfolder. You can open them there.)' ...
                ] );
            
            o.pactExport = w_panelAction( o, cPosMap{2,4} + w_panel.nHalfD ...
                , cwave.sLog_Towed_Export, 'Export to MARE2DEM' ...
                , @()o.oWave.ExportTow2MARE, [], [] ...
                , [
                'Export the towed CSEM data to the MARE2DEM ' ...
                'inversion data format.' ...
                ] );
            
            %----- Connect the various panels -----%
            o.ConnectV(  o.pfileBin,    1, 1, o.ptblTowRxCfg, 1, 1 );
            o.ConnectH(  o.ptblTowRxCfg,1, 1, o.pactCSEM, 1, 1 );
            o.ConnectV(  o.puiCSEM,     1, 1, o.pactCSEM, 1, 1 );
            o.ConnectH(  o.pactCSEM,    1, 1, o.pfileCSEM, 1, 1 );
            o.ConnectV3( o.pactCSEM,    1, 1, o.plinkTxNav, 2, 2, 1/2, 'Up' );
            o.ConnectV3( o.pactCSEM,    1, 1, o.plinkSW, 1, 2, 1/2, 'Up' );
            o.ConnectH3( o.pfileCSEM,   1, 1, o.pactReplot, 3, 3, 1/2 );
            o.ConnectH3( o.pfileCSEM,   1, 1, o.pactExport, 1, 3, 1/2 );
            
            
            %----- Setup listeners to cascade changes down dependencies -----%
            addlistener( o.oWave, 'CSEMUI_VarChg',               @(~,~)o.Event_UpdateCnts() );
            addlistener( o.oWave, 'tableTow',         'PostSet', @(~,~)o.Event_UpdateCnts() );
            addlistener( o.oWave, 'tableSDM',         'PostSet', @(~,~)o.Event_UpdateCnts() );
            addlistener( o.oWave, 'tableHarmonics',   'PostSet', @(~,~)o.Event_UpdateCnts() );
            addlistener( o.oWave, 'tableTowRxCfg',    'PostSet', @(~,~)o.EnablePanels() );
            addlistener( o.oWave, 'tableTxNav',       'PostSet', @(~,~)o.EnablePanels() );
            addlistener( o.oWave, 'tableCTET',        'PostSet', @(~,~)o.EnablePanels() );
            addlistener( o.oWave, 'cFiles_Bin',       'PostSet', @(~,~)o.EnablePanels() );
            addlistener( o.oWave, 'cFiles_TowedCSEM', 'PostSet', @(~,~)o.EnablePanels() );
            
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
            o.ptblTowRxCfg.UpdateUI();
            o.puiCSEM.UpdateUI();
            o.pactCSEM.UpdateUI();
            o.pfileCSEM.UpdateUI();
            
            % En/Disable panels based on loaded data
            o.EnablePanels();
            
            return;
        end % LoadUI
        
        %-----------------------------------------------------------------------
        % En/disable panels based on whether their prereqs are ready
        function EnablePanels( o )
            o.ptblTowRxCfg.Enable( ~isempty( o.oWave.cFiles_Bin ) );
            o.pactCSEM.Enable( ...
                    o.puiCSEM.AllOK() ...
                && ~isempty( o.oWave.tableTowRxCfg ) ...
                && ~isempty( o.oWave.tableTow ) ...
                && ~isempty( o.oWave.tableSDM ) ...
                && ~isempty( o.oWave.tableHarmonics ) ...
                && ~isempty( o.oWave.tableTxNav ) ...
                );
            o.pactReplot.Enable( ~isempty( o.oWave.cFiles_TowedCSEM ) );
            o.pactExport.Enable( ~isempty( o.oWave.cFiles_TowedCSEM ) );
            
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
        % Clear both tableTowRxCfg and tableTowRxCh
        function RxCfgClear( o )
            sBtn = uiconfirm( o.oWave.hFig ...
                , 'Clear the Towed RX Config table?', 'Towed RX Config Table' ...
                , 'Options', {'Yes', 'No'}, 'DefaultOption', 2 );
            if ~strcmpi( sBtn, 'Yes' )
                return;
            end
            
            % Log it
            o.oWave.AddLog( cwave.LogOK, cwave.sLog_Towed_RxCfg, 'User cleared the data table manually.' );
            
            % Make the change - TowRxCfg will engage listeners but not RxCh
            o.oWave.tableTowRxCh  = cwave.GetDfltFor( 'tableTowRxCh' );
            o.oWave.tableTowRxCfg = cwave.GetDfltFor( 'tableTowRxCfg' );
            return;
        end % RxCfgClear
        
        %-----------------------------------------------------------------------
        % Put a wrapper around the Validate function so I can pass in the
        % channel table too. Since this is ONLY called by w_panelTable for
        % displaying "it's OK" colors, always pass the tables directly
        function [bOK,cErrMsg] = WrapValidateTowRxCfg( o, ~, ~, ~ ) % tbl, hUIFig, bQuery )
            [bOK,cErrMsg] = cwave.ValidateTowRxCfg( ...
                o.oWave.tableTowRxCfg, o.oWave.tableTowRxCh, o.oWave.sDir_Calib );
            return;
        end % WrapValidateTowRxCfg
        
        %-----------------------------------------------------------------------
        % For the user's convenience. Replot a selection of vulcan + towline
        % plots, keeping the windows open. Yes the user could simply go to the
        % _Plots folder and open them. No, they probably won't think of that.
        function sub_Replot(o)
            % Get the user's selection of what to plot
            [iReplot,bOK] = listdlg( 'ListString', o.oWave.cFiles_TowedCSEM ...
                , 'ListSize', [400 300] ...
                , 'Name', 'Select data to re-plot', 'PromptString', { ...
                'Select towed CSEM data files to re-plot.'
                }, 'SelectionMode', 'multiple', 'OKString', 'Plot' ...
                );
            if ~bOK     % user cancel
                return;
            end
            
            % Plot it, keeping the figures open this time
            for i = onerow( iReplot )
                PlotTowedCSEM( o.oWave, o.oWave.cFiles_TowedCSEM{i}, true );
            end
            
            return;
        end
        
    end % protected methods
    
end % w_tabTowedCSEM
