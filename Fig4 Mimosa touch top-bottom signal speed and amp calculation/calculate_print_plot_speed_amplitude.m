% ===============================================================
% Bidirectional inward wave propagation (two-end stimulation)
% [Author Li Wenlong]
% ===============================================================

clear; clc;

% ---- Parameters ----
fs = 100;               % sampling rate (Hz)
channel_distance = 2;   % mm between adjacent channels

% ---- File setup ----
files = dir('*.txt');
[~, ix] = sort(lower({files.name}));
files = files(ix);
nFiles = numel(files);

% ---- Containers (cells, then matrices) ----
peakL_cell = cell(1, nFiles);   % each: 5x1
peakR_cell = cell(1, nFiles);   % each: 5x1
velL_cell  = cell(1, nFiles);   % each: 4x1
velR_cell  = cell(1, nFiles);   % each: 4x1

sample_names = strings(1, nFiles);
valid = false(1, nFiles);

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

    left_idx  = 1:5;                              % negative peaks
    right_idx = (num_channels-4):num_channels;    % positive peaks

    % ----- Left group (negative peaks) -----
    [ampL, idxL] = min(data(:, left_idx), [], 1);   % 1x5
    tL = t(idxL);                                   % 1x5

    % ----- Right group (positive peaks) -----
    [ampR, idxR] = max(data(:, right_idx), [], 1);  % 1x5
    tR = t(idxR);                                   % 1x5

    % ----- Compute velocity (directional) -----
    dT_L = diff(tL);                % 1x4
    dT_R = diff(tR);                % 1x4

    vel_L =  abs(channel_distance ./ dT_L);   % + (rightward)
    vel_R = -abs(channel_distance ./ dT_R);   % - (leftward)

    vel_L(abs(dT_L) < 1e-6) = NaN;
    vel_R(abs(dT_R) < 1e-6) = NaN;

    % ----- Store as column vectors -----
    peakL_cell{k} = ampL(:);     % 5x1
    peakR_cell{k} = ampR(:);     % 5x1
    velL_cell{k}  = vel_L(:);    % 4x1
    velR_cell{k}  = vel_R(:);    % 4x1

    valid(k) = true;
    fprintf('%s processed.\n', base);
end

% Keep only valid samples
peakL_cell = peakL_cell(valid);
peakR_cell = peakR_cell(valid);
velL_cell  = velL_cell(valid);
velR_cell  = velR_cell(valid);
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
vel_left_matrix   = NaN(4, nValid);
vel_right_matrix  = NaN(4, nValid);

for k = 1:nValid
    peak_left_matrix(:, k)  = peakL_cell{k};
    peak_right_matrix(:, k) = peakR_cell{k};
    vel_left_matrix(:, k)   = velL_cell{k};
    vel_right_matrix(:, k)  = velR_cell{k};
end

% ===============================================================
% Write to Excel (4 sheets)
% ===============================================================
out_xlsx = "InwardWave_Peak_Velocity_Matrices.xlsx";

writecell([cellstr(sample_names); num2cell(peak_left_matrix)],  out_xlsx, 'Sheet', 'Peak_Left_Negative');
writecell([cellstr(sample_names); num2cell(peak_right_matrix)], out_xlsx, 'Sheet', 'Peak_Right_Positive');
writecell([cellstr(sample_names); num2cell(vel_left_matrix)],   out_xlsx, 'Sheet', 'Vel_Left_Positive');
writecell([cellstr(sample_names); num2cell(vel_right_matrix)],  out_xlsx, 'Sheet', 'Vel_Right_Negative');

fprintf("✅ Excel saved: %s\n", out_xlsx);

% ===============================================================
% Mean ± SD (across samples) for plotting
% ===============================================================
mPeakL = mean(peak_left_matrix,  2, 'omitnan')';  sPeakL = std(peak_left_matrix,  0, 2, 'omitnan')';
mPeakR = mean(peak_right_matrix, 2, 'omitnan')';  sPeakR = std(peak_right_matrix, 0, 2, 'omitnan')';
mVelL  = mean(vel_left_matrix,   2, 'omitnan')';  sVelL  = std(vel_left_matrix,   0, 2, 'omitnan')';
mVelR  = mean(vel_right_matrix,  2, 'omitnan')';  sVelR  = std(vel_right_matrix,  0, 2, 'omitnan')';

% ---- X positions (with discontinuity) ----
xP_L = 1:5;   xP_R = 7:11;
xV_L = 1:4;   xV_R = 7:10;

% ===============================================================
% Plot Peak Potential (mean ± SD)
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

set(gca,'FontSize',40,'Box','on','LineWidth',1.5,'TickDir','out');
xlim([1 11]); ylim([-100 100]);
xlabel('Channel index');
ylabel('Peak Potential (mV)');
hold off;
exportgraphics(gcf, 'PeakPotential_inward_mean_SD.pdf','ContentType','vector');

% ===============================================================
% Plot Velocity (mean ± SD)
% ===============================================================
figure('Units','centimeters','Position',[5 5 30 20]); hold on;

fill([xV_L fliplr(xV_L)], [mVelL+sVelL fliplr(mVelL-sVelL)], ...
    [0.8 0.9 1.0], 'EdgeColor','none', 'FaceAlpha',0.5);
plot(xV_L, mVelL, 'b-', 'LineWidth',3);
plot(xV_L, mVelL+sVelL, 'b--', 'LineWidth',1.5);
plot(xV_L, mVelL-sVelL, 'b--', 'LineWidth',1.5);

fill([xV_R fliplr(xV_R)], [mVelR+sVelR fliplr(mVelR-sVelR)], ...
    [1.0 0.85 0.85], 'EdgeColor','none', 'FaceAlpha',0.5);
plot(xV_R, mVelR, 'r-', 'LineWidth',3);
plot(xV_R, mVelR+sVelR, 'r--', 'LineWidth',1.5);
plot(xV_R, mVelR-sVelR, 'r--', 'LineWidth',1.5);

set(gca,'FontSize',40,'Box','on','LineWidth',1.5,'TickDir','out');
xlim([1 10]); ylim([-10 10]);
xlabel('Channel index');
ylabel('Velocity (mm/s)');
hold off;
exportgraphics(gcf, 'Velocity_inward_mean_SD.pdf','ContentType','vector');

disp('✅ Two-end inward wave analysis complete.');