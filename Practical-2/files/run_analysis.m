%% run_analysis.m
% EEE4120F Practical 2 - Performance Analysis Script
% Benchmarks sequential vs parallel Mandelbrot set computation

clear; clc; close all;

%% =====================================================================
%  CONFIGURATION
%% =====================================================================

MAX_ITERATIONS = 1000;

% Standard resolutions
resolutions = {
    'SVGA',    800,  600;
    'HD',     1280,  720;
    'Full HD',1920, 1080;
    '2K',     2048, 1080;
    'QHD',    2560, 1440;
    '4K UHD', 3840, 2160;
    '5K',     5120, 2880;
    '8K UHD', 7680, 4320;
};

num_resolutions = size(resolutions, 1);

% Determine max physical cores available
max_workers = feature('numcores');
fprintf('Detected %d physical cores on this machine.\n\n', max_workers);

% TO PREVENT THERMAL THROTTLING: Only test specific worker intervals
if max_workers >= 8
    worker_counts = unique([2, 4, 6, 8, max_workers]);
else
    worker_counts = unique([2, floor(max_workers/2), max_workers]);
end

output_dir = 'mandelbrot_images';
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

%% =====================================================================
%  STEP 1: SEQUENTIAL BENCHMARK (with fixed filename handling)
%% =====================================================================
fprintf('=== SEQUENTIAL BENCHMARK ===\n');
seq_times = zeros(num_resolutions, 1);

for r = 1:num_resolutions
    name   = resolutions{r, 1};
    width  = resolutions{r, 2};
    height = resolutions{r, 3};

    [img, t] = mandelbrot_sequential(width, height, MAX_ITERATIONS);
    seq_times(r) = t;

    % FIX: Create safe filename
    % Remove any problematic characters from the name
    safe_name = regexprep(name, '[<>:"/\|?*'' ,;()]', '_');
    fname = fullfile(output_dir, sprintf('seq_%s_%dx%d.png', safe_name, width, height));
    
    % Ensure the filename isn't too long (Windows has 260 char limit)
    if length(fname) > 250
        % Shorten by using just width/height and abbreviation
        abbrev = regexprep(name, '[aeiou\s]', '');
        abbrev = abbrev(1:min(5, length(abbrev)));
        fname = fullfile(output_dir, sprintf('seq_%s_%dx%d.png', abbrev, width, height));
    end
    
    mandelbrot_plot(img, width, height, fname);
end
fprintf('\nSequential benchmarking complete.\n\n');

%% =====================================================================
%  STEP 2: PARALLEL BENCHMARK (varying worker counts)
%% =====================================================================
fprintf('=== PARALLEL BENCHMARK ===\n');

num_worker_configs = length(worker_counts);
par_times = zeros(num_resolutions, num_worker_configs);

for w = 1:num_worker_configs
    nw = worker_counts(w);
    fprintf('\n-- %d Workers --\n', nw);

    % Start the pool for this worker count
    poolobj = gcp('nocreate');
    if isempty(poolobj) || poolobj.NumWorkers ~= nw
        if ~isempty(poolobj)
            delete(poolobj);
        end
        parpool('local', nw);
    end

    % WARM-UP RUN: Run a tiny matrix to force JIT compilation!
    fprintf('[Warming up workers...]\n');
    mandelbrot_parallel(100, 100, 100, nw); 

    for r = 1:num_resolutions
        width  = resolutions{r, 2};
        height = resolutions{r, 3};

        pixels = width * height;
        if pixels < 4e6   % Less than QHD
            runs = 3;
        else
            runs = 1;
        end
        
        temp_times = zeros(1, runs);
        for run_idx = 1:runs
            [~, t] = mandelbrot_parallel(width, height, MAX_ITERATIONS, nw);
            temp_times(run_idx) = t;
        end
        
        par_times(r, w) = median(temp_times);
    end
end
fprintf('\nParallel benchmarking complete.\n\n');

%% =====================================================================
%  STEP 3: COMPUTE METRICS
%% =====================================================================
megapixels = zeros(num_resolutions, 1);
for r = 1:num_resolutions
    megapixels(r) = (resolutions{r,2} * resolutions{r,3}) / 1e6;
end

speedup    = seq_times ./ par_times;          
efficiency = speedup ./ worker_counts * 100;  

%% =====================================================================
%  STEP 4: PRINT RESULTS TABLE
%% =====================================================================
fprintf('=== RESULTS TABLE ===\n');
header = sprintf('%-10s | %8s | %8s', 'Resolution', 'Seq (s)', 'MP');
for w = 1:num_worker_configs
    header =[header, sprintf(' | W%-2d Spd', worker_counts(w))]; %#ok<AGROW>
end
fprintf('%s\n', header);
fprintf('%s\n', repmat('-', 1, length(header)));

