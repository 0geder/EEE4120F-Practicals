% =========================================================================
% Practical 2: Mandelbrot-Set Serial vs Parallel Analysis
% EEE4120F - High Performance Embedded Systems
% University of Cape Town, 2026
% =========================================================================
%
% GROUP NUMBER: 24
%
% MEMBERS:
%   - Member 1 Nyakallo Peete, PTXNYA001
%   - Member 2 Samson Okuthe, OKTSAM001
%
% =========================================================================
% USAGE:
%   In the MATLAB command window, simply type:  run_analysis
%
% PARALLEL STRATEGIES TESTED:
%   1. Parallel   - Standard parfor (row-level decomposition)
%   2. Shuffled   - parfor with shuffled row order (load balancing)
%   3. Interleaved- parfor with interleaved/strided row assignment
%   4. SPMD       - spmd block with manual domain decomposition
%   5. Parfeval   - parfeval async futures-based parallel dispatch
%
% BENCHMARKING NOTE:
%   tic/toc is placed INSIDE each compute function, after coordinate
%   pre-computation and before any parallel work begins.
%   Pool startup is done BEFORE any timing begins.
% =========================================================================

%% ========================================================================
%  PART 4: Testing and Analysis  (entry point — must be FIRST function)
%  ========================================================================
function run_analysis()
    clc; close all;
    fprintf('Starting Mandelbrot Benchmarking Analysis...\n\n');

    % Standard testing resolutions defined in the practical spec
    resolutions = {
        'SVGA',      800,  600;
        'HD',       1280,  720;
        'Full HD',  1920, 1080;
        '2K Cinema',2048, 1080;
        '2K QHD',   2560, 1440;
        '4K UHD',   3840, 2160;
        '5K',       5120, 2880;
        '8K UHD',   7680, 4320
    };

    num_res        = size(resolutions, 1);
    max_iterations = 1000;

    % Worker counts: 1 (serial baseline), 2, 4, max physical cores
    max_cores = feature('numcores');
    worker_counts = unique([1, 2, 4, max_cores]);
    % Remove 1 from parallel worker list — 1 worker = serial reference only
    par_worker_counts = worker_counts(worker_counts > 1);
    num_par_w = length(par_worker_counts);

    % Strategy names (must match number of strategy functions below)
    strategy_names = {'Parallel', 'Shuffled', 'Interleaved', 'SPMD', 'Parfeval'};
    num_strat = length(strategy_names);

    % Pre-allocate:
    %   serial_times   [num_res x 1]
    %   par_times      [num_res x num_par_w x num_strat]
    %   speedups       [num_res x num_par_w x num_strat]
    %   efficiencies   [num_res x num_par_w x num_strat]
    pixels_count  = zeros(num_res, 1);
    serial_times  = zeros(num_res, 1);
    par_times     = zeros(num_res, num_par_w, num_strat);
    speedups      = zeros(num_res, num_par_w, num_strat);
    efficiencies  = zeros(num_res, num_par_w, num_strat);

    % -----------------------------------------------------------------------
    % Output directory structure
    % -----------------------------------------------------------------------
    out_dir        = 'mandelbrot_results';
    serial_dir     = fullfile(out_dir, 'images', 'serial');
    parallel_dir   = fullfile(out_dir, 'images', 'parallel');
    graphs_dir     = fullfile(out_dir, 'graphs');
    data_dir       = fullfile(out_dir, 'data');

    for d = {serial_dir, parallel_dir, graphs_dir, data_dir}
        if ~isfolder(d{1}), mkdir(d{1}); end
    end

    fprintf('Output directories created under: ./%s/\n\n', out_dir);

    % -----------------------------------------------------------------------
    % Pre-warm parallel pool BEFORE any timing begins.
    % -----------------------------------------------------------------------
    fprintf('Initializing parallel pool (%d workers)...\n', max_cores);
    poolobj = gcp('nocreate');
    if isempty(poolobj) || poolobj.NumWorkers ~= max_cores
        delete(gcp('nocreate'));
        parpool('local', max_cores);
    end
    fprintf('Pool ready with %d workers.\n\n', max_cores);

    % -----------------------------------------------------------------------
    % Main benchmark loop
    % -----------------------------------------------------------------------
    for i = 1:num_res
        res_name = resolutions{i, 1};
        width    = resolutions{i, 2};
        height   = resolutions{i, 3};
        pixels_count(i) = width * height;
        megapixels = pixels_count(i) / 1e6;

        fprintf('\n%s (%dx%d) — %.2f MP\n', res_name, width, height, megapixels);
        fprintf('%s\n', repmat('-', 1, 70));

        % Serial baseline
        fprintf('  [Serial]      ');
        [M_serial, serial_times(i)] = mandelbrot_serial(width, height, max_iterations);
        fprintf('  %.4f s\n', serial_times(i));

        % Save serial image
        serial_fname = sprintf('serial_%s_%dx%d.png', ...
            strrep(res_name,' ','_'), width, height);
        mandelbrot_plot(M_serial, width, height, serial_fname, serial_dir, ...
            sprintf('Serial - %s', res_name));

        % Parallel strategies at each worker count
        for w = 1:num_par_w
            nw = par_worker_counts(w);
            fprintf('\n  --- %d workers ---\n', nw);

            strat_fns = {
                @(W,H,MI,NW) mandelbrot_parallel(W,H,MI,NW),
                @(W,H,MI,NW) mandelbrot_shuffled(W,H,MI,NW),
                @(W,H,MI,NW) mandelbrot_interleaved(W,H,MI,NW),
                @(W,H,MI,NW) mandelbrot_spmd(W,H,MI,NW),
                @(W,H,MI,NW) mandelbrot_parfeval(W,H,MI,NW)
            };

            for s = 1:num_strat
                fprintf('  [%-11s] ', strategy_names{s});
                [M_par, t] = strat_fns{s}(width, height, max_iterations, nw);
                par_times(i, w, s) = t;
                speedups(i, w, s)     = serial_times(i) / t;
                efficiencies(i, w, s) = (speedups(i,w,s) / nw) * 100;

                fprintf('  %.4f s  (S=%.2fx  E=%.1f%%)\n', ...
                    t, speedups(i,w,s), efficiencies(i,w,s));

                % Verify correctness against serial (first worker config only)
                if w == 1 && max(abs(double(M_serial(:)) - double(M_par(:)))) > 0
                    warning('Mismatch: %s strategy at %s!', strategy_names{s}, res_name);
                end

                % Save image for max-worker config
                if w == num_par_w
                    par_fname = sprintf('par_%s_%dw_%s_%dx%d.png', ...
                        strrep(strategy_names{s},' ','_'), nw, ...
                        strrep(res_name,' ','_'), width, height);
                    mandelbrot_plot(M_par, width, height, par_fname, parallel_dir, ...
                        sprintf('%s (%d workers) - %s', strategy_names{s}, nw, res_name));
                end
            end
        end
    end

    % -----------------------------------------------------------------------
    % Generate all report-ready graphs
    % -----------------------------------------------------------------------
    fprintf('\n--- Generating graphs ---\n');
    generate_all_graphs(resolutions, pixels_count, serial_times, par_times, ...
        par_worker_counts, speedups, efficiencies, strategy_names, graphs_dir);

    % -----------------------------------------------------------------------
    % Save raw data
    % -----------------------------------------------------------------------
    fprintf('\n--- Saving data ---\n');
    save_all_data(data_dir, resolutions, pixels_count, serial_times, par_times, ...
        par_worker_counts, speedups, efficiencies, strategy_names);

    display_results_table(resolutions, pixels_count, serial_times, par_times, ...
        par_worker_counts, speedups, efficiencies, strategy_names);

    delete(gcp('nocreate'));
    fprintf('\nDone! All results saved to ./%s/\n', out_dir);
