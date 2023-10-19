classdef w_tabWaveform < w_tab
    % w_tabWaveform( cwave, oTabGrp )
    %
    % Class for the "Waveform" tab of the WAVE project
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
        plinkSuesi      % tab-link from "SUESI Logs" tab
        
        pfileSNAP       % filelist: SUESI SNAPshots
        pactSNAP2Wave   % action: aggregate SNAPs --> waveform
        ptblSNAP        % table: aggregate waveform from SNAPS
        ptblIdeal       % table: idealized waveform
        pactHarmonics   % action: waveform --> freq domain harmonic amp,phi
        ptblHarmonics   % table: freq domain harmonic amp,phi
        
    end % protected properties
    
    methods( Access = public )
        function o = w_tabWaveform( oWave, oTabGrp )
            % Call the superclass constructor
            o@w_tab( oWave, oTabGrp, w_tab.sTabWaveform );
        end
        
        function MakeUI(o)
            o.bUIMade = true;
            oProg = uiprogressdlg( o.oWave.hFig ...
                , 'Title',  ['First time accessing tab: ' o.sTitle] ...
                , 'Message', 'Creating UI elements & filling with data ...' ...
                , 'Indeterminate', 'on' ); %#ok<NASGU>
            
            %----- Create & connect the workbench panels -----%
            cPosMap = o.GetPanelGrid( 3, 4 );
            
            %-- Link to the SUESI tab --%
            % NB: Scoot this one over to be centered over both panels it links
            o.plinkSuesi = w_panelLink( o, cPosMap{1,1} + w_panel.nHalfL ...
                , w_tab.sTabSUESI ...
                , '. SNAPs & ideal waveform description from SUESI logs' );
            
            %-- SNAP and ideal waveform creation --%
            o.pfileSNAP = w_panelFile( o, cPosMap{2,1} ...
                , cwave.sLog_Wave_Files, 'Waveform SNAPshot Files', 'cFiles_SNAP' ...
                , {'*.snap','Waveform SNAPshots';'*','All Files'} ...
                , o.oWave.sSuesiDir ... default path variable for "Add" button
                , @isFile_SNAP, 'Load' );
            
            o.ptblIdeal = w_panelTable( o, cPosMap{2,2} ...
                , cwave.sLog_Wave_Ideal, 'Idealized Waveform' ...
                , 'tableWaveIdeal', @o.EditIdealWave, @(~,~)o.oWave.PlotWaveIdeal ...
                , 'ClearTable', [], {'Time', 'Amplitude',{},{'LineStyle','-','Marker','none'}} ...
                );
            
            o.pactSNAP2Wave = w_panelAction( o, cPosMap{3,1} ...
                , cwave.sLog_Wave_SNAP ...
                , 'Create Waveform from SNAPs' ...
                , @()o.oWave.SNAP2Waveform, [], [] ...
                , [
                'Using one or more waveform SNAPshots from SUESI, ' ...
                'create a normalized waveform which takes into account ' ...
                'roll-on and roll-off of current at the transitions. It is ' ...
                'a more accurate way to calculate waveform harmonic scaling.' ...
                ] );
            
            o.ptblSNAP = w_panelTable( o, cPosMap{3,2} ...
                , cwave.sLog_Wave_SNAP, 'Waveform from SNAPs' ...
                , 'tableWaveSNAP', [], @(~,~)o.oWave.PlotWaveSnap, 'ClearTable', [] ...
                , {'Time', 'Amplitude'} );
            o.pactHarmonics = w_panelAction( o, cPosMap{3,3} ...
                , cwave.sLog_Wave_Harmonics ...
                , 'Select Waveform Harmonics' ...
                , @()o.oWave.SelectHarmonics, [], [] ...
                , [
                'Select waveform scaling harmonics from an idealized ' ...
                'waveform or SNAP-derived waveform. The harmonics are ' ...
                'used to properly scale the source SDM time series when ' ...
                'the CSEM transfer function is calculated.' ...
                ] );
            o.ptblHarmonics = w_panelTable( o, cPosMap{3,4} ...
                , cwave.sLog_Wave_Ideal, 'Waveform Harmonics' ...
                , 'tableHarmonics', [], @(~,~)o.oWave.PlotWaveHarmonics, 'ClearTable', [] ...
                );
            
            %----- Connect the various panels -----%
            o.ConnectV3( o.plinkSuesi, 1, 2, o.pfileSNAP, 1, 1, 1/2 );
            o.ConnectV3( o.plinkSuesi, 2, 2, o.ptblIdeal, 1, 1, 1/2 );
            
            o.ConnectV( o.pfileSNAP, 1, 1, o.pactSNAP2Wave, 1, 1 );
            o.ConnectH( o.pactSNAP2Wave, 1, 1, o.ptblSNAP, 1, 1 );
            o.ConnectH5( o.ptblIdeal, 1, 1, o.pactHarmonics, 1, 2, [1/2 1/2 1/2] );
            o.ConnectH( o.ptblSNAP, 2, 2, o.pactHarmonics, 2, 2 );
            o.ConnectH( o.pactHarmonics, 1, 1, o.ptblHarmonics, 1, 1 );
            
            %----- Setup listeners to cascade changes down dependencies -----%
            addlistener( o.oWave, 'cFiles_SNAP',    'PostSet', @(src,evt)o.Event_UpdateSnapCnts() );
            addlistener( o.oWave, 'tableWaveSNAP',  'PostSet', @(src,evt)o.EnablePanels() );
            addlistener( o.oWave, 'tableWaveIdeal', 'PostSet', @(src,evt)o.EnablePanels() );
            addlistener( o.oWave, 'tableHarmonics', 'PostSet', @(src,evt)o.EnablePanels() );
            
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
            o.pfileSNAP.UpdateUI();
            o.ptblIdeal.UpdateUI();
            o.pactSNAP2Wave.UpdateUI();
            o.ptblSNAP.UpdateUI();
            o.pactHarmonics.UpdateUI();
            o.ptblHarmonics.UpdateUI();
            
            % En/Disable panels based on loaded data
            o.EnablePanels();
            
            return;
        end % LoadUI
        
        %-----------------------------------------------------------------------
        % En/disable panels based on whether their prereqs are ready
        function EnablePanels( o )
            o.pactSNAP2Wave.Enable( ~isempty( o.oWave.cFiles_SNAP ) );
            o.ptblSNAP.Enable( ~isempty( o.oWave.tableWaveSNAP ) );
            o.pactHarmonics.Enable( ...
                   ~isempty( o.oWave.tableWaveSNAP ) ...
                || ~isempty( o.oWave.tableWaveIdeal ) ...
                );
            o.ptblHarmonics.Enable( ~isempty( o.oWave.tableHarmonics ) );
            
            return;
        end % EnablePanels
        
    end % public methods
    
    
    methods( Access = protected )
        %-----------------------------------------------------------------------
        % listener for cFiles_SNAP
        function Event_UpdateSnapCnts( o )
            o.pactSNAP2Wave.UpdateUI(); % Reset the log counts on the action panel
            o.EnablePanels();           % En/Disable panels appropriately
            return;
        end % Event_UpdateSnapCnts
        
        %-----------------------------------------------------------------------
        % Ideal waveform panel: Edit/Create an ideal waveform
        function EditIdealWave( o, ~, ~ )
            % Retrieve the existing ideal waveform, if any
            nSamp   = o.oWave.tableWaveIdeal.Time * 400;  % 400Hz --> sample
            nA      = o.oWave.tableWaveIdeal.Amplitude;
            
            % Call the UI. If it's successful, log the success
            [bOK,nSamp,nA,sType] = UIMakeWaveform( nSamp, nA, o.oWave.hFig );
            if bOK
                o.oWave.AddLog( cwave.LogOK, cwave.sLog_Wave_Ideal ...
                    , ['User edited/created ideal waveform: ' sType] );
                
                % Update the table (NB: triggers listeners so replace entire table
                % at one time, not in pieces)
                t = cwave.GetDfltFor( 'tableWaveIdeal', numel(nSamp) );
                t.Time               = nSamp / 400; % sample / 400Hz SUESI --> time
                t.Amplitude          = nA;
                o.oWave.tableWaveIdeal = t;
                
                % Clear the harmonics table. It MIGHT now be invalid (if there
                % are no SNAPs)
                o.oWave.tableHarmonics = cwave.GetDfltFor( 'tableHarmonics' );
            end
            
            return;
        end % EditIdealWave
        
    end % protected methods
    
end % w_tabWaveform
