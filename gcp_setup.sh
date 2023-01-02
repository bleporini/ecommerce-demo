#!/usr/bin/env bash

#check if gcloud is available and authenticated 

if [[ "$CONFIG_FILE" == "" ]] || [[ ! -e $CONFIG_FILE ]]; then
	echo "Please provide an environment variable CONFIG_FILE with the path of the config file"
	exit 1
fi
echo Config file: $CONFIG_FILE
. $CONFIG_FILE

gcloud compute instances list > /dev/null 

if [ $? != 0 ]; then
      echo "gcloud CLI is not available or is not authenticated"
      exit 1
fi

echo gcloud check OK


wait_for () {
	local function_to_check=$1
	local name=$2

	local retries=0
	local max_retries=100
	local sleep_delay=5
	until $function_to_check
	do
		retries=$(($retries+1))
		if [ $retries -gt $max_retries ]; then
			echo Timeout waiting for $name readiness
			exit 1
		fi
		sleep $sleep_delay
		echo $name is not ready, retrying
	done
	echo $name ready!
}

ssh_pub=$(cat $SSH_PUB_KEY_FILE)

gcloud compute instances create ps-sample --project=$GCP_PROJECT --zone=$GCP_ZONE --machine-type=e2-medium --network-interface=network-tier=PREMIUM,subnet=default --metadata=ssh-keys="$USER:$ssh_pub" --tags=http-server --create-disk=auto-delete=yes,boot=yes,device-name=instance-2,image=projects/cos-cloud/global/images/cos-101-17162-40-42,mode=rw,size=10 --labels=owner=$VM_OWNER --format="json" > vm_ps_sample.json

#set -x
vm_pub_ip=$(cat vm_ps_sample.json| jq -r ".[0].networkInterfaces[0].accessConfigs[0].natIP")
echo VM public IP: $vm_pub_ip

## To avoid IP reuse with different keys
ssh_options="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

check_ssh () {
	ssh $ssh_options $vm_pub_ip echo OK
}

wait_for check_ssh "SSH"

echo Creating .env file
echo MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD > env
echo MYSQL_PASSWORD=$MYSQL_PASSWORD >> env
echo VM_PUBLIC_IP=$vm_pub_ip >> env

scp $ssh_options env $vm_pub_ip:~/
scp $ssh_options Dockerfile $vm_pub_ip:~/
scp $ssh_options ps_sample_compose.yml $vm_pub_ip:~/
scp $ssh_options -r init-scripts $vm_pub_ip:~/

ssh $ssh_options $vm_pub_ip docker run -d --rm \
	--name compose \
	-v \$PWD/ps_sample_compose.yml:/work/docker-compose.yml  \
	-v \$PWD/Dockerfile:/work/Dockerfile  \
	-v \$PWD/env:/work/.env  \
	-v \$PWD/init-scripts:/work/init-scripts \
	--workdir /work \
       	-v /var/run/docker.sock:/var/run/docker.sock \
       	docker/compose up -d

check_shop () {
	curl --fail --max-time 10 $vm_pub_ip
}

wait_for check_shop "Shop"

cd terraform
./terraform.sh init 
./terraform.sh apply -auto-approve \
	-var "confluent_cloud_api_key=$CONFLUENT_CLOUD_API_KEY" \
	-var "confluent_cloud_api_secret=$CONFLUENT_CLOUD_API_SECRET" \
	-var "mongodbatlas_public_key=$MONGODBATLAS_PUBLIC_KEY" \
	-var "mongodbatlas_private_key=$MONGODBATLAS_PRIVATE_KEY" \
	-var "mongodbatlas_project_id=$MONGODBATLAS_PROJECT_ID" \
	-var "db_hostname=$vm_pub_ip"  \
	-var "db_password=$MYSQL_PASSWORD" \
	-var "mongodbatlas_password=$MYSQL_PASSWORD"

cd ..
./get_ksqldb_api_key.sh

./ksql.sh -f ddl.sql

echo Now you can visit the shop at http://$vm_pub_ip 
cd terraform
./terraform.sh output