end


%% ========================================================================
%  GRAPHS: Five publication-quality figures matching TA sample layout
%  ========================================================================
%
%  Figure 1: Overview panel at P_max (Wall Time | Speedup | Efficiency)
%  Figure 2: Speedup vs Worker Count — one subplot per resolution (8 panels)
%  Figure 3: Efficiency vs Worker Count — one subplot per resolution (8 panels)
%  Figure 4: Estimated parallel fraction f — Amdahl & Gustafson view
%  Figure 5: Amdahl Law Fit — measured vs theoretical, one panel per strategy

function generate_all_graphs(resolutions, pixels_count, serial_times, par_times, ...
    par_worker_counts, speedups, efficiencies, strategy_names, graphs_dir)

    num_res   = size(resolutions, 1);
    num_par_w = length(par_worker_counts);
    num_strat = length(strategy_names);
    P_max     = par_worker_counts(end);

    % Index of max-worker column
    wmax_idx = num_par_w;

    % Worker axis including P=1 (for full scaling curve)
    all_workers = [1, par_worker_counts];

    % Colours per strategy (consistent across all figures)
    strat_colors = [
        0.2  0.6  1.0;   % Parallel   — blue
        1.0  0.5  0.1;   % Shuffled   — orange
        1.0  1.0  0.0;   % Interleaved— yellow
        0.9  0.2  0.9;   % SPMD       — magenta
        0.0  0.9  0.5    % Parfeval   — cyan-green
    ];

    strat_markers = {'o', 's', '^', 'd', '*'};

    res_labels = resolutions(:,1);

    % =====================================================================
    % Figure 1: Overview at P_max (3-panel: Wall Time | Speedup | Efficiency)
    % =====================================================================
    fig1 = figure('Name','Overview at P_max','Color','k', ...
        'Position',[50,50,1500,500]);

    % --- Panel A: Wall time (log scale) ---
    ax1 = subplot(1,3,1,'Parent',fig1);
    set(ax1,'Color','k','XColor','w','YColor','w','GridColor',[0.4 0.4 0.4]);
    hold(ax1,'on'); grid(ax1,'on');

    % Serial line
    megapix = pixels_count / 1e6;
    plot(ax1, 1:num_res, serial_times, '-o', 'Color','b', ...
        'LineWidth',2,'MarkerSize',6,'MarkerFaceColor','b','DisplayName','Serial');

    for s = 1:num_strat
        t_vec = squeeze(par_times(:, wmax_idx, s));
        plot(ax1, 1:num_res, t_vec, ['-' strat_markers{s}], ...
            'Color', strat_colors(s,:), 'LineWidth',1.8, 'MarkerSize',6, ...
            'MarkerFaceColor', strat_colors(s,:), 'DisplayName', strategy_names{s});
    end

    set(ax1,'YScale','log','XTick',1:num_res,'XTickLabel',res_labels, ...
        'XTickLabelRotation',45,'FontSize',9,'TickLabelInterpreter','none');
    xlabel(ax1,'Resolution','Color','w','FontSize',10);
    ylabel(ax1,'Wall Time (s)','Color','w','FontSize',10);
    title(ax1, sprintf('Wall Time  (P=%d)', P_max), 'Color','w','FontWeight','bold');
    legend(ax1,'TextColor','w','Color',[0.15 0.15 0.15],'FontSize',8, ...
        'Location','northwest');
    hold(ax1,'off');

    % --- Panel B: Speedup ---
    ax2 = subplot(1,3,2,'Parent',fig1);
    set(ax2,'Color','k','XColor','w','YColor','w','GridColor',[0.4 0.4 0.4]);
    hold(ax2,'on'); grid(ax2,'on');

    % Serial reference (S=1)
    plot(ax2, 1:num_res, ones(num_res,1), '-o','Color','b','LineWidth',2, ...
        'MarkerSize',4,'DisplayName','Serial');

    for s = 1:num_strat
        s_vec = squeeze(speedups(:, wmax_idx, s));
        plot(ax2, 1:num_res, s_vec, ['-' strat_markers{s}], ...
            'Color', strat_colors(s,:), 'LineWidth',1.8, 'MarkerSize',6, ...
            'MarkerFaceColor', strat_colors(s,:), 'DisplayName', strategy_names{s});
    end

    set(ax2,'XTick',1:num_res,'XTickLabel',res_labels,'XTickLabelRotation',45, ...
        'FontSize',9,'TickLabelInterpreter','none');
    xlabel(ax2,'Resolution','Color','w','FontSize',10);
    ylabel(ax2,'Speedup S = T_{serial}/T_{strategy}','Color','w','FontSize',10);
    title(ax2, sprintf('Speedup  (P=%d)', P_max),'Color','w','FontWeight','bold');
    legend(ax2,'TextColor','w','Color',[0.15 0.15 0.15],'FontSize',8, ...
        'Location','southeast');
    hold(ax2,'off');

    % --- Panel C: Efficiency ---
    ax3 = subplot(1,3,3,'Parent',fig1);
    set(ax3,'Color','k','XColor','w','YColor','w','GridColor',[0.4 0.4 0.4]);
    hold(ax3,'on'); grid(ax3,'on');

    for s = 1:num_strat
        e_vec = squeeze(efficiencies(:, wmax_idx, s));
        plot(ax3, 1:num_res, e_vec, ['-' strat_markers{s}], ...
            'Color', strat_colors(s,:), 'LineWidth',1.8, 'MarkerSize',6, ...
            'MarkerFaceColor', strat_colors(s,:), 'DisplayName', strategy_names{s});
    end

    set(ax3,'XTick',1:num_res,'XTickLabel',res_labels,'XTickLabelRotation',45, ...
        'FontSize',9,'TickLabelInterpreter','none','YLim',[40 115]);
    xlabel(ax3,'Resolution','Color','w','FontSize',10);
    ylabel(ax3,'Efficiency E = (S/P)\times100%','Color','w','FontSize',10);
    title(ax3, sprintf('Efficiency  (P=%d)', P_max),'Color','w','FontWeight','bold');
    legend(ax3,'TextColor','w','Color',[0.15 0.15 0.15],'FontSize',8, ...
        'Location','southeast');
    hold(ax3,'off');

    sgtitle(fig1, sprintf('Overview at Maximum Workers (P=%d)', P_max), ...
        'Color','w','FontSize',13,'FontWeight','bold');

    saveas(fig1, fullfile(graphs_dir,'fig1_overview_pmax.png'));
    exportgraphics(fig1, fullfile(graphs_dir,'fig1_overview_pmax.pdf'),'ContentType','vector');
    close(fig1);
    fprintf('  Saved: fig1_overview_pmax\n');

    % =====================================================================
    % Figure 2: Speedup vs Worker Count — 8 subplots (one per resolution)
    % =====================================================================
    fig2 = figure('Name','Speedup vs Workers by Resolution','Color','k', ...
        'Position',[50,50,1600,900]);

    for i = 1:num_res
        ax = subplot(2,4,i,'Parent',fig2);
        set(ax,'Color','k','XColor','w','YColor','w','GridColor',[0.35 0.35 0.35]);
        hold(ax,'on'); grid(ax,'on');

        % Ideal linear scaling
        plot(ax, all_workers, all_workers, '--w','LineWidth',1.2,'DisplayName','Ideal (S=P)');

        for s = 1:num_strat
            % Build full S curve: S(P=1)=1, then measured at par_worker_counts
            s_curve = [1, reshape(speedups(i,:,s), 1, [])];
            plot(ax, all_workers, s_curve, ['-' strat_markers{s}], ...
                'Color', strat_colors(s,:), 'LineWidth',1.6, 'MarkerSize',6, ...
                'MarkerFaceColor', strat_colors(s,:), 'DisplayName', strategy_names{s});
        end

        set(ax,'XTick', all_workers,'FontSize',8,'XColor','w','YColor','w', ...
            'YLim',[0, P_max+0.5]);
        xlabel(ax,'Workers (P)','Color','w','FontSize',8);
        ylabel(ax,'Speedup S','Color','w','FontSize',8);
        title(ax, res_labels{i},'Color','w','FontWeight','bold','FontSize',9, ...
            'Interpreter','none');

        if i == 1
            legend(ax,'TextColor','w','Color',[0.1 0.1 0.1],'FontSize',7, ...
                'Location','northwest');
        end
        hold(ax,'off');
    end

    sgtitle(fig2,'Speedup vs Worker Count — by Resolution', ...
        'Color','w','FontSize',13,'FontWeight','bold');

    saveas(fig2, fullfile(graphs_dir,'fig2_speedup_vs_workers_grid.png'));
    exportgraphics(fig2, fullfile(graphs_dir,'fig2_speedup_vs_workers_grid.pdf'),'ContentType','vector');
    close(fig2);
    fprintf('  Saved: fig2_speedup_vs_workers_grid\n');

    % =====================================================================
    % Figure 3: Efficiency vs Worker Count — 8 subplots
    % =====================================================================
    fig3 = figure('Name','Efficiency vs Workers by Resolution','Color','k', ...
        'Position',[50,50,1600,900]);

    for i = 1:num_res
        ax = subplot(2,4,i,'Parent',fig3);
        set(ax,'Color','k','XColor','w','YColor','w','GridColor',[0.35 0.35 0.35]);
        hold(ax,'on'); grid(ax,'on');

        % Ideal 100% efficiency reference
        yline(ax, 100,'--w','LineWidth',1.2,'Alpha',0.6);

        for s = 1:num_strat
            % E at P=1 is always 100%
            e_curve = [100, reshape(efficiencies(i,:,s), 1, [])];
            plot(ax, all_workers, e_curve, ['-' strat_markers{s}], ...
                'Color', strat_colors(s,:), 'LineWidth',1.6, 'MarkerSize',6, ...
                'MarkerFaceColor', strat_colors(s,:), 'DisplayName', strategy_names{s});
        end

        set(ax,'XTick', all_workers,'FontSize',8,'YLim',[0 120]);
        xlabel(ax,'Workers (P)','Color','w','FontSize',8);
        ylabel(ax,'Efficiency (%)','Color','w','FontSize',8);
        title(ax, res_labels{i},'Color','w','FontWeight','bold','FontSize',9, ...
            'Interpreter','none');

        if i == 1
            legend(ax,'TextColor','w','Color',[0.1 0.1 0.1],'FontSize',7, ...
                'Location','southwest');
        end
        hold(ax,'off');
    end

    sgtitle(fig3,'Parallel Efficiency vs Worker Count — by Resolution', ...
        'Color','w','FontSize',13,'FontWeight','bold');

    saveas(fig3, fullfile(graphs_dir,'fig3_efficiency_vs_workers_grid.png'));
    exportgraphics(fig3, fullfile(graphs_dir,'fig3_efficiency_vs_workers_grid.pdf'),'ContentType','vector');
    close(fig3);
    fprintf('  Saved: fig3_efficiency_vs_workers_grid\n');

    % =====================================================================
    % Figure 4: Estimated parallel fraction f — Amdahl & Gustafson view
    %
    % f estimated per resolution and strategy using:
    %   Amdahl:    S = 1 / ((1-f) + f/P)
    %   => f = (1/S - 1) / (1/P - 1)
    %
    % Gustafson view: same f plotted against log10(pixel count)
    % =====================================================================
    f_est = zeros(num_res, num_strat);  % using max-worker column

    for s = 1:num_strat
        S_obs  = squeeze(speedups(:, wmax_idx, s));
        P_obs  = P_max;
        f_vals = (1./S_obs - 1) ./ (1/P_obs - 1);
        f_vals(f_vals <= 0 | f_vals >= 1) = NaN;
        f_est(:, s) = f_vals;
    end

    fig4 = figure('Name','Estimated f','Color','k', ...
        'Position',[50,50,1400,600]);

    % --- Panel A: f vs resolution label ---
    ax4a = subplot(1,2,1,'Parent',fig4);
    set(ax4a,'Color','k','XColor','w','YColor','w','GridColor',[0.35 0.35 0.35]);
    hold(ax4a,'on'); grid(ax4a,'on');

    yline(ax4a, 1,'--w','LineWidth',1,'Alpha',0.5,'DisplayName','f=1 (fully parallel)');

    for s = 1:num_strat
        plot(ax4a, 1:num_res, f_est(:,s), ['-' strat_markers{s}], ...
            'Color', strat_colors(s,:),'LineWidth',1.8,'MarkerSize',8, ...
            'MarkerFaceColor',strat_colors(s,:),'DisplayName',strategy_names{s});
    end

    set(ax4a,'XTick',1:num_res,'XTickLabel',res_labels,'XTickLabelRotation',45, ...
        'FontSize',9,'YLim',[0 1.05],'TickLabelInterpreter','none');
    xlabel(ax4a,'Resolution','Color','w','FontSize',10);
    ylabel(ax4a,'Estimated f  (parallel fraction)','Color','w','FontSize',10);
    title(ax4a,'f̂ vs Resolution (Amdahl fit)','Color','w','FontWeight','bold','FontSize',10);
    legend(ax4a,'TextColor','w','Color',[0.1 0.1 0.1],'FontSize',8,'Location','southeast');
    hold(ax4a,'off');

    % --- Panel B: f vs log10(pixel count) — Gustafson trend ---
    ax4b = subplot(1,2,2,'Parent',fig4);
    set(ax4b,'Color','k','XColor','w','YColor','w','GridColor',[0.35 0.35 0.35]);
    hold(ax4b,'on'); grid(ax4b,'on');

    yline(ax4b, 1,'--w','LineWidth',1,'Alpha',0.5,'DisplayName','f=1');
    log_px = log10(pixels_count);

    for s = 1:num_strat
        scatter(ax4b, log_px, f_est(:,s), 60, strat_colors(s,:), ...
            strat_markers{s}, 'filled', 'DisplayName', strategy_names{s});
        % Trend line (ignore NaN)
        valid = ~isnan(f_est(:,s));
        if sum(valid) >= 2
            p = polyfit(log_px(valid), f_est(valid,s), 1);
            x_fit = linspace(min(log_px), max(log_px), 100);
            plot(ax4b, x_fit, polyval(p,x_fit), '-', 'Color', strat_colors(s,:), ...
                'LineWidth', 1.2, 'HandleVisibility','off');
        end
    end

    set(ax4b,'XTick', log_px,'XTickLabel',res_labels,'XTickLabelRotation',45, ...
        'FontSize',9,'YLim',[0 1.05],'TickLabelInterpreter','none');
    xlabel(ax4b,'log_{10}(pixel count)','Color','w','FontSize',10);
    ylabel(ax4b,'Estimated f','Color','w','FontSize',10);
    title(ax4b,'f̂ vs Problem Size (Gustafson trend)','Color','w','FontWeight','bold','FontSize',10);
    legend(ax4b,'TextColor','w','Color',[0.1 0.1 0.1],'FontSize',8,'Location','southeast');
    hold(ax4b,'off');

    sgtitle(fig4,'Estimated Parallel Fraction f̂  (Amdahl Regression)', ...
        'Color','w','FontSize',13,'FontWeight','bold');

    saveas(fig4, fullfile(graphs_dir,'fig4_amdahl_f_estimate.png'));
    exportgraphics(fig4, fullfile(graphs_dir,'fig4_amdahl_f_estimate.pdf'),'ContentType','vector');
    close(fig4);
    fprintf('  Saved: fig4_amdahl_f_estimate\n');

    % =====================================================================
    % Figure 5: Amdahl Law Fit — measured vs theoretical
    %   One subplot per strategy (2x3 grid, last cell empty if 5 strategies)
    %   Scatter: measured speedup coloured by resolution
    %   Curve:   Amdahl prediction using median f across resolutions
    % =====================================================================
    % Colours per resolution
    res_colors = lines(num_res);

    fig5 = figure('Name',"Amdahl's Law Fit",'Color','k', ...
        'Position',[50,50,1500,900]);

    subplot_positions = [1 2 3; 4 5 6];  % 2 rows x 3 cols, last unused

    for s = 1:num_strat
        % Use median f across resolutions (robust to outliers)
        col = f_est(:,s);
        f_med = median(col(~isnan(col)));
        if isnan(f_med) || f_med <= 0, f_med = 0.9; end

        P_range = linspace(1, P_max, 200);
        amdahl_pred = 1 ./ ((1-f_med) + f_med./P_range);

        ax = subplot(2,3,s,'Parent',fig5);
        set(ax,'Color','k','XColor','w','YColor','w','GridColor',[0.35 0.35 0.35]);
        hold(ax,'on'); grid(ax,'on');

        % Ideal linear
        plot(ax, [1 P_max],[1 P_max],'--w','LineWidth',1.5,'DisplayName','Ideal S=P');

        % Amdahl curve
        plot(ax, P_range, amdahl_pred, '-r','LineWidth',2.5, ...
            'DisplayName', sprintf("Amdahl f=%.3f", f_med));

        % Measured scatter points (all resolutions, all worker counts)
        for i = 1:num_res
            s_meas = [1, reshape(speedups(i,:,s), 1, [])];
            scatter(ax, all_workers, s_meas, 50, res_colors(i,:), 'filled', ...
                'DisplayName', res_labels{i});
        end

        set(ax,'XTick', all_workers,'FontSize',9,'YLim',[0 P_max+0.5], ...
            'XLim',[0.5 P_max+0.3]);
        xlabel(ax,'Workers (P)','Color','w','FontSize',9);
        ylabel(ax,'Speedup S','Color','w','FontSize',9);
        title(ax, strategy_names{s},'Color','w','FontWeight','bold','FontSize',11);

        % Legend: only strategy info + resolutions
        hl = legend(ax,'TextColor','w','Color',[0.08 0.08 0.08],'FontSize',7, ...
            'Location','northwest','NumColumns',2);
        hold(ax,'off');
    end

    % Hide unused 6th subplot
    subplot(2,3,6,'Parent',fig5,'Visible','off');

    sgtitle(fig5,"Amdahl's Law Fit — Measured vs Theoretical", ...
        'Color','w','FontSize',13,'FontWeight','bold');

    saveas(fig5, fullfile(graphs_dir,"fig5_amdahl_law_fit.png"));
    exportgraphics(fig5, fullfile(graphs_dir,"fig5_amdahl_law_fit.pdf"),'ContentType','vector');
    close(fig5);
    fprintf('  Saved: fig5_amdahl_law_fit\n');

    close all;
