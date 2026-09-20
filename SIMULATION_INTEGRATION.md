# MATLAB / Simulink integration

The dashboard now has three data sources: **DEMO**, **MATLAB**, and **ESP32**.

## What is included

The `simulation/` directory contains the supplied Navin PV model archive, boost/EKF archive, parameter scripts, scenario runner, and CSV exporter. The `bridge/` directory contains the optional local WebSocket replay bridge.

## Run the MATLAB simulation

MATLAB and Simulink are required to execute the `.slx` files. The current hosted environment does not include MATLAB or Octave, so the model has not been executed here.

1. Extract `simulation/navin/Navin_PV_model.slx.zip` and `simulation/boost/ekf.slx(1).zip` in MATLAB.
2. Assemble the missing `master_testbench.slx` by connecting the supplied PV and boost blocks to the real EKF/MPPT subsystem.
3. Set the model PreLoadFcn to `init_parameters`.
4. Enable signal logging with these names: `V_pv`, `I_pv`, `P_pv`, `V_mp_ref`, `I_ph_est`, `D`, and `V_out`.
5. Run `run_scenario('S1')` through `run_scenario('S5')`.
6. Confirm that MATLAB creates `simulation/output/simulation_results.csv`.
7. Restart the web application. Select **MATLAB** in the dashboard source selector.

The website reads that CSV through `simulation.status` and `simulation.latest`, maps the rows into the dashboard telemetry shape, and stops the Demo stream while MATLAB mode is selected.

## Optional local replay bridge

For a separate WebSocket replay process:

```bash
cd bridge
npm install
SIM_CSV=../simulation/output/simulation_results.csv npm start
```

The bridge exposes `/health` and `/ws/simulation` on port `8787`. It is useful for testing a browser WebSocket adapter, while the hosted dashboard's primary integration reads the CSV server-side.

## Honest limitation

The supplied package does not contain a completed `master_testbench.slx` or the final EKF/MPPT subsystem. The dashboard reports when the model archives are present and when the exported CSV is available; it does not fabricate a MATLAB result when the simulation has not been run.
