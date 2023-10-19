classdef (Abstract = true) w_panel < handle
    % Superclass for all of the workbench "panel" classes (file, action, etc)
    % which ensures uniformity in various aspects.
    %---------------------------------------------------------------------------
    % Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
    %---------------------------------------------------------------------------
    
    % Constants to ensure uniformity of look across various panel types
    properties( Constant )
        nWd double = 300;       % panel width in pixels
        nHt double = 200;       % panel height in pixels
        nEdge double = 5;       % edge buffer to keep controls off the panel beveling & title
        
        nSpcH double = 100;     % distance between panels horizontally
        nSpcV double =  60;     % " " " vertically
        
        % For shifting a panel half over to the left or down. Subtract for
        % opposite shift (duh)
        nHalfL double = [(w_panel.nWd + w_panel.nSpcH) / 2, 0];
        nHalfD double = [0, -(w_panel.nHt + w_panel.nSpcV) / 2];
        
        BtnWd double = 80;      % panel buttons are smaller than cwave.BtnWd
    end % constants specific to w_panel
    
    % Immutable properties - only set in the constructor & never changed
    properties( SetAccess = immutable )
        oWave                   % cwave object for this instance
        tab                     % w_tab... object this panel lives on
        hPanel                  % handle to the panel
        hTNode                  % uitreenode for this panel
    end
    properties( SetAccess = immutable, GetAccess = public )
        sLogType                % which cwave.sLog_* to use in the "I did this" log
        sTitle                  % caller-provided text to use as panel title & prompt
    end
    
    methods( Access = public )
        function o = w_panel( tab, nLB, sLogType, sTitle )
            o.oWave     = tab.oWave;
            o.tab       = tab;
            o.sLogType  = sLogType;
            o.sTitle    = sTitle;
            o.hPanel    = uipanel( 'Parent', tab.hTab ...
                , 'Title', [' ' sTitle ' '], 'TitlePosition', 'centertop' ...
                , 'FontSize', cwave.FontSize, 'FontWeight', 'bold' ...
                , 'Units', 'pixels', 'Position', [nLB o.nWd o.nHt] ...
                , 'BorderType', 'line' ...
                );
            
            % Create the tree node for this panel in its parent tab's list
            if ~isa( o, 'w_panelLink' )
                o.hTNode = uitreenode( 'Parent', tab.hTNode, 'Text', sTitle, 'UserData', 'panel' );
                
                % Create a listener to the panel's background color and use it
                % to update the icon in the uitree
                %
                % NOPE. MatLab claims that 'BackgroundColor' is not a property
                % of uipanel despite the fact that it is. I think this means
                % that it is not SetObservable in the handle class. That might
                % be an R2020b bug. The offshoot is that I have to implement
                % this manually in each panel subclass. C'est la vie.
                %
                % addlistener( o.hPanel, 'BackgroundColor', 'postset', @(src,evt)o.PanelStateChg );
            end
            return;
        end
        
        %-----------------------------------------------------------------------
        % What is the current position for the uipanel object?
        function nLBWH = Position( o )
            nLBWH = o.hPanel.OuterPosition;
            return;
        end % Position
        
        %-----------------------------------------------------------------------
        % En/disable this panel. Set other internal states as appropriate
        function o = Enable( o, bEnable )
            o.hPanel.Enable = iif( bEnable, 'on', 'off' );
            o.PanelStateChg();
            return;
        end % Enable
        
        %-----------------------------------------------------------------------
        function b = IsEnabled( o )
            % NB: though uipanel's docs say 'Enable' may be true/false, once the
            % obj is created, it acts like a regular panel obj with strings
            % 'on', 'off', or 'inactive'
            b = strcmpi( o.hPanel.Enable, 'on' );
        end % IsEnabled
        
        %-----------------------------------------------------------------------
        % Set the state of the panel to one of the cwave::Log... constant states
        function SetPanelState( o, nState )
            % Color the panel's border
            switch( nState )
            case cwave.LogWarn
                o.hPanel.BackgroundColor = cwave.nClrWarn;
            case cwave.LogError
                o.hPanel.BackgroundColor = cwave.nClrError;
            otherwise
                o.hPanel.BackgroundColor = cwave.nClrBkgd;
            end
            
            % Update the icon for this panel in the master to-do list tree
            o.PanelStateChg();
            return;
        end
        
        %-----------------------------------------------------------------------
        % Listener for state changes to the panel which should be noted in the
        % uitree
        function PanelStateChg( o )
            % Figure out which icon to use
            if ~o.IsEnabled() || isequal( o.hPanel.BackgroundColor, cwave.nClrError )
                o.hTNode.Icon = w_IconLib( 'Stop' );
            elseif isequal( o.hPanel.BackgroundColor, cwave.nClrWarn )
                o.hTNode.Icon = w_IconLib( 'Warn' );
            else
                o.hTNode.Icon = '';
            end
            return;
        end % PanelStateChg
        
    end % public methods
    
    
    methods( Access = protected )
        %-----------------------------------------------------------------------
        % Create the "hamburger" menu in the top right. It's ContextMenu
        % property is already filled with the handle to an empty uicontextmenu
        % object. Add uimenu() options to it using hBtn.ContextMenu as the
        % parent to the sub-menu options.
        function hBtn = MakeOptionsBtn( o )
            % nPosI = o.hPanel.InnerPosition;
            nPosO = o.hPanel.OuterPosition;
            % nPnlB = nPosI(1) - nPosO(1);  % size of panel's all-around border
            nTHt  = 21; % MatLab lies!  (nPosO(4) - nPosI(4)) - 2 * nPnlB;  % ht of title withOUT borders
            
            % NB: in order to put the button ON the panel's title, it needs to
            % be in the panel's parent
            hBtn  = uibutton( 'Parent', o.hPanel.Parent, 'Text', cwave.Char3Line ...
                            , 'FontSize', 10 ...
                            , 'Position', [nPosO(1) + nPosO(3) - nTHt ...
                                           nPosO(2) + nPosO(4) - nTHt ...
                                           nTHt nTHt ] ...
                            , 'ContextMenu', uicontextmenu(o.oWave.hFig) ...
                            , 'ButtonPushedFcn', @o.OpenContextMenu ...
                            );
            return;
        end % MakeOptionsBtn
        
        %-----------------------------------------------------------------------
        % Open the 3-line menu on a panel. Put it next to the context button
        function OpenContextMenu(o,hBtn,~)
            % NB: need to account for the scroll context of the tab. If it is
            % scrolled, then the position needs to be adjusted because the
            % button position is relative to the origin of the containing panel
            nAbsMouseLoc = get( groot(), 'PointerLocation' );
            nAbsFigLoc   = o.oWave.hFig.InnerPosition;
            open( hBtn.ContextMenu, nAbsMouseLoc - nAbsFigLoc(1:2) );
            return;
        end % OpenContextMenu
    end % protected methods - callable by the class & subclasses only
    
end % classdef w_panel
