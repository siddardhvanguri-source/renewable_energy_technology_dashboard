function init_parameters()
% Model PreLoadFcn entry point.
cfg = simulation_config();

assignin('base','Ts',cfg.Ts);
assignin('base','telemetryTs',cfg.telemetryTs);
assignin('base','G_irr',cfg.panel.G);
assignin('base','T_amb',cfg.panel.T);

assignin('base','MPPT_SCENARIO','S1');
end
