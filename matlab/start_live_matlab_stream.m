function start_live_matlab_stream(varargin)
% START_LIVE_MATLAB_STREAM
% CONTINUOUS CHUNKED SIMULINK LIVE TELEMETRY STREAM WITH DIRECT SIMULINK SIGNAL PATH
%
% Architecture:
%   Scenario G_irr(t), T_amb(t) -> simIn block parameters (gIrrPath, tAmbPath)
%       ↓
%   Navin PV Subsystem inside Simulink -> I_pv, T_c
%       ↓
%   EKF_Algorithm block inside Simulink -> V_mp_ref, I_ph_est, T_c_est
%       ↓
%   MPPT Control / Duty path inside Simulink -> duty D
%       ↓
%   50 kHz Boost Power Stage inside Simulink -> V_out, I_out
%       ↓
%   logsout Signal Logging Extraction -> POST http://localhost:3000/api/telemetry/simulation
%       ↓
%   Backend /ws/matlab -> React dashboard updates LIVE
%
% Usage:
%   start_live_matlab_stream             % Scenario S2 (Irradiance 1000 -> 500 -> 800 -> 1000 W/m^2)
%   start_live_matlab_stream("S3")       % Scenario S3 (Temp 25 -> 40 -> 60 °C)

    clc;
    fprintf('\n============================================================\n');
    fprintf(' CONTINUOUS CHUNKED SIMULINK LIVE TELEMETRY STREAM\n');
    fprintf('============================================================\n');

    %% 1. Configuration & Defaults
    baseUrl       = "http://localhost:3000";
    modelName     = "ekf";
    scenarioCode  = "S2";
    chunkDuration = 0.20;   % 0.20 s simulation time per chunk
    rateHz        = 15.0;   % 15 Hz telemetry delivery rate to browser
    showPlot      = true;

    if nargin >= 1 && (isstring(varargin{1}) || ischar(varargin{1}))
        arg1 = upper(string(varargin{1}));
        if startsWith(arg1, "HTTP://") || startsWith(arg1, "HTTPS://")
            baseUrl = arg1;
        elseif arg1 == "S2" || arg1 == "S3" || arg1 == "S5" || arg1 == "S1"
            scenarioCode = arg1;
        else
            modelName = lower(arg1);
        end
    end

    if nargin >= 2
        arg2 = varargin{2};
        if isstring(arg2) || ischar(arg2)
            baseUrl = string(arg2);
        elseif isnumeric(arg2)
            chunkDuration = double(arg2);
        end
    end

    if nargin >= 3 && isnumeric(varargin{3})
        chunkDuration = double(varargin{3});
    end

    if nargin >= 4 && isnumeric(varargin{4})
        rateHz = double(varargin{4});
    end

    chunkDuration = max(0.05, min(1.0, chunkDuration));
    rateHz        = max(5.0, min(30.0, rateHz));

    %% 2. Check for Duplicate Active Streams
    running = getappdata(0, 'MPPT_LIVE_STREAM_RUNNING');
    if ~isempty(running) && running
        fprintf('[WARN] Resetting previous active stream session...\n');
        setappdata(0, 'MPPT_LIVE_STREAM_RUNNING', false);
        pause(0.2);
    end

    %% 3. Verify Server Connectivity
    fprintf('Checking Web Server at %s...\n', baseUrl);
    try
        httpOptions = weboptions('MediaType', 'application/json', 'Timeout', 5);
        health = webread(baseUrl + "/api/health", httpOptions);
        fprintf('  [OK] Server is ONLINE.\n');
        fprintf('  [OK] Telemetry Endpoint : %s%s\n', baseUrl, health.matlab.endpoint);
        fprintf('  [OK] WebSocket Route    : %s\n', health.matlab.websocket);
        fprintf('  [OK] Connected Clients  : %d\n', health.matlab.clients);
    catch ME
        fprintf('  [ERROR] Server connectivity failed: %s\n', ME.message);
        fprintf('  Make sure dev server is running on %s\n', baseUrl);
        return;
    end

    %% 4. Ensure Model & Algorithm Paths
    defaultModelDir = "C:\Users\saisi\OneDrive\Documents\RENEWABLE ENERGY TECH\matlabsimulation\MPPT_STEP1_STARTER\models";
    defaultAlgDir   = "C:\Users\saisi\OneDrive\Documents\RENEWABLE ENERGY TECH\matlabsimulation\MPPT_STEP1_STARTER\algorithms";
    if exist(defaultModelDir, "dir")
        addpath(defaultModelDir);
    end
    if exist(defaultAlgDir, "dir")
        addpath(defaultAlgDir);
    end

    %% 5. Load Model & Resolve Exact Scenario Input Block Paths
    load_system(modelName);

    gBlks = find_system(modelName, 'SearchDepth', 1, 'Name', 'G_irr');
    if isempty(gBlks)
        gBlks = find_system(modelName, 'Name', 'G_irr');
    end

    tBlks = find_system(modelName, 'SearchDepth', 1, 'Name', 'T_amb');
    if isempty(tBlks)
        tBlks = find_system(modelName, 'Name', 'T_amb');
    end

    if isempty(gBlks) || isempty(tBlks)
        error("Scenario input block not found. Could not locate G_irr or T_amb in %s.slx", modelName);
    end

    gIrrPath = gBlks{1};
    tAmbPath = tBlks{1};

    fprintf('\n  Irradiance block : %s (%s)\n', gIrrPath, get_param(gIrrPath, 'BlockType'));
    fprintf('  Temperature block: %s (%s)\n\n', tAmbPath, get_param(tAmbPath, 'BlockType'));

    %% 6. Register Cleanup Handler
    setappdata(0, 'MPPT_LIVE_STREAM_RUNNING', true);
    cleanupObj = onCleanup(@() cleanupSession());

    fprintf('============================================================\n');
    fprintf(' Architecture     : Direct Simulink Signal Path Streaming\n');
    fprintf(' Selected Scenario: %s (%s)\n', scenarioCode, getScenarioDescription(scenarioCode));
    fprintf(' Chunk Duration   : %.2f s simulation time\n', chunkDuration);
    fprintf(' Telemetry Rate   : %.1f Hz\n', rateHz);
    fprintf(' Model Target     : %s.slx (50 kHz Boost Converter)\n', modelName);
    fprintf(' State Continuity : Dataset Operating Point (xFinal handoff)\n');
    fprintf(' Mode             : MATLAB LIVE\n');
    fprintf(' Signal Source    : 100%% Direct Simulink Signal Logging (logsout)\n');
    fprintf(' Halt Control     : stop_live_matlab_stream or Ctrl+C\n');
    fprintf('============================================================\n\n');

    %% 7. Live Monitor Figure (Dark Theme)
    fig = [];
    hP = []; hV = []; hVmp = []; hI = []; hD = [];
    historyTime  = [];
    historyPower = [];
    historyVpv   = [];
    historyVmp   = [];
    historyIpv   = [];
    historyDuty  = [];

    if showPlot
        fig = findall(0, 'Type', 'figure', 'Name', 'MATLAB MPPT Live Stream Monitor');
        if isempty(fig)
            fig = figure( ...
                'Name', 'MATLAB MPPT Live Stream Monitor', ...
                'NumberTitle', 'off', ...
                'Color', [0.05 0.08 0.12]);
            set(fig, 'Position', [80, 80, 960, 680]);
        else
            figure(fig);
            clf(fig);
        end

        tiledlayout(2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

        nexttile;
        hP = plot(nan, nan, 'Color', [0.45 0.89 0.82], 'LineWidth', 1.8);
        grid on;
        title('PV Power P_{pv} (W) [MATLAB LIVE]', 'Color', [0.9 0.95 1.0], 'FontWeight', 'bold');
        xlabel('Simulation Time (s)', 'Color', [0.7 0.8 0.85]); ylabel('Power (W)', 'Color', [0.7 0.8 0.85]);
        set(gca, 'Color', [0.08 0.12 0.18], 'XColor', [0.6 0.7 0.75], 'YColor', [0.6 0.7 0.75]);

        nexttile;
        hV = plot(nan, nan, 'Color', [0.5 0.84 0.95], 'LineWidth', 1.8);
        hold on;
        hVmp = plot(nan, nan, '--', 'Color', [0.95 0.77 0.43], 'LineWidth', 1.4);
        grid on;
        title('PV Voltage V_{pv} vs V_{mp} (V)', 'Color', [0.9 0.95 1.0], 'FontWeight', 'bold');
        xlabel('Simulation Time (s)', 'Color', [0.7 0.8 0.85]); ylabel('Voltage (V)', 'Color', [0.7 0.8 0.85]);
        legend('V_{pv}','V_{mp}','Location','best', 'TextColor', [0.9 0.9 0.9], 'Color', [0.08 0.12 0.18]);
        set(gca, 'Color', [0.08 0.12 0.18], 'XColor', [0.6 0.7 0.75], 'YColor', [0.6 0.7 0.75]);

        nexttile;
        hI = plot(nan, nan, 'Color', [0.73 0.55 0.99], 'LineWidth', 1.8);
        grid on;
        title('PV Current I_{pv} (A)', 'Color', [0.9 0.95 1.0], 'FontWeight', 'bold');
        xlabel('Simulation Time (s)', 'Color', [0.7 0.8 0.85]); ylabel('Current (A)', 'Color', [0.7 0.8 0.85]);
        set(gca, 'Color', [0.08 0.12 0.18], 'XColor', [0.6 0.7 0.75], 'YColor', [0.6 0.7 0.75]);

        nexttile;
        hD = plot(nan, nan, 'Color', [0.94 0.47 0.57], 'LineWidth', 1.8);
        grid on;
        title('Duty Cycle D (%)', 'Color', [0.9 0.95 1.0], 'FontWeight', 'bold');
        xlabel('Simulation Time (s)', 'Color', [0.7 0.8 0.85]); ylabel('Duty (%)', 'Color', [0.7 0.8 0.85]);
        set(gca, 'Color', [0.08 0.12 0.18], 'XColor', [0.6 0.7 0.75], 'YColor', [0.6 0.7 0.75]);

        drawnow;
    end

    %% 8. HTTP Post Options
    txOptions = weboptions('MediaType', 'application/json', 'Timeout', 5);

    %% 9. CONTINUOUS CHUNKED SIMULATION LOOP
    currentTime      = 0.0;
    chunkIndex       = 1;
    totalPacketsSent = 0;
    streamStartTime  = tic;
    savedFinalState  = [];

    while getappdata(0, 'MPPT_LIVE_STREAM_RUNNING')
        t0 = currentTime;
        t1 = currentTime + chunkDuration;

        % Evaluate scenario inputs
        t_mid = (t0 + t1) / 2.0;
        [G_curr, T_curr] = evaluateScenario(scenarioCode, t_mid);

        fprintf('[CHUNK %2d] %5.2f -> %5.2f s | G=%4.0f W/m^2 | T=%4.1f°C\n', ...
            chunkIndex, t0, t1, G_curr, T_curr);

        %% Build SimulationInput for this chunk
        simIn = Simulink.SimulationInput(modelName);
        simIn = simIn.setModelParameter( ...
            'StartTime',                 num2str(t0, '%.4f'), ...
            'StopTime',                  num2str(t1, '%.4f'), ...
            'SolverType',                'Variable-step', ...
            'Solver',                    'ode23t', ...
            'MaxStep',                   '1e-3', ...
            'SaveFinalState',            'on', ...
            'FinalStateName',            'xFinal', ...
            'SaveFormat',                'Dataset', ...
            'SaveCompleteFinalSimState', 'off', ...
            'SimscapeLogType',           'none');

        % Drive scenario inputs into verified block paths if Constant blocks
        if strcmp(get_param(gIrrPath, 'BlockType'), 'Constant')
            simIn = simIn.setBlockParameter(gIrrPath, 'Value', num2str(G_curr, '%.2f'));
        end
        if strcmp(get_param(tAmbPath, 'BlockType'), 'Constant')
            simIn = simIn.setBlockParameter(tAmbPath, 'Value', num2str(T_curr, '%.2f'));
        end

        % State continuity handoff from previous chunk
        if ~isempty(savedFinalState)
            simIn = simIn.setInitialState(savedFinalState);
        end

        %% Run Simulink model for this chunk
        try
            outChunk = sim(simIn);
        catch ME
            fprintf('  [SIM ERROR] Chunk %d failed: %s\n', chunkIndex, ME.message);
            break;
        end

        %% Preserve final state dataset for next chunk
        if isprop(outChunk, 'xFinal') && ~isempty(outChunk.xFinal)
            savedFinalState = outChunk.xFinal;
        end

        %% Extract direct Simulink signals from logsout
        [tChunk, V_pv, I_pv, P_pv, V_mp, I_ph, D, V_out, T_c, I_out] = extractSimulinkChunkSignals(outChunk, t0, t1);

        nChunkPts = numel(tChunk);
        if nChunkPts < 1
            currentTime = t1;
            chunkIndex  = chunkIndex + 1;
            continue;
        end

        % Subsample chunk to target telemetry rate (~15 Hz)
        targetChunkSamples = max(2, round(chunkDuration * rateHz));
        if nChunkPts > targetChunkSamples
            sampleIndices = unique(round(linspace(1, nChunkPts, targetChunkSamples)));
        else
            sampleIndices = 1:nChunkPts;
        end

        %% Transmit chunk telemetry to backend
        for s = 1:numel(sampleIndices)
            if ~getappdata(0, 'MPPT_LIVE_STREAM_RUNNING')
                break;
            end

            k = sampleIndices(s);
            simTimePt = tChunk(k);

            payload = struct( ...
                'timestamp',    round(posixtime(datetime('now')) * 1000), ...
                'v_pv',         finiteOrZero(V_pv(k)), ...
                'i_pv',         finiteOrZero(I_pv(k)), ...
                'p_pv',         finiteOrZero(P_pv(k)), ...
                'v_mp',         finiteOrZero(V_mp(k)), ...
                'i_ph',         finiteOrZero(I_ph(k)), ...
                'duty',         clamp(finiteOrZero(D(k)), 0, 1), ...
                'v_out',        finiteOrZero(V_out(k)), ...
                't_c',          finiteOrZero(T_c(k)), ...
                'scenarioCode', char(scenarioCode), ...
                'source',       'MATLAB');

            % Compute efficiency ONLY when valid output current measurement exists from Simulink
            p_in = payload.p_pv;
            v_o  = payload.v_out;
            if ~isempty(I_out) && numel(I_out) >= k && isfinite(I_out(k)) && I_out(k) > 0 && v_o > 0.1 && p_in > 0.05
                p_out = v_o * I_out(k);
                payload.efficiency = round(clamp((p_out / p_in) * 100, 0, 100), 2);
            end

            % POST to Web Backend
            try
                resp = webwrite(baseUrl + "/api/telemetry/simulation", payload, txOptions);
                totalPacketsSent = totalPacketsSent + 1;
            catch ME_tx
                if mod(totalPacketsSent, 20) == 0
                    fprintf('  [TX WARN] Send retry: %s\n', ME_tx.message);
                end
            end

            % Console display
            elapsedSec = toc(streamStartTime);
            fprintf('  TX %5d | P=%7.3f W | V=%6.3f V | I=%6.3f A | D=%6.4f | t_sim=%6.2fs (elapsed: %5.1fs)\n', ...
                totalPacketsSent, payload.p_pv, payload.v_pv, payload.i_pv, payload.duty, simTimePt, elapsedSec);

            % Update live monitor figure
            if showPlot && ~isempty(fig) && isvalid(fig)
                historyTime(end+1)  = simTimePt;      %#ok<AGROW>
                historyPower(end+1) = payload.p_pv;   %#ok<AGROW>
                historyVpv(end+1)   = payload.v_pv;   %#ok<AGROW>
                historyVmp(end+1)   = payload.v_mp;   %#ok<AGROW>
                historyIpv(end+1)   = payload.i_pv;   %#ok<AGROW>
                historyDuty(end+1)  = payload.duty * 100; %#ok<AGROW>

                if numel(historyTime) > 200
                    historyTime(1)  = [];
                    historyPower(1) = [];
                    historyVpv(1)   = [];
                    historyVmp(1)   = [];
                    historyIpv(1)   = [];
                    historyDuty(1)  = [];
                end

                try
                    hP.XData = historyTime; hP.YData = historyPower;
                    hV.XData = historyTime; hV.YData = historyVpv;
                    hVmp.XData = historyTime; hVmp.YData = historyVmp;
                    hI.XData = historyTime; hI.YData = historyIpv;
                    hD.XData = historyTime; hD.YData = historyDuty;
                    drawnow limitrate;
                catch
                end
            end
        end

        % Advance simulation time
        currentTime = t1;
        chunkIndex  = chunkIndex + 1;
    end

    fprintf('\n============================================================\n');
    fprintf(' CHUNKED MATLAB LIVE SIMULATION HALTED\n');
    fprintf(' Total Chunks Executed     : %d\n', chunkIndex - 1);
    fprintf(' Total Packets Transmitted : %d\n', totalPacketsSent);
    fprintf(' Total Active Duration     : %.2f seconds\n', toc(streamStartTime));
    fprintf(' Final Simulation Time     : %.2f seconds\n', currentTime);
    fprintf(' Status                    : STANDBY\n');
    fprintf('============================================================\n\n');
end

%% =========================================================
% CLEANUP HANDLER
% =========================================================
function cleanupSession()
    setappdata(0, 'MPPT_LIVE_STREAM_RUNNING', false);
    fprintf('\n[MATLAB LIVE STREAM] Stopped cleanly. Ready for next run.\n');
end

%% =========================================================
% SCENARIO DEFINITIONS
% =========================================================
function [G, T] = evaluateScenario(code, t)
    switch upper(code)
        case "S2"
            % Scenario S2: Irradiance step (1000 -> 500 -> 800 -> 1000 W/m^2)
            if t < 2.0
                G = 1000.0;
            elseif t < 5.0
                G = 500.0;
            elseif t < 8.0
                G = 800.0;
            else
                G = 1000.0;
            end
            T = 25.0;

        case "S3"
            % Scenario S3: Temperature sweep (25 -> 40 -> 60 °C)
            G = 1000.0;
            if t < 3.0
                T = 25.0;
            elseif t < 6.0
                T = 40.0;
            else
                T = 60.0;
            end

        case "S5"
            % Scenario S5: Combined dynamic ramp
            if t < 2.0
                G = 1000.0; T = 25.0;
            elseif t < 5.0
                G = 600.0 + 200.0 * sin(2 * pi * 0.2 * (t - 2.0));
                T = 35.0;
            else
                G = 1000.0; T = 25.0;
            end

        otherwise % S1 standard STC
            G = 1000.0;
            T = 25.0;
    end
end

function desc = getScenarioDescription(code)
    switch upper(code)
        case "S2", desc = "Irradiance Step: 1000 -> 500 -> 800 -> 1000 W/m^2";
        case "S3", desc = "Temperature Step: 25 -> 40 -> 60 °C";
        case "S5", desc = "Dynamic Oscillating Irradiance & Temp Ramp";
        otherwise, desc = "Standard STC (1000 W/m^2, 25°C)";
    end
end

%% =========================================================
% EXTRACT DIRECT SIMULINK SIGNALS FROM LOGSOUT (No Fabricated Fallbacks)
% =========================================================
function [tChunk, V_pv, I_pv, P_pv, V_mp, I_ph, D, V_out, T_c, I_out] = extractSimulinkChunkSignals(outChunk, t0, t1)
    tChunk = []; V_pv = []; I_pv = []; P_pv = [];
    V_mp = []; I_ph = []; D = []; V_out = []; T_c = []; I_out = [];

    if isempty(outChunk)
        error("SimulationOutput outChunk is empty.");
    end

    % Master Time Vector
    if isprop(outChunk, "tout") && ~isempty(outChunk.tout)
        tChunk = double(outChunk.tout(:));
    elseif isfield(outChunk, "tout") && ~isempty(outChunk.tout)
        tChunk = double(outChunk.tout(:));
    else
        tChunk = linspace(t0, t1, 20)';
    end

    if ~isprop(outChunk, "logsout") || isempty(outChunk.logsout)
        error("outChunk.logsout is missing or empty. Verify signal logging on ekf.slx.");
    end

    logsout = outChunk.logsout;

    % Read signals strictly by exact logged names
    V_pv_raw  = readSignalByName(logsout, "V_pv");
    I_pv_raw  = readSignalByName(logsout, "I_pv");
    V_mp_raw  = readSignalByName(logsout, "V_mp_ref");
    I_ph_raw  = readSignalByName(logsout, "I_ph_est");
    T_c_raw   = readSignalByName(logsout, "T_c_est");
    D_raw     = readSignalByName(logsout, "duty");
    V_out_raw = readSignalByName(logsout, "V_out");

    V_pv  = alignSignalToTime(V_pv_raw,  tChunk);
    I_pv  = alignSignalToTime(I_pv_raw,  tChunk);
    V_mp  = alignSignalToTime(V_mp_raw,  tChunk);
    I_ph  = alignSignalToTime(I_ph_raw,  tChunk);
    D     = alignSignalToTime(D_raw,     tChunk);
    T_c   = alignSignalToTime(T_c_raw,   tChunk);
    V_out = alignSignalToTime(V_out_raw, tChunk);

    % Actual P_pv calculated from actual Simulink V_pv and I_pv
    P_pv = V_pv .* I_pv;
    I_out = []; % Optional output current
end

%% =========================================================
% READ SIGNAL BY EXACT LOGGED NAME
% =========================================================
function value = readSignalByName(logsout, signalName)
    element = [];
    allNames = {};
    try allNames = logsout.getElementNames; catch; end

    target = char(signalName);
    
    % Try exact match
    if any(strcmp(target, allNames))
        try element = logsout.get(target); catch; end
    end
    
    % Try common signal aliases if exact match not found
    if isempty(element)
        aliases = {target};
        if strcmpi(target, 'duty') || strcmpi(target, 'D')
            aliases = {'duty', 'D', 'duty_cycle', 'dutyCycle'};
        elseif strcmpi(target, 'V_mp') || strcmpi(target, 'V_mp_ref')
            aliases = {'V_mp_ref', 'V_mp', 'Vmp_ref', 'Vmp'};
        elseif strcmpi(target, 'I_ph') || strcmpi(target, 'I_ph_est')
            aliases = {'I_ph_est', 'I_ph', 'Iph_est', 'Iph'};
        elseif strcmpi(target, 'T_c') || strcmpi(target, 'T_c_est') || strcmpi(target, 'T_c_out')
            aliases = {'T_c', 'T_c_est', 'T_c_out', 'Tc'};
        elseif strcmpi(target, 'V_pv') || strcmpi(target, 'Vpv')
            aliases = {'V_pv', 'Vpv', 'V_pv_meas'};
        elseif strcmpi(target, 'I_pv') || strcmpi(target, 'Ipv')
            aliases = {'I_pv', 'Ipv', 'I_pv_meas'};
        end
        
        for k = 1:numel(aliases)
            if any(strcmp(aliases{k}, allNames))
                try
                    element = logsout.get(aliases{k});
                    if ~isempty(element), break; end
                catch
                end
            end
        end
    end

    if isempty(element)
        error("Required Simulink signal '%s' not found in logsout.", signalName);
    end

    if isa(element, "timeseries")
        value = element.Data;
    elseif isprop(element, "Values") || isfield(element, "Values")
        value = element.Values;
        if isa(value, "timeseries"), value = value.Data;
        elseif isstruct(value) && isfield(value, "Data"), value = value.Data;
        end
    elseif isprop(element, "Data") || isfield(element, "Data")
        value = element.Data;
    else
        value = element;
    end

    value = double(squeeze(value));
    value = value(:);
end

%% =========================================================
% ALIGN SIGNAL TO MASTER CHUNK TIMELINE
% =========================================================
function aligned = alignSignalToTime(raw, timeVec)
    timeVec = timeVec(:);
    if isempty(raw), aligned = nan(size(timeVec)); return; end
    raw = double(raw(:));
    if numel(raw) == 1, aligned = repmat(raw(1), size(timeVec)); return; end
    if numel(raw) == numel(timeVec), aligned = raw; return; end
    rawTime = linspace(timeVec(1), timeVec(end), numel(raw))';
    aligned = interp1(rawTime, raw, timeVec, "linear", "extrap");
    aligned = aligned(:);
end

%% =========================================================
% NUMERIC UTILITIES
% =========================================================
function val = finiteOrZero(v)
    if isempty(v) || ~isfinite(v), val = 0; else, val = double(v); end
end

function val = clamp(v, low, high)
    val = min(high, max(low, v));
end
