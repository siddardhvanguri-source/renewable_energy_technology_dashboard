function T = fetch_telemetry_from_web(baseUrl)
% FETCH_TELEMETRY_FROM_WEB Fetch all persistent logged telemetry samples from the web server into a MATLAB Table.
%
% Usage:
%   T = fetch_telemetry_from_web();
%   T = fetch_telemetry_from_web("http://localhost:3000");
%
% Returns:
%   T - MATLAB table with columns: [timestamp_ms, iso_time, source, scenario_code, v_pv, i_pv, p_pv, v_mp, i_ph, duty, efficiency]

    if nargin < 1 || strlength(string(baseUrl)) == 0
        baseUrl = "http://localhost:3000";
    end

    csvUrl = string(baseUrl) + "/api/telemetry/export.csv";
    fprintf("Fetching logged telemetry from %s ...\n", csvUrl);

    try
        tempFile = [tempname, '.csv'];
        websave(tempFile, csvUrl);
        T = readtable(tempFile);
        delete(tempFile);

        fprintf("Successfully retrieved %d telemetry samples from SQLite database!\n", height(T));
        disp(head(T, 5));
    catch ex
        error("Failed to fetch telemetry from server: %s", ex.message);
    end
end
