function PlotCudaCfg( oWave )
% cwave::PlotCudaCfg( oWave )
%
% Plot helper info linking Benthos pings & Barracuda GPS positions
%
% Parameters:
%   oWave - the controlling cwave instance
% Returns:
%-------------------------------------------------------------------------------
% Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
%-------------------------------------------------------------------------------
    arguments
        oWave cwave
    end
    
    % Must have something to plot
    if isempty( oWave.tableCudaGPS ) || isempty( oWave.tableCudaCfg ) || isempty( oWave.tableBenthos )
        uialert( oWave.hFig, {
            'The Barracuda configuration plot shows helpful'
            'info to assist you in linking the benthos pings'
            '& replies with the Barracuda GPS time series.'
            'It requires that the Benthos pings, Barracuda'
            'GPS locations, and Barracuda configuration all'
            'have data. At least one is empty.'
            ' '
            'There is nothing to plot.'
            }, 'Plot Barracuda Config', 'Icon', 'error' );
        return;
    end
    
    % Figure out which Benthos pings belong to which NAVx configuration and
    % which are unassigned
    cDesc       = {};
    iGPSCfg     = zeros(height(oWave.tableCudaGPS),1);
    iPingCfg    = zeros(height(oWave.tableBenthos),1);
    for iCfg = 1:height(oWave.tableCudaCfg)
        % Get text for the legend and a date range
        if isnat(oWave.tableCudaCfg.DateFrom(iCfg))
            cDesc{iCfg} = ['NAV' num2str(oWave.tableCudaCfg.DeviceNo(iCfg))];
            [dFrom,dTo] = deal(NaT);
        else
            dFrom = oWave.tableCudaCfg.DateFrom(iCfg);
            dTo   = oWave.tableCudaCfg.DateTo(iCfg);
            cDesc{iCfg} = ['NAV' num2str(oWave.tableCudaCfg.DeviceNo(iCfg)) ...
                ' (' char(dFrom) ' to ' char(dTo) ')'];
        end
        
        % Which benthos pings belong to this config?
        if isnan(oWave.tableCudaCfg.ReplyFreq(iCfg))
            b = oWave.tableBenthos.PingFreq == oWave.tableCudaCfg.ListenFreq(iCfg) ...
                & oWave.tableBenthos.ReplyCh  == oWave.tableCudaCfg.ReplyCh(iCfg);
        else
            b = oWave.tableBenthos.PingFreq  == oWave.tableCudaCfg.ListenFreq(iCfg) ...
                & oWave.tableBenthos.ReplyFreq == oWave.tableCudaCfg.ReplyFreq(iCfg);
        end
        if ~isnat(dFrom)
            b = b & btwn( dFrom, oWave.tableBenthos.Time, dTo );
        end
        iPingCfg(b) = iCfg;
        
        % Which GPS points belong to this config?
        if isnat(dFrom)
            b = oWave.tableCudaGPS.DeviceNo == oWave.tableCudaCfg.DeviceNo(iCfg);
        else
            b = oWave.tableCudaGPS.DeviceNo == oWave.tableCudaCfg.DeviceNo(iCfg) ...
                & btwn( dFrom, oWave.tableCudaGPS.Time, dTo );
        end
        iGPSCfg(b) = iCfg;
    end
    
    % Plot helpful stuff
    nClrs = DavesDiscreteColors( height(oWave.tableCudaCfg) );
    hFig = getStackedFig( 'pptHD', 'Name', 'Barracuda Configuration' );
    hAx(1) = subplot( 3, 2, 1, 'Parent', hFig );
    hAx(2) = subplot( 3, 2, 3, 'Parent', hFig );
    hAx(3) = subplot( 3, 2, 5, 'Parent', hFig );
    hMap   = subplot( 3, 2, [2 4 6], 'Parent', hFig );
    
    for iCfg = 0:height(oWave.tableCudaCfg)
        if iCfg == 0
            sDesc = 'Unassigned';
            nClr  = [0 0 0];
        else
            sDesc = cDesc{iCfg};
            nClr  = nClrs(iCfg,:);
        end
        
        % Benthos ping info
        bPing = (iPingCfg == iCfg);
        if any( bPing )
            if iCfg == 0
                sSuffix = sprintf( ' (%d pings)', sum(bPing) );
            else
                sSuffix = '';
            end
            
            dtPing = oWave.tableBenthos.Time(bPing);
            plot( hAx(1), dtPing, oWave.tableBenthos.ReplyFreq(bPing) ...
                , '.', 'Color', nClr, 'DisplayName', [sDesc sSuffix] );
            hold( hAx(1), 'on' );
            
            plot( hAx(2), dtPing, oWave.tableBenthos.ReplyCh(bPing) ...
                , '.', 'Color', nClr, 'DisplayName', [sDesc sSuffix] );
            hold( hAx(2), 'on' );
            
            plot( hAx(3), dtPing, oWave.tableBenthos.ReplyTWTT(bPing) ...
                , '.', 'Color', nClr, 'DisplayName', [sDesc sSuffix] );
            hold( hAx(3), 'on' );
        end
        
        % Barracuda GPS Map
        bGPS = (iGPSCfg == iCfg);
        if any( bGPS )
            if iCfg == 0
                sSuffix = sprintf( ' (%d GPS pts)', sum(bGPS) );
            else
                sSuffix = '';
            end
            
            plot( hMap, oWave.tableCudaGPS.East(bGPS), oWave.tableCudaGPS.North(bGPS) ...
                , '.', 'Color', nClr, 'DisplayName', [sDesc sSuffix] );
            hold( hMap, 'on' );
        end
    end
    
    % Finish up the plot
    axisTight( hAx(1) );
    axisTight( hAx(2), 'y' );
    axisTight( hAx(3), 'y' );
    linkaxes( hAx, 'x' );
    hAx(1).YTick = unique( oWave.tableBenthos.ReplyFreq );
    hAx(2).YTick = unique( oWave.tableBenthos.ReplyCh );
    title( hAx(1), 'Reply Frequency (Hz)' );
    title( hAx(2), 'Reply Channel' );
    title( hAx(3), 'TWTT' );
    legend( hAx(2), 'Location', 'best' );
    
    axis( hMap, 'equal' );
    axisTight( hMap );
    axisTicksUTM( hMap, 'xy' );
    legend( hMap, 'Location', 'best' );
    title( hMap, 'Barracuda GPS map' );
    sgtitle( 'Barracuda Configuration' );
    
    addPlotMenu( hFig, fullfile( oWave.sPlotDir, 'Barracuda_Cfg' ), 'Save' );
    
    return;
end % PlotCudaCfg
