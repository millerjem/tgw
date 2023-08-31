variable "AWS_REGION" {    
    default = "us-east-1"
}

provider "aws" {
    region = "${var.AWS_REGION}"
}

resource "aws_vpc" "tcb-mgmt-vpc" {
    cidr_block = "10.0.0.0/16"
    enable_dns_support = "true" #gives you an internal domain name
    enable_dns_hostnames = "true" #gives you an internal host name
    # enable_classiclink = "false" # throws an error on plan
    instance_tenancy = "default"
    tags = {
        Name = "tcb-mgmt-vpc"
        Owner = "john.miller@solo.io"
    }
}

resource "aws_subnet" "tcb-mgmt-subnet-public-1" {
    vpc_id = "${aws_vpc.tcb-mgmt-vpc.id}"
    cidr_block = "10.0.1.0/24"
    map_public_ip_on_launch = "true" //it makes this a public subnet
    availability_zone = "us-east-1a"
    tags = {
        Name = "tcb-mgmt-subnet-public-1"
    }
}

resource "aws_internet_gateway" "tcb-mgmt-igw" {
    vpc_id = "${aws_vpc.tcb-mgmt-vpc.id}"
    tags = {
        Name = "tcb-mgmt-igw"
    }
}

resource "aws_route_table" "tcb-mgmt-public-rt" {
    vpc_id = "${aws_vpc.tcb-mgmt-vpc.id}"
    
    route {
        //associated subnet can reach everywhere
        cidr_block = "0.0.0.0/0" 
        //CRT uses this IGW to reach internet
        gateway_id = "${aws_internet_gateway.tcb-mgmt-igw.id}" 
    }
    
    tags = {
        Name = "tcb-mgmt-public-rt"
    }
}

resource "aws_route_table_association" "tcb-mgmt-public-subnet-1"{
    subnet_id = "${aws_subnet.tcb-mgmt-subnet-public-1.id}"
    route_table_id = "${aws_route_table.tcb-mgmt-public-rt.id}"
}

resource "aws_security_group" "ssh-allowed" {
    vpc_id = "${aws_vpc.tcb-mgmt-vpc.id}"
    
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
