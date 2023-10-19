function [bOK, tData, sInFile] = UITableEdit( tData, hParent, sTitle, sDesc, fcnValid, fcnReset, cBtns, varargin )
% Simple editor for a table of data
%
% Params:
%   table    - table to display
%   hParent  - handle of uifigure to center over
%   sTitle   - figure title
%   sDesc    - multi-line text description to show in the top of the dialog for
%               the user's instruction
%   fcnValid - Are the table rows valid: [bOK,cErrMsg(,tbl)]=fcn(tbl,hFig,bAsk)
%               bOK must have the same number of rows as table and will be
%               used to color errant rows red. hFig is the UITableEdit figure.
%               bAsk is true if it's OK for fcnValid to ask the user questions.
%               fcnValid MAY return a 3rd arg which is the updated table. This
%               is for e.g. converting Lon,Lat cols to E,N cols
%   fcnReset - fcn( uitable ). User fcn to reset the table. It should directly 
%               modify the uitable object's .data property
%   cBtns    - list of buttons. Valid: Add, Delete, Import
%   varargin - 'name','value' pairs to pass to uitable object when it is created
% Returns:
%   bOK     - True if save, False if cancel
%   table   - edited table
%   sInFile - path+filename of file if IMPORT was used to edit the table
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
% See also UITablePlot, UITableImport

    % Default the return values
    bOK     = false;
    sInFile = '';
    
    % Which buttons are OK for this dialog
    bCanAddRow = ismember( 'Add', cBtns );
    bCanDelRow = ismember( 'Delete', cBtns );
    bCanImport = ismember( 'Import', cBtns );
    
    % Create the UI elements
    hFig = uifigure( 'Name', sTitle ...
        , 'Visible', false, 'WindowStyle', 'modal', 'Resize', true ...
        , 'Units', 'pixels', 'Position', [1 1 800 600] ...
        );
    figCenter( hParent, hFig );
    
    % General grid for all the zones
    hG = uigridlayout( hFig );
    hG.RowHeight    = {'fit', cwave.BtnHt, '1x', cwave.BtnHt};
    hG.ColumnWidth  = {'1x'};
    hG.ColumnSpacing= 0;
    hG.RowSpacing   = 5;
    hG.Padding      = [10 10 10 10];
    
    uilabel( 'Parent', hG, 'FontSize', cwave.FontSize, 'WordWrap', true, 'Text', sDesc );
    
    % Table-related button row needs sub-dividing
    hGB = uigridlayout( hG );
    hGB.RowHeight       = {'1x'};
    hGB.ColumnWidth     = {cwave.BtnWd, cwave.BtnWd, cwave.BtnWd, '1x', cwave.BtnWd};
    hGB.ColumnSpacing   = 0;
    hGB.RowSpacing      = 0;
    hGB.Padding         = [0 0 0 0];
    if bCanImport
        uibutton( 'Parent', hGB, 'FontSize', cwave.FontSize, 'Text', 'Import' ...
            , 'Icon', w_IconLib('Import'), 'ButtonPushedFcn', @sub_Import );
    end
    if bCanAddRow
        uibutton( 'Parent', hGB, 'FontSize', cwave.FontSize, 'Text', 'Add Row' ...
            , 'Icon', w_IconLib('AddRow'), 'ButtonPushedFcn', @sub_AddRow );
    end
    if bCanDelRow
        uibutton( 'Parent', hGB, 'FontSize', cwave.FontSize, 'Text', 'Delete Row' ...
            , 'Icon', w_IconLib('DelRow'), 'ButtonPushedFcn', @sub_DelRow );
    end
    if isa( fcnReset, 'function_handle' )
        h = uibutton( 'Parent', hGB, 'FontSize', cwave.FontSize, 'Text', 'Reset' ...
            , 'Icon', w_IconLib('Eraser'), 'ButtonPushedFcn', @sub_Reset );
        h.Layout.Column = numel(hGB.ColumnWidth);
    end
    
    % Define the table
    iTblSelect = [];
    if isempty( varargin )
        hTable = uitable( 'Parent', hG, 'FontSize', cwave.FontSize ...
            , 'Data', tData, 'CellSelectionCallback', @sub_TrackSlctn ...
            , 'ColumnEditable', true );
    else
        hTable = uitable( 'Parent', hG, 'FontSize', cwave.FontSize ...
            , 'Data', tData, 'CellSelectionCallback', @sub_TrackSlctn ...
            , 'ColumnEditable', true ...
            , varargin{:} );
    end
    
    % Dialog button row needs sub-dividing
    hGB = uigridlayout( hG );
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
        bOK = false;
        delete( hFig );
        return;
    end % sub_Cancel
    
    %---------------------------------------------------------------------------
    function sub_Save(~,~)
        % Validate the table
        if nargout(fcnValid) == 3 % some validations rtn an updated table
            [bChk,cErrMsg,tChg] = fcnValid( hTable.Data, hFig, true );
            if ~isempty(tChg)
                hTable.Data = tChg;
            end
        else
            [bChk,cErrMsg] = fcnValid( hTable.Data, hFig, true ); % true = OK to ask questions
        end
        if ~all( bChk )
            % Color bad rows
            removeStyle( hTable );
            addStyle( hTable, uistyle( 'FontColor', cwave.nClrError ) ...
                , 'row', reshape( find( ~bChk ), 1, [] ) );
            
            % Scroll to the first non-valid row.
            iBadRow = find( ~bChk, 1, 'first' );
            scrollR2020b( hTable, 'row', iBadRow );
            
            % Show the error message. NB: if cErrMsg is empty, then assume the
            % validation function has already explained matters to the user
            if ~isempty( cErrMsg )
                uialert( hFig, cErrMsg, 'Error', 'Icon', 'error', 'Modal', true );
            end
            
            % return early
            return;
        end
        
        % Take the data from the table and update the table object. Note that
        % sub_AddRow & sub_DelRow MUST keep the number & order of rows
        % synchronized between this return table and the uitable object.
        tData = hTable.Data;
        
        % If we get here, everything is OK
        bOK = true;
        delete( hFig );
        return;
    end % sub_Save
    
    %---------------------------------------------------------------------------
    % Activate the caller's reset function - might clear the table or might just
    % reset some values. Both are valid.
    function sub_Reset(~,~)
        fcnReset( hTable );
        sInFile = '';   % reset the filename imported from - import erased
        return;
    end
    
    %---------------------------------------------------------------------------
    % Add a new row to the bottom of the table
    function sub_AddRow(~,~)
        hTable.Data{end+1,:} = missing();
        scrollR2020b( hTable, 'row', size(hTable.Data,1) );
        return;
    end % sub_AddRow
    
    %---------------------------------------------------------------------------
    % User wants to delete the currently selected rows
    function sub_DelRow(~,~)
        if isempty( iTblSelect )
            uialert( hFig, 'No rows selected', 'Delete Rows' );
            return;
        end
        iRows = unique( iTblSelect(:,1) );  % dim(n,2) [row col;... row col] pairs
        hTable.Data(iRows,:) = [];
        return;
    end % sub_DelRow

    %---------------------------------------------------------------------------
    % Track selection events because the stupid uitable class does NOT give you
    % a way to find out what is currently selected. How dumb is that?
    function sub_TrackSlctn(~,st)
        iTblSelect = st.Indices;
        return;
    end % sub_TrackSlctn
    
    %---------------------------------------------------------------------------
    % Run the generic import from a file which can be read by readtable 
    function sub_Import(~,~)
        % Run the import UI
        [bOK, tNew, sFile] = UITableImport( tData, hFig, sTitle, fcnValid );
        if ~bOK
            return;
        end
        
        % Data imported & validated. Add to or replace the UI's copy
        % Ask about adding to or replacing the existing table
        if height( hTable.Data ) >= 1
            switch( uiconfirm( hFig, {
                    sprintf( 'There are %d rows currently in the table.', height( hTable.Data ))
                    'Do you want to Add To the existing list or Replace it?'
                    }, 'Add or Replace?', 'Options', {'Add To', 'Replace', 'Cancel'} ...
                    , 'DefaultOption', 1, 'CancelOption', 3 ) )
            case 'Add To'
                tNew = [hTable.Data; tNew];
                
                % If the first column is either a string or datetime, then sort
                % based on it
                if isstring(tNew(1,1)) || isdatetime(tNew(1,1))
                    tNew = sortrows( tNew, 1 );
                end
                
            case 'Replace'
                % Nothing to do. Replace existing table
            otherwise
                return;
            end
        end
        
        % Update the UI
        sInFile     = sFile;
        hTable.Data = tNew;
        
        return;
    end % sub_Import
    
end % UITableEdit
