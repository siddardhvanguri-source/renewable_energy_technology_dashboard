% fix_ekf_block_wiring_and_rate.m
% Fixes EKF block port wiring and signal logging in ekf.slx

clc;
clearvars -except varargin;

fprintf('============================================================\n');
fprintf(' FIXING EKF BLOCK WIRING & SIGNAL LOGGING\n');
fprintf('============================================================\n\n');

modelDir1 = 'C:\Users\saisi\OneDrive\Documents\RENEWABLE ENERGY TECH\matlabsimulation\MPPT_STEP1_STARTER\models';
modelDir2 = 'c:\Users\saisi\.antigravity-ide\renewable_energy_technology_dashboard\matlab';

addpath(modelDir1);
addpath(modelDir2);
addpath('C:\Users\saisi\OneDrive\Documents\RENEWABLE ENERGY TECH\matlabsimulation\MPPT_STEP1_STARTER\algorithms');

modelPath = fullfile(modelDir1, 'ekf.slx');
try close_system('ekf', 0); catch; end
load_system(modelPath);

ekfBlk = 'ekf/EKF_Algorithm';

%% 1. REWIRE EKF_ALGORITHM INPORTS CORRECTLY
fprintf('1. Rewiring EKF_Algorithm Inports...\n');
% Input 1: V_pv_meas <- Vpv_test/1
connectPorts('ekf', 'Vpv_test/1', 'EKF_Algorithm/1');
set_param('ekf/EKF_Algorithm/V_pv_meas', 'SampleTime', '-1');

% Input 2: I_pv_meas <- PV_Subsystem/1 (I_pv)  <-- FIXES THE 1000 W/m^2 MISWIRING!
connectPorts('ekf', 'PV_Subsystem/1', 'EKF_Algorithm/2');
set_param('ekf/EKF_Algorithm/I_pv_meas', 'SampleTime', '-1');

% Input 3: T_c_meas <- Sum_Tc/1 (Cell Temp in °C)
connectPorts('ekf', 'Sum_Tc/1', 'EKF_Algorithm/3');
set_param('ekf/EKF_Algorithm/T_c_meas', 'SampleTime', '-1');

% Input 4: T_amb <- T_amb/1 (Ambient Temp in °C)
connectPorts('ekf', 'T_amb/1', 'EKF_Algorithm/4');
set_param('ekf/EKF_Algorithm/T_amb', 'SampleTime', '-1');

fprintf('   [OK] Inport 1: V_pv_meas (from Vpv_test)\n');
fprintf('   [OK] Inport 2: I_pv_meas (from PV_Subsystem I_pv)\n');
fprintf('   [OK] Inport 3: T_c_meas  (from Sum_Tc)\n');
fprintf('   [OK] Inport 4: T_amb     (from T_amb)\n');

%% 2. REWIRE EKF_ALGORITHM OUTPORTS & TERMINATORS
fprintf('\n2. Wiring EKF_Algorithm Outports...\n');
% Outport 1: V_mp_ref -> Sum/2
connectPorts('ekf', 'EKF_Algorithm/1', 'Sum/2');

% Add Terminators for Outports 2 & 3 if missing
if isempty(find_system('ekf', 'SearchDepth', 1, 'Name', 'Terminator_Iph'))
    add_block('simulink/Sinks/Terminator', 'ekf/Terminator_Iph', 'Position', [480, 435, 500, 455]);
end
if isempty(find_system('ekf', 'SearchDepth', 1, 'Name', 'Terminator_Tc'))
    add_block('simulink/Sinks/Terminator', 'ekf/Terminator_Tc', 'Position', [480, 465, 500, 485]);
end

connectPorts('ekf', 'EKF_Algorithm/2', 'Terminator_Iph/1');
connectPorts('ekf', 'EKF_Algorithm/3', 'Terminator_Tc/1');
fprintf('   [OK] Outports 1 (V_mp_ref), 2 (I_ph_est), 3 (T_c_est) connected.\n');

%% 3. CONFIGURE SIGNAL LOGGING FOR EKF OUTPORTS
fprintf('\n3. Enabling DataLogging on EKF Outports...\n');
ph_ekf = get_param(ekfBlk, 'PortHandles');
set_param(ph_ekf.Outport(1), 'DataLogging', 'on', 'DataLoggingNameMode', 'Custom', 'DataLoggingName', 'V_mp_ref');
set_param(ph_ekf.Outport(2), 'DataLogging', 'on', 'DataLoggingNameMode', 'Custom', 'DataLoggingName', 'I_ph_est');
set_param(ph_ekf.Outport(3), 'DataLogging', 'on', 'DataLoggingNameMode', 'Custom', 'DataLoggingName', 'T_c_est');

