function [bChgs,oOut] = UIEditVars( oWave, sTitle, cVars, sLogType, cCVfcn, fPlot )
% [bChgs,oWave] = UIEditVars( oWave, sTitle, cVars, sLogType, cCVfcn, fPlot )
%
% Runs the UI to edit a list of variables whose characteristics are kept in a
% structure .stVarInfo
%
% Parameters:
%   oWave - the controlling cwave instance
%           --OR-- a struct with members .hFig, .stVarInfo, & .(var) where
%           stVarInfo is a prompt structure like found in cwave and .(var) is
%           the starting value for each variable named in cVars
%   sTitle - dialog title
%   cVars - cell array of variable names in the order they should be prompted
%   sLogType - cwave.sLog_... string for logging changes (only used if oWave is
%           a cwave instance)
%   cCVfcn - (opt) cell array of contextual validation functions for some of the
%           variables in cVars. This allows you to cross validate some variables
%           against others (e.g. either X or Y must be filled but not both)
%   fPlot  - (opt) function to plot helpful information on the right half of the
%           dialog. It will be passed a uigridlayout object and should work only 
%           in row 1, col 2.
%
% Returns:
% --IF oWave is a cwave instance
%   bChgs - True = some changes were made to inputs. 
%           False = either no changes were made or the user canceled
% --OTHERWISE
%   bOK  - True = OK, False = user cancel
%   oOut - a copy of the input param oWave with .(var) updated by the user
%-------------------------------------------------------------------------------
% Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
%-------------------------------------------------------------------------------
    arguments
        oWave       % can be cwave or a struct emulating it
        sTitle      char
        cVars       cell
        sLogType    char = ''
        cCVfcn      cell = {} % start of optional params
        fPlot       = []
    end
    
    % Default the return values
    bCancel = false;
    bChgs   = false;
    oOut    = [];
    
    % Is this an automatic cwave call or a customized call?
    bCWave = isa( oWave, 'cwave' );
    
    % Build the UI
    nWd = iif( isempty( fPlot ), 700, 1500 );
    nHt = (cwave.LblHt+5)*max(5,numel(cVars)) + cwave.BtnHt + 40;
    hFig = uifigure( 'Name', sTitle, 'WindowStyle', 'modal' ...
        , 'Visible', false, 'Resize', true, 'Units', 'pixels' ...
        , 'Position', [1 1 nWd nHt] ...
        );
    figCenter( oWave.hFig, hFig );
    
    % If the caller wants to put useful info on the dialog, give it the right
    % half. Otherwise, take over the entire dialog
    if isempty( fPlot )
        hG = uigridlayout( hFig );
    else
        hGHalves = uigridlayout( hFig, [1 2] );
        hGHalves.ColumnSpacing   = 10;
        hGHalves.RowSpacing      = 0;
        hGHalves.Padding         = [0 0 0 10];
        
        hG = uigridlayout( hGHalves );
    end
    
    % General grid for all the zones
    hG.RowHeight       = [repmat({cwave.LblHt},1,numel(cVars)), '1x', {cwave.BtnHt}];
    hG.ColumnWidth     = {'fit','1x',cwave.BtnWd/2,cwave.BtnWd/2,cwave.BtnWd};
    hG.ColumnSpacing   = 5;
    hG.RowSpacing      = 5;
    hG.Padding         = [10 10 10 20];
    
    % Create each variable's edits from the list
    cSpecialValue = cell(numel(cVars),1);
    for iVar = 1:numel(cVars)
        sVar    = cVars{iVar};
        if bCWave
            vDflt = cwave.GetDfltFor( sVar ); % could be any type
        else
            vDflt = oWave.(sVar);
        end
        
        % The sSpecialBtn instruction may also tell to use a different field
        % type than a normal edit field
        %
        % NB: sSpecialBtn format = "Type:Value:Button Text"
        cSpclBits = strsplit( oWave.stVarInfo.(sVar).sSpecialBtn, ':' );
        
        % Prompt label
        uilabel( 'Parent', hG, 'FontSize', cwave.FontSize ...
            , 'HorizontalAlignment', 'right', 'Text', oWave.stVarInfo.(sVar).sDesc );
        
        % Edit field
        if isnumeric(vDflt) 
            assert( numel(vDflt) == 1, 'UIEditVars::Editing of numeric vectors must be done as a string.' );
            hEd(iVar) = uieditfield( hG, 'numeric', 'FontSize', cwave.FontSize ...
                , 'Value', oWave.(sVar), 'Tag', sVar );
        elseif strncmpi( cSpclBits{1}, 'DropDown', 8 )
            hEd(iVar) = uidropdown( 'Parent', hG, 'FontSize', cwave.FontSize ...
                , 'Items', cSpclBits(2:end), 'Value', oWave.(sVar), 'Tag', sVar );
            
            % Clear the indicator field so a "Special" button isn't made
            cSpclBits = {''};
        else
            hEd(iVar) = uieditfield( 'Parent', hG, 'FontSize', cwave.FontSize ...
                , 'Value', oWave.(sVar), 'Tag', sVar );
        end
        
        % "Reset to default" button
        uibutton( 'Parent', hG, 'FontSize', cwave.FontSize, 'Text', '' ...
            , 'Icon', w_IconLib('Reset'), 'ButtonPushedFcn', @(~,~)sub_Reset(iVar) );
        
        % Optional "Help" button
        if isempty( oWave.stVarInfo.(sVar).sHelp )
            uilabel( 'Parent', hG, 'Text', '' ); % dummy fill
        else
            uibutton( 'Parent', hG, 'FontSize', cwave.FontSize, 'Text', '' ...
                , 'Icon', w_IconLib('Help'), 'ButtonPushedFcn', @(~,~)sub_Help(iVar) );
        end
        
        % Optional "special" button
        if isempty( cSpclBits{1} )
            % Create a button so the array is fully populated, but make it
            % invisible because it is NOT used for this row.
            hSpcBtn(iVar) = uibutton( 'Parent', hG, 'Text', '', 'Visible', 'off' );
        else
            switch( cSpclBits{1} )
            case 'Btn'
                cSpecialValue{iVar} = str2num(cSpclBits{2});
            otherwise
                error( 'UIEditVars::Special button type "%s" not implemented' ...
                    , oWave.stVarInfo.(sVar).sSpecialBtn );
            end
            
            hSpcBtn(iVar) = uibutton( hG, 'state', 'FontSize', cwave.FontSize ...
                , 'Text', cSpclBits{3} ...
                , 'Value', isequal( cSpecialValue{iVar}, hEd(iVar).Value ) ...
                , 'ValueChangedFcn', @(~,~)sub_SpecialBtnToggle(iVar) );
            if hSpcBtn(iVar).Value
                sub_SpecialBtnToggle( iVar );
            end
        end
        
    end % loop through variable list
    
    % Dialog control buttons
    hGB = uigridlayout( hG );
    hGB.Layout.Column   = [1 numel(hG.ColumnWidth)];
    hGB.Layout.Row      = numel(hG.RowHeight);
    hGB.RowHeight       = {'1x'};
    hGB.ColumnWidth     = {'1x', cwave.BtnWd, cwave.BtnWd};
    hGB.ColumnSpacing   = 0;
    hGB.RowSpacing      = 0;
    hGB.Padding         = [0 0 0 0];
    uilabel( 'Parent', hGB, 'Text', '' ); % dummy fill
    uibutton( 'Parent', hGB, 'FontSize', cwave.FontSize, 'Text', 'Save' ...
        , 'ButtonPushedFcn', @sub_Save );
    uibutton( 'Parent', hGB, 'FontSize', cwave.FontSize, 'Text', 'Cancel' ...
        , 'ButtonPushedFcn', @sub_Cancel );
    
    % Give the caller its half of the screen
    if ~isempty( fPlot )
        fPlot( hGHalves );
    end
    
    % Make the figure visible and run the MODAL figure
    hFig.Visible = true;
    hFig.CloseRequestFcn = @sub_Cancel;
    waitfor( hFig );
    
    if ~bCWave
        bChgs = ~bCancel;   % if not cwave instance, just care about user cancel
        oOut = oWave;
    end
    return;
    
    %---------------------------------------------------------------------------
    function sub_Cancel(~,~)
        bCancel = true;
        delete( hFig );
        return;
    end % sub_Cancel
    
    %---------------------------------------------------------------------------
    function sub_Save(~,~)
        % If there are any contextual validation functions, then pull all values
        % into a structure that can be passed to the fcn
        if ~isempty(cCVfcn)
            for i = 1:numel(cVars)
                stCurVal.(cVars{i}) = hEd(i).Value;
            end
        end
        
        % Run the validation function for each variable
        for i = 1:numel(cVars)
            try
                oWave.stVarInfo.(cVars{i}).fcnValid( hEd(i).Value );
                
                % If there is a contextual validation function, run it too
                if numel(cCVfcn) >= i && ~isempty(cCVfcn{i})
                    cCVfcn{i}( stCurVal );
                end
            catch Me
                sMsg = strrep( Me.message, 'Value', ['"' oWave.stVarInfo.(cVars{i}).sDesc '"'] );
                uialert( hFig, sMsg, sTitle );
                return;
            end
        end
        
        % All validations passed. Stash each value back into the main object
        % and, if it has changed, log the change.
        for i = 1:numel(cVars)
            vOld = oWave.(cVars{i});
            vNew = hEd(i).Value;
            if ~isequal( vOld, vNew )
                bChgs = true;
                sOld = iif( isnumeric( vOld ), num2str( vOld ), vOld );
                sNew = iif( isnumeric( vNew ), num2str( vNew ), vNew );
                if bCWave
                    oWave.AddLog( cwave.LogOK, sLogType ...
                        , sprintf( '"%s" changed to "%s" from "%s"' ...
                        , cVars{i}, sNew, sOld ...
                        ) );
                end
                oWave.(cVars{i}) = vNew;    % *might* fire off listeners
            end
        end
        
        % Close the dialog
        delete( hFig );
        
        return;
    end % sub_Save
    
    %---------------------------------------------------------------------------
    % Set the given variable back to its system default value
    function sub_Reset( iVar )
        % Reset
        s = cVars{iVar};
        if bCWave
            hEd(iVar).Value = cwave.GetDfltFor( s );
        else
            hEd(iVar).Value = oWave.(s);
        end
        
        % If it now equals its special button state, make that button be
        % selected. If not, make sure the button is NOT selected
        if ~isempty( oWave.stVarInfo.(s).sSpecialBtn )
            bValue = isequal( cSpecialValue{iVar}, hEd(iVar).Value );
            if hSpcBtn(iVar).Value ~= bValue
                hSpcBtn(iVar).Value = bValue;
                sub_SpecialBtnToggle( iVar );
            end
        end
        return;
    end % sub_Reset
    
    %---------------------------------------------------------------------------
    % The "special" button for an edit has been toggled
    function sub_SpecialBtnToggle( iVar )
        hEd(iVar).Enable    = ~hSpcBtn(iVar).Value;
        hEd(iVar).Editable  = ~hSpcBtn(iVar).Value;
        if hSpcBtn(iVar).Value
            hEd(iVar).Value = cSpecialValue{iVar};
        end
        return;
    end % sub_SpecialBtnToggle
    
    %---------------------------------------------------------------------------
    % The "Help" button for an edit has been toggled
    function sub_Help( iVar )
        uialert( hFig, oWave.stVarInfo.(cVars{iVar}).sHelp, sTitle, 'Icon', 'info' );
        return;
    end % sub_Help

end % UIEditVars
