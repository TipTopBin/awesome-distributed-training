#!/bin/bash
set -eux

# Under ec2-user
sudo -u ec2-user -i <<'EOF'

echo "Init and do your self configuration ..." # Replace with your own bucket and lifecycle name
aws s3 sync s3://$IA_S3_BUCKET/sagemaker/lifecycle/$LC_NAME/ /home/ec2-user/SageMaker/custom/lifecycle/
chmod +x /home/ec2-user/SageMaker/custom/lifecycle/*.sh && chown ec2-user:ec2-user /home/ec2-user/SageMaker/custom/lifecycle/ -R
nohup /home/ec2-user/SageMaker/custom/lifecycle/sm-al2-init.sh > /home/ec2-user/SageMaker/custom/lifecycle/init.log 2>&1 &  # execute asynchronously
nohup /home/ec2-user/SageMaker/custom/lifecycle/sm-al2-abc.sh > /home/ec2-user/SageMaker/custom/lifecycle/abc.log 2>&1 &
/home/ec2-user/SageMaker/custom/lifecycle/sm-al2-jupyter4.sh > /home/ec2-user/SageMaker/custom/lifecycle/jupyter4.log 2>&1

EOF


# Under root
echo "Auto stop to save cost ..."
IDLE_TIME=16200 # 4.5 hour
# IDLE_TIME=28800 # 8 hour
# umask 022

CONDA_PYTHON_DIR=$(source /home/ec2-user/anaconda3/bin/activate /home/ec2-user/anaconda3/envs/JupyterSystemEnv && which python)
if $CONDA_PYTHON_DIR -c "import boto3" 2>/dev/null; then
    PYTHON_DIR=$CONDA_PYTHON_DIR
elif /usr/bin/python -c "import boto3" 2>/dev/null; then
    PYTHON_DIR='/usr/bin/python'
else
    # If no boto3 just quit because the script won't work
    echo "No boto3 found in Python or Python3. Exiting..."
    exit 1
fi
echo "Found boto3 at $PYTHON_DIR"
echo "Starting the SageMaker autostop script in cron"
(crontab -l 2>/dev/null; echo "*/5 * * * * $PYTHON_DIR /home/ec2-user/SageMaker/custom/lifecycle/autostop.py --time $IDLE_TIME --ignore-connections >> /var/log/jupyter.log") | crontab -


echo "Restarting the Jupyter server.."
sudo systemctl daemon-reload
sudo systemctl restart jupyter-server # Amazon Linux 2
# sudo initctl restart jupyter-server --no-wait # Other OS