# create bucket
BUCKET_NAME=gs://${USER}_yt8m_train_bucket
# (One Time) Create a storage bucket to store training logs and checkpoints.
gsutil mb -l us-east1 $BUCKET_NAME


# Training on the Cloud over Video-Level Features
JOB_NAME=yt8m_train_$(date +%Y%m%d_%H%M%S); gcloud --verbosity=debug ml-engine jobs \
submit training $JOB_NAME \
--package-path=youtube-8m --module-name=youtube-8m.train \
--staging-bucket=$BUCKET_NAME --region=us-east1 \
--config=youtube-8m/cloudml-gpu.yaml \
-- --train_data_pattern='gs://youtube8m-ml-us-east1/1/video_level/train/train*.tfrecord' \
--model=LogisticModel \
--train_dir=$BUCKET_NAME/yt8m_train_video_level_logistic_model

# Evaluation and Inference
JOB_TO_EVAL=yt8m_train_frame_level_meanCNN_model
JOB_NAME=yt8m_eval_$(date +%Y%m%d_%H%M%S); gcloud --verbosity=debug ml-engine jobs \
submit training $JOB_NAME \
--package-path=youtube-8m --module-name=youtube-8m.eval \
--staging-bucket=$BUCKET_NAME --region=us-east1 \
--config=youtube-8m/cloudml-gpu.yaml \
-- --eval_data_pattern='gs://youtube8m-ml-us-east1/1/frame_level/validate/validate*.tfrecord' \
--frame_features=True --model=MeanCNNsModel --feature_names="rgb" \
--feature_sizes="1024" --batch_size=128 \
--train_dir=$BUCKET_NAME/${JOB_TO_EVAL} --run_once=True

JOB_TO_EVAL=yt8m_train_frame_level_meanCNN_model
JOB_NAME=yt8m_inference_$(date +%Y%m%d_%H%M%S); gcloud --verbosity=debug ml-engine jobs \
submit training $JOB_NAME \
--package-path=youtube-8m --module-name=youtube-8m.inference \
--staging-bucket=$BUCKET_NAME --region=us-east1 \
--config=youtube-8m/cloudml-gpu.yaml \
-- --input_data_pattern='gs://youtube8m-ml/1/frame_level/test/test*.tfrecord' \
--frame_features=True --model=MeanCNNsModel --feature_names="rgb" \
--feature_sizes="1024" --batch_size=128 \
--train_dir=$BUCKET_NAME/${JOB_TO_EVAL} \
--output_file=$BUCKET_NAME/${JOB_TO_EVAL}/predictions.csv


# Using Frame-Level Features
JOB_NAME=yt8m_train_ReCNN_$(date +%Y%m%d_%H%M%S); gcloud --verbosity=debug ml-engine jobs \
submit training $JOB_NAME \
--package-path=youtube-8m --module-name=youtube-8m.train \
--staging-bucket=$BUCKET_NAME --region=us-east1 \
--config=youtube-8m/cloudml-4gpu.yaml \
-- --train_data_pattern='gs://youtube8m-ml-us-east1/1/frame_level/train/train*.tfrecord' \
--frame_features=True --model=RecurrentCNNsModel --feature_names="rgb" \
--feature_sizes="1024" --batch_size=32 \
--train_dir=$BUCKET_NAME/yt8m_train_frame_level_ReCNN_model --start_new_model

JOB_NAME=yt8m_train_$(date +%Y%m%d_%H%M%S); gcloud --verbosity=debug ml-engine jobs \
submit training $JOB_NAME \
--package-path=youtube-8m --module-name=youtube-8m.train \
--staging-bucket=$BUCKET_NAME --region=us-east1 \
--config=youtube-8m/cloudml-gpu.yaml \
-- --train_data_pattern='gs://youtube8m-ml-us-east1/1/frame_level/train*.tfrecord' \
--frame_features=True --model=MeanCNNsModel --feature_names="rgb" \
--feature_sizes="1024" --batch_size=128 \
--train_dir=$BUCKET_NAME/yt8m_train_frame_level_meanCNN_model

# ----------------------------local-------------------------------------
gcloud ml-engine local train \
--package-path=youtube-8m --module-name=youtube-8m.train -- \
--train_data_pattern='gs://youtube8m-ml-us-east1/1/frame_level/train/train*.tfrecord' \
--frame_features=True --model=MeanCNNsModel --feature_names="rgb" \
--feature_sizes="1024" --batch_size=2 \
--train_dir=/tmp/yt8m_train --start_new_model

JOB_TO_EVAL=yt8m_train_frame_level_logistic_model
JOB_NAME=yt8m_eval_$(date +%Y%m%d_%H%M%S); gcloud --verbosity=debug ml-engine jobs \
submit training $JOB_NAME \
--package-path=youtube-8m --module-name=youtube-8m.eval \
--staging-bucket=$BUCKET_NAME --region=us-east1 \
--config=youtube-8m/cloudml-4gpu.yaml \
-- --eval_data_pattern='gs://youtube8m-ml-us-east1/1/video_level/validate/validate*.tfrecord' \
--model=LogisticModel \
--train_dir=$BUCKET_NAME/${JOB_TO_EVAL} --run_once=True

tensorboard --logdir=$BUCKET_NAME/yt8m_train_frame_level_MeanCNN_model --port=8080

BUCKET_NAME=gs://${USER}_yt8m_train_bucket
cd youtube-8m && git pull origin master && cd ..

