% ===============================================================
% Bidirectional voltage wave analysis (first 5 positive, last 5 negative)
% [Author Li Wenlong]
% ===============================================================

clear; clc;

% ---- Parameters ----
fs = 100;               % sampling rate (Hz)
channel_distance = 2;   % mm between channels

% ---- File setup ----
files = dir('*.txt');
[~, ix] = sort(lower({files.name}));
files = files(ix);
nFiles = numel(files);

% ---- Containers (cell, then matrix) ----
peakL_cell  = cell(1, nFiles);   % each: 5x1
peakR_cell  = cell(1, nFiles);   % each: 5x1
speedL_cell = cell(1, nFiles);   % each: 4x1
speedR_cell = cell(1, nFiles);   % each: 4x1

sample_names = strings(1, nFiles);
valid = false(1, nFiles);        % track which files actually used

for k = 1:nFiles
    data = readmatrix(files(k).name);
    [~, base] = fileparts(files(k).name);
    sample_names(k) = base;

    num_channels = size(data, 2);
    num_points   = size(data, 1);
    t = (0:num_points - 1) / fs;

    if num_channels < 10
        warning('%s has <10 channels; skipped.', base);
        continue;
    end

    left_idx  = 1:5;                            % positive peaks
    right_idx = (num_channels-4):num_channels;  % negative peaks

    % ----- Left (first 5 channels, positive peaks) -----
    [ampL, idxL] = max(data(:, left_idx), [], 1);   % 1x5
    tL = t(idxL);                                   % 1x5

    % ----- Right (last 5 channels, negative peaks) -----
    [ampR, idxR] = min(data(:, right_idx), [], 1);  % 1x5 (negative)
    tR = t(idxR);                                   % 1x5

    % ----- Compute speeds -----
    dT_L = diff(tL);                     % 1x4
    dT_R = diff(tR);                     % 1x4
    speed_L = channel_distance ./ dT_L;  % 1x4
    speed_R = channel_distance ./ dT_R;  % 1x4

    speed_L(abs(dT_L) < 1e-6) = NaN;
    speed_R(abs(dT_R) < 1e-6) = NaN;

    % ----- Store as column vectors -----
    peakL_cell{k}  = ampL(:);       % 5x1
    peakR_cell{k}  = ampR(:);       % 5x1
    speedL_cell{k} = speed_L(:);    % 4x1
    speedR_cell{k} = speed_R(:);    % 4x1

    valid(k) = true;
    fprintf('%s processed.\n', base);
end

% Keep only valid samples
peakL_cell  = peakL_cell(valid);
peakR_cell  = peakR_cell(valid);
speedL_cell = speedL_cell(valid);
speedR_cell = speedR_cell(valid);
sample_names = sample_names(valid);

nValid = numel(sample_names);
if nValid == 0
    error("No valid files processed (need >=10 channels per file).");
end

% ===============================================================
% Build matrices (each column = one sample)
% ===============================================================
peak_left_matrix  = NaN(5, nValid);
peak_right_matrix = NaN(5, nValid);
speed_left_matrix = NaN(4, nValid);
speed_right_matrix= NaN(4, nValid);

for k = 1:nValid
    peak_left_matrix(:,k)   = peakL_cell{k};
    peak_right_matrix(:,k)  = peakR_cell{k};
    speed_left_matrix(:,k)  = speedL_cell{k};
    speed_right_matrix(:,k) = speedR_cell{k};
end

% ===============================================================
% Write to Excel (4 sheets)
% ===============================================================
out_xlsx = "Bidirectional_Peak_Speed_Matrices.xlsx";

writecell([cellstr(sample_names); num2cell(peak_left_matrix)],  out_xlsx, 'Sheet', 'Peak_Left_Positive');
writecell([cellstr(sample_names); num2cell(peak_right_matrix)], out_xlsx, 'Sheet', 'Peak_Right_Negative');
writecell([cellstr(sample_names); num2cell(speed_left_matrix)], out_xlsx, 'Sheet', 'Speed_Left');
writecell([cellstr(sample_names); num2cell(speed_right_matrix)],out_xlsx, 'Sheet', 'Speed_Right');

