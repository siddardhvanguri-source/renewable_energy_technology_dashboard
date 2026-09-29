# MATLAB & ESP32 MPPT Telemetry Integration

This folder contains MATLAB scripts to stream Simulink simulation logs, log values persistently to SQLite, and visualize telemetry curves directly in MATLAB and on the web dashboard.

---

## 1. Files in this directory

- [start_live_matlab_stream.m](file:///c:/Users/saisi/.antigravity-ide/renewable_energy_technology_dashboard/matlab/start_live_matlab_stream.m): **TRUE LIVE TELEMETRY**. Runs Simulink incrementally, transmits telemetry at ~15 Hz WHILE simulation progresses, preserves state between segments, and updates the web dashboard in real time.
- [stop_live_matlab_stream.m](file:///c:/Users/saisi/.antigravity-ide/renewable_energy_technology_dashboard/matlab/stop_live_matlab_stream.m): Cleanly halts active live streams and releases model resources.
- [send_simulation_to_web.m](file:///c:/Users/saisi/.antigravity-ide/renewable_energy_technology_dashboard/matlab/send_simulation_to_web.m): Streams Simulink `logsout` from a completed simulation run to the web dashboard.
- [fetch_telemetry_from_web.m](file:///c:/Users/saisi/.antigravity-ide/renewable_energy_technology_dashboard/matlab/fetch_telemetry_from_web.m): Fetches all persisted telemetry records from the SQLite database into a MATLAB `table`.
- [plot_mppt_comparison.m](file:///c:/Users/saisi/.antigravity-ide/renewable_energy_technology_dashboard/matlab/plot_mppt_comparison.m): Generates comparison plots ($P_{pv}$, $V_{pv}$ vs $V_{mp}$, $\text{Duty}$, $I_{pv}$) in MATLAB.
- [test_web_endpoint.m](file:///c:/Users/saisi/.antigravity-ide/renewable_energy_technology_dashboard/matlab/test_web_endpoint.m): Quick health-check verification script.

---

## 2. True Live Streaming (Continuous Real-Time)

To stream live while Simulink is executing:

```matlab
% In MATLAB command window:
cd("C:\Users\saisi\OneDrive\Documents\RENEWABLE ENERGY TECH\matlabsimulation\MPPT_STEP1_STARTER\models");
addpath("C:\Users\saisi\.antigravity-ide\renewable_energy_technology_dashboard\matlab");

% Start live streaming (continuous 15 Hz updates):
start_live_matlab_stream

% To stop anytime:
stop_live_matlab_stream
```

---

## 3. Retrieving Logged Data in MATLAB

You can retrieve the logged telemetry anytime from the SQLite database:

```matlab
% Fetch all recorded samples into a table
T = fetch_telemetry_from_web("http://localhost:3000");

% Plot the stored telemetry curves
plot_mppt_comparison("http://localhost:3000");
```
