%% ============================================================
% ESP32 MPPT CONTROL PLATFORM — MATLAB PIPELINE RUNNER
% ============================================================
% This master script runs your Simulink simulation ('ekf.slx'),
% streams the extracted telemetry frames to the local web server
% (http://localhost:3000), logs them persistently to SQLite, and
% generates comparison plots.
%
% Usage:
%   run_pipeline
% ============================================================

clc;
clearvars -except ans;

fprintf('\n');
fprintf('============================================================\n');
fprintf(' ESP32 MPPT DASHBOARD: MATLAB INTEGRATION PIPELINE\n');
fprintf('============================================================\n');

BASE_URL = "http://localhost:3000";
MODEL_NAME = "ekf";

%% 1. Verify Local Server Connectivity
fprintf('\n[1/4] Checking Web Server at %s...\n', BASE_URL);
try
    options = weboptions('MediaType', 'application/json', 'Timeout', 5);
    health = webread(BASE_URL + "/api/health", options);
    fprintf('  Server is ONLINE. Total database samples: %d\n', health.matlab.persistedTotal);
catch ME
    warning('Server check failed: %s', ME.message);
    fprintf('  Make sure the dev server is running on %s\n', BASE_URL);
    return;
end

%% 2. Run Simulink Simulation
fprintf('\n[2/4] Running Simulink model (%s.slx)...\n', MODEL_NAME);
try
    out = sim(MODEL_NAME);
    fprintf('  Simulink run complete.\n');
catch ME
    error('Failed to run Simulink model: %s', ME.message);
end

%% 3. Stream Telemetry to Web Dashboard & Log to SQLite
fprintf('\n[3/4] Streaming telemetry to dashboard (%s/api/telemetry/simulation)...\n', BASE_URL);
response = send_simulation_to_web(out, BASE_URL);

%% 4. Generate Telemetry Analysis & Comparison Plot
fprintf('\n[4/4] Generating MPPT comparison plots...\n');
if exist('plot_mppt_comparison', 'file') == 2
    fig = plot_mppt_comparison(BASE_URL);
    if ~isempty(fig)
        fprintf('  Comparison plot generated successfully.\n');
    end
else
    fprintf('  plot_mppt_comparison.m not found. Skipping plot.\n');
end

fprintf('\n============================================================\n');
fprintf(' PIPELINE COMPLETE: Telemetry streamed & logged to database!\n');
fprintf(' Web Dashboard: %s\n', BASE_URL);
fprintf('============================================================\n\n');