end


%% ========================================================================
%  DATA EXPORT
%  ========================================================================
function save_all_data(data_dir, resolutions, pixels_count, serial_times, par_times, ...
    par_worker_counts, speedups, efficiencies, strategy_names)

    num_res   = size(resolutions,1);
    num_par_w = length(par_worker_counts);
    num_strat = length(strategy_names);

    % Build flat CSV table
    rows = {};
    for i = 1:num_res
        for w = 1:num_par_w
            for s = 1:num_strat
                rows{end+1} = {
                    resolutions{i,1}, resolutions{i,2}, resolutions{i,3}, ...
                    pixels_count(i)/1e6, serial_times(i), ...
                    par_worker_counts(w), strategy_names{s}, ...
                    par_times(i,w,s), speedups(i,w,s), efficiencies(i,w,s)
                };
            end
        end
    end

    T = cell2table(vertcat(rows{:}), 'VariableNames', ...
        {'Resolution','Width','Height','Megapixels','Serial_Time_s', ...
         'Workers','Strategy','Par_Time_s','Speedup','Efficiency_pct'});

    writetable(T, fullfile(data_dir,'benchmark_results.csv'));

    save(fullfile(data_dir,'benchmark_data.mat'), ...
        'resolutions','pixels_count','serial_times','par_times', ...
        'par_worker_counts','speedups','efficiencies','strategy_names');

    fprintf('  Data saved: benchmark_results.csv + benchmark_data.mat\n');
