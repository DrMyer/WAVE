function [time_out, stTable] = FindRayPath(x1,y1,z1,x2,y2,z2,v,stTable,maxR)
%--------------------------------------------------------------------------
% function [time, stTable] = FindRayPath(x1,y1,z1,x2,y2,z2,v,stTable[,maxR])
%--------------------------------------------------------------------------
% DGM  6/2023 added optional param maxR
% DGM 11/2008 added table to dramatically speed things up
% DGM 10/2008 extracted from KKey's MarqNav and slightly modified for new
%   automatic nav program.
%
% Kerry Key
% Scripps Institution of Oceanography
%
% Version 1.0   Oct. 26, 2004
%
% Find ray-path take-off angle between 2 points at top and bottom of a
% layered velocity model.  Uses ray parameter p and calculates the
% horizontal offset of wave when it travels through model from top to
% bottom, then sees if this matches the source-receiver horizontal offset.
% Ray path code is from Peter Shearer's Intro to Seismology book.
%
% Params:
%   x1, y1, z1      top point (ship) (m)
%                   x1,y1,z1 can be an array of N points
%   x2, y2, z2      bottom point (receiver) (m)
%                   can only be one point, not array
%   v               depth to top of layer, velocity (m, m/s)
%   stTable         return from previous call to FindRayPath - speeds calc
%                   if you need to do lots of FindRayPath calls.
%   maxR            (opt; dflt 8500) max horizontal range to create ray table 
%
% Returns:
%   time            two way travel time for ray
%   stTable         structure containing a table of raypath travel times
%                   spaced such that cubic interpolation gets values
%                   accurate to 0.0001s or better.  Pass this table to
%                   subsequent calls of FindRayPath() to speed it up.
%                   The table is ONLY for cases where z1 is zero!
%--------------------------------------------------------------------------


%%% simple wholespace solution:
%     v        = 1500; %mean(v(:,2));
%     r        = sqrt( (x2-x1).^2 + (y2-y1).^2 + (z2-z1).^2 );
%     time_out = 2*r/v;
%     stTable = [];
%     return
% %
%%% full code below

if ~exist( 'maxR', 'var' ) || isempty( maxR )
    maxR = 8500;  % Maximum horizontal offset;
else
    % NB: we use steps of 50m horizontally so go up to the next step
    maxR = 50 * ceil( maxR / 50 );
end

% Preallocate arrays for speed:
time_out = zeros(length(x1),1);

% DGM Nov 2008 - use a table for speed.  Found that with cubic interpolation, I
% only need points spaced every 100m in depth and range to get the TWTT within
% 0.0001s.  The FindRayPath routine as written is very slow. Using the table
% speeds it up immensely.
%   NB: Assuming all ship positions (i.e. transducers) are at the SAME DEPTH of 
% water. If that ever changes, then the table is incorrect because even being 4m
% down in the water can make a change of ~0.004s for 2000m deep rcvr.
if nargout() > 1 && ~exist('stTable','var')
    stTable = [];       % requested but not passed.  Force build of table
end
if exist( 'stTable', 'var' ) && (nargout() > 1 || ~isempty( stTable ))
    if isempty( stTable )   % Table requested but not yet made.
        % Use smaller spacing for little extra accuracy
        stTable.nDepth  = z1 + [1:10 15:5:45 50:10:90 100:50:(ceil(max(v(:,1))/100)*100)];
        stTable.nRange  = 0:50:maxR;    % 10s TWTT ~7500m.  Usually only get up to ~5 or 6s TWTT on Benthos....
        stTable.nTWTT   = zeros(numel(stTable.nDepth), numel(stTable.nRange));
        nDummy          = zeros(size(stTable.nRange));
        for i = 1:length(stTable.nDepth)
            stTable.nTWTT(i,:) = FindRayPath( stTable.nRange, nDummy, nDummy+z1 ...   respect requested starting depth
                , 0, 0, stTable.nDepth(i), v );
        end
    end
    
    % plot check:
    %figure;pcolor(stTable.nRange, stTable.nDepth, stTable.nTWTT);shading flat;axis ij;
    
    % Table given.  Use it.
    %         for i = 1:length(x1)
    %             % table only does zero depth for ship and > 100m for rcvr
    %             if z1(i) ~= 0 || z2 < 100
    %                 time_out(i) = FindRayPath( x1(i), y1(i), z1(i), x2, y2, z2, v );
    %             else
    %                 time_out(i) = interp2( stTable.nRange, stTable.nDepth ...
    %                                      , stTable.nTWTT ...
    %                                      , sqrt( (x1(i) - x2)^2 + (y1(i) - y2)^2 ) ...
    %                                      , z2, 'cubic' );
    %             end
    %         end
    % Below is 2x faster than looping - but doesn't give the check on z1 & z2...
    r = sqrt( (x1 - x2).^2 + (y1 - y2).^2 );
    time_out = interp2( stTable.nRange, stTable.nDepth ...
        , stTable.nTWTT ...
        , r, z2*ones(size(r)), 'spline' );
    return
