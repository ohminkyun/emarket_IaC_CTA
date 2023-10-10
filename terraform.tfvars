my_home_ip = ["0.0.0.0/32"]  ## Your Home IP Address  (example: ["221.33.11.110/32"])
svc_name = "emarket"
purpose = "edu"
env = "dev"
region_name = "us-east-1"
region_name_alias = "us"
vpc_cidr_block = "10.1.0.0/16"
az_names = ["us-east-1a", "us-east-1c"]
public_cidrs = [
    {
        availability_zone = "us-east-1a"
        cidr_block = "10.1.0.0/24"
    }, 
    {
        availability_zone = "us-east-1c"
        cidr_block = "10.1.1.0/24"
    }
]
privnat_cidrs = [
    {
        availability_zone = "us-east-1a"
        cidr_block = "10.1.10.0/24"
    },
    {
        availability_zone = "us-east-1c"
        cidr_block = "10.1.11.0/24"        
    }
]
private_cidrs = [
    {
        availability_zone = "us-east-1a"
        cidr_block = "10.1.20.0/24"  
    },
    {
        availability_zone = "us-east-1c"
        cidr_block = "10.1.21.0/24"
    }
]
ssh_port = 2022
ami_id = "ami-0557a15b87f6559cf" ## ubuntu 22.04 jammy image. Need change to "ami-0735c191cf914754d" in Disaster Recovery Class
db_username = "admin"
doc_db_username = "mongoadmin"
autoscaling_policy_target_value = 90.0