end


%% ========================================================================
%  CONSOLE TABLE
%  ========================================================================
function display_results_table(resolutions, pixels_count, serial_times, par_times, ...
    par_worker_counts, speedups, efficiencies, strategy_names)

    num_par_w = length(par_worker_counts);
    wmax      = num_par_w;   % index of max-worker column

    fprintf('\n%s\n', repmat('=',1,100));
    fprintf('  BENCHMARK SUMMARY  (P=%d max workers)\n', par_worker_counts(end));
    fprintf('%s\n', repmat('=',1,100));
    fprintf('%-12s | %6s | %10s', 'Resolution','MP','Serial(s)');
    for s = 1:length(strategy_names)
        fprintf(' | %10s  S      E%%', strategy_names{s});
    end
    fprintf('\n%s\n', repmat('-',1,100));

    for i = 1:size(resolutions,1)
        fprintf('%-12s | %6.2f | %10.4f', ...
            resolutions{i,1}, pixels_count(i)/1e6, serial_times(i));
        for s = 1:length(strategy_names)
            fprintf(' | %8.4f  %5.2fx  %5.1f%%', ...
                par_times(i,wmax,s), speedups(i,wmax,s), efficiencies(i,wmax,s));
        end
        fprintf('\n');
    end
    fprintf('%s\n', repmat('=',1,100));
