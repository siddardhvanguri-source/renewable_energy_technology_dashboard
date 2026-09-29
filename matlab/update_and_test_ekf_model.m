% update_and_test_ekf_model.m
% Complete visual & runtime model fix for ekf.slx

clc;
clearvars -except varargin;

fprintf('============================================================\n');
fprintf(' UPDATING AND VERIFYING EKF.SLX SIMULINK MODEL (S2 SCENARIO)\n');
fprintf('============================================================\n\n');

% Paths
modelDir1 = 'C:\Users\saisi\OneDrive\Documents\RENEWABLE ENERGY TECH\matlabsimulation\MPPT_STEP1_STARTER\models';
modelDir2 = 'c:\Users\saisi\.antigravity-ide\renewable_energy_technology_dashboard\matlab';

addpath(modelDir1);
addpath(modelDir2);
addpath('C:\Users\saisi\OneDrive\Documents\RENEWABLE ENERGY TECH\matlabsimulation\MPPT_STEP1_STARTER\algorithms');

% Ensure model is open
modelPath = fullfile(modelDir1, 'ekf.slx');
try close_system('ekf', 0); catch; end
load_system(modelPath);

%% 1. CONSTRUCT TIME-VARYING G_IRR SCENARIO DRIVER FOR S2
fprintf('1. Creating native time-varying G_irr driver for S2 (0-10s)...\n');

% Check if G_irr block exists
gBlk = 'ekf/G_irr';
if ~isempty(find_system('ekf', 'SearchDepth', 1, 'Name', 'G_irr'))
    bType = get_param(gBlk, 'BlockType');
    if ~strcmp(bType, 'Lookup_n-D')
        delete_block(gBlk);
        fprintf('   Replaced old static G_irr block.\n');
    end
end

if isempty(find_system('ekf', 'SearchDepth', 1, 'Name', 'G_irr'))
    % Add Clock block if missing
    if isempty(find_system('ekf', 'SearchDepth', 1, 'Name', 'Clock'))
        add_block('simulink/Sources/Clock', 'ekf/Clock', 'Position', [30, 365, 60, 385]);
    end
    
    % Add 1-D Lookup Table for G_irr (S2 scenario: 1000 -> 500 -> 800 -> 1000)
    add_block('simulink/Lookup Tables/1-D Lookup Table', 'ekf/G_irr', ...
        'Position', [90, 360, 140, 390], ...
        'Table', '[1000 1000 500 500 800 800 1000 1000]', ...
        'BreakpointsForDimension1', '[0 2.0 2.0001 5.0 5.0001 8.0 8.0001 10.0]', ...
        'SampleTime', '1e-4');
        
    add_line('ekf', 'Clock/1', 'G_irr/1', 'autorouting', 'on');
    fprintf('   Added 1-D Lookup Table block for G_irr driven by Clock (SampleTime=1e-4).\n');
else
    set_param('ekf/G_irr', 'SampleTime', '1e-4');
end

% Ensure T_amb is Constant = 25 with SampleTime = 1e-4
if isempty(find_system('ekf', 'SearchDepth', 1, 'Name', 'T_amb'))
    add_block('simulink/Sources/Constant', 'ekf/T_amb', 'Value', '25', 'SampleTime', '1e-4', 'Position', [90, 420, 140, 440]);
else
    set_param('ekf/T_amb', 'Value', '25', 'SampleTime', '1e-4');
end

% Ensure Vpv_test is Constant = 19.25 with SampleTime = 1e-4
if ~isempty(find_system('ekf', 'SearchDepth', 1, 'Name', 'Vpv_test'))
    set_param('ekf/Vpv_test', 'SampleTime', '1e-4');
end

% Connect G_irr and T_amb to PV_Subsystem and EKF_Algorithm
connectPorts('ekf', 'G_irr/1', 'PV_Subsystem/1');
connectPorts('ekf', 'T_amb/1', 'PV_Subsystem/2');

connectPorts('ekf', 'G_irr/1', 'EKF_Algorithm/2');
connectPorts('ekf', 'T_amb/1', 'EKF_Algorithm/4');

fprintf('   [OK] G_irr time-varying driver & T_amb connected to Navin PV & EKF.\n');

