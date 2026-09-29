function fig = plot_mppt_comparison(baseUrl)
% PLOT_MPPT_COMPARISON Fetch logged data and plot comparison curves in MATLAB.
%
% Usage:
%   plot_mppt_comparison();
%   plot_mppt_comparison("http://localhost:3000");

    if nargin < 1 || strlength(string(baseUrl)) == 0
        baseUrl = "http://localhost:3000";
    end

    T = fetch_telemetry_from_web(baseUrl);
    if isempty(T) || height(T) == 0
        warning("No telemetry samples found in database to plot.");
        fig = [];
        return;
    end

    t_rel = (T.timestamp_ms - T.timestamp_ms(1)) / 1000;

    fig = figure("Name", "MATLAB MPPT Logged Analysis", "NumberTitle", "off", "Color", [0.06 0.09 0.14]);
    set(fig, "Position", [150, 150, 1000, 700]);

    % Power Output
    subplot(3, 1, 1);
    plot(t_rel, T.p_pv, "Color", [0.45 0.89 0.82], "LineWidth", 2);
    grid on;
    title(sprintf("P_{pv} Power Output (Mean: %.2f W, Peak: %.2f W)", mean(T.p_pv), max(T.p_pv)), ...
        "Color", [0.9 0.95 1.0], "FontWeight", "bold");
    xlabel("Time (s)", "Color", [0.7 0.8 0.85]); ylabel("Power (W)", "Color", [0.7 0.8 0.85]);
    set(gca, "Color", [0.09 0.13 0.20], "XColor", [0.6 0.7 0.75], "YColor", [0.6 0.7 0.75]);

    % Voltage vs V_mp
    subplot(3, 1, 2);
    plot(t_rel, T.v_pv, "Color", [0.5 0.84 0.95], "LineWidth", 1.8); hold on;
    plot(t_rel, T.v_mp, "--", "Color", [0.95 0.77 0.43], "LineWidth", 1.5);
    legend("V_{pv} Array", "V_{mp} Target", "TextColor", [0.9 0.9 0.9], "Color", [0.09 0.13 0.20]);
    grid on;
    title("Array Voltage vs Maximum Power Point (V_{mp})", "Color", [0.9 0.95 1.0], "FontWeight", "bold");
    xlabel("Time (s)", "Color", [0.7 0.8 0.85]); ylabel("Voltage (V)", "Color", [0.7 0.8 0.85]);
    set(gca, "Color", [0.09 0.13 0.20], "XColor", [0.6 0.7 0.75], "YColor", [0.6 0.7 0.75]);

    % Duty Cycle & Current
    subplot(3, 1, 3);
    yyaxis left;
    plot(t_rel, T.duty * 100, "Color", [0.94 0.47 0.57], "LineWidth", 1.8);
    ylabel("PWM Duty (%)", "Color", [0.94 0.47 0.57]);
    
    yyaxis right;
    plot(t_rel, T.i_pv, "Color", [0.73 0.55 0.99], "LineWidth", 1.8);
    ylabel("Array Current (A)", "Color", [0.73 0.55 0.99]);
    grid on;
    title("Controller PWM Duty Cycle & Array Current", "Color", [0.9 0.95 1.0], "FontWeight", "bold");
    xlabel("Time (s)", "Color", [0.7 0.8 0.85]);
    set(gca, "Color", [0.09 0.13 0.20], "XColor", [0.6 0.7 0.75]);
end
