function UIVProfiles( oWave )
% cwave::UIVProfiles( oWave )
%
% Edit UI for the velocity profiles table, which includes tableVProfile as well
% as the cell array cVProfile so cannot use the standardized UITableEdit.m
%
% Parameters:
%   oWave - the controlling cwave instance
% Returns:
%-------------------------------------------------------------------------------
% Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
%-------------------------------------------------------------------------------

    % Misc helper variables
    %
    % NB: I cannot put a button into uitable for importing velocity profile
    % tables so I have a fixed number of velocity profiles that I support -
    % purely for coding convenience. It's seems very unlikely more than a few
    % will ever be required.
    nCntEditRows        = 4;
    cVPFile             = cell(nCntEditRows,1); % filenames of imported profiles (for log)
    nRowClrs            = [0 0 1;1 0 0;0 0.7 0;0.7 0 0.7];
    tblBlankVP = table( 'Size', [0 2] ...
        , 'VariableNames', {'Depth', 'Velocity'} ...
        , 'VariableTypes', {'double', 'double'} ...
        );
    
    % Build the UI
    hFig = uifigure( 'Name', 'Edit Velocity Profiles', 'WindowStyle', 'modal' ...
        , 'Visible', false, 'Resize', true, 'Units', 'pixels' ...
        , 'Position', [1 1 1200 600] );
    figCenter( oWave.hFig, hFig );
    
    % General grid for all the zones
    hG = uigridlayout( hFig );
    hG.RowHeight        = {'fit','1x',cwave.BtnHt};
    hG.ColumnWidth      = {'1x','2x'};
    hG.ColumnSpacing    = 5;
    hG.RowSpacing       = 5;
    hG.Padding          = [10 10 10 20];
    
    % Instructions line
    h = uilabel( 'Parent', hG, 'WordWrap', 'on', 'FontSize', cwave.FontSize + 2 ...
        , 'Text', [
        'INSTRUCTIONS: WAVE supports multiple velocity profiles covering ' ...
        'unique stretches of time. For example when deployment and recovery ' ...
        'are done from different ships separated in time or when the local ' ...
        'water column is sufficiently disturbed by a passing storm to cause ' ...
        'significant changes in the velocity profile with depth. If you have ' ...
        'only one profile, the coverage dates are irrelevant. If you have 2+ ' ...
        'then the dates cannot overlap.'
        ]);
    h.Layout.Column     = [1 numel(hG.ColumnWidth)];
    
    % Plot axis
    hPlot = uiaxes( 'Parent', hG, 'FontSize', cwave.FontSize, 'Box', 'on' );
    hVP   = plot(hPlot,NaN,NaN); % will be an array of line objects
    
    % Fixed entry fields
    hGE = uigridlayout( hG );
    hGE.RowHeight       = [repmat({cwave.BtnHt},1,nCntEditRows+1) {'1x'}];
    hGE.ColumnWidth     = {'1x','1x','1x',cwave.BtnWd,cwave.BtnWd};
    hGE.ColumnSpacing   = 5;
    hGE.RowSpacing      = 5;
    hGE.Padding         = [0 0 0 0];
    uilabel( 'Parent', hGE, 'Text', 'Name' ...
        , 'FontWeight', 'bold', 'FontSize', cwave.FontSize + 2 ...
        , 'HorizontalAlignment', 'center' );
    uilabel( 'Parent', hGE, 'Text', 'Date From' ...
        , 'FontWeight', 'bold', 'FontSize', cwave.FontSize + 2 ...
        , 'HorizontalAlignment', 'center' );
    uilabel( 'Parent', hGE, 'Text', 'Date To' ...
        , 'FontWeight', 'bold', 'FontSize', cwave.FontSize + 2 ...
        , 'HorizontalAlignment', 'center' );
    uilabel( 'Parent', hGE, 'Text', '' );
    uilabel( 'Parent', hGE, 'Text', '' );
    cVP = oWave.cVProfile;
    for iRow = 1:nCntEditRows  %#ok<*FXUP>
        if iRow <= height( oWave.tableVProfile )
            sName       = oWave.tableVProfile.Name(iRow);
            dFrom       = oWave.tableVProfile.DateFrom(iRow);
            dTo         = oWave.tableVProfile.DateTo(iRow);
        else
            sName       = '';
            dFrom       = NaT;
            dTo         = NaT;
            cVP{iRow}   = tblBlankVP;
        end
        
        % NB: Do NOT allow the system-supplied Valeport velocity profile's name
        % to be edited
        hName(iRow) = uieditfield( 'Parent', hGE, 'Value', sName ...
            , 'FontSize', cwave.FontSize, 'FontColor', nRowClrs(iRow,:) ...
            , 'ValueChangedFcn', @(~,~)sub_NameChg(iRow) ...
            , 'Editable', iif( strcmpi( sName, cwave.sVProfile_Valeport ), 'off', 'on' ) ...
            );
        hDtFr(iRow) = uidatepicker( 'Parent', hGE, 'Value', dFrom ...
            , 'FontSize', cwave.FontSize ... , 'FontColor', nRowClrs(iRow,:) ...
            );
        hDtTo(iRow) = uidatepicker( 'Parent', hGE, 'Value', dTo ...
            , 'FontSize', cwave.FontSize... , 'FontColor', nRowClrs(iRow,:) ...
            );
        hBtnP(iRow) = uibutton( 'Parent', hGE, 'FontSize', cwave.FontSize ...
            , 'Text', 'Profile', 'Icon', w_IconLib('Import') ...
            , 'ButtonPushedFcn', @(~,~)sub_Profile(iRow) ...
            );
        hBtnP(iRow) = uibutton( 'Parent', hGE, 'FontSize', cwave.FontSize ...
            , 'Text', 'Reset', 'Icon', w_IconLib('Eraser') ...
            , 'ButtonPushedFcn', @(~,~)sub_Reset(iRow) ...
            );
    end
    
    % Plot the velocity profiles
    sub_Plot();
    
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
    
    % Make the figure visible and run the MODAL figure
    hFig.Visible = true;
    hFig.CloseRequestFcn = @sub_Cancel;
    waitfor( hFig );
    return;
    
    %---------------------------------------------------------------------------
    function sub_Cancel(~,~)
        delete( hFig );
        return;
    end % sub_Cancel
    
    %---------------------------------------------------------------------------
    function sub_Save(~,~)
        % Pull together the input data
        tblOut = cwave.GetDfltFor( 'tableVProfile' );
        cVPOut = {};
        for iRow = 1:nCntEditRows
            % NB: uidatepicker controls do not allow entry of times (so
            % frustrating). So make all 'from' begin at midnight and all 'to'
            % end at midnight
            sName   = hName(iRow).Value;
            dFrom   = hDtFr(iRow).Value + duration(0,0,0,0);
            dTo     = hDtTo(iRow).Value + duration(23,59,59,999);
            tblVP   = cVP{iRow};
            bEmpty  = [isempty(sName) isnat(dFrom) isnat(dTo) isempty(tblVP)];
            if all( bEmpty )
                continue;
            end
            tblOut{end+1,:} = missing();
            tblOut.Name(end) = sName;
            tblOut.DateFrom(end) = dFrom;
            tblOut.DateTo(end) = dTo;
            cVPOut{end+1} = tblVP;
        end
        if isempty( tblOut )
            uialert( hFig, 'There are no velocity profiles.', 'Edit Velocity Profiles' );
            return;
        end
        
        % Validate each velocity profile through the default validator
        %-- If only one row, datefrom & dateto may be NaT
        %-- No date ranges may overlap
        [bOK,cErrMsg] = cwave.ValidateVelProfile( tblOut, hFig, false );
        if ~all(bOK)
            uialert( hFig, cErrMsg, 'Edit Velocity Profiles' );
            return;
        end
        
        %-- Don't allow an empty velocity profile table
        bEmpty = cellfun( @isempty, cVPOut );
        if any( bEmpty )
            iFirst = find( bEmpty, 1, 'first' );
            uialert( hFig, ['The velocity profile table for ' tblOut.Name(iFirst) ' is empty.'] ...
                , 'Edit Velocity Profiles' );
            return;
        end
        
        % Log any import filenames
        for iRow = 1:nCntEditRows
            if ~isempty( cVPFile{iRow} )
                oWave.AddLog( cwave.LogOK, cwave.sLog_RxVProfile ...
                    , ['Profile ' hName(iRow).Value ' imported from ' cVPFile{iRow}] );
            end
        end
        
        % Update the internal table & cell array (table last because of
        % listeners)
        oWave.AddLog( cwave.LogOK, cwave.sLog_RxVProfile, 'User edited velocity profiles' );
        oWave.cVProfile     = cVPOut;
        oWave.tableVProfile = tblOut;
        
        % Close the dialog
        delete( hFig );
        
        return;
    end % sub_Save
    
    %---------------------------------------------------------------------------
    % Plot all the velocity profiles
    function sub_Plot()
        % Plot each velocity profile in the correct color
        for iRow = 1:nCntEditRows 
            tblVP       = cVP{iRow};
            if isempty( tblVP )
                tblVP{1:2,:} = missing();
            end
            hVP(iRow)   = plot( hPlot, tblVP.Velocity, tblVP.Depth ...
                , 'Marker', 'none', 'LineStyle', '-', 'LineWidth', 1 ...
                , 'Color', nRowClrs(iRow,:) ...
                , 'DisplayName', hName(iRow).Value ...
                );
            hold( hPlot, 'on' );
        end
        hold( hPlot, 'off' );
        hPlot.YDir = 'reverse';
        grid( hPlot, 'on' );
        axisTight( hPlot );
        xlabel( hPlot, 'Velocity (m/s)' );
        ylabel( hPlot, 'Depth (m)' );
        legend( hPlot, 'Location', 'best' );
        return;
    end % sub_Plot
    
    %---------------------------------------------------------------------------
    % The name of a profile changed, update in the plot
    function sub_NameChg( iRow )
        % Make sure beg/end spaces are gone
        sName = strtrim( hName(iRow).Value );
        if ~isequal( hName(iRow).Value, sName )
            hName(iRow).Value = sName;
        end
        
        % Update the plot line's name
        hVP(iRow).DisplayName = sName;
        
        return;
    end % sub_NameChg
    
    %---------------------------------------------------------------------------
    % Handle the "Reset" button for one velocity profile
    function sub_Reset( iRow )
        % The built-in Valeport row cannot be reset
        sName = strtrim( hName(iRow).Value );
        if strcmpi( sName, cwave.sVProfile_Valeport )
            uialert( hFig, {
                'The built-in Valeport velocity profile, which is '
                'derived from SUESI processing, cannot be deleted. '
                ''
                'If you want to use a different velocity profile '
                'in the navigation, then set the Valeport''s "From" '
                'and "To" dates to times outside the survey.'
                }, 'Valeport Profile cannot be Reset', 'Icon', 'info' );
            return;
        end
        
        % Reset the entry fields, velocity profile table, and plot line
        hName(iRow).Value       = '';
        hDtFr(iRow).Value       = NaT;
        hDtTo(iRow).Value       = NaT;
        cVP{iRow}               = tblBlankVP;
        hVP(iRow).DisplayName   = sName;
        set( hVP(iRow), 'XData', NaN, 'YData', NaN );
        return;
    end % sub_Reset
    
    %---------------------------------------------------------------------------
    % Handle the "Profile" button for one velocity profile
    function sub_Profile( iRow )
        % Call the general table edit UI
        [bOK, tblNew, sInFile] = UITableEdit( cVP{iRow}, hFig ...
            , ['Velocity profile for ' hName(iRow).Value], {
            'Create a table of depths (m) and velocities (m/s).'
            }, @ValidateVP, @VProf_Reset ...
            , {'Add', 'Delete', 'Import'} ...
            );
        if ~bOK
            return;
        end
        
        % Keep track of the file imported
        if ~isempty( sInFile )
            cVPFile{iRow} = sInFile;
            
            % Change the name to the filename
            [~,sF] = fileparts( sInFile );
            hName(iRow).Value       = sF;
            hVP(iRow).DisplayName   = sF;
        end
        
        % Update the internal table and the plot line
        cVP{iRow} = tblNew;
        if isempty( tblNew )    % user deleted all entries (sneaky bastard)
            set( hVP(iRow), 'XData', NaN, 'YData', NaN );
        else
            set( hVP(iRow), 'XData', tblNew.Velocity, 'YData', tblNew.Depth );
        end
        
        return;
        
        %-----------------------------------------------------------------------
        % "Reset" function for UITableEdit call above
        function VProf_Reset( hTable )
            hTable.Data = tblBlankVP;
            return;
        end % VProf_Reset
    end % sub_Profile
    
