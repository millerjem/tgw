variable "AWS_REGION" {    
    default = "us-east-1"
}

provider "aws" {
    region = "${var.AWS_REGION}"
}

locals {
    vpcs = [
        {
            "name" = "tbc-mgmt"
            "region" = "us-east-1"
            "cidr" = "10.1.0.0/16"
            "public-cidr" = "10.1.1.0/24"
            "private-cidr" = "10.1.2.0/24"
        },
        {
            "name" = "tbc-web"
            "region" = "us-east-1"
            "cidr" = "10.2.0.0/16"
            "public-cidr" = "10.2.1.0/24"
            "private-cidr" = "10.2.2.0/24"
        },
        {
            "name" = "tbc-lob"
            "region" = "us-east-1"
            "cidr" = "10.3.0.0/16"
            "public-cidr" = "10.3.1.0/24"
            "private-cidr" = "10.3.2.0/24"
        }
    ]
}

resource "aws_vpc" "vpc" {
    count = length(local.vpcs)
    cidr_block = "${local.vpcs[count.index].cidr}"
    enable_dns_support = "true" #gives you an internal domain name
    enable_dns_hostnames = "true" #gives you an internal host name
    # enable_classiclink = "false" # throws an error on plan
    instance_tenancy = "default"
    tags = {
        Name = "${local.vpcs[count.index].name}-vpc"
        Owner = "john.miller@solo.io"
    }
}

resource "aws_subnet" "subnet-public" {
    count = length(local.vpcs)
    vpc_id = "${aws_vpc.vpc[count.index].id}"
    cidr_block = "${local.vpcs[count.index].public-cidr}"
    map_public_ip_on_launch = "true" //it makes this a public subnet
    availability_zone = "${local.vpcs[count.index].region}a"
    tags = {
        Name = "${local.vpcs[count.index].name}-subnet-public"
    }
}

resource "aws_subnet" "subnet-private" {
    count = length(local.vpcs)
    vpc_id = "${aws_vpc.vpc[count.index].id}"
    cidr_block = "${local.vpcs[count.index].private-cidr}"
    map_public_ip_on_launch = "false"
    availability_zone = "${local.vpcs[count.index].region}a"
    tags = {
        Name = "${local.vpcs[count.index].name}-subnet-private"
    }
}

resource "aws_internet_gateway" "tcb-igw" {
    vpc_id = "${aws_vpc.vpc[0].id}"
    tags = {
        Name = "tcb-igw"
    }
}

resource "aws_route_table" "tcb-public-rt" {
    vpc_id = "${aws_vpc.vpc[0].id}"
    
    route {
        //associated subnet can reach everywhere
        cidr_block = "0.0.0.0/0" 
        //CRT uses this IGW to reach internet
        gateway_id = "${aws_internet_gateway.tcb-igw.id}" 
    }
    
    tags = {
        Name = "tcb-public-rt"
    }
}

resource "aws_route_table_association" "tcb-public-subnet"{
    subnet_id = "${aws_subnet.subnet-public[0].id}"
    route_table_id = "${aws_route_table.tcb-public-rt.id}"
}

resource "aws_security_group" "ssh-allowed" {
    vpc_id = "${aws_vpc.vpc[0].id}"
    
    egress {
        from_port = 0
        to_port = 0
        protocol = -1
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        // This means, all ip address are allowed to ssh ! 
        // Do not do it in the tcb-mgmtuction. 
        // Put your office or home address in it!
        cidr_blocks = ["0.0.0.0/0"]
    }
    //If you do not add this rule, you can not reach the gateway
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "ssh-allowed"
    }
}
