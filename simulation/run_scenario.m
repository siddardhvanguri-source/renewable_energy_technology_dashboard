function simOut = run_scenario(scenario, modelName)
% Run a scenario after master_testbench.slx has been assembled.
% This intentionally does not fake EKF/P&O outputs.

if nargin < 1, scenario = 'S1'; end
if nargin < 2, modelName = 'master_testbench'; end

cfg = simulation_config();
assignin('base','MPPT_SCENARIO',upper(scenario));

switch upper(scenario)
    case 'S1'
        G_irr = cfg.scenarios.S1.G;
        T_amb = cfg.scenarios.S1.T;
    case 'S2'
        G_irr = cfg.scenarios.S2.G_initial;
        T_amb = 25;
    case 'S3'
        G_irr = 1000;
        T_amb = cfg.scenarios.S3.T_initial;
    case 'S4'
        G_irr = cfg.scenarios.S4.G;
        T_amb = 25;
    case 'S5'
        G_irr = 1000;
        T_amb = 25;
    otherwise
        error('Unknown scenario: %s', scenario);
end

assignin('base','G_irr',G_irr);
assignin('base','T_amb',T_amb);

load_system(modelName);
simOut = sim(modelName,'ReturnWorkspaceOutputs','on');

if exist('export_simulation_results','file')
    export_simulation_results(simOut);
end
end