end

% Ray finding code

for ix = 1:length(x1)
    
    % Form new velocity model based on z1 and z2 bounds:
    ztop = min([z1(ix) z2]);
    zbot = max([z1(ix) z2]);
    
    ikeep = v(:,1) > ztop & v(:,1) < zbot;
    velocity(:,1)  = [ztop; v(ikeep,1); zbot];
    velocity(:,2)  = interp1(v(:,1),v(:,2),velocity(:,1),'linear','extrap');
    
    if size(velocity,1) <=3
        time_out(ix) = 2* sqrt( (x2-x1(ix))^2 + (y2-y1(ix))^2+(z2-z1(ix))^2 ) / interp1(velocity(:,1),velocity(:,2),z2,'linear','extrap');
    else
        % Horizontal source-receiver offset:
        X0  = sqrt( (x2-x1(ix))^2 + (y2-y1(ix))^2 );
        
        THETA = fminbnd(@myfun,0,89.9999, optimset('TolX',1d-2));
        
        [~, time_out(ix) ] = getModelXY(THETA,velocity);
        time_out(ix) = real(time_out(ix));
    end
end

% subfunction (has access to parent variables):
    function f = myfun(theta)
        
        XX = getModelXY(theta,velocity);
        % Misfit
        f = (XX - X0).^2;
    end

end

function [X T ] = getModelXY(theta,velocity)

p = sin(pi/180*theta) / velocity(1,2);

h = velocity(2:end,1) - velocity(1:end-1,1);

[X, T, iFlag] = layerxt(p, h, velocity(:,2));
T = 2*T;


if iFlag % ray turned above bottom depth so don't set X and T to large to omit this theta
    
    X = 1d10;
    T = 1d10;
    
    %fprintf('iFlag oh no!: %g\n',iFlag)
    
end

end


% Matlab version of P. Shearer's LAYERXT subroutine

function [X, T, iFlag] = layerxt(p, h, v)
% LAYERXT calculates dx and dt for a ray in a layer with a linear velocity gradient.
% This is a highly modified version of a subroutine in Chris Chapman's WKBJ program.

% Special version of layerXT for acoustic ranging

iFlag = 0; % 0 means good, anything is means layer turned in a layer
v1 = v(1:end-1);
v2 = v(2:end);
u1 = 1./v1;
u2 = 1./v2;

b  = (v2 - v1)./h; % slope of velocity gradient in each layer

eta1 = sqrt(u1.^2 - p^2);
x1   = eta1./(u1.*b*p);
tau1 = (log((u1+eta1)/p)-eta1./u1)./b;

eta2 = sqrt(u2.^2-p^2);
x2   = eta2./(u2.*b*p);
tau2 = (log((u2+eta2)/p) - eta2./u2)./b;

dx   = x1-x2;
dtau = tau1-tau2;
dt   = dtau+p*dx;

% Modify for:

% Constant velocity layers:
ib0 = b == 0;
dx(ib0) = h(ib0).*p./eta1(ib0);
dt(ib0) = h(ib0).*u1(ib0).^2./eta1(ib0);

% Zero thickness layers:
ih0 = (h == 0) ;
dx(ih0) = 0;
dt(ih0) = 0;

% Set results based on two cases:

% Ray turned within a layer (set warning flag):
if any(u1 <= p)
    iFlag = 1;
end
if any(u2 <= p)
    iFlag = 1;
end


% Ray made it to the bottom layer:
% Normal:

X = sum(dx);
T = sum(dt);

end