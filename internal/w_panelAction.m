classdef w_panelAction < w_panel
    % Class used inside WAVE to manage the UI for an "Action" that takes many
    % inputs, fires off action code, possibly in parallel, and passes output on
    % to a different panel object for display.
    %---------------------------------------------------------------------------
    % Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
    %---------------------------------------------------------------------------
    
    % immutable properties - only set in the constructor & never changed
    properties( SetAccess = immutable )
        fcnRunAll   % function to call for the "run all" button 
        fcnRunNew   % function to call for the "run new" button (can be empty)
        fcnViewDumps% function to call for "Text Dumps" button
        
        hlblOK      % label telling number of "good" log lines
        hlblWarn    % " warning
        hlblError   % " error
    end 
    
    methods( Access = public )
        %-----------------------------------------------------------------------
        % Constructor
        % Params:
        %   tab - the w_tab... object this panel lives on
        %   nLB - [left bottom] position in hParent in PIXELS
        %   sLogType - cwave.sLog_ PREFIX for entire class of log entries
        %   sTitle - text to show in the top of the panel
        %   fcnRunAll - function for the "run all" or "run" button (reqd)
        %   fcnRunNew - function for the "run new" button (can be empty)
        %   fcnViewDumps - function to allow the user to view any text dumps
        %               that result from the process. If [], button is hidden.
        %   sDesc - Wordy desc of the action / process this panel represents
        %-----------------------------------------------------------------------
        function o = w_panelAction( tab, nLB, sLogType, sTitle ...
                                  , fcnRunAll, fcnRunNew, fcnViewDumps, sDesc )
            % Call the superclass constructor
            o@w_panel( tab, nLB, sLogType, sTitle );
            
            % Save things specific to this panel type
            o.fcnRunAll     = fcnRunAll;
            o.fcnRunNew     = fcnRunNew;
            o.fcnViewDumps  = fcnViewDumps;
            bViewDumps      = isa( fcnViewDumps, 'function_handle' );
            
            % Add controls to the panel
            hG = uigridlayout( o.hPanel );
            hG.RowHeight    = {cwave.BtnHt, '1x', cwave.LblHt, cwave.LblHt, cwave.LblHt};
            hG.ColumnWidth  = {'1x', cwave.BtnWd};
            hG.RowSpacing   = 0;
            hG.Padding      = [5 5 5 5];
            
            %-- sub-divide the button row
            hGB = uigridlayout( hG );
            hGB.Layout.Column   = [1 2];
            hGB.Padding         = [0 0 0 0];
            hGB.ColumnSpacing   = 0;
            hGB.RowHeight       = {'1x'};
            hGB.ColumnWidth     = {w_panel.BtnWd, w_panel.BtnWd, '1x', w_panel.BtnWd};
            if isa( fcnRunNew, 'function_handle' )
                uibutton( 'Parent', hGB, 'FontSize', cwave.FontSize, 'Text', 'Run New' ...
                    , 'Icon', w_IconLib('Run'), 'ButtonPushedFcn', @o.BtnRunNew );
                uibutton( 'Parent', hGB, 'FontSize', cwave.FontSize, 'Text', 'Run All' ...
                    , 'Icon', w_IconLib('RunAll'), 'ButtonPushedFcn', @o.BtnRunAll );
            else
                uibutton( 'Parent', hGB, 'FontSize', cwave.FontSize, 'Text', 'Run' ...
                    , 'Icon', w_IconLib('Run'), 'ButtonPushedFcn', @o.BtnRunAll );
            end
            h = uibutton( 'Parent', hGB, 'FontSize', cwave.FontSize, 'Text', 'Events' ...
                , 'Icon', w_IconLib('Log'), 'ButtonPushedFcn', @o.BtnLog );
            h.Layout.Column = 4;
            
            h = uilabel( 'Parent', hG, 'Text', sDesc ...
                , 'FontSize', cwave.FontSize-2, 'WordWrap', true );
            h.Layout.Column = [1 2];
            
            o.hlblOK = uilabel( 'Parent', hG, 'Text', '0 normal events' ...
                , 'FontSize', cwave.FontSize+2, 'FontColor', cwave.nClrOK );
            o.hlblOK.Layout.Row     = 3;
            o.hlblOK.Layout.Column  = iif( bViewDumps, 1, [1 2] );
            
            o.hlblWarn = uilabel( 'Parent', hG, 'Text', '0 warnings' ...
                , 'FontSize', cwave.FontSize+2, 'FontColor', cwave.nClrWarn );
            o.hlblWarn.Layout.Row    = 4;
            o.hlblWarn.Layout.Column = iif( bViewDumps, 1, [1 2] );
            
            o.hlblError = uilabel( 'Parent', hG, 'Text', '0 errors' ...
                , 'FontSize', cwave.FontSize+2, 'FontColor', cwave.nClrError );
            o.hlblError.Layout.Row    = 5;
            o.hlblError.Layout.Column = iif( bViewDumps, 1, [1 2] );
            
            if bViewDumps
                h = uibutton( 'Parent', hG, 'FontSize', cwave.FontSize ...
                    , 'Text', {'View';'Dump';'Logs'} ...
                    , 'Icon', w_IconLib('ViewDump'), 'ButtonPushedFcn', @o.fcnViewDumps );
                h.Layout.Row    = [3 5];
                h.Layout.Column = 2;
            end
            
            % Now that everything is created, make sure texts are up to date
            o.UpdateUI();
            
            return;
        end % object constructor
        
        %-----------------------------------------------------------------------
        function [nOK,nWarn,nErr] = UpdateUI( o )
            cLog            = o.oWave.GetLogOfType( o.sLogType );
            nStat           = cell2mat( cLog(:,o.oWave.colLog.Status) );
            nOK             = sum(nStat == o.oWave.LogOK);
            nWarn           = sum(nStat == o.oWave.LogWarn);
            nErr            = sum(nStat == o.oWave.LogError);
            o.hlblOK.Text   = sprintf( '%d normal events',  nOK );
            o.hlblWarn.Text = sprintf( '%d warnings',       nWarn );
            o.hlblError.Text= sprintf( '%d errors',         nErr );
            return;
        end % UpdateUI
        
    end % public methods
    
    methods( Access = protected )
        %-----------------------------------------------------------------------
        % Button: Run New - run process for all items not yet run
        function BtnRunNew( o, ~, ~ )
            try
                o.fcnRunNew();  % ASSUME the function uses AddLog() to log its actions
            catch Me
                o.ErrMe( Me );
            end
            [~,nWarn,nErr] = o.UpdateUI();
            
            % If there were errors or warnings, automatically show the log
            if nWarn > 0 || nErr > 0
                o.BtnLog();
            end
            return;
        end % BtnRunNew
        
        %-----------------------------------------------------------------------
        % Button: Run All - run / rerun process for all items
        function BtnRunAll( o, ~, ~ )
            try
                o.fcnRunAll();  % ASSUME the function uses AddLog() to log its actions
            catch Me
                o.ErrMe( Me );
            end
            [~,nWarn,nErr] = o.UpdateUI();
            
            % If there were errors or warnings, automatically show the log
            if nWarn > 0 || nErr > 0
                o.BtnLog();
            end
            return;
        end % BtnRunAll
        
        %-----------------------------------------------------------------------
        % Report a caught error
        function ErrMe( o, Me )
            disp( '---------- Error ----------' );
            disp( Me );
            for iStack = 1:numel(Me.stack)
                fprintf( 'Line %d of <a href="matlab:edit %s">%s</a>\n' ...
                    , Me.stack(iStack).line, Me.stack(iStack).name, Me.stack(iStack).name );
            end
            % NB: uialert always returns immediately without waiting for OK even
            % when set Modal. Must use uiconfirm and collect the result, even if
            % you don't look at the result.
            s = uiconfirm( o.oWave.hFig, {
                'An error occurred. There may be more info in the'
                'MatLab command window.'
                ''
                ['Message: ' Me.message]
                ['Error: ' Me.identifier]
                }, 'Error occurred', 'Icon', 'error', 'Options', {'OK'} ); %#ok<NASGU>
            return;
        end % ErrMe
        
        %-----------------------------------------------------------------------
        % Button: Log - show the detailed log
        function BtnLog( o, ~, ~ )
            o.oWave.ShowLogForType( o.sLogType );
            return;
        end % BtnLog
    end % protected methods
    
end % classdef w_panelAction
