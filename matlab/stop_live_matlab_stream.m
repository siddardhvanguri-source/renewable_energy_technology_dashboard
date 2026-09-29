function stop_live_matlab_stream()
% STOP_LIVE_MATLAB_STREAM
% Cleanly stop the active MATLAB / Simulink live telemetry stream.
%
% Usage:
%   stop_live_matlab_stream
%
% This clears the global streaming flag and signals any running
% start_live_matlab_stream process to terminate immediately and release
% model / connection resources cleanly.

    fprintf('\n============================================================\n');
    fprintf(' STOPPING LIVE MATLAB TELEMETRY STREAM\n');
    fprintf('============================================================\n');

    wasRunning = getappdata(0, 'MPPT_LIVE_STREAM_RUNNING');
    setappdata(0, 'MPPT_LIVE_STREAM_RUNNING', false);

    if ~isempty(wasRunning) && wasRunning
        fprintf('  [OK] Streaming flag cleared.\n');
        fprintf('  [OK] Active live simulation stream will exit cleanly.\n');
    else
        fprintf('  [INFO] No live stream was marked active in this MATLAB session.\n');
    end

    % Close active monitor figure if open
    existingFig = findall(0, 'Type', 'figure', 'Name', 'MATLAB MPPT Live Stream Monitor');
    if ~isempty(existingFig)
        try
            delete(existingFig);
            fprintf('  [OK] Monitor figure closed.\n');
        catch
        end
    end

    fprintf('============================================================\n\n');
end