for r = 1:num_resolutions
    row_str = sprintf('%-10s | %8.3f | %8.2f', resolutions{r,1}, seq_times(r), megapixels(r));
    for w = 1:num_worker_configs
        row_str =[row_str, sprintf(' | %7.2fx', speedup(r, w))]; %#ok<AGROW>
    end
    fprintf('%s\n', row_str);
end

%% =====================================================================
%  STEP 5: PLOTS 
%% =====================================================================
res_labels = resolutions(:, 1);

% --- Plot 1: Execution Time vs Resolution ---
fig1 = figure('Name', 'Execution Time vs Resolution', 'Position',[100, 100, 900, 500]);
hold on;
plot(megapixels, seq_times, 'k-o', 'LineWidth', 2, 'DisplayName', 'Sequential');
colors = lines(num_worker_configs);
for w = 1:num_worker_configs
    plot(megapixels, par_times(:, w), '-s', 'Color', colors(w,:), ...
        'LineWidth', 1.5, 'DisplayName', sprintf('%d Workers', worker_counts(w)));
end
hold off;
xlabel('Resolution (Megapixels)'); ylabel('Execution Time (seconds)');
title('Mandelbrot Set: Execution Time vs Resolution');
legend('Location', 'northwest'); grid on;
set(gca, 'XTick', megapixels, 'XTickLabel', res_labels, 'XTickLabelRotation', 45);
saveas(fig1, fullfile(output_dir, 'plot_execution_time.png'));

% --- Plot 2: Speedup vs Resolution ---
fig2 = figure('Name', 'Speedup vs Resolution', 'Position',[100, 200, 900, 500]);
hold on;
for w = 1:num_worker_configs
    plot(megapixels, speedup(:, w), '-o', 'Color', colors(w,:), ...
        'LineWidth', 1.5, 'DisplayName', sprintf('%d Workers', worker_counts(w)));
end
for w = 1:num_worker_configs
    yline(worker_counts(w), '--', 'Color', colors(w,:), 'Alpha', 0.4, ...
        'Label', sprintf('Ideal %dW', worker_counts(w)));
end
hold off;
xlabel('Resolution (Megapixels)'); ylabel('Speedup (T_{serial} / T_{parallel})');
title('Mandelbrot Set: Speedup vs Resolution');
legend('Location', 'southeast'); grid on;
set(gca, 'XTick', megapixels, 'XTickLabel', res_labels, 'XTickLabelRotation', 45);
saveas(fig2, fullfile(output_dir, 'plot_speedup.png'));

% --- Plot 3: Efficiency vs Resolution ---
fig3 = figure('Name', 'Parallel Efficiency vs Resolution', 'Position',[100, 300, 900, 500]);
hold on;
for w = 1:num_worker_configs
    plot(megapixels, efficiency(:, w), '-^', 'Color', colors(w,:), ...
        'LineWidth', 1.5, 'DisplayName', sprintf('%d Workers', worker_counts(w)));
end
yline(100, 'k--', 'Label', 'Ideal (100%)');
hold off;
xlabel('Resolution (Megapixels)'); ylabel('Efficiency (%)');
title('Mandelbrot Set: Parallel Efficiency vs Resolution');
legend('Location', 'southeast'); grid on; ylim([0, 120]);
set(gca, 'XTick', megapixels, 'XTickLabel', res_labels, 'XTickLabelRotation', 45);
saveas(fig3, fullfile(output_dir, 'plot_efficiency.png'));

% --- Plot 4: Speedup vs Workers (for largest resolution) ---
fig4 = figure('Name', 'Speedup vs Workers (8K)', 'Position',[100, 400, 700, 450]);
spd_8k = speedup(end, :);  
plot(worker_counts, spd_8k, 'b-o', 'LineWidth', 2, 'DisplayName', 'Actual Speedup');
hold on;
plot(worker_counts, worker_counts, 'r--', 'LineWidth', 1.5, 'DisplayName', 'Ideal (Linear)');

if spd_8k(1) > 1
    f_est = 2 * (1 - 1/spd_8k(1));
    f_est = min(max(f_est, 0), 1);  
    amdahl_spd = 1 ./ ((1 - f_est) + f_est ./ worker_counts);
    plot(worker_counts, amdahl_spd, 'g-.', 'LineWidth', 1.5, ...
        'DisplayName', sprintf("Amdahl's Law (f=%.2f)", f_est));
end
hold off;
xlabel('Number of Workers'); ylabel('Speedup');
title('Speedup vs Workers for 8K Resolution');
legend('Location', 'northwest'); grid on; xticks(worker_counts);
saveas(fig4, fullfile(output_dir, 'plot_speedup_vs_workers.png'));

fprintf('\nAll plots saved to: %s/\n', output_dir);
fprintf('\n=== Analysis Complete ===\n');