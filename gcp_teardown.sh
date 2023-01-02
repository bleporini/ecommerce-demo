#!/usr/bin/env bash

if [[ "$CONFIG_FILE" == "" ]] || [[ ! -e $CONFIG_FILE ]]; then
	echo "Please provide an environment variable CONFIG_FILE with the path of the config file"
	exit 1
fi
echo Config file: $CONFIG_FILE
#set -x
. $CONFIG_FILE

cd terraform
./terraform.sh destroy \
	-var "confluent_cloud_api_key=$CONFLUENT_CLOUD_API_KEY" \
	-var "confluent_cloud_api_secret=$CONFLUENT_CLOUD_API_SECRET" \
	-var "mongodbatlas_public_key=$MONGODBATLAS_PUBLIC_KEY" \
	-var "mongodbatlas_private_key=$MONGODBATLAS_PRIVATE_KEY" \
	-var "mongodbatlas_project_id=$MONGODBATLAS_PROJECT_ID" \
	-var "db_hostname=$vm_pub_ip"  \
	-var "db_password=$MYSQL_PASSWORD" \
	-var "mongodbatlas_password=$MYSQL_PASSWORD"


gcloud compute instances delete ps-sample

cd ..
rm env
rm vm_ps_sample.json
rm -rf etc
