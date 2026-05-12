% ===============================================================
% Analyze multichannel voltage data for wave speed and amplitude
% calculation
% Author Li Wenlong
% ===============================================================
clear; clc;

% -------- Parameters --------
fs = 100;              % Sampling rate (Hz)
channel_distance = 2;  % mm between channels

% -------- File setup --------
files = dir('*.txt');
[~, ix] = sort(lower({files.name}));
files = files(ix);
nFiles = numel(files);

all_speed = {};      % each sample: (num_channels-1) x 1
all_amplitude = {};  % each sample: (num_channels) x 1
sample_names = strings(1, nFiles);

for k = 1:nFiles
    % ---- Load data ----
    data = readmatrix(files(k).name);
    [~, base] = fileparts(files(k).name);
    sample_names(k) = base;

    num_channels = size(data, 2);
    num_points = size(data, 1);
    t = (0:num_points - 1) / fs;   % time vector (s)

    % ---- Find min value (downward peak) per channel ----
    [amp_values, idx_min] = min(data, [], 1);  % 1×M
    time_of_peaks = t(idx_min);                % 1×M

    % ---- Compute speed between neighboring channels ----
    delta_t = diff(time_of_peaks);                 % 1×(M-1)
    speed = channel_distance ./ delta_t;           % 1×(M-1)
    speed(abs(delta_t) < 1e-6) = NaN;              % avoid divide-by-zero

    % ---- Store as column vectors ----
    all_speed{k}     = speed(:);        % (M-1)×1
    all_amplitude{k} = amp_values(:);   % M×1

    fprintf('%s: Mean speed = %.2f mm/s, Mean amplitude = %.2f mV\n', ...
        base, mean(speed,'omitnan'), mean(amp_values,'omitnan'));
end

% ===============================================================
% -------- Combine to matrices (columns = samples) --------------
% ===============================================================
max_len_speed = max(cellfun(@numel, all_speed));       % typically M-1
max_len_amp   = max(cellfun(@numel, all_amplitude));   % typically M

% Now matrices are: (vector_length × nFiles)
speed_matrix = NaN(max_len_speed, nFiles);
amp_matrix   = NaN(max_len_amp,   nFiles);

for k = 1:nFiles
    speed_matrix(1:numel(all_speed{k}), k) = all_speed{k};
    amp_matrix(1:numel(all_amplitude{k}), k) = all_amplitude{k};
end

% ===============================================================
% -------- Write to Excel (2 sheets) ----------------------------
% ===============================================================
out_xlsx = "Speed_Amplitude_Matrices.xlsx";

% Put sample names as header row (optional but very useful)
speed_cell = [cellstr(sample_names); num2cell(speed_matrix)];
amp_cell   = [cellstr(sample_names); num2cell(amp_matrix)];

writecell(speed_cell, out_xlsx, 'Sheet', 'Speed_mm_per_s');   % speed_matrix
writecell(amp_cell,   out_xlsx, 'Sheet', 'Amplitude_mV');     % amp_matrix

fprintf("✅ Excel saved: %s\n", out_xlsx);

% ===============================================================
% -------- Mean and SD (across samples) -------------------------
% ===============================================================
% Since columns are samples now, take mean/std along 2nd dimension
mean_speed = mean(speed_matrix, 2, 'omitnan');   % (max_len_speed×1)
std_speed  = std(speed_matrix,  0, 2, 'omitnan');

mean_amp   = mean(amp_matrix,   2, 'omitnan');   % (max_len_amp×1)
std_amp    = std(amp_matrix,    0, 2, 'omitnan');

x_speed = 1:max_len_speed;
x_amp   = 1:max_len_amp;

% ===============================================================
% ------------------ Plot: Speed (mean ± SD) --------------------
% ===============================================================
figure('Units','centimeters','Position',[5 5 30 20]); hold on;

fill([x_speed fliplr(x_speed)], ...
     [(mean_speed+std_speed)' fliplr((mean_speed-std_speed)')], ...
     [0.8 0.9 1.0], 'EdgeColor','none','FaceAlpha',0.5);

plot(x_speed, mean_speed, 'b-', 'LineWidth', 3);
plot(x_speed, mean_speed+std_speed, 'b--', 'LineWidth', 1.5);
plot(x_speed, mean_speed-std_speed, 'b--', 'LineWidth', 1.5);

set(gca, 'FontSize', 40, 'Box', 'on', 'LineWidth', 1.5, 'TickDir', 'out');
xlim([1 10]); ylim([-10 10]);
xlabel('Channel index');
ylabel('Speed (mm/s)');
title('Wave propagation speed');
hold off;
exportgraphics(gcf, 'WaveSpeed_mean_SD.pdf', 'ContentType','vector');

% ===============================================================
% ---------------- Plot: Amplitude (mean ± SD) ------------------
% ===============================================================
figure('Units','centimeters','Position',[5 5 30 20]); hold on;

fill([x_amp fliplr(x_amp)], ...
     [(mean_amp+std_amp)' fliplr((mean_amp-std_amp)')], ...
     [1.0 0.85 0.85], 'EdgeColor','none','FaceAlpha',0.5);

plot(x_amp, mean_amp, 'r-', 'LineWidth', 3);
plot(x_amp, mean_amp+std_amp, 'r--', 'LineWidth', 1.5);
plot(x_amp, mean_amp-std_amp, 'r--', 'LineWidth', 1.5);

set(gca, 'FontSize', 40, 'Box', 'on', 'LineWidth', 1.5, 'TickDir', 'out');
xlim([1 11]); ylim([-100 100]);
xlabel('Channel index');
ylabel('Peak V (mV)');
hold off;
exportgraphics(gcf, 'WaveAmplitude_mean_SD.pdf', 'ContentType','vector');

disp('✅ Wave speed and amplitude analysis complete.');