end


%% ========================================================================
%  PART 1: Mandelbrot Image Plotting
%  ========================================================================
function mandelbrot_plot(M, width, height, filename, save_dir, title_text)
    fig = figure('Visible','off','Position',[100,100,min(width,1200),min(height,800)]);
    imagesc(M); axis image off; colormap(turbo); colorbar;
    title(title_text,'FontSize',12,'Interpreter','none');
    full_path = fullfile(save_dir, filename);
    try
        exportgraphics(fig, full_path, 'Resolution',150);
    catch
        saveas(fig, full_path);
    end
    close(fig);
end


%% ========================================================================
%  PART 2: Serial Mandelbrot
%  ========================================================================
function [M, elapsed] = mandelbrot_serial(width, height, max_iterations)
    x_coords = linspace(-2.0, 0.5, width);
    y_coords = linspace(-1.2, 1.2, height);
    M = zeros(height, width, 'uint16');

    t_start = tic;
    for r = 1:height
        cy = y_coords(r);
        for c = 1:width
            cx = x_coords(c);
            zx = 0; zy = 0; iter = 0;
            while (iter < max_iterations) && (zx^2 + zy^2 <= 4)
                zx_new = zx^2 - zy^2 + cx;
                zy     = 2*zx*zy + cy;
                zx     = zx_new;
                iter   = iter + 1;
            end
            M(r,c) = iter;
        end
    end
    elapsed = toc(t_start);