% Saturation Outport -> duty (and D)
ph_sat = get_param('ekf/Saturation', 'PortHandles');
set_param(ph_sat.Outport(1), 'DataLogging', 'on', 'DataLoggingNameMode', 'Custom', 'DataLoggingName', 'duty');

fprintf('   [OK] Dataset Logging enabled for V_mp_ref, I_ph_est, T_c_est, duty.\n');

%% 4. SAVE MODEL TO BOTH DISK LOCATIONS
fprintf('\n4. Saving model to both locations...\n');
save_system('ekf', modelPath);

modelPath2 = fullfile(modelDir2, 'ekf.slx');
save_system('ekf', modelPath2);
fprintf('   [OK] Saved ekf.slx to:\n        1) %s\n        2) %s\n', modelPath, modelPath2);

%% 5. RUN DIAGNOSTIC TEST (StopTime = 0.20s)
fprintf('\n============================================================\n');
fprintf(' 5. RUNNING 0.20s SIMULINK SIMULATION DIAGNOSTIC\n');
fprintf('============================================================\n');

out = sim('ekf', 'StopTime', '0.20');

fprintf('\n=== ACTUAL FINAL DIAGNOSTIC ===\n');

names = {'G_irr','T_amb','V_pv','I_pv','V_mp_ref','I_ph_est','T_c_est','duty','V_out','I_out'};

for k = 1:numel(names)
    try
        s = out.logsout.get(names{k});
        v = double(s.Values.Data);
        fprintf('%-10s = %.6g\n', names{k}, v(end));
    catch ME
        fprintf('%-10s = [NOT FOUND: %s]\n', names{k}, ME.message);
    end
end

V = double(out.logsout.get('V_pv').Values.Data(end));
I = double(out.logsout.get('I_pv').Values.Data(end));
fprintf('P_in      = %.6f W\n', V*I);

try
    Vo = double(out.logsout.get('V_out').Values.Data(end));
    Io = double(out.logsout.get('I_out').Values.Data(end));
    fprintf('P_out     = %.6f W\n', Vo*Io);
catch
    fprintf('P_out     = unavailable\n');
end
fprintf('=================================\n');

%% 6. STANDALONE EKF ALGORITHM COMPARISON
fprintf('\n=== STANDALONE EKF_Algorithm COMPARISON ===\n');
V_pv_meas = V;
I_pv_meas = I;
try T_c_meas = double(out.logsout.get('T_c').Values.Data(end)); catch, T_c_meas = 25.0; end
try T_amb_val = double(out.logsout.get('T_amb').Values.Data(end)); catch, T_amb_val = 25.0; end

clear EKF_Algorithm;
[Vmp_ref_test, Iph_test, Tc_est_test] = EKF_Algorithm(V_pv_meas, I_pv_meas, T_c_meas, T_amb_val);

fprintf('Standalone:\n');
fprintf('  Vmp_ref_test = %.6f V\n', Vmp_ref_test);
fprintf('  Iph_test     = %.6f A\n', Iph_test);
fprintf('  Tc_est_test  = %.6f °C\n', Tc_est_test);

try
    simVmp = double(out.logsout.get('V_mp_ref').Values.Data(end));
    simIph = double(out.logsout.get('I_ph_est').Values.Data(end));
    simTc  = double(out.logsout.get('T_c_est').Values.Data(end));
    fprintf('Simulink:\n');
    fprintf('  V_mp_ref     = %.6f V\n', simVmp);
    fprintf('  I_ph_est     = %.6f A\n', simIph);
    fprintf('  T_c_est      = %.6f °C\n', simTc);
    fprintf('  Diff (Vmp)   = %.6g V\n', abs(simVmp - Vmp_ref_test));
    fprintf('  Diff (Iph)   = %.6g A\n', abs(simIph - Iph_test));
catch ME
    fprintf('Simulink comparison failed: %s\n', ME.message);
end
fprintf('===========================================\n');

function connectPorts(sys, srcStr, dstStr)
    tokensDst = strsplit(dstStr, '/');
    dstBlockPath = [sys '/' strjoin(tokensDst(1:end-1), '/')];
    dstPortNum = str2double(tokensDst{end});
    
    phDst = get_param(dstBlockPath, 'PortHandles');
    if dstPortNum <= length(phDst.Inport)
        existingLine = get_param(phDst.Inport(dstPortNum), 'Line');
        if existingLine ~= -1
            delete_line(existingLine);
        end
    end
    
    add_line(sys, srcStr, dstStr, 'autorouting', 'on');
end
