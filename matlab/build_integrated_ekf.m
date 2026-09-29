% build_integrated_ekf.m
% Integrates Navin's PV Subsystem and EKF_Algorithm into ekf.slx

try close_system('ekf', 0); catch; end
try close_system('EKF_Testbench', 0); catch; end

addpath('C:\Users\saisi\OneDrive\Documents\RENEWABLE ENERGY TECH\matlabsimulation\MPPT_STEP1_STARTER\models');
addpath('C:\Users\saisi\OneDrive\Documents\RENEWABLE ENERGY TECH\matlabsimulation\MPPT_STEP1_STARTER\algorithms');

load_system('ekf');
load_system('EKF_Testbench');

fprintf('====================================================\n');
fprintf(' INTEGRATING NAVIN PV MODEL + EKF ALGORITHM INTO EKF.SLX\n');
fprintf('====================================================\n');

% 1. Copy Navin PV Subsystem from EKF_Testbench to ekf
if isempty(find_system('ekf', 'SearchDepth', 1, 'Name', 'PV_Subsystem'))
    add_block('EKF_Testbench/Subsystem', 'ekf/PV_Subsystem', 'Position', [150, 400, 270, 500]);
    fprintf('  [+] Added PV_Subsystem to ekf.slx\n');
end

% 2. Copy EKF_Algorithm block from EKF_Testbench to ekf
if isempty(find_system('ekf', 'SearchDepth', 1, 'Name', 'EKF_Algorithm'))
    add_block('EKF_Testbench/EKF_Algorithm', 'ekf/EKF_Algorithm', 'Position', [340, 400, 460, 500]);
    fprintf('  [+] Added EKF_Algorithm to ekf.slx\n');
end

% 3. Copy/Create G_irr, T_amb, Constant_K Kelvin offset blocks if missing
if isempty(find_system('ekf', 'SearchDepth', 1, 'Name', 'G_irr'))
    add_block('simulink/Sources/Constant', 'ekf/G_irr', 'Value', '1000', 'Position', [30, 390, 80, 410]);
end
if isempty(find_system('ekf', 'SearchDepth', 1, 'Name', 'T_amb'))
    add_block('simulink/Sources/Constant', 'ekf/T_amb', 'Value', '25', 'Position', [30, 440, 80, 460]);
end
if isempty(find_system('ekf', 'SearchDepth', 1, 'Name', 'Constant_K'))
    add_block('simulink/Sources/Constant', 'ekf/Constant_K', 'Value', '273.15', 'Position', [30, 490, 80, 510]);
end
if isempty(find_system('ekf', 'SearchDepth', 1, 'Name', 'Sum_Tc'))
    add_block('simulink/Math Operations/Sum', 'ekf/Sum_Tc', 'Inputs', '+-', 'Position', [290, 470, 310, 490]);
end

% 4. Safely wire blocks
connectPorts('ekf', 'G_irr/1', 'PV_Subsystem/1');
connectPorts('ekf', 'T_amb/1', 'PV_Subsystem/2');
connectPorts('ekf', 'Vpv_test/1', 'PV_Subsystem/3');

connectPorts('ekf', 'PV_Subsystem/2', 'Sum_Tc/1');
connectPorts('ekf', 'Constant_K/1', 'Sum_Tc/2');

connectPorts('ekf', 'Vpv_test/1', 'EKF_Algorithm/1');
connectPorts('ekf', 'PV_Subsystem/1', 'EKF_Algorithm/2');
connectPorts('ekf', 'Sum_Tc/1', 'EKF_Algorithm/3');
connectPorts('ekf', 'T_amb/1', 'EKF_Algorithm/4');

% Connect EKF_Algorithm Outport 1 (V_mp_ref) -> Sum port 2
connectPorts('ekf', 'EKF_Algorithm/1', 'Sum/2');

% Enable Signal Logging on critical signals
ph_vpv = get_param('ekf/Vpv_test', 'PortHandles');
set_param(ph_vpv.Outport(1), 'DataLogging', 'on', 'DataLoggingNameMode', 'Custom', 'DataLoggingName', 'V_pv');

ph_pv = get_param('ekf/PV_Subsystem', 'PortHandles');
set_param(ph_pv.Outport(1), 'DataLogging', 'on', 'DataLoggingNameMode', 'Custom', 'DataLoggingName', 'I_pv');

ph_ekf = get_param('ekf/EKF_Algorithm', 'PortHandles');
set_param(ph_ekf.Outport(1), 'DataLogging', 'on', 'DataLoggingNameMode', 'Custom', 'DataLoggingName', 'V_mp_ref');
set_param(ph_ekf.Outport(2), 'DataLogging', 'on', 'DataLoggingNameMode', 'Custom', 'DataLoggingName', 'I_ph_est');
set_param(ph_ekf.Outport(3), 'DataLogging', 'on', 'DataLoggingNameMode', 'Custom', 'DataLoggingName', 'T_c_est');

ph_sat = get_param('ekf/Saturation', 'PortHandles');
set_param(ph_sat.Outport(1), 'DataLogging', 'on', 'DataLoggingNameMode', 'Custom', 'DataLoggingName', 'duty');

ph_ps = get_param('ekf/PS-Simulink Converter', 'PortHandles');
set_param(ph_ps.Outport(1), 'DataLogging', 'on', 'DataLoggingNameMode', 'Custom', 'DataLoggingName', 'V_out');

% Enable logsout saving in model
set_param('ekf', 'SignalLogging', 'on');
set_param('ekf', 'SignalLoggingName', 'logsout');

save_system('ekf');
fprintf('  [OK] Integrated model ekf.slx built and saved successfully.\n');

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
