function TxNavEdit( oWave )
% cwave::TxNavEdit( oWave )
%
% Manage editing tableTxNav on multiple tabs
%
% Parameters:
%   oWave - the controlling cwave instance
% Returns:
%-------------------------------------------------------------------------------
% Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
%-------------------------------------------------------------------------------

    % Call the general table edit UI
    [bOK, tblNew, sInFile] = UITableEdit( oWave.tableTxNav, oWave.hFig ...
        , 'TX Navigation Time Series', {
        'Import the TX Nav time series from external iLBL sources.' ...
        }, @WrapValidate, @TxNav_Reset ...
        , {'Add', 'Delete', 'Import'} ...
        );
    if ~bOK
        return;
    end
    
    % User updated the table. Log & update
    if isempty( sInFile )
        oWave.AddLog( cwave.LogOK, cwave.sLog_TxNav, 'User edited TX nav table.' );
    else
        oWave.AddLog( cwave.LogOK, cwave.sLog_TxNav ...
            , ['User IMPORTED TX nav table from: ' sInFile] );
    end
    oWave.tableTxNav = tblNew;
    
    return;
    
    %---------------------------------------------------------------------------
    % "Reset" function for UITableEdit call above
    function TxNav_Reset( hTable )
        hTable.Data = cwave.GetDfltFor( 'tableTxNav' );
        return;
    end % TxNav_Reset
    
    %---------------------------------------------------------------------------
    % Wrapper around cwave.ValidateTxNav so I can convert E,N to LL and vice
    % versa without forcing the user to do this manually
    function [bOK,cErrMsg,tOut] = WrapValidate( tData, hUIFig, bQuery )
        tOut        = [];
        bTblUpdt    = false;
        
        % Where do I have one (L,L or E,N) but not the other?
        bMissingLL  = isnan( tData.Longitude ) | isnan( tData.Latitude );
        bMissingEN  = isnan( tData.East ) | isnan( tData.North );
        bLLnoEN     = ~bMissingLL & bMissingEN;
        bENnoLL     = bMissingLL & ~bMissingEN;
        
        if any(bLLnoEN)
            [tData.East(bLLnoEN), tData.North(bLLnoEN)] ...
                = oWave.LonLat2UTM( cwave.sLog_TxNav ...
                , tData.Longitude(bLLnoEN), tData.Latitude(bLLnoEN) );
            bTblUpdt = true;
        end
        
        if any(bENnoLL)
            [tData.Longitude(bENnoLL), tData.Latitude(bENnoLL)] ...
                = oWave.UTM2LonLat( tData.East(bENnoLL), tData.North(bENnoLL) );
            bTblUpdt = true;
        end
        
        % Now run the actual validation
        [bOK,cErrMsg] = cwave.ValidateTxNav( tData, hUIFig, bQuery );
        
        % If everything is OK *and* the table was updated, return it as the 3rd
        % parameter
        if bTblUpdt && all(bOK)
            tOut = tData;
        end
        return;
    end % WrapValidate
end % TxNavEdit
