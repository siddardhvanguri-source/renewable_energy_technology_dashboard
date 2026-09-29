% test_scenario_physics.m
addpath('C:\Users\saisi\OneDrive\Documents\RENEWABLE ENERGY TECH\matlabsimulation\MPPT_STEP1_STARTER\models');
addpath('C:\Users\saisi\OneDrive\Documents\RENEWABLE ENERGY TECH\matlabsimulation\MPPT_STEP1_STARTER\algorithms');

clear EKF_Algorithm;

fprintf('=================================================================\n');
fprintf(' DYNAMIC SCENARIO S2 TEST: Irradiance 1000 -> 500 -> 1000 W/m^2\n');
fprintf('=================================================================\n');

testTimes = [0.0, 0.5, 1.5, 2.0, 2.5, 3.5, 4.0, 4.5];

for idx = 1:length(testTimes)
    t = testTimes(idx);
    
    % Scenario S2 logic
    if t < 2.0
        G = 1000;
    elseif t < 4.0
        G = 500;
    else
        G = 1000;
    end
    T_amb = 25.0;
    
    % Operating voltage around MPP
    V_test = 17.5;
    
    % Physical PV cell solver (Navin 10W model)
    [I_pv, T_c] = compute_pv_cell(V_test, G, T_amb);
    
    % Analytical / EKF estimation
    [V_mp, I_ph, T_c_est] = EKF_Algorithm(V_test, I_pv, T_c, T_amb);
    
    % Closed-loop MPPT duty cycle
    duty = 0.30 + 0.02 * (V_test - V_mp);
    P_pv = V_test * I_pv;
    
    fprintf('t=%4.1fs | G=%4d W/m^2 | Iph=%6.3fA | I_pv=%6.3fA | V_pv=%5.2fV | P_pv=%6.3fW | V_mp=%5.2fV | Duty=%6.4f\n', ...
        t, G, I_ph, I_pv, V_test, P_pv, V_mp, duty);
end

function [I_pv, T_c_out] = compute_pv_cell(V_pv, G_irr, T_amb)
    Iph0 = 0.5617;
    Io   = 1.1109e-09;
    n    = 1.20;
    Rs   = 1.5641;
    Rsh  = 101094505721.94;
    Ns   = 36;
    k    = 1.380649e-23;
    q    = 1.602176634e-19;
    Tstc = 298.15;
    Ki   = 0.0006;
    Eg   = 1.12;
    
    T_c = T_amb + 273.15 + ((45 - 20)/800) * G_irr;
    T_c_out = T_c - 273.15;
    
    a = Ns * n * k * T_c / q;
    Iph = Iph0 * (G_irr/1000) * (1 + Ki * (T_c - Tstc));
    Io_t = Io * (T_c/Tstc)^3 * exp((q * Eg / (n * k)) * (1/Tstc - 1/T_c));
    
    I = Iph;
    for it = 1:20
        E = exp((V_pv + I * Rs) / a);
        f = Iph - Io_t * (E - 1) - (V_pv + I * Rs)/Rsh - I;
        df = -Io_t * E * Rs / a - Rs / Rsh - 1;
        I = I - f / df;
    end
    I_pv = max(I, 0);
end
