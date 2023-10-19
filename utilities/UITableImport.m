function [bOK, tData, sFile] = UITableImport( tData, hParent, sTitle, fcnValid )
% Import data into a table from a file. Used mostly by UITableEdit but available
% to smart users externally
%
% Params:
%   tData    - table to import into. It it's not empty, it will be cleared
%               before data are imported into it
%   hParent  - handle of uifigure to center over
%   sTitle   - figure title
%   fcnValid - Are the table rows valid: [bOK,cErrMsg(,tbl)]=fcn(tbl,hFig,bAsk)
%               bOK must have the same number of rows as table and will be
%               used to color errant rows red. hFig is this figure.
%               bAsk is true if it's OK for fcnValid to ask the user questions.
%               fcnValid MAY return a 3rd arg which is the updated table. This
%               is for e.g. converting Lon,Lat cols to E,N cols
% Returns:
%   bOK     - True if save, False if cancel
%   tData   - edited table
%   sFile   - path+filename of file imported from
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
% See also UITablePlot, UITableEdit
    persistent sLastImport
    if isempty( sLastImport )
        sLastImport = fullfile( pwd(), '*' );
    end

    % Default the return variables
    bOK   = false;
    sFile = '';
    
    % If the current table is not empty, drop all its rows but keep its setup so
    % that missing() still works on it.
    if height( tData ) > 1
        tData(1:end,:) = [];
    end

    % Get the path + filename to import from
    [sF,sP] = uigetfile( {
        '*.mat;*.txt;*.dat;*.csv;*.xls;*.xlsx;*.xlsb;*.xlsm;*.xltm;*.ods', 'Columnar Text or Spreadsheet'
        '*', 'All Files'
        }, ['Import ' sTitle ' from:'], sLastImport );
    if ~ischar(sF)
        return
    end
    sLastImport = fullfile( sP, sF );
    sFile = sLastImport;
    
    % NB: MatLab figures out text vs spreadsheet by the extension alone. If it
    % doesn't know the extension (from a very short list) then it bombs.
    % Scientists (esp those who use Macs) don't give a rat's whisker about
    % extension so I need to *force* text except in a few cases where I know for
    % sure that it's a spreadsheet. Sigh.
    [~,~,sExt] = fileparts( sF );   % get the extension
    if strcmpi( sExt, '.mat' )
        sType = 'mat';
    elseif ismember( lower(sExt), {'.xls','.xlsx','.xlsb','.xlsm','.xltm','.ods'} )
        sType = 'spreadsheet';
    else
        sType = 'text'; % covers both fixed width & delimited
    end
    
    % Can this file be read with readtable? If so, get it's field structure and
    % some data rows to display
    stWarn = warning( 'off', 'MATLAB:table:ModifiedAndSavedVarnames' );
    oDone  = onCleanup( @()warning(stWarn) );
    try
        if strcmpi( sType, 'mat' )
            % Import from .mat should look for 'cols' or 'col' struct and a MxN
            % array with the right number of cols. If no colstruct, take the
            % largest MxN array, if there is one. If not, complain & exit
            m       = matfile( sFile );
            cVars   = who( m );
            iAt     = find( ismember( cVars, {'col','cols'} ), 1, 'first' );
            if ~isempty(iAt)
                col     = m.(cVars{iAt});
                cFlds   = reshape( fieldnames(col), 1, [] );
                if numel(cFlds) ~= col.(cFlds{end})
                    cFlds = {};
                end
            else
                cFlds = {};
            end
            nColCnt = size(cFlds,2);
            nMaxRow = 0;
            iAt = 0;
            for i = 1:numel(cVars)
                nSz = size( m.(cVars{i}) );
                if numel(nSz) == 2 && (nColCnt == 0 || nSz(2) == nColCnt) && nSz(1) > nMaxRow
                    iAt     = i;
                    nMaxRow = nSz(1);
                end
            end
            assert( iAt > 0, 'MAT file doesn''t have MxN array and col structure' );
            
            % Just read the first 20 rows as a sample
            sDataVar = cVars{iAt};
            if isempty( cFlds )
                tSample = array2table( m.(sDataVar)(1:min(nMaxRow,20),:) );
                cFlds   = reshape( tSample.Properties.VariableNames, 1, [] );
            else
                tSample = array2table( m.(sDataVar)(1:min(nMaxRow,20),:) ...
                    , 'VariableNames', cFlds );
            end
        else
            % MatLab's detection isn't amazing. If a column has a bunch of rows
            % that are all numeric then later one which is alphanum, it will
            % assume the col is numeric and NaN the others. This is not great
            % for things like receiver name which is often like '101' but may
            % have later '329b'. Look for a "Name" column and force it to be
            % char.
            opts = detectImportOptions( sFile, 'FileType', sType );
            for cTry = {'Name', 'name', 'RxName', 'rxname'}
                if ismember( cTry{1}, opts.VariableNames )
                    opts = setvartype( opts, cTry{1}, 'char' );
                end
            end
            
            if isfield( opts, 'DataLines' ) % spreadsheets don't have this
                opts.DataLines(2) = opts.DataLines(1) + 19;
                tSample = readtable( sFile, opts );
                opts.DataLines(2) = Inf;    % reset for full read later on
            else
                tSample = readtable( sFile, opts );
            end
        end
    catch Me
        uialert( hParent, {
            ['Unable to detect file type for import. The file must be readable ' ...
            'by readtable() or be a .mat file with an MxN array and optionally ' ...
            'a "col" or "cols" column structure with column names.']
            ''
            sFile
            ''
            Me.identifier
            Me.message
            }, 'Table Import Error' );
        return;
    end
    
    % Create the import table info
    sTagMiss        = 'missing()';
    sTagExpr        = 'expression';
    cFldMatch       = tData.Properties.VariableNames.';
    cFldMatch(:,2)  = {sTagMiss};
    cFldMatch(:,3)  = {''};
    if strcmpi( sType, 'mat' )
        cInOpts     = [{sTagMiss, sTagExpr} cFlds];
    else
        cInOpts     = [{sTagMiss, sTagExpr} opts.VariableNames];
    end
    
    % Create the UI to allow for field matching
    hFig = uifigure( 'Name', ['IMPORT into ' sTitle] ...
        , 'Visible', false, 'WindowStyle', 'modal', 'Resize', true ...
        , 'Units', 'pixels', 'Position', [1 1 1200 800] ...
        );
    figCenter( hParent, hFig );
    
    % General grid for all the zones
    hG = uigridlayout( hFig );
    hG.RowHeight    = {'fit', '1x', 2*cwave.BtnHt, cwave.BtnHt, '1x', cwave.BtnHt, '1x', cwave.BtnHt};
    hG.ColumnWidth  = {'1x'};
    hG.ColumnSpacing= 0;
    hG.RowSpacing   = 10;
    hG.Padding      = [10 10 10 10];
    
    uilabel( 'Parent', hG, 'FontSize', cwave.FontSize + 2, 'WordWrap', true, 'Text', [
        'INSTRUCTIONS: Match variables from the import file into the table. ' ...
        'Some variables can be left as "missing()". If you need to combine ' ...
        'or manipulate variables in the import file, select "expression" and ' ...
        'create a matlab expression using "t.variable". "t" is ' ...
        'an internal copy of the table to work with and "variable" is any one of ' ...
        'the variable names that are shown in the input file sample table below. ' ...
        'For example: -1 * (t.Var4 + t.Var5/60)'
        ] );
    
    htblMatch = uitable( 'Parent', hG, 'FontSize', cwave.FontSize ...
        , 'Data', cFldMatch ...
        , 'RowName', {} ...
        , 'ColumnName', {'Import Into', 'From', 'Expression'} ...
        , 'ColumnEditable', [false true true] ...
        , 'ColumnFormat', {'char', cInOpts, 'char'} ...
        , 'CellEditCallback', @sub_CellEdit ...
        );
    hlblErr = uilabel( 'Parent', hG, 'FontSize', cwave.FontSize + 2 ...
        , 'FontColor', 'r', 'BackgroundColor', 'w', 'Text', '' );
    
    uilabel( 'Parent', hG, 'FontSize', cwave.FontSize + 2, 'Text', 'Input File (Sample)' );
    uitable( 'Parent', hG, 'FontSize', cwave.FontSize ...
        , 'Data', tSample, 'RowName', {}, 'ColumnEditable', false );
    
    uilabel( 'Parent', hG, 'FontSize', cwave.FontSize + 2, 'Text', 'Output Table (Sample)' );
    htblOut = uitable( 'Parent', hG, 'FontSize', cwave.FontSize ...
        , 'Data', tData, 'ColumnEditable', false );
    
    % Action buttons
    hGB = uigridlayout( hG );
    hGB.RowHeight       = {'1x'};
    hGB.ColumnWidth     = {'1x', cwave.BtnWd, cwave.BtnWd};
    hGB.ColumnSpacing   = 0;
    hGB.RowSpacing      = 0;
    hGB.Padding         = [0 0 0 0];
    uilabel( 'Parent', hGB, 'Text', '' ); % dummy fill
    uibutton( 'Parent', hGB, 'FontSize', cwave.FontSize, 'Text', 'Import' ...
        , 'ButtonPushedFcn', @sub_Import );
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
    function sub_Import(~,~)
        % Read & convert the entire file. Bail if errors
        try
            if strcmpi( sType, 'mat' )
                tMat = array2table( m.(sDataVar), 'VariableNames', cFlds );
                [tFill, cErrMsg] = sub_Fill( tMat );
            else
                [tFill, cErrMsg] = sub_Fill( readtable( sFile, opts ) );
            end
        catch Me
            cErrMsg = ['Error during import: ' Me.identifier '::' Me.message];
        end
        if ~isempty( cErrMsg )
            uialert( hFig, cErrMsg, 'Import' );
            return;
        end
        
        % Validate
        if nargout(fcnValid) == 3 % some validations rtn an updated table
            [bChk,cErrMsg,tUpdt] = fcnValid( tFill, hFig, true ); % true = OK to ask questions
            if ~isempty(tUpdt)
                tFill = tUpdt;
            end
        else
            [bChk,cErrMsg] = fcnValid( tFill, hFig, true ); % true = OK to ask questions
        end
        if ~all( bChk )
            % NB: show the first N data lines from the file that have this
            % problem so the user can fix things if they want
            uialert( hFig, [{
                'Imported data fails validation:'
                ''
                }
                cErrMsg
                {
                ''
                ['Data lines: ' num2str(reshape( find( ~bChk, 5 ), 1, [] )) '...']
                }
                ], 'Import' );
            return;
        end
        
        % Done. Save data & close the UI
        tData   = tFill;
        bOK     = true;
        delete( hFig );
        
        return;
    end % sub_Import
    
    %---------------------------------------------------------------------------
    % User made a change in the field matching table. Update the sample
    function sub_CellEdit(~,oInfo)
        % If the "from" column changed, possibly need to clear the expression
        if oInfo.Indices(2) == 2
            if ~strcmpi( htblMatch.Data{oInfo.Indices(1),2}, sTagExpr )
                htblMatch.Data{oInfo.Indices(1),3} = '';
            end
        else
            % The user has just typed an expression. Make sure that the field
            % type is set to "expression"
            if ~isempty( htblMatch.Data{oInfo.Indices(1),3} ) ...
            && ~strcmpi( htblMatch.Data{oInfo.Indices(1),2}, sTagExpr )
                htblMatch.Data{oInfo.Indices(1),2} = sTagExpr;
            end
        end
        
        % Re-evaluate the input on the input sample and fill the output sample
        [tFill, cErrMsg] = sub_Fill( tSample );
        if isempty( cErrMsg )         % No expression errors. Try validating
            if nargout(fcnValid) == 3 % NB: some validations rtn an updated table
                [~,cErrMsg,tUpdt] = fcnValid( tFill, hFig, true );
                if ~isempty(tUpdt)
                    tFill = tUpdt;
                end
            else
                [~,cErrMsg] = fcnValid( tFill, hFig, false ); % false = DON'T ask questions
            end
        end
        htblOut.Data = tFill;
        hlblErr.Text = cErrMsg;
        
        return;
    end % sub_CellEdit
    
    %---------------------------------------------------------------------------
    % Convert the given input table (which may just be a short sample or the
    % whole thing) into the output table using the rules currently in the field
    % matching table. Return any errors.
    function [tOut, cErrMsg] = sub_Fill( t )
        % Initialize the output table with all "missing()" values
        tOut = copytable( tData, height(t) );
        
        % Pull the current set of field rules and execute them one at a time
        cErrMsg = {};
        cFld = htblMatch.Data;
        for iVar = 1:size(cFld,1)
            if strcmpi( cFld{iVar,2}, sTagMiss )
                continue;
            end
            try
                % NB: the "(:)" is VERY important below because it forces MatLab
                % to do a type conversion into the destination's type. Without
                % it, strings can become cell arrays (which blow up missing())
                if strcmpi( cFld{iVar,2}, sTagExpr )
                    if ~isempty( cFld{iVar,3} )
                        tOut.(cFld{iVar,1})(:) = eval( cFld{iVar,3} );
                    end
                elseif isdatetime( tOut.(cFld{iVar,1})(1) ) ...
                    && isnumeric(t.(cFld{iVar,2})(1))
                    % MatLab R2020b doesn't automatically convert datenum to
                    % datetime. Weird.
                    tOut.(cFld{iVar,1})(:) = datetime( t.(cFld{iVar,2})(:) ...
                        , 'ConvertFrom', 'datenum' );
                else
                    tOut.(cFld{iVar,1})(:) = t.(cFld{iVar,2})(:);
                end
            catch Me
                cErrMsg{end+1,1} = ['Error field "' cFld{iVar,1} '": ' Me.identifier];
            end
        end
        
        return;
    end % sub_Fill
    
end % UITableImport
