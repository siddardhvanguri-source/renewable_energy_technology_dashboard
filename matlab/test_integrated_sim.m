% test_integrated_sim.m
addpath('C:\Users\saisi\OneDrive\Documents\RENEWABLE ENERGY TECH\matlabsimulation\MPPT_STEP1_STARTER\models');
addpath('C:\Users\saisi\OneDrive\Documents\RENEWABLE ENERGY TECH\matlabsimulation\MPPT_STEP1_STARTER\algorithms');

try close_system('ekf', 0); catch; end

out = sim('ekf', 'StopTime', '0.01');

fprintf('====================================================\n');
fprintf(' INTEGRATED SIMULINK MODEL SIGNAL OUTPUT TEST\n');
fprintf('====================================================\n');

if isprop(out, 'logsout') && ~isempty(out.logsout)
    fprintf('logsout elements count: %d\n', out.logsout.numElements);
    for i = 1:out.logsout.numElements
        el = out.logsout.get(i);
        fprintf('  [%d] Name: "%s"\n', i, el.Name);
    end
end
