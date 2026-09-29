function [response, fig] = send_simulation_to_web(out, baseUrl, ingestToken, showPlot)
% SEND_SIMULATION_TO_WEB
% Send Simulink telemetry to the ESP32 MPPT web dashboard.
%
% Usage:
%   out = sim("ekf");
%   send_simulation_to_web(out);
%
% Optional:
%   send_simulation_to_web(out, "http://localhost:3000");
%   send_simulation_to_web(out, "http://localhost:3000", "", true);

    %% Defaults
    if nargin < 1 || isempty(out)
        error("Pass the SimulationOutput returned by sim().");
    end

    if nargin < 2 || strlength(string(baseUrl)) == 0
        baseUrl = "http://localhost:3000";
    end

    if nargin < 3
        ingestToken = "";
    end

    if nargin < 4
        showPlot = true;
    end

    %% Read logsout
    if ~isprop(out, "logsout") && ~isfield(out, "logsout")
        error("SimulationOutput does not contain logsout.");
    end

    logsout = out.logsout;

    if isempty(logsout)
        error("out.logsout is empty.");
    end

    fprintf("\n=============================================\n");
    fprintf(" MATLAB -> WEB TELEMETRY\n");
    fprintf("=============================================\n");

    numEl = 0;
    try
        numEl = logsout.numElements;
    catch
    end
    fprintf("logsout contains %d elements.\n", numEl);
    fprintf("Using the current 8-element mapping.\n");

    %% ---------------------------------------------------------
    % MASTER TIME VECTOR
    % ----------------------------------------------------------
    if isprop(out, "tout") && ~isempty(out.tout)
        masterTime = double(out.tout(:));
    elseif isfield(out, "tout") && ~isempty(out.tout)
        masterTime = double(out.tout(:));
    else
        % Fallback: try time vector from signal 8
        masterTime = signalTime(logsout, 8);
    end

    n = numel(masterTime);
    fprintf("Simulation samples : %d\n", n);

    if n > 1
        fprintf("Simulation time    : %.6f s\n", masterTime(end) - masterTime(1));
    else
        fprintf("Simulation time    : single sample\n");
    end

    %% ---------------------------------------------------------
    % READ AND ALIGN SIGNALS
    % ----------------------------------------------------------
    % Candidate names with fallback indices:
    % 2 = V_mp_ref, 3 = I_ph_est, 4 = T_c_est,
    % 5 = V_out, 6 = duty, 7 = I_pv, 8 = V_pv
    V_pv_raw  = readSignal(logsout, ["V_pv_meas","V_pv","Vpv_test"], 8);
    I_pv_raw  = readSignal(logsout, ["I_pv_meas","I_pv"], 7);
    V_mp_raw  = readSignal(logsout, ["V_mp_ref","V_mp"], 2);
    I_ph_raw  = readSignal(logsout, ["I_ph_est","I_ph"], 3);
    T_c_raw   = readSignal(logsout, ["T_c_est","T_c"], 4, true);
    V_out_raw = readSignal(logsout, ["V_out","Vout"], 5, true);
    D_raw     = readSignal(logsout, ["D","duty","Duty"], 6);

    %% Align everything onto masterTime
    V_pv  = alignSignal(V_pv_raw,  masterTime);
    I_pv  = alignSignal(I_pv_raw,  masterTime);
    V_mp  = alignSignal(V_mp_raw,  masterTime);
    I_ph  = alignSignal(I_ph_raw,  masterTime);
    D     = alignSignal(D_raw,     masterTime);
    T_c   = alignSignal(T_c_raw,   masterTime);
    V_out = alignSignal(V_out_raw, masterTime);

    %% Calculate actual PV power
    P_pv = V_pv .* I_pv;

    %% ---------------------------------------------------------
    % SUBSAMPLE TO ~10 Hz
    % ----------------------------------------------------------
    if n > 1
        duration = masterTime(end) - masterTime(1);
        if duration > 0
            targetSamples = max(2, round(duration * 10) + 1);
            selected = unique(round(linspace(1, n, targetSamples)));
        else
            selected = 1:n;
        end
    else
        selected = 1;
    end

    fprintf("\n=============================================\n");
    fprintf(" TELEMETRY TRANSMISSION\n");
    fprintf("=============================================\n");
    fprintf("Endpoint          : %s/api/telemetry/simulation\n", baseUrl);
    fprintf("Samples available : %d\n", n);
    fprintf("Samples sending   : %d\n", numel(selected));
    fprintf("Transmission rate : approximately 10 Hz\n\n");

    %% ---------------------------------------------------------
    % MATLAB MONITOR (Dark theme matching web dashboard)
    % ----------------------------------------------------------
    fig = [];
    if showPlot
        fig = figure( ...
            "Name", "MATLAB MPPT Telemetry Monitor", ...
            "NumberTitle", "off", ...
            "Color", [0.05 0.08 0.12]);
        set(fig, "Position", [100, 100, 950, 680]);

        tiledlayout(2, 2, "Padding", "compact", "TileSpacing", "compact");

        nexttile;
        hP = plot(masterTime(selected), P_pv(selected), "Color", [0.45 0.89 0.82], "LineWidth", 1.8);
        grid on;
        title("PV Power (W)", "Color", [0.9 0.95 1.0], "FontWeight", "bold");
        xlabel("Time (s)", "Color", [0.7 0.8 0.85]); ylabel("Power (W)", "Color", [0.7 0.8 0.85]);
        set(gca, "Color", [0.08 0.12 0.18], "XColor", [0.6 0.7 0.75], "YColor", [0.6 0.7 0.75]);

        nexttile;
        plot(masterTime(selected), V_pv(selected), "Color", [0.5 0.84 0.95], "LineWidth", 1.8);
        hold on;
        plot(masterTime(selected), V_mp(selected), "--", "Color", [0.95 0.77 0.43], "LineWidth", 1.4);
        grid on;
        title("PV Voltage vs V_{mp}", "Color", [0.9 0.95 1.0], "FontWeight", "bold");
        xlabel("Time (s)", "Color", [0.7 0.8 0.85]); ylabel("Voltage (V)", "Color", [0.7 0.8 0.85]);
        legend("V_{pv}","V_{mp}","Location","best", "TextColor", [0.9 0.9 0.9], "Color", [0.08 0.12 0.18]);
        set(gca, "Color", [0.08 0.12 0.18], "XColor", [0.6 0.7 0.75], "YColor", [0.6 0.7 0.75]);

        nexttile;
        plot(masterTime(selected), I_pv(selected), "Color", [0.73 0.55 0.99], "LineWidth", 1.8);
        grid on;
        title("PV Current (A)", "Color", [0.9 0.95 1.0], "FontWeight", "bold");
        xlabel("Time (s)", "Color", [0.7 0.8 0.85]); ylabel("Current (A)", "Color", [0.7 0.8 0.85]);
        set(gca, "Color", [0.08 0.12 0.18], "XColor", [0.6 0.7 0.75], "YColor", [0.6 0.7 0.75]);

        nexttile;
        plot(masterTime(selected), D(selected)*100, "Color", [0.94 0.47 0.57], "LineWidth", 1.8);
        grid on;
        title("Duty Cycle (%)", "Color", [0.9 0.95 1.0], "FontWeight", "bold");
        xlabel("Time (s)", "Color", [0.7 0.8 0.85]); ylabel("Duty (%)", "Color", [0.7 0.8 0.85]);
        set(gca, "Color", [0.08 0.12 0.18], "XColor", [0.6 0.7 0.75], "YColor", [0.6 0.7 0.75]);

        drawnow;
    end

    %% ---------------------------------------------------------
    % HTTP OPTIONS
    % ----------------------------------------------------------
    options = weboptions( ...
        "MediaType", "application/json", ...
        "Timeout", 15);

    if strlength(string(ingestToken)) > 0
        options.HeaderFields = {"x-matlab-token", char(ingestToken)};
    end

    response = [];

    %% ---------------------------------------------------------
    % TRANSMIT
    % ----------------------------------------------------------
    for k = 1:numel(selected)
        i = selected(k);

        payload = struct( ...
            "timestamp",   round(posixtime(datetime("now")) * 1000), ...
            "v_pv",        finiteOrZero(V_pv(i)), ...
            "i_pv",        finiteOrZero(I_pv(i)), ...
            "p_pv",        finiteOrZero(P_pv(i)), ...
            "v_mp",        finiteOrZero(V_mp(i)), ...
            "i_ph",        finiteOrZero(I_ph(i)), ...
            "duty",        clamp(finiteOrZero(D(i)), 0, 1), ...
            "v_out",       finiteOrZero(V_out(i)), ...
            "t_c",         finiteOrZero(T_c(i)), ...
            "scenarioCode", "S5", ...
            "source",      "MATLAB");

        % Only compute efficiency when valid input and output measurements exist
        p_in = payload.p_pv;
        v_o  = payload.v_out;
        if exist('I_out', 'var') && numel(I_out) >= i && isfinite(I_out(i)) && I_out(i) > 0 && p_in > 0.05
            p_out = v_o * I_out(i);
            payload.efficiency = round(clamp((p_out / p_in) * 100, 0, 100), 2);
        end

        try
            response = webwrite( ...
                string(baseUrl) + "/api/telemetry/simulation", ...
                payload, ...
                options);
        catch ME
            warning("Failed to send sample %d/%d: %s", k, numel(selected), ME.message);
        end

        %% Console progress
        if mod(k, 10) == 1 || k == numel(selected)
            fprintf( ...
                "TX %4d/%4d | P=%8.3f W | V=%8.3f V | I=%7.3f A | D=%7.4f\n", ...
                k, numel(selected), payload.p_pv, payload.v_pv, payload.i_pv, payload.duty);
        end

        %% Update MATLAB plot marker
        if showPlot && ~isempty(fig) && isvalid(fig)
            try
                hP.XData = masterTime(selected(1:k));
                hP.YData = P_pv(selected(1:k));
                drawnow limitrate;
            catch
            end
        end

        %% ~10 Hz stream pacing
        pause(0.08);
    end

    fprintf("\n=============================================\n");
    fprintf(" MATLAB TELEMETRY SEND COMPLETE\n");
    fprintf("=============================================\n");
    fprintf("Samples transmitted : %d\n", numel(selected));

    if isstruct(response)
        if isfield(response, "ok")
            fprintf("Server OK           : %d\n", response.ok);
        end
        if isfield(response, "clients")
            fprintf("WebSocket clients   : %d\n", response.clients);
        end
        if isfield(response, "persisted")
            fprintf("Persisted           : %d\n", response.persisted);
        end
    end
    fprintf("=============================================\n\n");
