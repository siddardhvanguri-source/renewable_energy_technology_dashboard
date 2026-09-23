function response = test_web_endpoint(baseUrl, ingestToken)
% TEST_WEB_ENDPOINT Verify that MATLAB can reach the MPPT website backend.
%
% Run this before a full Simulink export:
%   test_web_endpoint("http://localhost:3000")

    if nargin < 1 || strlength(string(baseUrl)) == 0
        baseUrl = "http://localhost:3000";
    end
    if nargin < 2
        ingestToken = "";
    end

    payload = struct( ...
        "timestamp", round(posixtime(datetime("now")) * 1000), ...
        "v_pv", 31.2, ...
        "i_pv", 6.9, ...
        "p_pv", 215.28, ...
        "v_mp", 30.9, ...
        "i_ph", 6.98, ...
        "duty", 0.61, ...
        "v_out", 48.2, ...
        "t_c", 25, ...
        "source", "matlab");

    options = weboptions("MediaType", "application/json", "Timeout", 15);
    if strlength(string(ingestToken)) > 0
        options.HeaderFields = {"x-matlab-token", char(ingestToken)};
    end

    response = webwrite(string(baseUrl) + "/api/telemetry/simulation", payload, options);
    disp("MATLAB endpoint is working. Telemetry was accepted by the website.");
    disp(response);
end
