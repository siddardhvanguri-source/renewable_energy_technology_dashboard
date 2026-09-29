% run_final_ekf_diagnostic.m
% Final diagnostic script for EKF signal path verification

% 1. Ensure path
addpath('c:\Users\saisi\.antigravity-ide\renewable_energy_technology_dashboard\matlab');
cd('c:\Users\saisi\.antigravity-ide\renewable_energy_technology_dashboard\matlab');

% Load system
modelName = 'ekf';
load_system(modelName);

fprintf('\n============================================================\n');
fprintf(' 1. EKF BLOCK SCRIPT INSPECTION\n');
fprintf('============================================================\n');
rt = sfroot;
chart = rt.find('-isa', 'Stateflow.EMChart', 'Path', [modelName '/EKF_Algorithm']);
if ~isempty(chart)
    fprintf('[OK] Found MATLAB Function block: ekf/EKF_Algorithm\n');
    fprintf('Block Script snippet (first 10 lines):\n');
    lines = splitlines(chart.Script);
    for k = 1:min(10, numel(lines))
        fprintf('   %s\n', lines{k});
    end
else
    fprintf('[WARN] EKF_Algorithm is not a Stateflow EMChart.\n');
end

fprintf('\n============================================================\n');
fprintf(' 2. PORT ORDER VERIFICATION\n');
fprintf('============================================================\n');
inports = find_system([modelName '/EKF_Algorithm'], 'SearchDepth', 1, 'BlockType', 'Inport');
outports = find_system([modelName '/EKF_Algorithm'], 'SearchDepth', 1, 'BlockType', 'Outport');

for k = 1:numel(inports)
    fprintf('Input %d: %s\n', k, get_param(inports{k}, 'Name'));
end
for k = 1:numel(outports)
    fprintf('Output %d: %s\n', k, get_param(outports{k}, 'Name'));
end

fprintf('\n============================================================\n');
fprintf(' 3. RUNNING 0.20s SIMULINK SIMULATION\n');
fprintf('============================================================\n');
out = sim(modelName, 'StopTime', '0.20');

% Extract logged signals or evaluate from logsout
logs = out.logsout;

% Helper function to get last scalar value
get_val = @(name) extract_signal(logs, out, name);

V_pv     = get_val('V_pv');
I_pv     = get_val('I_pv');
T_c_meas = get_val('T_c');
T_amb    = get_val('T_amb');
G_irr    = get_val('G_irr');

V_mp_ref = get_val('V_mp_ref');
I_ph_est = get_val('I_ph_est');
T_c_est  = get_val('T_c_est');

D        = get_val('duty');
V_out    = get_val('V_out');
I_out    = get_val('I_out');

P_in = V_pv * I_pv;
P_out = V_out * I_out;

fprintf('\n============================================================\n');
fprintf(' SIMULINK RUNTIME VALUES AT t = 0.20 s\n');
fprintf('============================================================\n');
fprintf('G_irr      = %.2f W/m^2\n', G_irr);
fprintf('T_amb      = %.2f degC\n', T_amb);
fprintf('V_pv       = %.4f V\n', V_pv);
fprintf('I_pv       = %.6f A\n', I_pv);
fprintf('P_in       = %.6f W\n', P_in);
fprintf('----------------------------------------\n');
fprintf('V_mp_ref   = %.6f V\n', V_mp_ref);
fprintf('I_ph_est   = %.6f A\n', I_ph_est);
fprintf('T_c_est    = %.4f degC\n', T_c_est);
fprintf('----------------------------------------\n');
fprintf('D          = %.6f\n', D);
fprintf('V_out      = %.4f V\n', V_out);
fprintf('I_out      = %.6f A\n', I_out);
fprintf('P_out      = %.6f W\n', P_out);

fprintf('\n============================================================\n');
fprintf(' 4. STANDALONE EKF ALGORITHM COMPARISON\n');
fprintf('============================================================\n');
clear EKF_Algorithm;
[Vmp_ref_test, Iph_test, Tc_est_test] = EKF_Algorithm(V_pv, I_pv, T_c_meas, T_amb);

fprintf('Standalone outputs for input (V=%.4f, I=%.6f, Tc=%.2f, Tamb=%.2f):\n', ...
    V_pv, I_pv, T_c_meas, T_amb);
fprintf('  Vmp_ref_test = %.6f V  (Simulink: %.6f V)\n', Vmp_ref_test, V_mp_ref);
fprintf('  Iph_test     = %.6f A  (Simulink: %.6f A)\n', Iph_test, I_ph_est);
fprintf('  Tc_est_test  = %.4f degC (Simulink: %.4f degC)\n', Tc_est_test, T_c_est);

fprintf('\n============================================================\n');
fprintf(' 5. ACCEPTANCE CRITERIA CHECK\n');
fprintf('============================================================\n');
check_pass = true;

if abs(Vmp_ref_test - V_mp_ref) < 0.1
    fprintf('[PASS] Simulink EKF and Standalone EKF V_mp_ref match!\n');
else
    fprintf('[FAIL] V_mp_ref mismatch!\n');
    check_pass = false;
end

if I_ph_est < 10.0 && I_ph_est > 0.01
    fprintf('[PASS] I_ph_est is physically sane (%.4f A, not thousands of amps)!\n', I_ph_est);
else
    fprintf('[FAIL] I_ph_est is unrealistic (%.4f A)!\n', I_ph_est);
    check_pass = false;
end

if V_mp_ref > 5.05
    fprintf('[PASS] V_mp_ref is not stuck at lower clamp 5.0V (%.4f V)!\n', V_mp_ref);
else
    fprintf('[FAIL] V_mp_ref stuck at lower clamp!\n');
    check_pass = false;
end

if check_pass
    fprintf('\nALL EKF ACCEPTANCE CRITERIA PASSED SUCCESSFULLY!\n');
end

function val = extract_signal(logs, out, sigName)
    val = NaN;
    try
        sig = logs.get(sigName);
        vals = sig.Values.Data;
        val = vals(end);
        return;
    catch
    end
    try
        val = evalin('base', sigName);
        if numel(val) > 1, val = val(end); end
        return;
    catch
    end
    try
        if isprop(out, sigName)
            v = out.(sigName);
            if isstruct(v) || isa(v, 'timeseries')
                val = v.Data(end);
            else
                val = v(end);
            end
        end
    catch
    end
end
