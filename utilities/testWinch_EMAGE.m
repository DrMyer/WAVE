function b = testWinch_EMAGE( s )
% Quick function used by WAVE (via ListFmts_GPS.m) to test whether a given
% single line from a file indicates that the file is a ship's winch file in
% the format found on the EMAGE cruise (R/V Sikuliaq)
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
% See also ListFmts_Winch, readWinch_EMAGE

try
    % This is the format from R/V Sikuliaq in 2019 EMAGE cruise
    %
    % <LDS Logger ID><tab><LDS time stamp><tab><data>
    % <LDS Logger ID> = 'winch_rapp'
    % <LDS time stamp> = 'yyyy-mm-ddThh:mm:ss.mmmmZ'
    % <data> = ...
    %{
		@RCWD,2,3,103.64,0.42,-29.95,0,102.96,0.294791*3d
			ID [@RCWD]
			Winch Number [1, 2, 6, 7]
			Winch Mode [1=manual, 2=auto_payout, 3=auto_haulin]
			Length [meters] - motor calculated
			Tension [metric tons] - motor calculated
			Velocity [meters per minute]
			Alarm
			Length [meters] - block counting
			Tension [metric tons] - load cell
			CheckSum
    %}
    %
    c = strsplit( s, char(9) ); % tab delimited
    b = strcmpi( c{1}, 'winch_rapp' ) && strncmpi( c{3}, '@', 1 );
    
catch
    b = false;
end

return;
end % testWinch_EMAGE
