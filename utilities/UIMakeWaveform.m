function [bOK,nSamp,nA,sType] = UIMakeWaveform( nSamp, nA, hParent )
% UI for editing / creating an ideal waveform using the symantic for entering
% SUESI 400Hz H:n L:n texts. (See decodeSUESITXTiming.m)
%
% Params:
%   nSamp, nA   - Sample#,Amp for pre-existing waveform. Can be empty.
%   hParent     - (opt) handle of uifigure to center over
% Returns:
%   bOK         - True if save, False if cancel
%   nSamp, nA   - Sample#,Amp for new waveform (in 'brief' mode; see
%                   decodeSUESITXTiming.m)
%   sType       - 'Name' of the waveform if the user selects a pre-constructed
%                 one otherwise will be 'Custom'
%
%-------------------------------------------------------------------------------
% Copyright (C) 2023 David Myer
% 
% This program is free software: you can redistribute it and/or modify it under
% the terms of the GNU General Public License as published by the Free Software
% Foundation, version 3. This program is distributed in the hope that it will be
% useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. To view the GNU General
% Public License see <https://www.gnu.org/licenses/>
%-------------------------------------------------------------------------------
% See also decodeSUESITXTiming, encodeSUESITXTiming

    % Handle optional params
    if ~exist( 'hParent', 'var' )
        hParent = [];
    end
    
    % Default the return values
    bOK     = false;
    sType   = '';
    
    % Waveforms & their names - placed here for easy modification / expansion
    cPremades = {
        'Daveform (1s)', 'H:40 L:40 H:20 L:20 H:40 L:80 H:40 L:20 H:20 L:40 H:40'
        'Daveform (2s)', 'H:80 L:80 H:40 L:40 H:80 L:160 H:80 L:40 H:40 L:80 H:80'
        'Daveform (4s)', 'H:160 L:160 H:80 L:80 H:160 L:320 H:160 L:80 H:80 L:160 H:160'
        'Square (1s)',   'H:200 L:200'
        'Custom',        ''
        };
    
    % If an ideal waveform was submitted, turn it into a SUESI H:/L: text string
    i1stType = 1;
    if ~isempty( nSamp )
        % If the custom timing is recognized as one of the pre-mades, make sure
        % that pre-made gets selected. If not, make the given waveform the
        % "custom" selection
        sCustomTiming = encodeSUESITXTiming( nSamp, nA );
        i1stType = find( strcmpi( sCustomTiming, cPremades(:,2) ), 1, 'first' );
        if isempty( i1stType )
            cPremades{end,2} = sCustomTiming;
            i1stType = size(cPremades,1);
        end
    end
    
    % Create the UI elements
    hFig = uifigure( 'Name', 'Edit / Create an Idealized Waveform' ...
        , 'Visible', false, 'WindowStyle', 'modal', 'Resize', true ...
        , 'Units', 'pixels', 'Position', [1 1 800 800] ...
        );
    figCenter( hParent, hFig );
    
    % General grid for all the zones
    hG = uigridlayout( hFig );
    hG.RowHeight    = {'fit', cwave.BtnHt, cwave.BtnHt, '1x', cwave.BtnHt};
    hG.ColumnWidth  = {'fit', '1x', cwave.BtnWd, cwave.BtnWd};
    hG.ColumnSpacing= 5;
    hG.RowSpacing   = 15;
    hG.Padding      = [10 10 10 10];
    
    % Instruction text
    h = uilabel( 'Parent', hG, 'FontSize', cwave.FontSize + 2, 'WordWrap', true, 'Text' ...
        , {
        'INSTRUCTIONS: Select a pre-defined waveform or "Custom" and design your own.'
        ''
        ['For CUSTOM waveforms: enter a series of High & Low commands as you would when entering ' ...
        'the "H:nn1 L:nn2 H:nn3..." waveform design directly into SUESI, where each number ' ...
        'is the count of 400 Hz cycles that the output current should be high (+ve) or low (-ve). ' ...
        'Press ENTER while coding to see the plot update.' ]
        });
    h.Layout.Column = [1 numel(hG.ColumnWidth)];
    
    % Entry fields
    uilabel( 'Parent', hG, 'FontSize', cwave.FontSize, 'Text', 'Pre-defined Waveform:' );
    hType = uidropdown( 'Parent', hG, 'FontSize', cwave.FontSize ...
        , 'Items', cPremades(:,1).', 'ItemsData', 1:size(cPremades,1), 'Value', i1stType ...
        , 'ValueChangedFcn', @sub_TypeChg );
    
    h = uilabel( 'Parent', hG, 'FontSize', cwave.FontSize, 'Text', 'SUESI 400Hz Timing:' );
    h.Layout.Row = 3;
    h.Layout.Column = 1;
    
    hTiming = uieditfield( 'Parent', hG, 'FontSize', cwave.FontSize ...
        , 'ValueChangingFcn', @sub_PlotWaveform, 'ValueChangedFcn', @sub_PlotWaveform );
    hTiming.Layout.Column = [2 numel(hG.ColumnWidth)];
    
    % Plot space
    hWave = uiaxes( 'Parent', hG, 'FontSize', cwave.FontSize, 'Box', 'on' );
    hWave.Layout.Row    = 4;
    hWave.Layout.Column = [1 numel(hG.ColumnWidth)];
    
    % Dialog control buttons
    h = uibutton( 'Parent', hG, 'FontSize', cwave.FontSize, 'Text', 'Save' ...
        , 'ButtonPushedFcn', @sub_Save );
    h.Layout.Column = numel(hG.ColumnWidth) - 1;
    uibutton( 'Parent', hG, 'FontSize', cwave.FontSize, 'Text', 'Cancel' ...
        , 'ButtonPushedFcn', @sub_Cancel );
    
    % Poke the type-change function so it triggers a full UI update
    sub_TypeChg();
    
    % Make the figure visible and run the MODAL figure
    hFig.Visible = true;
    hFig.CloseRequestFcn = @sub_Cancel;
    waitfor( hFig );
    return;
    
    %---------------------------------------------------------------------------
    % EMBEDDED FUNCTIONS
    %---------------------------------------------------------------------------
    
    %---------------------------------------------------------------------------
    function sub_Cancel(~,~)
        bOK = false;
        delete( hFig );
        return;
    end % sub_Cancel
    
    %---------------------------------------------------------------------------
    function sub_Save(~,~)
        % Force update (ValueChangingFcn doesn't fire consistently in R2020b)
        sub_PlotWaveform();
        
        % Is the waveform well-formed? (can it be decoded without crashing?)
        if isempty( nSamp )
            uialert( hFig, {
                'The waveform did not decode properly.'
                ''
                'When creating a custom waveform, the instruction line'
                'must be a collection of alternating H:nnn L:nnn entries'
                'indicating when the output current is High or Low. The'
                'numbers are number of 400Hz samples. So, for example,'
                'a 2-second square wave would be: H:400 L:400'
                }, 'Edit / Create an Ideal Waveform' );
            return;
        end
        
        % Is the waveform polarizing?
        [~,nA1] = decodeSUESITXTiming( hTiming.Value, 'Detailed' );
        nCntP = sum(nA1 > 0);
        nCntN = sum(nA1 < 0);
        if nCntP ~= nCntN
            uialert( hFig, {
                'The currently selected waveform is POLARIZING.'
                'Polarizing waveforms are not symmetrical in high'
                'and low current output and will DESTROY the antenna.'
                ''
                sprintf( 'Total High: %d', nCntP );
                sprintf( 'Total Low: %d', nCntN );
                ''
                'Please balance H: & L: entries.'
                }, 'Edit / Create an Ideal Waveform' );
            return;
        end
        
        % If we get here, all is well
        if hType.Value == size(cPremades,1) % custom, so give entire string
            sType = ['Custom: ' hTiming.Value];
        end
        bOK = true;
        delete( hFig );
        return;
    end % sub_Save
    
    %---------------------------------------------------------------------------
    % The pre-defined waveform uidropdown value has changed
    function sub_TypeChg(~,~)
        iType = hType.Value;
        sType = cPremades{iType,1};
        if iType == size(cPremades,1) && isempty( cPremades{end,2} )
            % If no custom was originally given, just leave the text unchanged
            % when the user selects away from a pre-made so it serves as a
            % starting point
        else
            hTiming.Value   = cPremades{iType,2};
        end
        hTiming.Editable    = (iType == size(cPremades,1));   % last = custom
        hTiming.Enable      = (iType == size(cPremades,1));   % last = custom
        
        sub_PlotWaveform();
        return;
    end
    
    %---------------------------------------------------------------------------
    % The timing entry field is being typed in real-time or a pre-defined
    % waveform has been selected. Plot, if possible, the waveform
    function sub_PlotWaveform(~,~)
        try
            [nSamp,nA] = decodeSUESITXTiming( hTiming.Value, 'Brief' );
        catch
            [nSamp,nA] = deal([]);
        end
        
        plot( hWave, nSamp / 400, nA, 'Marker', 'none', 'LineStyle', '-'  );
        hWave.XLabel.String = 'Time (s)';
        hWave.YLabel.String = 'Normalized Amplitude';
        axisTight( hWave, 'x' );
        hWave.YLim = [-1.05 1.05];
        
        drawnow limitrate;
        
        return;
    end % sub_PlotWaveform

end % UIMakeWaveform
