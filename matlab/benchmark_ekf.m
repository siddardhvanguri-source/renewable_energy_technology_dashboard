% Benchmark script for ekf.slx
addpath('C:\Users\saisi\OneDrive\Documents\RENEWABLE ENERGY TECH\matlabsimulation\MPPT_STEP1_STARTER\models');
addpath('C:\Users\saisi\OneDrive\Documents\RENEWABLE ENERGY TECH\matlabsimulation\MPPT_STEP1_STARTER\algorithms');

load_system('ekf');

chunkDuration = 0.20;

fprintf('=====================================================\n');
fprintf(' BENCHMARK 1: Standard chunked sim (FastRestart OFF)\n');
fprintf('=====================================================\n');
set_param('ekf', 'FastRestart', 'off');

savedState = [];
for k = 1:3
    t0 = (k-1) * chunkDuration;
    t1 = k * chunkDuration;
    
    t_start = tic;
    simIn = Simulink.SimulationInput('ekf');
    simIn = simIn.setModelParameter(...
        'StartTime', num2str(t0, '%.4f'), ...
        'StopTime', num2str(t1, '%.4f'), ...
        'SaveFinalState', 'on', ...
        'FinalStateName', 'xFinal', ...
        'SaveFormat', 'Dataset', ...
        'SaveCompleteFinalSimState', 'off');
    if ~isempty(savedState)
        simIn = simIn.setInitialState(savedState);
    end
    out = sim(simIn);
    wallTime = toc(t_start);
    savedState = out.xFinal;
    fprintf('  Chunk %d (%.2f -> %.2f s): Wall time = %.4f s (Sim samples = %d)\n', ...
        k, t0, t1, wallTime, length(out.tout));
end

fprintf('\n=====================================================\n');
fprintf(' BENCHMARK 2: Chunked sim with FastRestart ON\n');
fprintf('=====================================================\n');
try
    set_param('ekf', 'FastRestart', 'on');
    savedState = [];
    for k = 1:3
        t0 = (k-1) * chunkDuration;
        t1 = k * chunkDuration;
        
        t_start = tic;
        simIn = Simulink.SimulationInput('ekf');
        simIn = simIn.setModelParameter(...
            'StartTime', num2str(t0, '%.4f'), ...
            'StopTime', num2str(t1, '%.4f'), ...
            'SaveFinalState', 'on', ...
            'FinalStateName', 'xFinal', ...
            'SaveFormat', 'Dataset', ...
            'SaveCompleteFinalSimState', 'off');
        if ~isempty(savedState)
            simIn = simIn.setInitialState(savedState);
        end
        out = sim(simIn);
        wallTime = toc(t_start);
        savedState = out.xFinal;
        fprintf('  FastRestart Chunk %d (%.2f -> %.2f s): Wall time = %.4f s\n', ...
            k, t0, t1, wallTime);
    end
    set_param('ekf', 'FastRestart', 'off');
catch ME
    fprintf('  FastRestart benchmark failed: %s\n', ME.message);
    set_param('ekf', 'FastRestart', 'off');
end

fprintf('\n=== Zero-Crossing and Step Count Analysis ===\n');
if exist('out', 'var') && isprop(out, 'SimulationMetadata')
    meta = out.SimulationMetadata;
    disp(meta.ExecutionInfo);
end
