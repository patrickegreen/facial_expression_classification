function [accuracy] = classifier(dataSource, dataRoot, classNames, binCount, T, neighSize, hsig_smooth, hsig_deriv, hsig_alpha, boundIndents)
% @param dataSource - local text file with (imageName, classLabel)
%   A label of zero means to ignore
% @param dataRoot - folder for which to use images, dataset
% @param classNames - pretty names for the classes (idx == classLabel)
% @param binCount - number of histogram bins to use
% @param T - threshold for harris detector
% @param neighSize - neighborhood size for non-max suppression in harris
% @param hsig_smooth - used for gaussian smoothing in Harris
% @param hsig_deriv - used for size of the gradient filter in Harris
% @param hsig_alpha - used for the approximation of R in Harris
% @param boundIndents - cut corners at (%X, %Y)
%
% @returns accuracy - the accuracy obtained from 4-fold cross validation
    %% Prepare data for training & test
    f = fopen(dataSource, 'r');     % (filename, label)
    data = textscan(f, '%s%d');
    names = string(vertcat(data{:, 1}));
    labels = vertcat(data{:, 2});
    raw_count = size(labels, 1);
    remove_idxs = [];
    % Determine samples that are filtered from data (class label == 0)
    for i = 1:raw_count
        if ~labels(i)
            remove_idxs(end+1) = i;
        end
    end
    % Remove invalid samples (start from last index)
    remove_idxs = sort(remove_idxs, 'descend');
    for ridx = remove_idxs
        names(ridx) = [];
        labels(ridx) = [];
    end
    sample_count = size(labels, 1);    % count of valid samples

    %% Prepare Cross Valdidation
    cv_set_count = 4;
    cv_ranges = zeros(cv_set_count,2);
    set_size = floor(sample_count / cv_set_count);
    remainder = sample_count - set_size * cv_set_count;
    next_idx = 1;
    for i = 1:cv_set_count
        cv_ranges(i,1) = next_idx;
        step = 0;
        if remainder > 0
            step = 1;
            remainder = remainder - 1;
        end
        cv_size = set_size + step;
        next_idx = next_idx + cv_size;
        cv_ranges(i,2) = next_idx - 1;
    end
    perm = randperm(sample_count);
    sample_range = 1:sample_count;
    shuffled = sample_range;
    shuffled(1,perm) = sample_range(1,:);

    %% Run cross-validation
    total_correct = 0;
    for setN = 1:cv_set_count
        % Build the train and test sets (selected set is test)
        iStart = cv_ranges(setN, 1);
        iEnd = cv_ranges(setN, 2);
        if iStart == 1
            train = shuffled(1,iEnd+1:sample_count);  
        elseif iEnd == sample_count
            train = shuffled(1,1:iStart-1);
        else
            train = cat(2, shuffled(1:iStart-1), shuffled(iEnd+1:sample_count));
        end
        test = shuffled(1,iStart:iEnd);
        train_count = size(train,2);
        test_count = size(test,2);

        %% Build histogram templates for each class in training set
        cN = size(classNames,2);     % class count
        hist = zeros(cN, binCount);    % row per class (frown, smile, surprise, tongue)
        class_counts = zeros(1,cN);  % counts of each class for normalization
        for idx = train
            name = names(idx);
            label = labels(idx);
            filename = sprintf('%s/%s', dataRoot, name);
            img = double(imread(filename));
            % Get histogram and update appropriate class template / count
            [h, interests] = gradientHistogram(img, binCount, T, neighSize, hsig_smooth, hsig_deriv, hsig_alpha);
            hist(label, :) = hist(label, :) + h;    
            class_counts(label) = class_counts(label) + 1;
        end
        % Normalize sum of histograms by count
        for i = 1:cN
            hist(i, :) = hist(i, :) ./ class_counts(i);
            % Display the histogram
            cname = classNames(i);
            bar(hist(i, :));
            ylim([0 0.12]);
            title(cname);
            output = sprintf('files/hist_%s', cname);
            print(output, '-dpng');
            pause;
        end

        %% Classify Test Data
        % Chi-squared distance (sum of square of difference divided by sum of magnitudes)
        for idx = test
            name = names(idx);
            label = labels(idx);
            filename = sprintf('%s/%s', dataRoot, name);
            img = double(imread(filename));
            % Get histogram and find best matching template
            [h, interests] = gradientHistogram(img, binCount, T, neighSize, hsig_smooth, hsig_deriv, hsig_alpha);
            D = zeros(1, cN);
            for i = 1:cN
                template = hist(i, :);
                dist = chiDistance(h, template);
                D(i) = dist;
            end
            [dist, guess] = min(D);
            correct = guess == label;
            if correct
                total_correct = total_correct + 1;
            end
            % Display test image with results
            %title = sprintf('Guess=%s, Actual=%s', classNames(guess), classNames(label));
            %plotImage(img, interests, title, false, true);
        end 
    end
    %% Calculate totals
    accuracy = total_correct / sample_count;
end