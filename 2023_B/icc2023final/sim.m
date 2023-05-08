clear;
close all;

%% Setup the Import Options and import the data
opts = delimitedTextImportOptions("NumVariables", 3);

% Specify range and delimiter
opts.DataLines = [1, Inf];
opts.Delimiter = " ";

% Specify column names and types
opts.VariableNames = ["Var1", "Var2", "VarName3"];
opts.SelectedVariableNames = "VarName3";
opts.VariableTypes = ["string", "string", "single"];

% Specify file level properties
opts.ExtraColumnsRule = "ignore";
opts.EmptyLineRule = "read";
opts.ConsecutiveDelimitersRule = "join";
opts.LeadingDelimitersRule = "ignore";

% Specify variable properties
opts = setvaropts(opts, ["Var1", "Var2"], "WhitespaceRule", "preserve");
opts = setvaropts(opts, ["Var1", "Var2"], "EmptyFieldRule", "auto");

% Import the data
PAT1 = table2array(readtable("./PAT1.dat", opts));
GOLD0 = table2array(readtable("./GOLD0.dat", opts));
GOLD1 = table2array(readtable("./GOLD1.dat", opts));
GOLD2 = table2array(readtable("./GOLD2.dat", opts));
GOLD3 = table2array(readtable("./GOLD3.dat", opts));
GOLD4 = table2array(readtable("./GOLD4.dat", opts));


%% Clear temporary variables
clear opts

F = fimath(...
  'RoundingMethod', 'Floor',...
  'OverflowAction', 'Wrap');

globalfimath(F);

%%
nx = PAT1(PAT1 < 0);
px = PAT1(PAT1 > 0);

FRAC_WIDTH = 28;
wl = 4+FRAC_WIDTH; % signed + -6~6 (3 bit)
fl = FRAC_WIDTH;
qPAT1 = fi(PAT1, 1, wl, fl);

% PAT1 distribution
% fitting three parts maybe better (-6, -4), (-4, 4), (4, 6)
% histogram(PAT1);
%% ELU
gx = nx;
ggold = (exp(gx)-1) ./ 8;

x = nx;
gold = ggold(:);

qx = single(fi(x, 1, wl, fl));
p = polyfit(qx, gold, 5);

qgx = fi(gx, 1, wl, fl);
qp = fi(p, 1, wl, fl);
actual = fi_polyval(qp, qgx);

%% Sigmoid
% gx = PAT1;
% ggold = 1./(1+exp(-gx));
%
% x = [nx; -px];
% gold = [1./(1+exp(-nx))-0.5; 1./(1+exp(px))-0.5];
%
% qx = single(fi(x, 1, wl, fl));
% % 6-degree is fine for sigmoid, but failed in SiLU
% p = polyfit(qx, gold, 7);
%
% qgx = fi(gx, 1, wl, fl);
% qp = fi(p, 1, wl, fl);
%
% qpp = qp(:);
% qpn = qp(:);
% qpp(end) = qpp(end)-0.5;
% qpn(end) = qpn(end)+0.5;
% actual = fi_polyval(qpn, qgx);
% nactual = fi_polyval(qpp, -qgx);
%
% % qp5 = fi(0.5, 0, 1, 1);
% % actual(qgx > 0) = qp5-nactual(qgx > 0);
% % actual(qgx < 0) = actual(qgx < 0)+qp5;
%
% % Combining 0.5 into poly's const
% actual(qgx > 0) = -nactual(qgx > 0);

%% SiLU (uncomment Sigmoid code aswell)
% gx = PAT1;
% ggold = gx./(1+exp(-gx));
%
% qgx2 = fi(gx, 1, wl, fl);
% actual = actual .* qgx2;
% actual = fi(actual, 1, wl, fl);

%% Tanh
% gx = PAT1;
% ggold = tanh(gx);

% x = [nx; -px];
% gold = [tanh(nx); tanh(-px)];

% qx = single(fi(x, 1, wl, fl));
% p = polyfit(qx, gold, 8);

% qgx = fi(gx, 1, wl, fl);
% qp = fi(p, 1, wl, fl);
% actual = fi_polyval(qp, qgx);
% nactual = fi_polyval(qp, -qgx);
% actual(qgx > 0) = -nactual(qgx > 0);

%% Expand bits
ep = int(fi(p, 1, wl+20, fl+2));

ec = int(fi(p(end), 1, fl+2, fl-10));
% sigmoid
if exist('qpp', 'var')
    ecp = int(fi(qpp(end), 1, fl+2, fl-10));
    ecn = int(fi(qpn(end), 1, fl+2, fl-10));
end

% convert fp32 to hex (sigmoid constants need to be handled differently)
hexp = reshape(sprintf('%tx', p), 8, [])';

%%
actual = single(actual);

scatter(gx, ggold);
hold on;
scatter(qgx, actual);
legend('golden', 'actual');


%%
% gx = PAT1;
% ggold = GOLD1;
% actual = approx_ELU(PAT1);

%%
dist = err_dist(ggold, actual);
ratio = err_ratio(ggold, actual);
total = length(gx);
wrong = 0;
correct = 0;
min_wrong = 100000;
max_wrong = -100000;
wrong_x = [];
for i = 1:length(gx)
    if ratio(i) > 0.01 && dist(i) > 0.002
        fprintf("f(%.2f)=\t%.5f\t%.5f, dist = %.3f, ratio = %.3f\n", ...
            gx(i), ggold(i), actual(i), dist(i), ratio(i));
        if gx(i) < min_wrong
            min_wrong = gx(i);
        end
        if gx(i) > max_wrong
            max_wrong = gx(i);
        end
        wrong_x = [wrong_x; gx(i)];
        wrong = wrong+1;
    else
        correct = correct+1;
    end
end
fprintf("Wrong: %d/Total: %d, Correct: %d\n", wrong, total, correct);
fprintf("Min: %f, Max: %f\n", min_wrong, max_wrong);

if ~isempty(wrong_x)
    figure;
    histogram(wrong_x);
end


function out = fi_polyval(p, x)
    pow_x = cell(size(p));
    last = fi(ones(size(x)), 0, 1, 0);

    M = length(pow_x);
    for i = M:-1:1
        last = fi(last, 1, get(p, 'WordLength')+20, get(p, 'FractionLength')+2);
        pow_x{i} = last;
        last = last.*x;
    end

    out = cell(size(p));
    for i = 1:M
        out{i} = pow_x{i} .* p(i);
        out{i} = fi(out{i}, 1, get(p, 'WordLength')-2, get(p, 'FractionLength')-10);
    end

    wl = get(out{1}, 'WordLength');
    fl = get(out{1}, 'FractionLength');
    for i = 2:M
        out{1} = out{1} + out{i};
        out{1} = fi(out{1}, 1, wl, fl);
    end

    out = out{1};
end

function dist = err_dist(real, act)
    dist = ((real - act) .* (real - act)) .^ 0.5;
end

function ratio = err_ratio(real, act)
    ratio = err_dist(real, act)./abs(real);
end