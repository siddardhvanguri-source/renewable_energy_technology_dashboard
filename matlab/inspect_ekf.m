% Diagnostic script to inspect ekf.slx structure
addpath('C:\Users\saisi\OneDrive\Documents\RENEWABLE ENERGY TECH\matlabsimulation\MPPT_STEP1_STARTER\models');
addpath('C:\Users\saisi\OneDrive\Documents\RENEWABLE ENERGY TECH\matlabsimulation\MPPT_STEP1_STARTER\algorithms');

load_system('ekf');

fprintf('=== SOLVER CONFIGURATION ===\n');
fprintf('Solver: %s\n', get_param('ekf', 'Solver'));
fprintf('SolverType: %s\n', get_param('ekf', 'SolverType'));
fprintf('MaxStep: %s\n', get_param('ekf', 'MaxStep'));
fprintf('MinStep: %s\n', get_param('ekf', 'MinStep'));
fprintf('RelTol: %s\n', get_param('ekf', 'RelTol'));
fprintf('AbsTol: %s\n', get_param('ekf', 'AbsTol'));
fprintf('ZeroCross: %s\n', get_param('ekf', 'ZeroCross'));

ssc = find_system('ekf', 'Name', 'Solver Configuration');
if ~isempty(ssc)
    fprintf('\n=== SIMSCAPE SOLVER CONFIGURATION ===\n');
    params = {'ResidualTolerance', 'UseLocalSolver', 'DoFixedCost', 'LocalSolverChoice', 'LocalSolverSampleTime'};
    for i = 1:length(params)
        try
            val = get_param(ssc{1}, params{i});
            fprintf('  %s: %s\n', params{i}, string(val));
        catch
        end
    end
end

fprintf('\n=== KEY BLOCKS & PARAMETERS ===\n');
r_seq = find_system('ekf', 'Name', 'Repeating Sequence');
if ~isempty(r_seq)
    fprintf('Repeating Sequence:\n');
    fprintf('  rep_seq_t: %s\n', get_param(r_seq{1}, 'rep_seq_t'));
    fprintf('  rep_seq_y: %s\n', get_param(r_seq{1}, 'rep_seq_y'));
end

vpv_blk = find_system('ekf', 'Name', 'Vpv_test');
if ~isempty(vpv_blk)
    fprintf('Vpv_test Value: %s\n', get_param(vpv_blk{1}, 'Value'));
end

vmp_blk = find_system('ekf', 'RegExp', 'on', 'Name', 'Vmp_ref');
if ~isempty(vmp_blk)
    fprintf('%s Value: %s\n', vmp_blk{1}, get_param(vmp_blk{1}, 'Value'));
end

const_blks = find_system('ekf', 'BlockType', 'Constant');
for i = 1:length(const_blks)
    fprintf('Constant block: %s -> Value = %s\n', const_blks{i}, get_param(const_blks{i}, 'Value'));
end

gain_blks = find_system('ekf', 'BlockType', 'Gain');
for i = 1:length(gain_blks)
    fprintf('Gain block: %s -> Gain = %s\n', gain_blks{i}, get_param(gain_blks{i}, 'Gain'));
end

fprintf('\n=== SIGNAL LOGGING CONFIG ===\n');
fprintf('SignalLogging: %s\n', get_param('ekf', 'SignalLogging'));
fprintf('SignalLoggingName: %s\n', get_param('ekf', 'SignalLoggingName'));
fprintf('SaveOutput: %s\n', get_param('ekf', 'SaveOutput'));
fprintf('SaveTime: %s\n', get_param('ekf', 'SaveTime'));
fprintf('SaveState: %s\n', get_param('ekf', 'SaveState'));
fprintf('SaveFinalState: %s\n', get_param('ekf', 'SaveFinalState'));
fprintf('FinalStateName: %s\n', get_param('ekf', 'FinalStateName'));

fprintf('\n=== SUBSYSTEMS & MATLAB FUNCTION BLOCKS ===\n');
mf_blks = find_system('ekf', 'SFBlockType', 'MATLAB Function');
for i = 1:length(mf_blks)
    fprintf('MATLAB Function Block: %s\n', mf_blks{i});
end

subsys = find_system('ekf', 'BlockType', 'SubSystem');
for i = 1:length(subsys)
    fprintf('SubSystem: %s\n', subsys{i});
end

fprintf('\n=== LOGGED SIGNALS (RUN 1ms SIM) ===\n');
try
    simIn = Simulink.SimulationInput('ekf');
    simIn = simIn.setModelParameter('StopTime', '0.001', 'SaveOutput', 'on');
    out = sim(simIn);
    if isprop(out, 'logsout') && ~isempty(out.logsout)
        fprintf('logsout elements count: %d\n', out.logsout.numElements);
        for i = 1:out.logsout.numElements
            el = out.logsout.get(i);
            fprintf('  [%d] Name: "%s"\n', i, el.Name);
        end
    end
catch ME
    fprintf('Simulation error: %s\n', ME.message);
end

fprintf('\n=== BLOCK CONNECTIONS ===\n');
blks = find_system('ekf', 'Type', 'Block');
for i = 1:length(blks)
    try
        ph = get_param(blks{i}, 'PortHandles');
        outPorts = ph.Outport;
        for p = 1:length(outPorts)
            line = get_param(outPorts(p), 'Line');
            if line ~= -1
                dstPorts = get_param(line, 'DstPortHandle');
                dstNames = cell(1, length(dstPorts));
                for d = 1:length(dstPorts)
                    dstNames{d} = get_param(dstPorts(d), 'Parent');
                end
                sigName = get_param(line, 'Name');
                fprintf('  %s (Port %d) [%s] -> %s\n', blks{i}, p, sigName, strjoin(dstNames, '; '));
            end
        end
    catch
    end
end

