# Ecommerce demo

The purpose of this demo is to showcase how you can board a legacy application, like this PHP ecommerce shop, on a [Confluent Cloud](https://confluent.cloud) cluster and share data without touching any line of code in the existing application. So the demo is collecting all the fact that occur on the shopping carts, make some aggregation on the fly in order to compute to total cost of the shopping cart and store it in a MongoDB Atlas DB.

This repository comes with all the automation needed in order to set up the demo from the ground: 
- a VM in GCP to run the DB and the PHP application
- Confluent Cloud resources: environment, Kafka cluster, connectors and a ksqlDB cluster
- A target MongoDB Atlas instance

## Requirements

On your laptop, the only tools needed are:
- Bash
- Docker
- jq
- gcloud CLI
- confluent CLI

Please also check that the `gcloud` and the `confluent` CLIs are already authenticated.

## Set up 

You need to create a configuraiton file that holds the following variables:

```bash
GCP_PROJECT=<your GCP project id>
GCP_ZONE=asia-south1-c
SSH_PUB_KEY_FILE=~/.ssh/id_rsa.pub
VM_OWNER=<a value to identity who s owner for the created VM>

MYSQL_ROOT_PASSWORD=< password you want to set >
MYSQL_PASSWORD=< password you want to set >

CONFLUENT_CLOUD_API_KEY=XXXXXXXXXXXXXXXX
CONFLUENT_CLOUD_API_SECRET=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

MONGODBATLAS_PUBLIC_KEY=XXXXXXXXXXXXXXXX
MONGODBATLAS_PRIVATE_KEY=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
MONGODBATLAS_PROJECT_ID=<The project id where the DB will be spun up> 
```

ìf you want to run it in a different region, please keep it in sync between the former file and the Terraform variables file and the default values, otherwise the sink connector will reject to connect to a DB in a different region:

```
variable "mongodbatlas_region" {
  type        = string
  default     = "ASIA_SOUTH_1"
}
variable "region" {
  description = "Cloud region"
  type        = string
  default     = "asia-south1"
}
```

Then provide this file to the `gcp_setup.sh` script as an environment variable:

```bash
$ CONFIG_FILE=../etc/ps_sample.properties ./gcp_setup.sh
[...]
Now you can visit the shop at http://34.93.110.11
MongoDB_url = "mongodb+srv://prestashop.xxxxxxx.mongodb.net"
cluster = "SASL_SSL://pkc-xxxxxx.asia-south1.gcp.confluent.cloud:9092"
sr_endpoint = "https://psrc-xxxxx.australia-southeast1.gcp.confluent.cloud"
```
Then you can browe the ecommerce app, put items in your cart and check in MongoDB that everything is in sync in real time. 

## Dispose all resources

When you're done with the demo, just dispose everything to avoid any unexpected cloud costs:

```bash
$ CONFIG_FILE=../etc/ps_sample.properties ./gcp_teardown.sh
[...]
Do you really want to destroy all resources?
  Terraform will destroy all your managed infrastructure, as shown above.
  There is no undo. Only 'yes' will be accepted to confirm.

  Enter a value: yes
[...]
Destroy complete! Resources: 18 destroyed.
No zone specified. Using zone [asia-south1-c] for instance: [ps-sample].
The following instances will be deleted. Any attached disks configured to be auto-deleted will be deleted unless they are attached to
 any other instances or the `--keep-disks` flag is given and specifies them for keeping. Deleting a disk is irreversible and any data
 on the disk will be lost.
 - [ps-sample] in [asia-south1-c]

Do you want to continue (Y/n)?

Deleted [https://www.googleapis.com/compute/v1/projects/XXXXXXXXXXXXXXXX/zones/asia-south1-c/instances/ps-sample].
```

This script will ask for two confirmation: one for the Confluent Cloud resources, the other one for the GCP VM deletion.