end % UIVProfiles

%-------------------------------------------------------------------------------
% Validate the Depth, Velocity table for a single velocity profile
function [bOK,cErrMsg] = ValidateVP( tData, ~, ~ ) % hUIFig, bQuery )
    cErrMsg = '';   % default a return value
    
    % Table cannot be empty
    if isempty( tData )
        bOK = false;
        cErrMsg = {'The Velocity table cannot be empty.'};
        return;
    end
    
    % Table cannot contain NaNs or missing values
    bOK = ~isnan( tData.Depth ) & ~isnan( tData.Velocity );
    if ~all( bOK )
        cErrMsg = {'Velocity profile cannot contain NaNs.'};
        return;
    end
    
    % Depths must be positive
    bOK = tData.Depth >= 0;
    if ~all( bOK )
        cErrMsg = {'Velocity depths must be >= 0.'};
        return;
    end
    
    % Data must be in depth order
    bOK = diff( tData.Depth ) > 0;
    bOK(end+1) = bOK(end);  % diff() shortens by one
    if ~all( bOK )
        cErrMsg = {'Depths must be increasing.'};
        return;
    end
    
    % Velocities must be positive and generally > 1400 m/s in water
    bOK = tData.Velocity > 1400;
    if ~all( bOK )
        cErrMsg = {'Velocities must be positive and in m/s units.'};
        return;
    end
    
    return
end % ValidateVP
