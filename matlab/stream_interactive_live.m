function stream_interactive_live(varargin)
% STREAM_INTERACTIVE_LIVE
% Runs Zero_Perturb_MPPT_Live interactively in paced real-time while streaming
% live telemetry to the web dashboard (http://localhost:3000).
%
% Usage:
%   stream_interactive_live                       % Runs for 120 seconds
%   stream_interactive_live(300)                  % Runs for 300 seconds
%   stream_interactive_live(inf)                  % Runs indefinitely until stopped

    clc;
    fprintf('\n============================================================\n');
    fprintf('  INTERACTIVE SLIDER LIVE STREAM TO WEB DASHBOARD           \n');
    fprintf('============================================================\n');

    mdl = 'Zero_Perturb_MPPT_Live';
    simDuration = 180; % default 3 minutes of interactive slider control

    if nargin >= 1 && isnumeric(varargin{1})
        simDuration = double(varargin{1});
    end

    baseUrl = "http://localhost:3000";

    %% 1. Verify Web Server Connectivity
    fprintf('1. Connecting to Web Server (%s)...\n', baseUrl);
    try
        opt = weboptions('MediaType', 'application/json', 'Timeout', 4);
        health = webread(baseUrl + "/api/health", opt);
        fprintf('   [OK] Server is ONLINE. Connected Clients: %d\n', health.matlab.clients);
    catch ME
        fprintf('   [ERROR] Web server not reachable: %s\n', ME.message);
        fprintf('   Ensure your dashboard is running at http://localhost:3000\n');
        return;
    end

    %% 2. Load Model & Enable Simulation Pacing
    if ~bdIsLoaded(mdl)
        load_system(mdl);
    end
    open_system(mdl);

    % Enable simulation pacing so simulation clock matches real-world wall clock
    try
        set_param(mdl, 'EnablePacing', 'on');
        set_param(mdl, 'PacedSimulationRate', '1.0'); % 1x real-time pacing
    catch
        % Older MATLAB versions ignore if pacing property is different
    end

    if isinf(simDuration)
        set_param(mdl, 'StopTime', 'inf');
    else
        set_param(mdl, 'StopTime', num2str(simDuration));
    end

    fprintf('2. Model Ready: %s\n', mdl);
    fprintf('   Simulation Stop Time: %s s\n', get_param(mdl, 'StopTime'));
    fprintf('   Interactive Sliders : Live_G_W (Irradiance) & Live_T_amb (Temp)\n');
    fprintf('   Web Destination     : %s\n\n', baseUrl);

    %% 3. Start Simulink Simulation & Stream Loop
    fprintf('============================================================\n');
    fprintf('  SIMULATION ACTIVE — MOVE SLIDERS IN SIMULINK NOW!         \n');
    fprintf('  Dashboard updating at http://localhost:3000               \n');
    fprintf('  Press Ctrl+C or run stop_live_matlab_stream to stop       \n');
    fprintf('============================================================\n\n');

    setappdata(0, 'MPPT_LIVE_STREAM_RUNNING', true);

    % Run simulation in background or interactive loop
    start_live_matlab_stream("S1", baseUrl, 0.25, 12.0);

end
