function response = send_simulation_to_web(out, baseUrl, ingestToken)
% SEND_SIMULATION_TO_WEB Send Simulink logs to the MPPT website.
%
% Usage:
%   out = sim("ekf");
%   send_simulation_to_web(out, "http://localhost:3000");
%
% For the hosted website, pass its HTTPS URL instead of localhost.
% The function supports the current blank-name logsout order shown in the
% supplied model and also works with named logs when names are available.

    if nargin < 1 || isempty(out)
        error("Pass the SimulationOutput returned by sim().");
    end
    if nargin < 2 || strlength(string(baseUrl)) == 0
        baseUrl = "http://localhost:3000";
    end
    if nargin < 3
        ingestToken = "";
    end

    logsout = out.logsout;
    if isempty(logsout)
        error("out.logsout is empty. Enable signal logging in Simulink first.");
    end

    % Current model fallback order from your EKF screenshot/package:
    % 2 = V_mp_ref, 3 = I_ph_est, 4 = T_c_est,
    % 5 = V_out, 6 = duty, 7 = I_pv, 8 = V_pv.
    V_pv = readSignal(logsout, ["V_pv_meas", "V_pv", "Vpv_test"], 8);
    I_pv = readSignal(logsout, ["I_pv_meas", "I_pv"], 7);
    V_mp = readSignal(logsout, ["V_mp_ref", "V_mp"], 2);
    I_ph = readSignal(logsout, ["I_ph_est", "I_ph"], 3);
    T_c = readSignal(logsout, ["T_c_est", "T_c"], 4);
    V_out = readSignal(logsout, ["V_out", "Vout"], 5, true);
    duty = readSignal(logsout, ["D", "duty", "Duty"], 6);

    n = min([numel(V_pv), numel(I_pv), numel(V_mp), numel(I_ph), numel(duty)]);
    if n < 1
        error("No complete telemetry samples were found in logsout.");
    end

    V_pv = V_pv(1:n);
    I_pv = I_pv(1:n);
    V_mp = V_mp(1:n);
    I_ph = I_ph(1:n);
    duty = duty(1:n);
    P_pv = V_pv .* I_pv;

    if numel(V_out) >= n
        V_out = V_out(1:n);
    else
        V_out = nan(n, 1);
    end
    if numel(T_c) >= n
        T_c = T_c(1:n);
    else
        T_c = nan(n, 1);
    end

    time = signalTime(logsout, ["V_pv_meas", "V_pv", "Vpv_test"], 8, n);
    if isempty(time)
        time = (0:n-1)' * 0.1;
    end
    time = time(:);
    if numel(time) < n
        time = (0:n-1)' * median(diff(time));
    else
        time = time(1:n);
    end
    timestampMs = round(posixtime(datetime("now")) * 1000 + (time - time(1)) * 1000);

    % Do not stream the switching-rate signal. Keep the website readable.
    if numel(time) > 1
        dt = median(diff(time));
        stride = max(1, round(0.1 / max(dt, eps)));
    else
        stride = 1;
    end
    selected = 1:stride:n;
    if selected(end) ~= n
        selected(end + 1) = n;
    end

    options = weboptions("MediaType", "application/json", "Timeout", 15);
    if strlength(string(ingestToken)) > 0
        options.HeaderFields = {"x-matlab-token", char(ingestToken)};
    end

    fprintf("MATLAB -> WEB: %d/%d samples to %s\n", numel(selected), n, baseUrl);
    for k = 1:numel(selected)
        i = selected(k);
        payload = struct( ...
            "timestamp", timestampMs(i), ...
            "v_pv", finiteOrZero(V_pv(i)), ...
            "i_pv", finiteOrZero(I_pv(i)), ...
            "p_pv", finiteOrZero(P_pv(i)), ...
            "v_mp", finiteOrZero(V_mp(i)), ...
            "i_ph", finiteOrZero(I_ph(i)), ...
            "duty", clamp(finiteOrZero(duty(i)), 0, 1), ...
            "v_out", finiteOrZero(V_out(i)), ...
            "t_c", finiteOrZero(T_c(i)), ...
            "source", "matlab");

        response = webwrite(string(baseUrl) + "/api/telemetry/simulation", payload, options);
        if mod(k, 10) == 1 || k == numel(selected)
            fprintf("TX %d/%d | P=%.3f W | V=%.3f V | I=%.3f A\n", k, numel(selected), payload.p_pv, payload.v_pv, payload.i_pv);
        end
        pause(0.1);
    end
    fprintf("MATLAB TELEMETRY SEND COMPLETE\n");
end

function value = readSignal(logsout, names, fallbackIndex, optional)
    if nargin < 4
        optional = false;
    end
    element = [];
    try
        for name = names
            element = logsout.get(char(name));
            if ~isempty(element)
                break;
            end
        end
    catch
        element = [];
    end
    if isempty(element)
        try
            element = logsout.get(fallbackIndex);
        catch
            if optional
                value = nan(0, 1);
                return;
            end
            error("Could not read logged signal %d.", fallbackIndex);
        end
    end
    value = element.Values;
    if isa(value, "timeseries")
        value = value.Data;
    elseif isstruct(value) && isfield(value, "Data")
        value = value.Data;
    end
    value = double(squeeze(value));
    value = value(:);
end

function time = signalTime(logsout, names, fallbackIndex, n)
    time = [];
    try
        element = [];
        for name = names
            element = logsout.get(char(name));
            if ~isempty(element)
                break;
            end
        end
        if isempty(element)
            element = logsout.get(fallbackIndex);
        end
        if isa(element.Values, "timeseries")
            time = element.Values.Time;
        end
    catch
        time = (0:n-1)' * 0.1;
    end
end

function value = finiteOrZero(value)
    if ~isfinite(value)
        value = 0;
    end
end

function value = clamp(value, low, high)
    value = min(high, max(low, value));
end
