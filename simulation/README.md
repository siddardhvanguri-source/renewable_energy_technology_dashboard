# Simulink integration

The supplied Navin and boost model archives are preserved under `navin/` and `boost/`.

Important: this package does **not** silently fabricate a completed `master_testbench.slx`. The missing EKF/MPPT model and exact port/interface details must be connected in Simulink. Once connected, use:

1. `init_parameters.m` as Model PreLoadFcn: `init_parameters`
2. signal logging names:
   `V_pv`, `I_pv`, `P_pv`, `V_mp_ref`, `I_ph_est`, `D`, `V_out`
3. `run_scenario('S1')` ... `run_scenario('S5')`
4. `export_simulation_results.m`

The browser telemetry bridge can replay `output/simulation_results.csv` at 20 Hz, so the web dashboard can be tested before MATLAB/Simulink live control is connected.
