# MATLAB → MPPT website

The website already exposes the transport. MATLAB only needs to run the Simulink model and send the logged values.

## 1. Copy the sender files

Copy this folder into the same MATLAB working folder as `ekf.slx`:

- `send_simulation_to_web.m`
- `test_web_endpoint.m`

## 2. Configure Simulink logging

Open `ekf.slx` and use **Model Settings → Data Import/Export**:

- Enable signal logging.
- Use the `Dataset` format.
- Keep the logged dataset variable as `logsout`.
- Mark these signals for logging where possible:

| Signal | Meaning |
|---|---|
| `V_pv_meas` or `Vpv_test` | PV voltage |
| `I_pv_meas` | PV current |
| `V_mp_ref` | MPPT reference voltage |
| `I_ph_est` | Estimated photo current |
| `T_c_est` | Estimated cell temperature |
| `V_out` | Converter output voltage |
| `D` or `duty` | Converter duty cycle |

The sender supports named signals. For the current blank-name model it falls back to the existing order: **2 = V_mp_ref, 3 = I_ph_est, 4 = T_c_est, 5 = V_out, 6 = duty, 7 = I_pv, 8 = V_pv**. Check the `logsout` order once in the Signal Logging Inspector before running a long simulation.

## 3. Test the website first

For the hosted website:

```matlab
test_web_endpoint("https://esp32mppt-5j9ji3de.manus.space")
```

For a local WebDev server:

```matlab
test_web_endpoint("http://localhost:3000")
```

A successful result says that MATLAB telemetry was accepted by the website.

## 4. Run and stream the model

```matlab
out = sim("ekf");
send_simulation_to_web(out, "https://esp32mppt-5j9ji3de.manus.space");
```

For local development:

```matlab
out = sim("ekf");
send_simulation_to_web(out, "http://localhost:3000");
```

The sender downsamples switching-rate signals to about 10 frames per second so the website remains readable. It sends:

```text
V_pv, I_pv, P_pv, V_mp, I_ph, duty, V_out, T_c
```

`P_pv` is calculated as `V_pv .* I_pv`.

## 5. What changes in the website

The backend receives `POST /api/telemetry/simulation`, stores samples with source `MATLAB`, and broadcasts them through `/ws/matlab`. The dashboard connects to that WebSocket automatically. When MATLAB frames arrive, the comparison card changes from **WAITING** to **CONNECTED** and plots:

- MATLAB reference power
- ESP32 live power
- measured MPPT ripple

To compare against actual ESP32 data, click **connect** in the dashboard after the ESP32 WebSocket is available. Demo frames stop when the hardware link becomes live, so demo data is not mixed into the comparison.

## 6. If the test fails

- `out.logsout is empty`: enable Signal logging and rerun `sim("ekf")`.
- `Could not read logged signal`: rename the signals using the table above, or update the fallback indices in `send_simulation_to_web.m` to match the Signal Logging Inspector.
- `Connection refused`: start the local website or use the hosted HTTPS URL.
- `401 Invalid MATLAB ingest token`: the deployed project has `MATLAB_INGEST_TOKEN` enabled; pass the same token as the third argument:

```matlab
send_simulation_to_web(out, "https://your-site.example", "your-token");
```

Do not commit the token to GitHub. Keep it in your local MATLAB script call or environment configuration.
