classdef (Abstract) w_tab < handle
    % Superclass for all of the workbench "tab" classes for uniformity and for
    % managing the "connection" arrows between the various w_panel objects that
    % get dropped on them. This is an abstract class and *must* be sub-classed
    % to be instantiated.
    %---------------------------------------------------------------------------
    % Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
    %---------------------------------------------------------------------------
    
    % Constants to ensure uniformity of look across various panel types
    properties( Constant )
        nTabEdge = 60;      % edge around the tab to keep the panels off of
        nConnWd  = 2;       % LineWidth of connectors
        nArrowLn = 10;      % Arrow HeadLength
        nArrowWd = 15;      % Arrow HeadWidth
        
        % Tab strings. Centralized because w_panelLink needs to know the texts
        % exactly to find the proper tab to change to.
        sTabCfg         = 'Configuration';
        sTabShipData    = 'Ship Data';
        sTabSUESI       = 'SUESI Logs';
        sTabWaveform    = 'Waveform';
        sTabRxNav       = 'RX Benthos Nav';
        sTabUSBLNav     = 'USBL Nav';
        sTabiLBLNav     = 'iLBL Nav';
        sTabCSEMNodal   = 'Nodal CSEM';
        sTabCSEMTowed   = 'Towed CSEM';
    end
    
    % Immutable properties - only set in the constructor & never changed
    properties( SetAccess = immutable, GetAccess = public )
        oWave   % cwave object for this instance
        hTab    % uitab object
        hTNode  % uitreenode for this entire tab
        sTitle  % which sub-class tab is this?
    end
    
    properties( SetAccess = protected, GetAccess = public )
        bUIMade = false;
    end
    
    methods( Access = public )
        %-----------------------------------------------------------------------
        % super-class constructor - makes the tab and stashes immutable props
        function o = w_tab( oWave, hTabGrp, sTitle )
            o.oWave  = oWave;
            o.sTitle = sTitle;
            o.hTab   = uitab( 'Parent', hTabGrp, 'Scrollable', true ...
                , 'Title', ['  ' sTitle '  '] ... make the tab larger than MatLab's default
                , 'AutoResizeChildren', false ...
                , 'UserData', o ...
                );
            % If there is no tree control then don't create a tree node. This
            % occurs for the config tab where the tree control lives.
            if ~isempty( oWave.hTree )
                o.hTNode = uitreenode( 'Parent', oWave.hTree, 'Text', sTitle, 'UserData', 'tab' );
            end
            return;
        end
        
        function SelectTab( oTab )
            if ~oTab.bUIMade
                tm = tic();
                fprintf( ['Creating UI on tab "' oTab.sTitle '" ... '] );  % no \n on purpose
                oTab.MakeUI();
                toc(tm);
            end
        end
    end
    
    % Abstract public - all subclasses MUST implement these methods
    methods( Access = public, Abstract )
        o = LoadUI(o)   % this overload is for load from .mat file. All other updates generally handled by listeners
        EnablePanels(o) % for children of a tab to tell the tab that data has changed which isn't listened to
        MakeUI(o)
    end
    
    % Protected methods - available to the sub-classes
    methods( Access = protected )
        
        %-----------------------------------------------------------------------
        % Return a cell array (nRows,nCols) with the [bottom left] positions for
        % a grid of w_panel objects. 
        % 
        % NB: I CANNOT USE uigridlayout because of the annotation arrows between
        % the panels. uigridlayout got an opaque background in 2020b so
        % annotation objects in the underlying uitab do not show through. And
        % annotation objects cannot be put inside the uigridlayout without
        % tremendous pain & suffering.
        function cPosMap = GetPanelGrid( o, nRows, nCols )
            cPosMap = cell( nRows, nCols );
            nLeft = ((w_panel.nWd + w_panel.nSpcH) * (0:nCols-1)) + w_tab.nTabEdge;
            nBott = ((w_panel.nHt + w_panel.nSpcV) * (0:nRows-1)) + w_tab.nTabEdge;
            for iR = 1:nRows
                for iC = 1:nCols
                    cPosMap{iR,iC} = [nLeft(iC) nBott(iR)];
                end
            end
            cPosMap = flipud( cPosMap );
            
            % Create a control at the top right corner so that the uitab's
            % scrollbars respect the nTabEdge setting
            uilabel( 'Parent', o.hTab, 'Text', '', 'Position', [
                max(nLeft) + w_tab.nTabEdge + w_panel.nWd
                max(nBott) + w_tab.nTabEdge + w_panel.nHt
                1
                1
                ].' );
            return;
        end % GetPanelGrid
        
        %-----------------------------------------------------------------------
        % Draw a HORIZONTAL ARROW connection between two given panels
        % Parameter Note:
        %   n.../n...Cnt - n...Cnt is the number of connections going from
        %       this panel elsewhere and n... is which of these connections this
        %       particular one is (ie 3rd of 7)
        %   sLeft - 'Left' means make arrow go from <-- instead of -->
        function oArrow = ConnectH( o, panelFrom, nFrom, nFromCnt, panelTo, nTo, nToCnt, sLeft )
            nPosFrom= panelFrom.Position();
            nPosTo  = panelTo.Position();
            
            nX(1)   = nPosFrom(1) + nPosFrom(3);
            nX(2)   = nPosTo(1);
            
            n = linspace( nPosFrom(2), nPosFrom(2) + nPosFrom(4), nFromCnt + 2 );
            nY(1)   = n(numel(n) - nFrom);
            n = linspace( nPosTo(2), nPosTo(2) + nPosTo(4), nToCnt + 2 );
            nY(2)   = n(numel(n) - nTo);
            
            if exist('sLeft','var') && strncmpi( sLeft, 'L', 1 )
                nX = nX([2 1]);
                nY = nY([2 1]);
            end
            oArrow = annotation( o.hTab, 'arrow', 'LineWidth', w_tab.nConnWd ...
                , 'Units', 'pixels', 'X', nX, 'Y', nY ...
                , 'HeadLength', w_tab.nArrowLn, 'HeadWidth', w_tab.nArrowWd ...
                );
            return;
        end % ConnectH
        
        %-----------------------------------------------------------------------
        % Simple double-headed HORIZONTAL ARROW
        function oArrow = ConnectHDouble( o, panelFrom, nFrom, nFromCnt, panelTo, nTo, nToCnt )
            nPosFrom= panelFrom.Position();
            nPosTo  = panelTo.Position();
            
            nX(1)   = nPosFrom(1) + nPosFrom(3);
            nX(2)   = nPosTo(1);
            
            n = linspace( nPosFrom(2), nPosFrom(2) + nPosFrom(4), nFromCnt + 2 );
            nY(1)   = n(numel(n) - nFrom);
            n = linspace( nPosTo(2), nPosTo(2) + nPosTo(4), nToCnt + 2 );
            nY(2)   = n(numel(n) - nTo);
            
            oArrow = annotation( o.hTab, 'doublearrow', 'LineWidth', w_tab.nConnWd ...
                , 'Units', 'pixels', 'X', nX, 'Y', nY ...
                , 'Head1Length', w_tab.nArrowLn, 'Head1Width', w_tab.nArrowWd ...
                , 'Head2Length', w_tab.nArrowLn, 'Head2Width', w_tab.nArrowWd ...
                );
            return;
        end % ConnectHDouble
        
        %-----------------------------------------------------------------------
        % Like ConnectH() but does a 3-segment arrow. nPosCue says how far into
        % the vertical gutter to go.
        function ConnectH3( o, panelFrom, nFrom, nFromCnt, panelTo, nTo, nToCnt, nPosCue, nWhichGutter )
            % Set up optional parameters
            if ~exist( 'nWhichGutter', 'var' ) || isempty( nWhichGutter )
                nWhichGutter = 1;
            end
            
            % Get the panel positions
            nPosFrom= panelFrom.Position();
            nPosTo  = panelTo.Position();
            
            % Horizontal line starting at 'from' into vertical gutter
            x   = nPosFrom(1) + nPosFrom(3);
            x2  = x ...
                + (w_panel.nSpcH * nPosCue) ...
                + (nWhichGutter - 1) * (w_panel.nWd + w_panel.nSpcH);
            y   = linspace( nPosFrom(2), nPosFrom(2) + nPosFrom(4), nFromCnt + 2 );
            y   = y(numel(y) - nFrom);
            annotation( o.hTab, 'line', 'Units', 'pixels', 'X', [x x2], 'Y', [y y] ...
                , 'LineStyle', '-', 'LineWidth', w_tab.nConnWd );
            
            % Vertical line up/down to correct panel
            y2  = linspace( nPosTo(2), nPosTo(2) + nPosTo(4), nToCnt + 2 );
            y2  = y2(numel(y2) - nTo);
            annotation( o.hTab, 'line', 'Units', 'pixels', 'X', [x2 x2], 'Y', [y y2] ...
                , 'LineStyle', '-', 'LineWidth', w_tab.nConnWd );
            
            % Horizontal ARROW from gutter to panel
            x   = nPosTo(1);
            annotation( o.hTab, 'arrow', 'LineWidth', w_tab.nConnWd ...
                , 'Units', 'pixels', 'X', [x2 x], 'Y', [y2 y2] ...
                , 'HeadLength', w_tab.nArrowLn, 'HeadWidth', w_tab.nArrowWd ...
                );
            
            return;
        end % ConnectH3
        
        %-----------------------------------------------------------------------
        % Like ConnectH() but does a 5-segment arrow. Used for connecting panels
        % on different rows or even cycling back to show cyclic relation between
        % a line of panels.
        % Param 'nPosCues' has 3 elements indicating the percentage into the
        % appropriate gutter the line should extend.
        function ConnectH5( o, panelFrom, nFrom, nFromCnt, panelTo, nTo, nToCnt, nPosCues )
            nPosFrom= panelFrom.Position();
            nPosTo  = panelTo.Position();
            
            % Horizontal line starting at 'from' into vertical gutter
            x   = nPosFrom(1) + nPosFrom(3);
            x2  = x + (w_panel.nSpcH * nPosCues(1));
            y   = linspace( nPosFrom(2), nPosFrom(2) + nPosFrom(4), nFromCnt + 2 );
            y   = y(numel(y) - nFrom);
            annotation( o.hTab, 'line', 'Units', 'pixels', 'X', [x x2], 'Y', [y y] ...
                , 'LineStyle', '-', 'LineWidth', w_tab.nConnWd );
            
            % Vertical line down to next horizontal gutter
            y2  = nPosFrom(2) - (w_panel.nSpcV * nPosCues(2));
            annotation( o.hTab, 'line', 'Units', 'pixels', 'X', [x2 x2], 'Y', [y y2] ...
                , 'LineStyle', '-', 'LineWidth', w_tab.nConnWd );
            
            % Horizontal line left/right to proper vertical gutter
            x   = nPosTo(1) - (w_panel.nSpcH * nPosCues(3));
            annotation( o.hTab, 'line', 'Units', 'pixels', 'X', [x x2], 'Y', [y2 y2] ...
                , 'LineStyle', '-', 'LineWidth', w_tab.nConnWd );
            
            % Vertical line up/down to beside 'to' panel
            y   = linspace( nPosTo(2), nPosTo(2) + nPosTo(4), nToCnt + 2 );
            y   = y(numel(y) - nTo);
            annotation( o.hTab, 'line', 'Units', 'pixels', 'X', [x x], 'Y', [y y2] ...
                , 'LineStyle', '-', 'LineWidth', w_tab.nConnWd );
            
            % Horizontal ARROW from gutter to panel
            x2  = nPosTo(1);
            annotation( o.hTab, 'arrow', 'LineWidth', w_tab.nConnWd ...
                , 'Units', 'pixels', 'X', [x x2], 'Y', [y y] ...
                , 'HeadLength', w_tab.nArrowLn, 'HeadWidth', w_tab.nArrowWd ...
                );
            
            return;
        end % ConnectH5
        
        %-----------------------------------------------------------------------
        % Draw a VERTICAL ARROW connection between two given panels
        % Parameter Note:
        %   n.../n...Cnt - n...Cnt is the number of connections going from
        %       this panel elsewhere and n... is which of these connections this
        %       particular one is (ie 3rd of 7)
        %   sUp - 'Up' = arrow points from panelBelow UP to panelAbove
        function oArrow = ConnectV( o, panelAbove, nFrom, nFromCnt, panelBelow, nTo, nToCnt, sUp )
            if ~exist('sUp','var') || isempty(sUp)
                bUp = false;
            else
                bUp = strncmpi( sUp, 'Up', 2 );
            end
            nPosFrom= panelAbove.Position();
            nPosTo  = panelBelow.Position();
            
            n = linspace( nPosFrom(1), nPosFrom(1) + nPosFrom(3), nFromCnt + 2 );
            nX(1)   = n(nFrom + 1);
            n = linspace( nPosTo(1), nPosTo(1) + nPosTo(3), nToCnt + 2 );
            nX(2)   = n(nTo + 1);
            
            nY(1)   = nPosFrom(2);
            nY(2)   = nPosTo(2) + nPosTo(4);
            
            if bUp
                nX = fliplr(nX);
                nY = fliplr(nY);
            end
            
            oArrow = annotation( o.hTab, 'arrow', 'LineWidth', w_tab.nConnWd ...
                , 'Units', 'pixels', 'X', nX, 'Y', nY ...
                , 'HeadLength', w_tab.nArrowLn, 'HeadWidth', w_tab.nArrowWd ...
                );
            return;
        end % ConnectV
        
        %-----------------------------------------------------------------------
        % Like ConnectV() but does a 3-segment arrow DOWNWARD. 
        %   nPosCue - how far into the horizontal gutter to go.
        %   sUp - 'Up' = arrow points from panelBelow UP to panelAbove
        function ConnectV3( o, panelAbove, nFrom, nFromCnt, panelBelow, nTo, nToCnt, nPosCue, sUp, nWhichGutter )
            % Set up optional parameters
            if ~exist( 'nWhichGutter', 'var' ) || isempty( nWhichGutter )
                nWhichGutter = 1;
            end
            if ~exist('sUp','var') || isempty(sUp)
                bUp = false;
            else
                bUp = strncmpi( sUp, 'Up', 2 );
            end
            nPosFrom= panelAbove.Position();
            nPosTo  = panelBelow.Position();
            
            % Vertical line starting at 'from' into horizontal gutter
            n  = linspace( nPosFrom(1), nPosFrom(1) + nPosFrom(3), nFromCnt + 2 );
            x  = n(nFrom + 1);
            y  = nPosFrom(2);
            y2 = y ...
                - (w_panel.nSpcV * nPosCue) ...
                - (nWhichGutter - 1) * (w_panel.nHt + w_panel.nSpcV);
            if bUp
                annotation( o.hTab, 'arrow', 'Units', 'pixels', 'X', [x x], 'Y', [y2 y] ...
                    , 'HeadLength', w_tab.nArrowLn, 'HeadWidth', w_tab.nArrowWd ...
                    , 'LineStyle', '-', 'LineWidth', w_tab.nConnWd );
            else
                annotation( o.hTab, 'line', 'Units', 'pixels', 'X', [x x], 'Y', [y y2] ...
                    , 'LineStyle', '-', 'LineWidth', w_tab.nConnWd );
            end
            
            % Horizontal line along gutter
            x2  = linspace( nPosTo(1), nPosTo(1) + nPosTo(3), nToCnt + 2 );
            x2  = x2(nTo + 1);
            annotation( o.hTab, 'line', 'Units', 'pixels', 'X', [x x2], 'Y', [y2 y2] ...
                , 'LineStyle', '-', 'LineWidth', w_tab.nConnWd );
            
            % Vertical ARROW from gutter to panel
            y   = nPosTo(2) + nPosTo(4);
            if bUp
                annotation( o.hTab, 'line', 'LineWidth', w_tab.nConnWd ...
                    , 'Units', 'pixels', 'X', [x2 x2], 'Y', [y2 y] ...
                    );
            else
                annotation( o.hTab, 'arrow', 'LineWidth', w_tab.nConnWd ...
                    , 'Units', 'pixels', 'X', [x2 x2], 'Y', [y2 y] ...
                    , 'HeadLength', w_tab.nArrowLn, 'HeadWidth', w_tab.nArrowWd ...
                    );
            end
            
            return;
        end % ConnectV3
        
    end % protected methods - super & subclass access
    
end % classdef w_tab
