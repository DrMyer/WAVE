classdef w_panelInput < w_panel
    % Class used inside WAVE to define a single "user input" panel for a uitab.
    % It is intentionally simple. This class mostly handles UI.
    %---------------------------------------------------------------------------
    % Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
    %---------------------------------------------------------------------------
    
    % immutable properties - only set in the constructor & never changed
    properties( SetAccess = immutable )
        sEvent  % Name of the cwave::event to trigger on variable changes
        cVars   % cell array of cwave::variables to show and/or edit here
        cCVfcn  % cell array of contextual validation functions for some of the 
                % variables in cVars
        fPlot   % function handle of optional plot routine for UIEditVars
        
        hTable  % handle to the UI table showing the data
    end
    
    methods( Access = public )
        %-----------------------------------------------------------------------
        % Constructor
        % Params:
        %   tab - the w_tab... instance this panel lives on
        %   nLB - [left bottom] position in hParent in PIXELS
        %   sLogType - cwave.sLog_ type to use in the user log
        %   sTitle - text to show in the top of the panel
        %   sEvent - Name of the cwave::event to trigger on variable changes
        %   cVars - list of cwave::variables to show & edit
        %   cCVfcn - cell array of contextual validation functions for some of 
        %           the variables in cVars
        %   fPlot - accessory plot function to pass to UIEditVars, if given
        %-----------------------------------------------------------------------
        function o = w_panelInput( tab, nLB, sLogType, sTitle, sEvent, cVars, cCVfcn, fPlot )
            arguments
                tab         w_tab
                nLB (1,2)   double
                sLogType    char
                sTitle      char
                sEvent      char
                cVars       cell
                cCVfcn      cell = {}
                fPlot       = []
            end
            
            % Call the superclass constructor
            o@w_panel( tab, nLB, sLogType, sTitle );
            
            % If there are any contextual validation functions, make sure the
            % array is the same length as the variable array. Otherwise empty is
            % fine.
            if ~isempty( cCVfcn ) && numel(cCVfcn) ~= numel(cVars)
                cCVfcn{numel(cVars)} = '';
            end
            
            % Save params we need to persistently track
            o.sEvent    = sEvent;
            o.cVars     = onerow( cVars );
            o.cCVfcn    = onerow( cCVfcn );
            o.fPlot     = fPlot;
            
            % Add controls to the panel
            hG = uigridlayout( o.hPanel );
            hG.RowHeight    = {cwave.BtnHt,'1x'};
            hG.ColumnWidth  = {w_panel.BtnWd, '1x', w_panel.BtnWd};
            hG.ColumnSpacing= 0;
            hG.RowSpacing   = 0;
            hG.Padding      = [5 5 5 5];
            
            uibutton( 'Parent', hG, 'FontSize', cwave.FontSize, 'Text', 'Edit' ...
                , 'Icon', w_IconLib('Pencil'), 'ButtonPushedFcn', @o.BtnEdit );
            h = uibutton( 'Parent', hG, 'FontSize', cwave.FontSize, 'Text', 'Reset' ...
                , 'Icon', w_IconLib('Eraser'), 'ButtonPushedFcn', @o.BtnReset );
            h.Layout.Column = 3;
            
            o.hTable = uitable( 'Parent', hG, 'FontSize', cwave.FontSize - 2 );
            o.hTable.Layout.Column = [1 3];
            
            % Fill the UI table
            o.UpdateUI();
            
            return;
        end % object constructor
        
        %-----------------------------------------------------------------------
        % Collect the user input list & pop it into the table
        function o = UpdateUI( o )
            % Assemble the info about the variables
            cUI = cell( numel(o.cVars), 3 );
            for iVar = 1:numel(o.cVars)
                sVar = o.cVars{iVar};
                cUI{iVar,1} = cwave.stVarInfo.(sVar).sDesc;
                cUI{iVar,3} = o.oWave.(sVar);
                try
                    cwave.stVarInfo.(sVar).fcnValid( cUI{iVar,3} );
                    % If there is a contextual validation function, run it too
                    if numel(o.cCVfcn) >= iVar && ~isempty(o.cCVfcn{iVar})
                        o.cCVfcn{iVar}( o.oWave );
                    end
                    cUI{iVar,2} = true;
                catch
                    cUI{iVar,2} = false;
                end
            end
            
            % Update the table
            o.hTable.ColumnName = {'Variable','OK','Value'};
            o.hTable.ColumnEditable = false;
            o.hTable.ColumnWidth = {'auto',30,'auto'};
            o.hTable.RowName = {};
            o.hTable.Data = cUI;
            
            % Color the bad inputs as errors & color the panel
            removeStyle( o.hTable );
            bBad = ~cell2mat( cUI(:,2) );
            if any( bBad )
                addStyle( o.hTable, uistyle('FontColor',cwave.nClrError) ...
                    , 'row', reshape( find( bBad ), 1, [] ) );
                o.SetPanelState( cwave.LogError );
            else
                o.SetPanelState( cwave.LogOK );
            end
            return;
        end % UpdateUI
        
        %-----------------------------------------------------------------------
        % Indicate whether or not all user inputs are currently valid
        function bOK = AllOK( o )
            bOK = all( cell2mat( o.hTable.Data(:,2) ) );
            return;
        end % AllOK
        
    end % public methods
    
    methods( Access = protected )
        %-----------------------------------------------------------------------
        function BtnEdit( o, ~, ~ )   % obj, button handle, eventdata
            bChgs = UIEditVars( o.oWave, o.sTitle, o.cVars, o.sLogType, o.cCVfcn, o.fPlot );
            if bChgs
                o.UpdateUI();
                notify( o.oWave, o.sEvent );
            end
            return;
        end % BtnEdit
        
        %-----------------------------------------------------------------------
        function BtnReset( o, ~, ~ )   % obj, button handle, eventdata
            sBtn = uiconfirm( o.oWave.hFig ...
                , 'Reset all inputs to defaults?', o.sTitle ...
                , 'Options', {'Yes', 'No'}, 'DefaultOption', 2 );
            if ~strcmpi( sBtn, 'Yes' )
                return;
            end
            
            % Reset to defaults
            bChgs = false;
            for iVar = 1:numel(o.cVars)
                sVar = o.cVars{iVar};
                if ~isequal( o.oWave.(sVar), cwave.GetDfltFor( sVar ) )
                    bChgs = true;
                    o.oWave.(sVar) = cwave.GetDfltFor( sVar );
                end
            end
            if bChgs
                o.UpdateUI();
                notify( o.oWave, o.sEvent );
            end
            
            % Log it
            o.oWave.AddLog( cwave.LogOK, o.sLogType, 'User cleared all inputs.' );
            
            return;
        end % BtnReset
    end % protected methods
    
end % classdef w_panelInput
