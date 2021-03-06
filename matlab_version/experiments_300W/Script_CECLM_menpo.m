function Script_CECLM_menpo()

addpath(genpath('../'));

% Replace this with the location of the 300W data location
if(exist([getenv('USERPROFILE') '/Dropbox/AAM/test data/'], 'file'))
    root_test_data = [getenv('USERPROFILE') '/Dropbox/AAM/test data/'];    
else
    root_test_data = 'F:\Dropbox\AAM\test data/';
end
[images, detections, labels] = Collect_wild_imgs(root_test_data);

%% loading the CE-CLM model and parameters   
[patches, pdm, clmParams, early_term_params] = Load_CECLM_menpo();
% Use the multi-hypothesis model, as bounding box tells nothing about
% orientation
views = [0,0,0; 0,-30,0; 0,30,0; 0,0,30; 0,0,-30;];
views = views * pi/180;                                                                                     

%% Setup recording

num_points = numel(pdm.M)/3;

shapes_all = zeros(size(labels,2),size(labels,3), size(labels,1));
labels_all = zeros(size(labels,2),size(labels,3), size(labels,1));
lhoods = zeros(numel(images),1);
all_lmark_lhoods = zeros(num_points, numel(images));
all_views_used = zeros(numel(images),1);

% Change if you want to visualize the outputs
verbose = true;
output_img = false;

if(output_img)
    output_root = './ceclm_menpo_out/';
    if(~exist(output_root, 'dir'))
        mkdir(output_root);
    end
end
if(verbose)
    f = figure;
end


%% Fitting the model to the provided images

tic
for i=1:numel(images)

    image = imread(images(i).img);
    image_orig = image;
    
    if(size(image,3) == 3)
        image = rgb2gray(image);
    end              

    bbox = detections(i,:);                  
    
    % have a multi-view version
    [shape,~,~,lhood,lmark_lhood,view_used] =...
        Fitting_from_bb_multi_hyp(image, [], bbox, pdm, patches, clmParams, views, early_term_params);

    all_lmark_lhoods(:,i) = lmark_lhood;
    all_views_used(i) = view_used;

    shapes_all(:,:,i) = shape;
    labels_all(:,:,i) = labels(i,:,:);

    if(mod(i, 200)==0)
        fprintf('%d done\n', i );
    end

    lhoods(i) = lhood;

    if(output_img)
        v_points = sum(squeeze(labels(i,:,:)),2) > 0;
        DrawFaceOnImg(image_orig, shape, sprintf('%s/%s%d.jpg', output_root, 'fit', i), bbox, v_points);
    end
    
    if(verbose)
        v_points = sum(squeeze(labels(i,:,:)),2) > 0;
        DrawFaceOnFig(image_orig, shape, bbox, v_points);
    end
end
toc

experiment.errors_normed = compute_error(labels_all, shapes_all + 1.0);
experiment.lhoods = lhoods;
experiment.shapes = shapes_all;
experiment.labels = labels_all;
experiment.all_lmark_lhoods = all_lmark_lhoods;
experiment.all_views_used = all_views_used;

fprintf('Done: mean normed error %.3f median normed error %.4f\n', ...
    mean(experiment.errors_normed), median(experiment.errors_normed));

%%
output_results = 'results/results_ceclm_menpo.mat';
save(output_results, 'experiment');
    
end
