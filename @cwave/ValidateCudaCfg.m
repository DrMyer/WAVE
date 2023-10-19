function [bOK,cErrMsg] = ValidateCudaCfg( tData, hUIFig, bQuery )
% Validate a copy of the barracuda nav config table - used primarily
% with w_panelTable.m and UITableEdit.m but may be used elsewhere.
%
% Params:
%   tData   - copy of the cwave::tableCudaCfg.
%   hUIFig  - handle of a uifigure to which to parent uiconfirm
%   bQuery  - T/F. If T, it's OK to ask questions. If F, validate silently.
% Returns:
%   bOK     - logical(n,1) for n rows of table. Which are valid.
%   cErrMsg - Text that the caller should uialert or log (as appropriate). If a
%           msg was already displayed, it should be empty even if ~all(bOK).
%-------------------------------------------------------------------------------
% Copyright (C) 2023 David Myer. See wave.m for GNU GPL notice.
%-------------------------------------------------------------------------------

% bOK     = true( height( tData ), 1 );
cErrMsg = '';   % default a return value

% {'DeviceNo', 'DucerDepth', 'ListenFreq', 'ReplyFreq', 'ReplyCh', 'DateFrom', 'DateTo'} ...

% DeviceNo cannot be NaN
bOK = ~isnan( tData.DeviceNo );
if ~all(bOK)
    cErrMsg = {'DeviceNo cannot be NaN. This is the NAV<x> number in the GPS time series.'};
    return;
end

% If times are given, DateTo must be > DateFrom
bOK = (isnat( tData.DateFrom ) & isnat( tData.DateTo )) ...
    | tData.DateFrom < tData.DateTo;
if ~all(bOK)
    cErrMsg = {'DateFrom must be < DateTo, when specified.'};
    return;
end

% DeviceNo must either be unique or have non-overlapping times
[nDevList,~,iC] = unique( tData.DeviceNo );
if numel(nDevList) < height( tData )
    bOK = true( height( tData ), 1 );
    for iUniq = 1:numel(nDevList)
        nWhich = find( iC == iUniq );
        if numel(nWhich) == 1
            continue;
        end
        for i = 1:numel(nWhich)
            nCnt = sum( btwn( tData.DateFrom(nWhich), tData.DateFrom(nWhich(i)), tData.DateTo(nWhich) ) );
            if nCnt > 1
                bOK(nWhich) = false;
                break;
            end
            nCnt = sum( btwn( tData.DateFrom(nWhich), tData.DateTo(nWhich(i)), tData.DateTo(nWhich) ) );
            if nCnt > 1
                bOK(nWhich) = false;
                break;
            end
        end
        if ~all(bOK)
            break;
        end
    end
    if ~all(bOK)
        cErrMsg = {'Multiple entries for the same NAVx cannot have overlapping DateFrom/To'};
        return;
    end
end

% Depth cannot be NaN
bOK = ~isnan( tData.DucerDepth );
if ~all(bOK)
    cErrMsg = {'The transducer depth cannot be NaN. This is the depth below the sea surface.'};
    return;
end

% ListenFreq cannot be NaN
bOK = ~isnan( tData.ListenFreq );
if ~all(bOK)
    cErrMsg = {'Listening Frequency cannot be NaN.'};
    return;
end

% ReplyFreq & ReplyCh cannot BOTH be NaN
bOK = ~isnan( tData.ReplyFreq ) | ~isnan( tData.ReplyCh );
if ~all(bOK)
    cErrMsg = {'Need either a Reply Frequency or a Reply Channel.'};
    return;
end

% If ReplyCh is NOT NaN, then ReplyFreq should be NaN
bOK = isnan( tData.ReplyFreq ) | isnan( tData.ReplyCh );
if ~all(bOK)
    cErrMsg = {'Specify ONLY either a Reply Frequency or Channel. Do not give both.'};
    return;
end

% Cannot have duplicate listen & reply info without non-overlapping times
for i = 1:(height( tData ) - 1)
    iAt = find( tData.ListenFreq(i+1:end) == tData.ListenFreq(i) ...
              & sub_NanEq( tData.ReplyFreq(i), tData.ReplyFreq(i+1:end) ) ...
              & sub_NanEq( tData.ReplyCh(i), tData.ReplyCh(i+1:end) ) ) ...
          + i;
    if isempty( iAt )
        continue;
    end
    for j = onerow( iAt )
        if isnat( tData.DateFrom(i) ) || isnat( tData.DateTo(i) ) ...
        || isnat( tData.DateFrom(j) ) || isnat( tData.DateTo(j) ) ...
        || btwn( tData.DateFrom(i), tData.DateFrom(j), tData.DateTo(i) ) ...
        || btwn( tData.DateFrom(j), tData.DateFrom(i), tData.DateTo(j) )
            bOK([i j]) = false;
            cErrMsg = {'Two barracudas cannot share listen/reply info and overlapping time ranges.'};
            return;
        end
    end
end

return;
end % ValidateCudaCfg

%-------------------------------------------------------------------------------
% Return true when the scalar & vector are equal or when they are both NaN
function b = sub_NanEq( s, v )
    arguments
        s (1,1) double
        v (:,1) double
    end
    if isnan(s)
        b = isnan(v);
    else
        b = (s == v);
    end
end
