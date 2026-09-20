function export_simulation_results(simOut)
% Export logged signals when the master model exposes logsout entries.
% Required names:
% V_pv, I_pv, P_pv, V_mp_ref, I_ph_est, D, V_out

outDir = fullfile(fileparts(mfilename('fullpath')),'output');
if ~exist(outDir,'dir'), mkdir(outDir); end

if ~isprop(simOut,'logsout') && ~isfield(simOut,'logsout')
    warning('No logsout found; configure signal logging in master_testbench.slx.');
    return;
end

logs = simOut.logsout;
names = {'V_pv','I_pv','P_pv','V_mp_ref','I_ph_est','D','V_out'};
series = cell(size(names));

for k = 1:numel(names)
    item = logs.get(names{k});
    if isempty(item)
        warning('Missing logged signal: %s', names{k});
        return;
    end
    series{k} = item.Values;
end

t = series{1}.Time;
data = zeros(numel(t), numel(names));
for k = 1:numel(names)
    data(:,k) = series{k}.Data(:);
end

T = array2table([t data], 'VariableNames', ...
    {'time','v_pv','i_pv','p_pv','v_mp','i_ph','duty','v_out'});

writetable(T,fullfile(outDir,'simulation_results.csv'));
fprintf('Wrote %s\n',fullfile(outDir,'simulation_results.csv'));
end
