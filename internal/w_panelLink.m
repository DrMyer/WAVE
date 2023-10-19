classdef w_panelLink < w_panel
    % Class used inside WAVE to manage the UI for a "Link to Tab" panel
    %---------------------------------------------------------------------------
    % Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
    %---------------------------------------------------------------------------
    
    % immutable properties - only set in the constructor & never changed
    properties( SetAccess = immutable )
    end 
    
    methods( Access = public )
        %-----------------------------------------------------------------------
        % Constructor
        % Params:
        %   tab - the w_tab... object this panel lives on
        %   nLB - [left bottom] position in hParent in PIXELS
        %   sTabTxt - Text on the tab to go to
        %   sDesc - Wordy desc of what the other tab provides. Can be anything
        %           valid to pass to uilabel's 'Text' parameter
        %-----------------------------------------------------------------------
        function o = w_panelLink( tab, nLB, sTabTxt, sDesc )
            arguments
                tab w_tab
                nLB (1,2) double
            end
            arguments (Repeating)
                sTabTxt char
                sDesc
            end
            
            % Call the superclass constructor
            o@w_panel( tab, nLB, '', 'Linked Tab' );
            
            % Change the nature of the panel
            o.hPanel.TitlePosition = 'lefttop';
            
            % Add controls to the panel
            hG = uigridlayout( o.hPanel );
            hG.RowHeight    = [repmat({cwave.BtnHt, 'fit'},1,numel(sTabTxt)) '1x'];
            hG.ColumnWidth  = {'1x'};
            hG.RowSpacing   = 5;
            hG.Padding      = [0 0 0 0] + 10;
            
            for i = 1:numel(sTabTxt)
                uibutton( 'Parent', hG, 'FontSize', cwave.FontSize ...
                    , 'Text', ['Go to: ' sTabTxt{i}], 'Icon', w_IconLib('TabLink') ...
                    , 'ButtonPushedFcn', @(~,~)o.oWave.GoToTab(sTabTxt{i}) );
                
                uilabel( 'Parent', hG, 'Text', sDesc{i}, 'VerticalAlignment', 'top' ...
                    , 'FontSize', cwave.FontSize, 'WordWrap', true );
            end
            
            return;
        end % object constructor
        
    end % public methods
    
end % classdef w_panelLink