end


%% ========================================================================
%  PART 3a: Parallel — Standard parfor (row decomposition)
%  ========================================================================
function [M, elapsed] = mandelbrot_parallel(width, height, max_iterations, num_workers)
    x_coords = linspace(-2.0, 0.5, width);
    y_coords = linspace(-1.2, 1.2, height);
    M = zeros(height, width, 'uint16');

    t_start = tic;
    parfor (r = 1:height, num_workers)
        cy = y_coords(r);
        row = zeros(1, width, 'uint16');
        for c = 1:width
            cx = x_coords(c);
            zx = 0; zy = 0; iter = 0;
            while (iter < max_iterations) && (zx^2 + zy^2 <= 4)
                zx_new = zx^2 - zy^2 + cx;
                zy     = 2*zx*zy + cy;
                zx     = zx_new;
                iter   = iter + 1;
            end
            row(c) = iter;
        end
        M(r,:) = row;
    end
    elapsed = toc(t_start);
end


%% ========================================================================
%  PART 3b: Shuffled parfor
%  =========================================================================
%  Motivation: In the Mandelbrot set, rows near the centre of the complex
%  plane (y~0) tend to hit max_iterations most often — they are the most
%  expensive rows. When parfor assigns rows sequentially, all the heavy rows
%  land on the same workers, causing load imbalance.
%
%  Fix: Shuffle the row order so each worker receives a random mix of cheap
%  and expensive rows.  The permutation is inverted before writing back to M
%  so the final matrix is identical to the serial result.

