function recommend_pump()
    % Set default character encoding to UTF-8 to handle special characters
    feature('DefaultCharacterSet', 'UTF-8');
    
    % Get user input for pump requirements with validation
    while true
        try
            % Prompt user for required head (10-50 meters)
            head = input('Required head (10-50 m): ');
            % Prompt user for required flow rate (3-50 m³/h)
            flow_rate = input('Required flow rate (3-50 m³/h): ');
            
            % Validate input ranges
            if ~isnumeric(head) || ~isnumeric(flow_rate) || ...
               head < 10 || head > 50 || flow_rate < 3 || flow_rate > 50
                error('Invalid input');
            end
            break;
        catch
            % Display error message if input is invalid
            fprintf('\nInvalid input! Valid ranges: Head 10-50m, Flow 3-50m³/h\n\n');
        end
    end
    
    % List of available pump data files and their corresponding model names
    pump_files = {
        'pump32125.xlsx', '32-125'
        'pump32160.xlsx', '32-160'
        'pump32200.xlsx', '32-200'
        'pump40125.xlsx', '40-125'
        'pump40160.xlsx', '40-160'
        'pump40200.xlsx', '40-200'
        'pump50125.xlsx', '50-125'
        'pump50160.xlsx', '50-160'
        'pump50200.xlsx', '50-200'
    };
    
    % Initialize variables to store the best pump found
    best_pump = '';
    best_diameter = 0;
    best_efficiency = 0;
    best_power = 0;
    min_distance = Inf;  % Used to find the closest matching pump
    
    % Evaluate each pump model
    for i = 1:size(pump_files,1)
        try
            % Read pump's operating boundary from Excel file
            boundary = readtable(pump_files{i,1}, 'Sheet', 'Boundary');
            x = boundary{:,1};  % Flow rate values
            y = boundary{:,2};  % Head values
            
            % Check if requested parameters fall within this pump's operating range
            if inpolygon(flow_rate, head, x, y)
                % Calculate distance to center of pump's operating range
                center_flow = mean(x);
                center_head = mean(y);
                distance = sqrt((flow_rate-center_flow)^2 + (head-center_head)^2);
                
                % If this is the closest matching pump so far, store its details
                if distance < min_distance
                    % Read diameter data
                    diameter_data = readtable(pump_files{i,1}, 'Sheet', 'Diameter');
                    % Read efficiency data
                    eff_data = readtable(pump_files{i,1}, 'Sheet', 'Efficiency');
                    
                    % Find closest matching point for interpolation
                    [~, idx] = min(sqrt((diameter_data{:,1} - flow_rate).^2 + (diameter_data{:,2} - head).^2));
                    
                    % Select the smallest diameter that is >= interpolated value
                    diameter_options = unique(diameter_data{:,3});
                    interpolated_diameter = diameter_data{idx, 3};
                    valid_diameters = diameter_options(diameter_options >= interpolated_diameter);
                    if ~isempty(valid_diameters)
                        diameter = min(valid_diameters);
                    else
                        diameter = max(diameter_options);
                    end
                    
                    % Interpolate efficiency value
                    F_eff = scatteredInterpolant(eff_data{:,1}, eff_data{:,2}, eff_data{:,3}, 'natural');
                    efficiency_interp = F_eff(flow_rate, head);
                    % Clamp efficiency value to valid range
                    efficiency_interp = max(min(eff_data{:,3}), min(max(eff_data{:,3}), efficiency_interp));
                    [~, idx_eff] = min(abs(eff_data{:,3} - efficiency_interp));
                    efficiency = eff_data{idx_eff, 3};
                    
                    % Calculate required power
                    power_data = readtable(pump_files{i,1}, 'Sheet', 'Power');
                    % ????? ???: ????? scatteredInterpolant ?? scatteredInterpolant
                    F_power = scatteredInterpolant(power_data{:,1}, power_data{:,3}, power_data{:,2}, 'natural');
                    power = F_power(flow_rate, diameter);
                    
                    % Update best pump information
                    min_distance = distance;
                    best_pump = pump_files{i,2};
                    best_diameter = diameter;
                    best_efficiency = efficiency;
                    best_power = power;
                end
            end
        catch ME
            % Display error if there's a problem processing a pump file
            fprintf('Error processing pump %s: %s\n', pump_files{i,2}, ME.message);
            continue;
        end
    end
    
    % Display results to user
    if ~isempty(best_pump)
        fprintf('\nRecommended Pump:\n');
        fprintf('Type: %s\n', best_pump);
        fprintf('Diameter: %.1f mm\n', best_diameter);
        fprintf('Efficiency: %.2f%%\n', best_efficiency);
        fprintf('Electrical Power: %.2f kW\n', best_power);
    else
        fprintf('\nNo suitable pump found for the given parameters.\n');
    end
end