%% 2. VERIFY SENSORS & BOOST CONVERTER WIRING
fprintf('\n2. Verifying Boost Converter & Sensor Wiring...\n');
% Voltage sensor (+) -> Diode Cathode, (-) -> Ground
ph_vs = get_param('ekf/Voltage Sensor', 'PortHandles');
l1 = get_param(ph_vs.LConn(1), 'Line'); if l1 ~= -1, delete_line(l1); end
l3 = get_param(ph_vs.RConn(2), 'Line'); if l3 ~= -1, delete_line(l3); end
add_line('ekf', 'Diode/RConn1', 'Voltage Sensor/LConn1', 'autorouting', 'on');
add_line('ekf', 'Electrical Reference2/LConn1', 'Voltage Sensor/RConn2', 'autorouting', 'on');

% Current sensor in series before load resistor
ph_is = get_param('ekf/Current Sensor', 'PortHandles');
l_is1 = get_param(ph_is.LConn(1), 'Line'); if l_is1 ~= -1, delete_line(l_is1); end
l_is3 = get_param(ph_is.RConn(2), 'Line'); if l_is3 ~= -1, delete_line(l_is3); end

ph_res = get_param('ekf/Resistor', 'PortHandles');
l_res1 = get_param(ph_res.LConn(1), 'Line'); if l_res1 ~= -1, delete_line(l_res1); end

add_line('ekf', 'Diode/RConn1', 'Current Sensor/LConn1', 'autorouting', 'on');
add_line('ekf', 'Current Sensor/RConn2', 'Resistor/LConn1', 'autorouting', 'on');
fprintf('   [OK] Boost output Voltage & Current sensors wired correctly.\n');

%% 3. CONSTRUCT P_pv MULTIPLIER BLOCK
fprintf('\n3. Ensuring P_pv is calculated and logged in Simulink...\n');
if isempty(find_system('ekf', 'SearchDepth', 1, 'Name', 'Product_Ppv'))
    add_block('simulink/Math Operations/Product', 'ekf/Product_Ppv', 'Position', [420, 310, 445, 335]);
    connectPorts('ekf', 'Vpv_test/1', 'Product_Ppv/1');
    connectPorts('ekf', 'PV_Subsystem/1', 'Product_Ppv/2');
end

%% 4. CONFIGURE SIGNAL LOGGING (logsout)
fprintf('\n4. Configuring Signal Logging on all 11 required signals...\n');

set_param('ekf', 'SignalLogging', 'on');
set_param('ekf', 'SignalLoggingName', 'logsout');
set_param('ekf', 'SaveFormat', 'Dataset');

% G_irr
ph = get_param('ekf/G_irr', 'PortHandles');
set_param(ph.Outport(1), 'DataLogging', 'on', 'DataLoggingNameMode', 'Custom', 'DataLoggingName', 'G_irr');

% T_amb
ph = get_param('ekf/T_amb', 'PortHandles');
set_param(ph.Outport(1), 'DataLogging', 'on', 'DataLoggingNameMode', 'Custom', 'DataLoggingName', 'T_amb');

% V_pv
ph = get_param('ekf/Vpv_test', 'PortHandles');
set_param(ph.Outport(1), 'DataLogging', 'on', 'DataLoggingNameMode', 'Custom', 'DataLoggingName', 'V_pv');

% I_pv
ph = get_param('ekf/PV_Subsystem', 'PortHandles');
set_param(ph.Outport(1), 'DataLogging', 'on', 'DataLoggingNameMode', 'Custom', 'DataLoggingName', 'I_pv');
set_param(ph.Outport(2), 'DataLogging', 'on', 'DataLoggingNameMode', 'Custom', 'DataLoggingName', 'T_c');

% P_pv
ph = get_param('ekf/Product_Ppv', 'PortHandles');
set_param(ph.Outport(1), 'DataLogging', 'on', 'DataLoggingNameMode', 'Custom', 'DataLoggingName', 'P_pv');

% EKF outputs
ph = get_param('ekf/EKF_Algorithm', 'PortHandles');
set_param(ph.Outport(1), 'DataLogging', 'on', 'DataLoggingNameMode', 'Custom', 'DataLoggingName', 'V_mp_ref');
set_param(ph.Outport(2), 'DataLogging', 'on', 'DataLoggingNameMode', 'Custom', 'DataLoggingName', 'I_ph_est');
set_param(ph.Outport(3), 'DataLogging', 'on', 'DataLoggingNameMode', 'Custom', 'DataLoggingName', 'T_c_est');

