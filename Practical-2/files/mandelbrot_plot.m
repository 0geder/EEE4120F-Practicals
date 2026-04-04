function mandelbrot_plot(image_data, width, height, filename)
% MANDELBROT_PLOT Plots and saves a Mandelbrot set image.
%
% Inputs:
%   image_data - 2D matrix of iteration counts (height x width)
%   width      - Image width in pixels
%   height     - Image height in pixels
%   filename   - Output filename (e.g., 'mandelbrot_HD.png')

    % FIX: Ensure directory exists and filename is valid
    [filepath, name, ext] = fileparts(filename);
    
    % Create directory if it doesn't exist
    if ~isempty(filepath) && ~exist(filepath, 'dir')
        mkdir(filepath);
    end
    
    % FIX: Sanitize filename - remove problematic characters
    % Replace spaces and special chars that might cause issues
    safe_name = regexprep(name, '[<>:"/\|?*'' ,;]', '_');
    safe_filename = fullfile(filepath, [safe_name, ext]);
    
    fprintf('Saving to: %s\n', safe_filename);
    
    % Create figure with appropriate size
    fig = figure('Visible', 'off', 'Position', [100, 100, min(width, 1920), min(height, 1080)]);
    
    imagesc(image_data);
    colormap(hot);
    colorbar;
    axis image off;
    title(sprintf('Mandelbrot Set (%d x %d)', width, height), ...
        'FontSize', 12, 'Color', 'white');
    set(gca, 'Color', 'black');
    set(fig, 'Color', 'black');
    
    % FIX: Try different save methods with error handling
    try
        % Method 1: exportgraphics (more robust for large images)
        exportgraphics(fig, safe_filename, 'Resolution', 150);
    catch
        try
            % Method 2: saveas (fallback)
            saveas(fig, safe_filename);
        catch ME
            % Method 3: print with explicit format
            warning('Standard save failed, trying print command...');
            print(fig, safe_filename, '-dpng', '-r150');
        end
    end
    
    close(fig);
    fprintf('Saved image: %s\n', safe_filename);
end