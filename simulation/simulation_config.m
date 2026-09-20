function cfg = simulation_config()
% Central configuration for the Member-4 MPPT integration.

cfg.Ts = 1e-6;              % target Simulink fixed step
cfg.telemetryTs = 0.05;     % 20 Hz browser telemetry

cfg.panel.G = 1000;
cfg.panel.T = 25;

cfg.scenarios.S1.G = 1000;
cfg.scenarios.S1.T = 25;

cfg.scenarios.S2.G_initial = 1000;
cfg.scenarios.S2.G_cloud = 400;
cfg.scenarios.S2.t_cloud = 1;
cfg.scenarios.S2.t_recover = 2;

cfg.scenarios.S3.T_initial = 25;
cfg.scenarios.S3.T_final = 50;
cfg.scenarios.S3.duration = 3;

cfg.scenarios.S4.G = 200;

cfg.scenarios.S5.duration = 5;
end
