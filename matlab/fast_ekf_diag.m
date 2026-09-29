% fast_ekf_diag.m
addpath('c:\Users\saisi\.antigravity-ide\renewable_energy_technology_dashboard\matlab');
addpath('C:\Users\saisi\OneDrive\Documents\RENEWABLE ENERGY TECH\matlabsimulation\MPPT_STEP1_STARTER\algorithms');
cd('c:\Users\saisi\.antigravity-ide\renewable_energy_technology_dashboard\matlab');

bdclose('all');
modelName = 'ekf';
load_system(modelName);

% Set solver properties for fast execution
set_param(modelName, 'SolverType', 'Variable-step');
set_param(modelName, 'Solver', 'ode23t');
set_param(modelName, 'MaxStep', '1e-3');

fprintf('Starting sim...\n');
tic;
out = sim(modelName, 'StopTime', '0.10');
t_sim = toc;
fprintf('Sim completed in %.2f seconds.\n', t_sim);

logs = out.logsout;
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
fprintf(' SIMULINK RUNTIME VALUES AT t = 0.10 s\n');
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
fprintf(' STANDALONE EKF ALGORITHM COMPARISON\n');
fprintf('============================================================\n');
clear EKF_Algorithm;
[Vmp_ref_test, Iph_test, Tc_est_test] = EKF_Algorithm(V_pv, I_pv, T_c_meas, T_amb);

fprintf('Standalone outputs for input (V=%.4f, I=%.6f, Tc=%.2f, Tamb=%.2f):\n', ...
    V_pv, I_pv, T_c_meas, T_amb);
fprintf('  Vmp_ref_test = %.6f V  (Simulink: %.6f V)\n', Vmp_ref_test, V_mp_ref);
fprintf('  Iph_test     = %.6f A  (Simulink: %.6f A)\n', Iph_test, I_ph_est);
fprintf('  Tc_est_test  = %.4f degC (Simulink: %.4f degC)\n', Tc_est_test, T_c_est);

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
