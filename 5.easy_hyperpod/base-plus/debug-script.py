#!/usr/bin/env python

import argparse
from enum import Enum
import json
import os
import socket
import subprocess
import sys
import time
from typing import Any, Dict, List, Optional, Tuple

class ExecuteBashScript:
    def __init__(self, script_name: str):
        self.script_name = script_name

    def run(self, *args):
        print(f"Execute script: {self.script_name} {' '.join([str(x) for x in args])}")
        result = subprocess.run(["sudo", "bash", self.script_name, *args])
        result.check_returncode()
        print(f"Script {self.script_name} executed successully")

class ProvisioningParameters:
    WORKLOAD_MANAGER_KEY: str = "workload_manager"
    FSX_DNS_NAME: str = "fsx_dns_name"
    FSX_MOUNT_NAME: str = "fsx_mountname"
    EFS_DNS_NAME: str = "efs_dns_name"

    def __init__(self, path: str):
        with open(path, "r") as f:
            self._params = json.load(f)

    @property
    def workload_manager(self) -> Optional[str]:
        return self._params.get(ProvisioningParameters.WORKLOAD_MANAGER_KEY)

    @property
    def fsx_settings(self) -> Tuple[str, str]:
        return self._params.get(ProvisioningParameters.FSX_DNS_NAME), self._params.get(ProvisioningParameters.FSX_MOUNT_NAME)

    @property
    def controller_group(self) -> Optional[str]:
        return self._params.get("controller_group")

    @property
    def login_group(self) -> Optional[str]:
        return self._params.get("login_group")

    @property
    def efs_settings(self) -> Optional[str]:
        return self._params.get(ProvisioningParameters.EFS_DNS_NAME)

    @property
    def s3_settings(self) -> Optional[List[Dict[str, str]]]:
        return self._params.get("s3_buckets")

def main(args):
    # params = ProvisioningParameters("/home/ec2-user/SageMaker/efs/hp-efs/hp-demo/provisioning_parameters.json")
    params = ProvisioningParameters("/tmp/ia-xxx-us-west-2/sagemaker/hp-demo/LifeCycleScripts/base-config/provisioning_parameters.json")        
    # Debug EFS
    efs_dns_name = "fs-xxx.efs.us-west-2.amazonaws.com"
    if efs_dns_name:
        with open("shared_users_efs.txt") as file:
            for line in file:
                line = line.strip()
                username, user_group_id, mount_directory, accesspoint_id = line.split(sep=",")
                ExecuteBashScript("./mount_efs.sh").run(efs_dns_name, mount_directory, accesspoint_id)

    # Debug S3
    # BUCKET_NAME = "hp-standard-us-west-2"
    # MOUNT_OPTIONS = "--max-threads 96 --part-size 16777216 --allow-other --allow-overwrite --allow-delete --maximum-throughput-gbps 100 --dir-mode 777 --cache /opt/dlami/nvme"
    # MOUNT_POINT = "/home/ec2-user/SageMaker/s3/hp-standard-2"
    # ExecuteBashScript("./mount_s3.sh").run(BUCKET_NAME, MOUNT_OPTIONS, MOUNT_POINT)

    # s3_settings = params.s3_settings
    # if s3_settings:
    #     for s3_config in s3_settings:
    #         bucket_name = s3_config.get("bucket_name")
    #         mount_point = s3_config.get("mount_point")
    #         mount_options = s3_config.get("mount_options")
    #         # print(bucket_name, mount_point, mount_options)
    #         ExecuteBashScript("./mount_s3.sh").run(bucket_name, mount_options, mount_point)


if __name__ == "__main__":
    parser=argparse.ArgumentParser()
    args=parser.parse_args()
    main(args)