function [M, elapsed] = mandelbrot_shuffled(width, height, max_iterations, num_workers)
    x_coords = linspace(-2.0, 0.5, width);
    y_coords = linspace(-1.2, 1.2, height);

    % Shuffle row indices for balanced load distribution
    perm    = randperm(height);
    inv_perm(perm) = 1:height;          %#ok<AGROW>  inverse permutation
    y_shuf  = y_coords(perm);           % reordering y-coordinates accordingly

    M_shuf = zeros(height, width, 'uint16');

    t_start = tic;
    parfor (r = 1:height, num_workers)
        cy = y_shuf(r);
        row = zeros(1, width, 'uint16');
        for c = 1:width
            cx = x_coords(c);
            zx = 0; zy = 0; iter = 0;
            while (iter < max_iterations) && (zx^2 + zy^2 <= 4)
                zx_new = zx^2 - zy^2 + cx;
                zy     = 2*zx*zy + cy;
                zx     = zx_new;
                iter   = iter + 1;
            end
            row(c) = iter;
        end
        M_shuf(r,:) = row;
    end
    elapsed = toc(t_start);

    % Restoring original row ordering
    M = M_shuf(inv_perm, :);
end


%% ========================================================================
%  PART 3c: Interleaved parfor
%  =========================================================================
%  Motivation: Instead of random shuffling, assign rows in a round-robin
%  (interleaved / strided) fashion: worker 1 gets rows 1, P+1, 2P+1, ...;
%  worker 2 gets rows 2, P+2, 2P+2, ...; etc.
%
%  This is a deterministic load-balancing strategy.  Because cheap and
%  expensive rows alternate predictably (the set is roughly symmetric about
%  the real axis), striding ensures every worker sees an equal share of
%  both.  Unlike the random shuffle, this is reproducible between runs.

