%% ===============================================================
% Line plot and delay-compensated imagesc plot
% [Author Li Wenlong]
% ===============================================================

clc;
clear;
close all;

%% ===============================================================
% User settings
% ===============================================================

infile = "Mimosa touch bottom signal.txt";

sampling_rate = 100;     % Sampling rate, unit: Hz

% Line plot settings
line_fig_width  = 30;    % cm
line_fig_height = 20;    % cm
line_font_size  = 40;
line_width      = 3;

line_xlim = [0 15];      % Time range for line plot, unit: s
line_ylim = [-50 100];   % Voltage range for line plot, unit: mV

% Imagesc interpolation settings
interp_factor = 100;     % Number of interpolated channels per original channel
trim_head_sec = 4;       % Seconds removed from the beginning
trim_tail_sec = 10;      % Seconds removed from the end

imagesc_fig_width  = 30; % cm
imagesc_fig_height = 20; % cm
imagesc_font_size  = 30;
clims = [-100 100];      % Color limits for imagesc plot

%% ===============================================================
% Read data
% ===============================================================

[folder, base, ~] = fileparts(infile);

raw_data = readmatrix(infile);

% In this script, all columns are treated as voltage channels.
data_4 = raw_data;

%% ===============================================================
% Line plot
% ===============================================================

figure('Units', 'centimeters', 'Position', [5 5 line_fig_width line_fig_height]);

N = size(data_4, 1);
t = (1:N) / sampling_rate;

num_lines = size(data_4, 2);

% Use a reversed cool colormap for different channels
co = flipud(cool(num_lines));
colororder(co);

plot(t, data_4, 'LineWidth', line_width);

xlabel('Time (s)');
ylabel('Potential (mV)');

set(gca, ...
    'FontSize', line_font_size, ...
    'Box', 'off', ...
    'LineWidth', 1.5, ...
    'TickDir', 'out', ...
    'XLim', line_xlim, ...
    'YLim', line_ylim, ...
    'PlotBoxAspectRatio', [1.5 1 1]);

% Export the line plot as a vector PDF
exportgraphics(gcf, fullfile(folder, base + "_lineplot.pdf"), ...
    'ContentType', 'vector', ...
    'BackgroundColor', 'white');

%% ===============================================================
% Delay-compensated interpolation for imagesc plot
% ===============================================================

data = data_4;
fs = sampling_rate;

[N, M] = size(data);             % N: time points, M: original channels
Nc = M * interp_factor;          % Number of interpolated virtual channels

t = (0:N-1)' / fs;               % Original physical time axis, unit: s
ch_old = 1:M;                    % Original channel index
ch_new = linspace(1, M, Nc);     % Interpolated channel index

% Fill missing values along the time direction to avoid interpolation errors
X = fillmissing(data, 'linear', 1, 'EndValues', 'nearest');

%% ===============================================================
% Step 1: Detect peak arrival time for each original channel
% ===============================================================

% Downward peak is detected by the minimum value
[~, idx_min] = min(X, [], 1);

% Peak arrival time for each channel
tpeak = (idx_min - 1) / fs;

%% ===============================================================
% Step 2: Build a common aligned time axis
% ===============================================================

% After shifting each channel by its peak time, use the overlapping time range
tau_lo = max(t(1)   - tpeak);
tau_hi = min(t(end) - tpeak);

tau = linspace(tau_lo, tau_hi, N)';

%% ===============================================================
% Step 3: Shift each original channel to the aligned time axis
% ===============================================================

aligned = zeros(N, M, 'like', X);

for c = 1:M
    aligned(:, c) = interp1(t - tpeak(c), X(:, c), tau, ...
        'linear', 'extrap');
end

%% ===============================================================
% Step 4: Interpolate along the channel direction
% ===============================================================

% pchip interpolation is used to preserve waveform shape
aligned_hi = interp1(ch_old, aligned.', ch_new, 'pchip').';

%% ===============================================================
% Step 5: Shift each virtual channel back to the physical time axis
% ===============================================================

% Estimate the peak arrival time of each virtual channel
tpeak_new = interp1(ch_old, tpeak, ch_new, 'pchip');

Z = zeros(N, Nc, 'like', aligned_hi);

for j = 1:Nc
    Z(:, j) = interp1(tau, aligned_hi(:, j), ...
        t - tpeak_new(j), ...
        'linear', 'extrap');
end

%% ===============================================================
% Step 6: Trim the beginning and end of the time axis
% ===============================================================

t0 = t(1) + trim_head_sec;
t1 = t(end) - trim_tail_sec;

if t0 >= t1
    error('Invalid trimming range: t0 >= t1. Please adjust trim_head_sec or trim_tail_sec.');
end

mask = (t >= t0) & (t <= t1);

t_plot = t(mask);
Z_plot = Z(mask, :);

%% ===============================================================
% Step 7: Imagesc visualization
% ===============================================================

figure('Units', 'centimeters', 'Position', [5 5 imagesc_fig_width imagesc_fig_height]);

imagesc(ch_new, t_plot, Z_plot);

set(gca, 'YDir', 'normal');

colormap("parula");
colorbar;
clim(clims);

xlabel('Channels');
ylabel('Time (s)');

% Mark the original channel positions on the x-axis
x_orig = linspace(ch_new(1), ch_new(end), M);

set(gca, ...
    'FontSize', imagesc_font_size, ...
    'Box', 'off', ...
    'LineWidth', 1.5, ...
    'TickDir', 'out', ...
    'PlotBoxAspectRatio', [1.5 1 1]);

set(gca, ...
    'XTick', x_orig, ...
    'XTickLabel', 1:M);

% Export the imagesc plot
exportgraphics(gcf, fullfile(folder, base + "_imagesc.pdf"), ...
    'ContentType', 'vector', ...
    'BackgroundColor', 'white');

%% ===============================================================
% Done
% ===============================================================

disp('Line plot and imagesc plot have been generated successfully.');
disp("Exported files:");
disp(fullfile(folder, base + "_lineplot.pdf"));
disp(fullfile(folder, base + "_imagesc.pdf"));