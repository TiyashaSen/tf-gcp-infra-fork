# tf-gcp-infra

Create VPC with Terraform(Infrastructure as Code)-

Steps to initialize Terraform:

1. terraform init
2. terraform init --upgrade

To run this project, use the following commands:

1. terraform validate
2. terraform plan
3. terraform apply -var-file=values.tfvars

To destroy the created VPCs:

1. terraform destroy -var-file=values.tfvars

To setup gcloud CLI:

1. Check current Python version, run python3 -V or python -V. Supported versions are Python 3.8 to 3.12.
2. ./google-cloud-sdk/bin/gcloud init

To setup in Google Cloud console:

1. Created new project in console.
2. gcloud auth login
3. gcloud auth application-default login
4. gcloud config set project
5. gcloud auth revoke
6. gcloud auth application-default revoke

APIs and Services enabled:

1. Compute Engine API
2. Cloud OS Login API
3. Service Usage API