function [M, elapsed] = mandelbrot_interleaved(width, height, max_iterations, num_workers)
    x_coords = linspace(-2.0, 0.5, width);
    y_coords = linspace(-1.2, 1.2, height);

    % Interleaved index order: [1, P+1, 2P+1, ..., 2, P+2, ..., P, 2P, ...]
    % i.e. row r_orig maps to logical index such that worker floor(r/P) handles it
    stride_idx  = reshape(reshape(1:height, num_workers, []).', 1, []);
    % Clamp to height (last stride may be shorter than num_workers)
    stride_idx  = stride_idx(stride_idx <= height);
    y_interleaved = y_coords(stride_idx);

    % Inverse map for restoring order
    inv_idx(stride_idx) = 1:height;  %#ok<AGROW>

    M_int = zeros(height, width, 'uint16');

    t_start = tic;
    parfor (r = 1:height, num_workers)
        cy = y_interleaved(r);
        row = zeros(1, width, 'uint16');
        for c = 1:width
            cx = x_coords(c);
            zx = 0; zy = 0; iter = 0;
            while (iter < max_iterations) && (zx^2 + zy^2 <= 4)
                zx_new = zx^2 - zy^2 + cx;
                zy     = 2*zx*zy + cy;
                zx     = zx_new;
                iter   = iter + 1;
            end
            row(c) = iter;
        end
        M_int(r,:) = row;
    end
    elapsed = toc(t_start);

    M = M_int(inv_idx, :);
end


%% ========================================================================
%  PART 3d: SPMD (Single Program Multiple Data)
%  =========================================================================
%  Motivation: parfor schedules iterations dynamically from a central queue.
%  SPMD instead launches all workers simultaneously with a pre-assigned
%  static partition — each worker knows exactly which rows it owns from the
%  start.  There is no task-queue overhead for fine-grained scheduling.
%
%  Implementation:
%    - spmd block launches num_workers labs (labindex 1..num_workers).
%    - Each lab computes its own contiguous block of rows.
%    - Results are gathered on the client with gcat (global concatenation).
%
%  Variable classification:
%    labindex, numlabs — PCT intrinsics, one per lab
%    my_rows           — range of rows owned by this lab
%    local_M           — local result buffer (subset of full image)
%    M_dist            — Composite: one chunk per lab after spmd block

function [M, elapsed] = mandelbrot_spmd(width, height, max_iterations, num_workers)
    x_coords = linspace(-2.0, 0.5, width);
    y_coords = linspace(-1.2, 1.2, height);

    t_start = tic;

    spmd(num_workers)
        % Each lab computes a contiguous block of rows
        rows_per_lab = ceil(height / numlabs);
        r_start = (labindex-1)*rows_per_lab + 1;
        r_end   = min(labindex*rows_per_lab, height);

        local_M = zeros(r_end - r_start + 1, width, 'uint16');

        for local_r = 1:(r_end - r_start + 1)
            cy  = y_coords(r_start + local_r - 1);
            row = zeros(1, width, 'uint16');
            for c = 1:width
                cx = x_coords(c);
                zx = 0; zy = 0; iter = 0;
                while (iter < max_iterations) && (zx^2 + zy^2 <= 4)
                    zx_new = zx^2 - zy^2 + cx;
                    zy     = 2*zx*zy + cy;
                    zx     = zx_new;
                    iter   = iter + 1;
                end
                row(c) = iter;
            end
            local_M(local_r,:) = row;
        end
    end

    elapsed = toc(t_start);

    % Reassemble: M_dist is a Composite — concatenate along rows
    M = zeros(height, width, 'uint16');
    rows_per_lab = ceil(height / num_workers);
    for k = 1:num_workers
        r_start = (k-1)*rows_per_lab + 1;
        r_end   = min(k*rows_per_lab, height);
        M(r_start:r_end, :) = local_M{k};
    end
end


%% ========================================================================
%  PART 3e: Parfeval (asynchronous futures)
%  =========================================================================
%  Motivation: parfeval submits tasks asynchronously so the client does not
%  block waiting for each task to finish.  This removes the synchronisation
%  barrier present in parfor and SPMD, allowing the scheduler to overlap
%  computation and communication.
%
%  Implementation:
%    - Divide rows into num_workers equal chunks.
%    - Submit one parfeval future per chunk (calls a local helper function).
%    - fetchOutputs collects results as they complete.
%
%  Note: nested parfeval (calling parfeval inside a function run on a worker)
%  is NOT supported. We call parfeval from the client, passing chunk data.

function [M, elapsed] = mandelbrot_parfeval(width, height, max_iterations, num_workers)
    x_coords = linspace(-2.0, 0.5, width);
    y_coords = linspace(-1.2, 1.2, height);

    % Divide rows into chunks for each future
    chunk_size = ceil(height / num_workers);

    futures(num_workers) = parallel.FevalFuture;  % pre-allocate

    t_start = tic;

    for k = 1:num_workers
        r_start = (k-1)*chunk_size + 1;
        r_end   = min(k*chunk_size, height);
        y_chunk = y_coords(r_start:r_end);

        futures(k) = parfeval(@mandelbrot_chunk, 1, ...
            x_coords, y_chunk, max_iterations);
    end

    % Collect results
    M = zeros(height, width, 'uint16');
    for k = 1:num_workers
        r_start = (k-1)*chunk_size + 1;
        r_end   = min(k*chunk_size, height);
        chunk   = fetchOutputs(futures(k));
        M(r_start:r_end, :) = chunk;
    end

    elapsed = toc(t_start);
end

% Helper: compute one row-chunk (runs on a worker, no nested parfeval)
function chunk = mandelbrot_chunk(x_coords, y_chunk, max_iterations)
    h = length(y_chunk);
    w = length(x_coords);
    chunk = zeros(h, w, 'uint16');
    for r = 1:h
        cy = y_chunk(r);
        for c = 1:w
            cx = x_coords(c);
            zx = 0; zy = 0; iter = 0;
            while (iter < max_iterations) && (zx^2 + zy^2 <= 4)
                zx_new = zx^2 - zy^2 + cx;
                zy     = 2*zx*zy + cy;
                zx     = zx_new;
                iter   = iter + 1;
            end
            chunk(r,c) = iter;
        end
    end
end