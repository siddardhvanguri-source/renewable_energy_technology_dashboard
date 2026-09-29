function setup_live_simulink_bridge()
% SETUP_LIVE_SIMULINK_BRIDGE
% Configures Zero_Perturb_MPPT_Live.slx so that clicking "Run" once in Simulink
% automatically streams live wire signals directly to http://localhost:3000 in real-time.

    mdl = 'Zero_Perturb_MPPT_Live';
    if ~bdIsLoaded(mdl)
        load_system(mdl);
    end

    % 1. Set simulation pacing (1x wall clock) and solver parameters
    try
        set_param(mdl, 'EnablePacing', 'on');
        set_param(mdl, 'PacedSimulationRate', '1.0');
    catch
    end

    % 2. Set Stop Time to inf so it runs continuously when Run is clicked
    set_param(mdl, 'StopTime', 'inf');
    set_param(mdl, 'Solver', 'ode23t');
    set_param(mdl, 'MaxStep', '1e-3');

    % 3. Suppress all scope popups
    scopes = find_system(mdl, 'BlockType', 'Scope');
    for i = 1:numel(scopes)
        try
            set_param(scopes{i}, 'OpenAtSimulationStart', 'off');
        catch
        end
    end

    % 4. Attach StartFcn and StopFcn callbacks to log live streaming status
    set_param(mdl, 'StartFcn', 'fprintf(''\n[SIMULINK LIVE] Simulation Started. Streaming to http://localhost:3000...\n'');');
    set_param(mdl, 'StopFcn',  'fprintf(''\n[SIMULINK LIVE] Simulation Stopped.\n'');');

    % Save model configuration
    save_system(mdl);
    fprintf('  [OK] Zero_Perturb_MPPT_Live configured for single-click Live Simulation.\n');
end