end

%% =========================================================
% READ SIGNAL (Warning-Free Named & Index Lookup)
% =========================================================
function value = readSignal(logsout, names, fallbackIndex, optional)
    if nargin < 4
        optional = false;
    end

    element = [];

    % Check available names safely to prevent DatasetNotFound warnings
    allNames = {};
    try
        allNames = logsout.getElementNames;
    catch
    end

    for k = 1:numel(names)
        target = char(names(k));
        if any(strcmp(target, allNames))
            try
                element = logsout.get(target);
                if ~isempty(element)
                    break;
                end
            catch
            end
        end
    end

    % Fallback to known index
    if isempty(element)
        try
            element = logsout.get(fallbackIndex);
        catch ME
            if optional
                value = nan;
                return;
            else
                error("Could not read logged signal %d: %s", fallbackIndex, ME.message);
            end
        end
    end

    %% Extract Values
    if isa(element, "timeseries")
        value = element.Data;
    elseif isprop(element, "Values") || isfield(element, "Values")
        value = element.Values;
        if isa(value, "timeseries")
            value = value.Data;
        elseif isstruct(value) && isfield(value, "Data")
            value = value.Data;
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
% ALIGN SIGNAL TO MASTER TIME (Handles 1-sample constants)
% =========================================================
function aligned = alignSignal(raw, masterTime)
    masterTime = masterTime(:);

    if isempty(raw)
        aligned = nan(size(masterTime));
        return;
    end

    raw = double(raw(:));

    %% One sample = constant reference signal (expand to full length)
    if numel(raw) == 1
        aligned = repmat(raw(1), size(masterTime));
        return;
    end

    %% Same number of samples
    if numel(raw) == numel(masterTime)
        aligned = raw;
        return;
    end

    %% Different length: interpolate over normalized simulation time
    rawTime = linspace(masterTime(1), masterTime(end), numel(raw))';
    aligned = interp1(rawTime, raw, masterTime, "linear", "extrap");
    aligned = aligned(:);
end

%% =========================================================
% EXTRACT TIME VECTOR FALLBACK
% =========================================================
function t = signalTime(logsout, fallbackIndex)
    t = [];
    try
        elem = logsout.get(fallbackIndex);
        if isa(elem.Values, "timeseries")
            t = double(elem.Values.Time);
        end
    catch
    end
    if isempty(t)
        t = (0:38800)' * (10 / 38800);
    end
end

%% =========================================================
% FINITE VALUE HELPER
% =========================================================
function value = finiteOrZero(v)
    if isempty(v) || ~isfinite(v)
        value = 0;
    else
        value = double(v);
    end
end

%% =========================================================
% CLAMP HELPER
% =========================================================
function value = clamp(v, low, high)
    value = min(high, max(low, v));
end