% D (duty)
ph = get_param('ekf/Saturation', 'PortHandles');
set_param(ph.Outport(1), 'DataLogging', 'on', 'DataLoggingNameMode', 'Custom', 'DataLoggingName', 'D');

% V_out
ph = get_param('ekf/PS-Simulink Converter', 'PortHandles');
set_param(ph.Outport(1), 'DataLogging', 'on', 'DataLoggingNameMode', 'Custom', 'DataLoggingName', 'V_out');

% I_out
ph = get_param('ekf/PS-Simulink Converter1', 'PortHandles');
set_param(ph.Outport(1), 'DataLogging', 'on', 'DataLoggingNameMode', 'Custom', 'DataLoggingName', 'I_out');

fprintf('   [OK] All 11 signals configured for dataset logging in logsout.\n');

%% 5. SAVE MODEL TO BOTH LOCATIONS TO PREVENT SHADOWING
fprintf('\n5. Saving updated model to both workspace locations...\n');
save_system('ekf', modelPath);

modelPath2 = fullfile(modelDir2, 'ekf.slx');
save_system('ekf', modelPath2);
fprintf('   [OK] Saved ekf.slx to:\n        1) %s\n        2) %s\n', modelPath, modelPath2);

%% 6. RUN SINGLE 10-SECOND NORMAL SIMULINK TEST
fprintf('\n============================================================\n');
fprintf(' 6. RUNNING SINGLE NORMAL 10-SECOND SIMULINK SIMULATION\n');
fprintf('============================================================\n');

out = sim('ekf', 'StopTime', '10.0');

logs = out.logsout;
fprintf('   Simulink completed. Extracted logsout dataset with %d elements:\n', logs.numElements);
for i=1:logs.numElements
    fprintf('     - Signal %d: %s\n', i, logs.get(i).Name);
end

%% 7. EXTRACT & EVALUATE SIGNAL TRANSITIONS
t_vec    = logs.get('G_irr').Values.Time;
g_vec    = logs.get('G_irr').Values.Data;
tamb_vec = logs.get('T_amb').Values.Data;
vpv_vec  = logs.get('V_pv').Values.Data;
ipv_vec  = logs.get('I_pv').Values.Data;
ppv_vec  = logs.get('P_pv').Values.Data;
vmp_vec  = logs.get('V_mp_ref').Values.Data;
iph_vec  = logs.get('I_ph_est').Values.Data;
d_vec    = logs.get('D').Values.Data;
vout_vec = logs.get('V_out').Values.Data;
iout_vec = logs.get('I_out').Values.Data;
tc_vec   = logs.get('T_c').Values.Data;

%% 8. PRINT VALIDATION TABLE
sampleTimes = [1.9, 2.1, 4.9, 5.1, 7.9, 8.1];

fprintf('\n=========================================================================================================\n');
fprintf(' ACTUAL LOGGED SIMULINK TELEMETRY AROUND S2 IRRADIANCE TRANSITIONS\n');
fprintf('=========================================================================================================\n');
fprintf('%-6s | %-6s | %-5s | %-6s | %-6s | %-6s | %-8s | %-8s | %-6s | %-7s | %-7s | %-5s\n', ...
    'time', 'G', 'T_amb', 'V_pv', 'I_pv', 'P_pv', 'V_mp_ref', 'I_ph_est', 'D', 'V_out', 'I_out', 'T_c');
fprintf('---------------------------------------------------------------------------------------------------------\n');

for st = sampleTimes
    [~, idx] = min(abs(t_vec - st));
    fprintf('%6.1f | %6.0f | %5.1f | %6.2f | %6.4f | %6.2f | %8.4f | %8.4f | %6.4f | %7.4f | %7.4f | %5.2f\n', ...
        t_vec(idx), g_vec(idx), tamb_vec(idx), vpv_vec(idx), ipv_vec(idx), ppv_vec(idx), ...
        vmp_vec(idx), iph_vec(idx), d_vec(idx), vout_vec(idx), iout_vec(idx), tc_vec(idx));
end
fprintf('=========================================================================================================\n\n');

%% Helper function
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
