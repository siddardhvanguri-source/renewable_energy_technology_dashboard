% fix_boost_sensor_wiring.m
addpath('C:\Users\saisi\OneDrive\Documents\RENEWABLE ENERGY TECH\matlabsimulation\MPPT_STEP1_STARTER\models');
addpath('C:\Users\saisi\OneDrive\Documents\RENEWABLE ENERGY TECH\matlabsimulation\MPPT_STEP1_STARTER\algorithms');

try close_system('ekf', 0); catch; end
load_system('ekf');

fprintf('====================================================\n');
fprintf(' FIXING BOOST CONVERTER VOLTAGE & CURRENT SENSOR WIRING\n');
fprintf('====================================================\n');

% 1. Inspect Voltage Sensor ports & existing lines
ph_vs = get_param('ekf/Voltage Sensor', 'PortHandles');
ph_diode = get_param('ekf/Diode', 'PortHandles');
ph_gnd = get_param('ekf/Electrical Reference2', 'PortHandles');
ph_res = get_param('ekf/Resistor', 'PortHandles');

% Delete existing lines on Voltage Sensor ports if present
l1 = get_param(ph_vs.LConn(1), 'Line');
if l1 ~= -1, delete_line(l1); end
l3 = get_param(ph_vs.RConn(2), 'Line');
if l3 ~= -1, delete_line(l3); end

% Connect Voltage Sensor + (LConn1) to Diode cathode (RConn1)
add_line('ekf', 'Diode/RConn1', 'Voltage Sensor/LConn1', 'autorouting', 'on');

% Connect Voltage Sensor - (RConn2) to Electrical Reference2 (LConn1)
add_line('ekf', 'Electrical Reference2/LConn1', 'Voltage Sensor/RConn2', 'autorouting', 'on');

% 2. Inspect Current Sensor ports & existing lines
ph_is = get_param('ekf/Current Sensor', 'PortHandles');
l_is1 = get_param(ph_is.LConn(1), 'Line');
if l_is1 ~= -1, delete_line(l_is1); end
l_is3 = get_param(ph_is.RConn(2), 'Line');
if l_is3 ~= -1, delete_line(l_is3); end

% Connect Current Sensor in series before Resistor:
% Diode Cathode -> Current Sensor + (LConn1)
% Current Sensor - (RConn2) -> Resistor top (LConn1)
l_res1 = get_param(ph_res.LConn(1), 'Line');
if l_res1 ~= -1, delete_line(l_res1); end

add_line('ekf', 'Diode/RConn1', 'Current Sensor/LConn1', 'autorouting', 'on');
add_line('ekf', 'Current Sensor/RConn2', 'Resistor/LConn1', 'autorouting', 'on');

% Enable DataLogging for I_out
ph_ps_i = get_param('ekf/PS-Simulink Converter1', 'PortHandles');
set_param(ph_ps_i.Outport(1), 'DataLogging', 'on', 'DataLoggingNameMode', 'Custom', 'DataLoggingName', 'I_out');

save_system('ekf');
fprintf('  [OK] Voltage & Current Sensors re-wired directly to boost converter output node.\n');

% Test 0.20 s simulation
out = sim('ekf', 'StopTime', '0.20');
v_out = out.logsout.get('V_out').Values.Data;
i_out = out.logsout.get('I_out').Values.Data;
fprintf('  [TEST] Measured V_out from actual boost output: min=%.4f V, max=%.4f V, end=%.4f V\n', ...
    min(v_out), max(v_out), v_out(end));
fprintf('  [TEST] Measured I_out from actual boost output: min=%.4f A, max=%.4f A, end=%.4f A\n', ...
    min(i_out), max(i_out), i_out(end));