fprintf("✅ Excel saved: %s\n", out_xlsx);

% ===============================================================
% Mean ± SD (across samples) for plotting
% ===============================================================
mPeakL = mean(peak_left_matrix,  2, 'omitnan')';  sPeakL = std(peak_left_matrix,  0, 2, 'omitnan')';
mPeakR = mean(peak_right_matrix, 2, 'omitnan')';  sPeakR = std(peak_right_matrix, 0, 2, 'omitnan')';
mSpdL  = mean(speed_left_matrix, 2, 'omitnan')';  sSpdL  = std(speed_left_matrix, 0, 2, 'omitnan')';
mSpdR  = mean(speed_right_matrix,2, 'omitnan')';  sSpdR  = std(speed_right_matrix,0, 2, 'omitnan')';

% ---- X positions (discontinuity between left and right) ----
xP_L = 1:5;   xP_R = 7:11;   % peak voltage
xS_L = 1:4;   xS_R = 7:10;   % speed

% ===============================================================
% Plot peak voltage (mean ± SD)
% ===============================================================
figure('Units','centimeters','Position',[5 5 30 20]); hold on;

fill([xP_L fliplr(xP_L)], [mPeakL+sPeakL fliplr(mPeakL-sPeakL)], ...
    [0.8 0.9 1.0], 'EdgeColor','none', 'FaceAlpha',0.5);
plot(xP_L, mPeakL, 'b-', 'LineWidth',3);
plot(xP_L, mPeakL+sPeakL, 'b--', 'LineWidth',1.5);
plot(xP_L, mPeakL-sPeakL, 'b--', 'LineWidth',1.5);

fill([xP_R fliplr(xP_R)], [mPeakR+sPeakR fliplr(mPeakR-sPeakR)], ...
    [1.0 0.85 0.85], 'EdgeColor','none', 'FaceAlpha',0.5);
plot(xP_R, mPeakR, 'r-', 'LineWidth',3);
plot(xP_R, mPeakR+sPeakR, 'r--', 'LineWidth',1.5);
plot(xP_R, mPeakR-sPeakR, 'r--', 'LineWidth',1.5);

set(gca,'FontSize',40, 'Box', 'on', 'LineWidth',1.5,'TickDir','out');
xlim([1 11]);
ylim([-100 100]);
xlabel('Channel index');
ylabel('Peak V (mV)');
hold off;
exportgraphics(gcf, 'PeakVoltage_mean_SD.pdf','ContentType','vector');

% ===============================================================
% Plot speed mean ± SD
% ===============================================================
figure('Units','centimeters','Position',[5 5 30 20]); hold on;

fill([xS_L fliplr(xS_L)], [mSpdL+sSpdL fliplr(mSpdL-sSpdL)], ...
    [0.8 0.9 1.0], 'EdgeColor','none', 'FaceAlpha',0.5);
plot(xS_L, mSpdL, 'b-', 'LineWidth',3);
plot(xS_L, mSpdL+sSpdL, 'b--', 'LineWidth',1.5);
plot(xS_L, mSpdL-sSpdL, 'b--', 'LineWidth',1.5);

fill([xS_R fliplr(xS_R)], [mSpdR+sSpdR fliplr(mSpdR-sSpdR)], ...
    [1.0 0.85 0.85], 'EdgeColor','none', 'FaceAlpha',0.5);
plot(xS_R, mSpdR, 'r-', 'LineWidth',3);
plot(xS_R, mSpdR+sSpdR, 'r--', 'LineWidth',1.5);
plot(xS_R, mSpdR-sSpdR, 'r--', 'LineWidth',1.5);

set(gca,'FontSize',40, 'Box', 'on', 'LineWidth',1.5,'TickDir','out');
xlim([1 10]);
ylim([-10 10]);
xlabel('Channel index');
ylabel('Velocity (mm s^{-1})');
hold off;
exportgraphics(gcf, 'Speed_mean_SD.pdf','ContentType','vector');

disp('✅ Bidirectional peak voltage & speed analysis complete.');