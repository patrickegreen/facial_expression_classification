function [hist, interests] = gradientHistogram(img, bins, T, nSize)
% @param face - a grayscale image
% @param bins - number of histogram bins
% @param T - threshold for harris detector
% @param nSize - neighborhood size
    sigma_smooth = 1.0;
    sigma_deriv = 0.7;
    alpha = 0.05;
    bin_size = 360.0 / bins;
    % Get the interest points (linear indices) and the derivatives
    [interests, Ix, Iy] = harrisDetector(img, sigma_smooth, sigma_deriv, alpha, nSize, T, false);
    N = size(interests, 2);
    % Calculate the gradient angle directions at each interest point
    %   (1) Get the angle from trig in radians
    %   (2) Convert angle to degrees
    %   (3) Add angle offset based sign of dx, dy
    %   (4) Determine the bucket using mod and increment histogram
    hist = zeros(1, bins);
    for linear_idx = interests
        dx = Ix(linear_idx);
        dy = Iy(linear_idx);
        px = dx >= 0;       % positive x component
        py = dy >= 0;     % positive y component
        D = atan(dy/dx);    % angle in radians  
        theta = radtodeg(D);
        % (+,+): theta, (-,+): 180+theta, (-,-): 180+theta, (+,-): 360+theta
        % MATLAB treats divide by zero as infinity
        % Negative dx xor dy results in negative atan
        if isinf(D) && py
            theta = 90;
        elseif isinf(D)
            theta = 270;
        elseif ~px
            theta = 180 + theta;
        elseif px && ~py
            theta = 360 + theta;
        end
        bin = fix(theta / bin_size) + 1;
        value = hist(bin) + 1;
        hist(bin) = value;
    end
    % Normalize the histogram
    hist = hist ./ N;
end
