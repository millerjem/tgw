variable "AWS_REGION" {    
    default = "us-east-1"
}

provider "aws" {
    region = "${var.AWS_REGION}"
}

locals {
    vpcs = [
        {
            "name" = "tcb-gateway"
            "region" = "${var.AWS_REGION}"
            "cidr" = "10.1.0.0/16"
            "public-cidr" = "10.1.1.0/24"
            "private-cidr" = "10.1.2.0/24"
        },
        {
            "name" = "tcb-web"
            "region" = "${var.AWS_REGION}"
            "cidr" = "10.2.0.0/16"
            "public-cidr" = "10.2.1.0/24"
            "private-cidr" = "10.2.2.0/24"
        },
        {
            "name" = "tcb-lob"
            "region" = "${var.AWS_REGION}"
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
    tags = {
        Name = "${local.vpcs[count.index].name}-vpc"
        Owner = "john.miller@solo.io"
    }
}

resource "aws_subnet" "subnet-public" {
    vpc_id = "${aws_vpc.vpc[0].id}"
    cidr_block = "${local.vpcs[0].public-cidr}"
    map_public_ip_on_launch = "true" //it makes this a public subnet
    availability_zone = "${local.vpcs[0].region}a"
    tags = {
        Name = "${local.vpcs[0].name}-subnet-public"
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

resource "aws_route_table" "tcb-gateway-rt" {
    vpc_id = "${aws_vpc.vpc[0].id}"
    
    route {
        //associated subnet can reach everywhere
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.tcb-igw.id}"
    }
    
    tags = {
        Name = "tcb-${local.vpcs[0].name}-rt"
        Owner = "john.miller@solo.io"
    }
}

# NAT Gateway
resource "aws_eip" "ip" {
  vpc = true
  tags = {
    Name = "nat-elastic-ip"
  }
}

resource "aws_nat_gateway" "nat-gateway" {
  allocation_id = "${aws_eip.ip.id}"
  subnet_id     = "${aws_subnet.subnet-public.id}"
  tags = {
    Name = "nat-gateway"
  }
}

resource "aws_route_table" "nat-route-table" {
  vpc_id = "${aws_vpc.vpc[0].id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_nat_gateway.nat-gateway.id}"
  }

  tags = {
    Name = "nat-route-table"
  }
}

resource "aws_route_table_association" "nat-association" {
  subnet_id      = "${aws_subnet.subnet-private[0].id}"
  route_table_id = "${aws_route_table.nat-route-table.id}"
}

resource "aws_route_table" "tcb-web-rt" {

    vpc_id = "${aws_vpc.vpc[1].id}"
    
    #  route {
    #     //associated subnet can reach everywhere
    #     cidr_block = "${local.vpcs[count.index].cidr}" 
    #     transit_gateway_id = "${aws_ec2_transit_gateway.tcb-tgw.id}"
    # }
    
    tags = {
        Name = "tcb-${local.vpcs[1].name}-rt"
        Owner = "john.miller@solo.io"
    }
}

resource "aws_route_table" "tcb-lob-rt" {

    vpc_id = "${aws_vpc.vpc[2].id}"
    
    #  route {
    #     //associated subnet can reach everywhere
    #     cidr_block = "${local.vpcs[count.index].cidr}" 
    #     transit_gateway_id = "${aws_ec2_transit_gateway.tcb-tgw.id}"
    # }
    
    tags = {
        Name = "tcb-${local.vpcs[2].name}-rt"
        Owner = "john.miller@solo.io"
    }
}

# resource "aws_route_table" "tcb-rt" {
#     count = length(local.vpcs)
#     vpc_id = "${aws_vpc.vpc[count.index].id}"
    
#     #  route {
#     #     //associated subnet can reach everywhere
#     #     cidr_block = "${local.vpcs[count.index].cidr}" 
#     #     transit_gateway_id = "${aws_ec2_transit_gateway.tcb-tgw.id}"
#     # }
    
#     tags = {
#         Name = "tcb-${local.vpcs[count.index].name}-rt"
#         Owner = "john.miller@solo.io"
#     }

#     # depends_on = [aws_ec2_transit_gateway.tcb-tgw]
# }

resource "aws_route_table_association" "tcb-public-subnet"{
    # count = length(local.vpcs)
    subnet_id = "${aws_subnet.subnet-public.id}"
    route_table_id = "${aws_route_table.tcb-gateway-rt.id}"
}

# resource "aws_route_table_association" "tcb-lob-subnet"{
#     count = length(local.vpcs)
#     subnet_id = "${aws_subnet.subnet-private[count.index].id}"
#     route_table_id = "${aws_route_table.tcb-rt[count.index].id}"
# }

resource "aws_route_table_association" "tcb-web-subnet"{
    # count = length(local.vpcs)
    subnet_id = "${aws_subnet.subnet-private[1].id}"
    route_table_id = "${aws_route_table.tcb-web-rt.id}"
}

resource "aws_route_table_association" "tcb-lob-subnet"{
    # count = length(local.vpcs)
    subnet_id = "${aws_subnet.subnet-private[2].id}"
    route_table_id = "${aws_route_table.tcb-lob-rt.id}"
}

# resource "aws_route" "default_route_public_subnet" {
#     # count = length(local.vpcs)
#     route_table_id = aws_route_table.tcb-gateway-rt.id
#     destination_cidr_block = "0.0.0.0/0"
#     gateway_id = aws_internet_gateway.tcb-igw.id
#     depends_on = [ aws_ec2_transit_gateway.tcb-tgw ]
# }

resource "aws_route" "default_route_private_subnet0" {
    # count = length(local.vpcs)
    route_table_id = aws_route_table.tcb-web-rt.id
    destination_cidr_block = "0.0.0.0/0"
    transit_gateway_id = aws_ec2_transit_gateway.tcb-tgw.id
    depends_on = [ aws_ec2_transit_gateway.tcb-tgw ]
}

resource "aws_route" "default_route_private_subnet1" {
    # count = length(local.vpcs)
    route_table_id = aws_route_table.tcb-lob-rt.id
    destination_cidr_block = "0.0.0.0/0"
    transit_gateway_id = aws_ec2_transit_gateway.tcb-tgw.id
    depends_on = [ aws_ec2_transit_gateway.tcb-tgw ]
}

resource "aws_route" "tgw-route0" {
    route_table_id = aws_route_table.tcb-gateway-rt.id
    destination_cidr_block = "10.2.0.0/16"
    transit_gateway_id = aws_ec2_transit_gateway.tcb-tgw.id
}

resource "aws_route" "tgw-route1" {
    route_table_id = aws_route_table.tcb-gateway-rt.id
    destination_cidr_block = "10.3.0.0/16"
    transit_gateway_id = aws_ec2_transit_gateway.tcb-tgw.id
}

resource "aws_route" "tgw-route2" {
    route_table_id = aws_route_table.tcb-web-rt.id
    destination_cidr_block = "10.1.0.0/16"
    transit_gateway_id = aws_ec2_transit_gateway.tcb-tgw.id
}

resource "aws_route" "tgw-route3" {
    route_table_id = aws_route_table.tcb-web-rt.id
    destination_cidr_block = "10.3.0.0/16"
    transit_gateway_id = aws_ec2_transit_gateway.tcb-tgw.id
}

resource "aws_route" "tgw-route4" {
    route_table_id = aws_route_table.tcb-lob-rt.id
    destination_cidr_block = "10.1.0.0/16"
    transit_gateway_id = aws_ec2_transit_gateway.tcb-tgw.id
}

resource "aws_route" "tgw-route5" {
    route_table_id = aws_route_table.tcb-lob-rt.id
    destination_cidr_block = "10.2.0.0/16"
    transit_gateway_id = aws_ec2_transit_gateway.tcb-tgw.id
}

resource "aws_security_group" "ssh-allowed" {
    count = length(local.vpcs)
    vpc_id = "${aws_vpc.vpc[count.index].id}"
    
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
        // Do not do it in the tcb-gateway. 
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
        Name = "ssh-allowed-${local.vpcs[count.index].name}"
    }
}

resource "aws_ec2_transit_gateway" "tcb-tgw" {
    auto_accept_shared_attachments = "enable"
    default_route_table_association = "enable"
    default_route_table_propagation = "enable"
    dns_support = "enable"
    vpn_ecmp_support = "enable"

    amazon_side_asn = 65534
    tags = {
        Name = "tcb-tgw"
        Owner  = "john.miller@solo.io"
    }
}

resource "aws_ec2_transit_gateway_route_table" "association_default_route_table" {
  transit_gateway_id = "${aws_ec2_transit_gateway.tcb-tgw.id}"
}

resource "aws_ec2_transit_gateway_vpc_attachment" "tcb-tgw-att-vpc" {
    count = length(local.vpcs)
    
    subnet_ids = ["${aws_subnet.subnet-private[count.index].id}"]
    transit_gateway_id = "${aws_ec2_transit_gateway.tcb-tgw.id}"
    vpc_id = "${aws_vpc.vpc[count.index].id}"
    tags = {
        Name = "tgw-att-${local.vpcs[count.index].name}vpc"
    }
}

# TGW Route Table
resource "aws_ec2_transit_gateway_route" "tgw_default_route" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = "${aws_ec2_transit_gateway_vpc_attachment.tcb-tgw-att-vpc[0].id}"
  # transit_gateway_route_table_id = "${aws_ec2_transit_gateway_route_table.association_default_route_table.id}"
  transit_gateway_route_table_id = "${aws_ec2_transit_gateway.tcb-tgw.association_default_route_table_id}"
}

# resource "aws_ec2_transit_gateway_route" "default" {
#     transit_gateway_route_table_id = "${aws_ec2_transit_gateway_route_table.tcb-grt.id}"
#     destination_cidr_block = "0.0.0.0/0"
#     transit_gateway_attachment_id = "${aws_ec2_transit_gateway_vpc_attachment.tcb-tgw-att-vpc[0].id}"
# }

# resource "aws_ec2_transit_gateway_route_table" "tcb-tgw-rt" {
#     count = length(local.vpcs)
#     transit_gateway_id = "${aws_ec2_transit_gateway.tcb-tgw.id}"
#     tags = {
#         Name = "tcb-tgw-${local.vpcs[count.index].name}-rt"
#     }
#     depends_on = [aws_ec2_transit_gateway.tcb-tgw]
# }

# resource "aws_main_route_table_association" "tcb-rta" {
#    count = length(local.vpcs)
#    vpc_id = "${aws_vpc.vpc[count.index].id}"
#    route_table_id = "${aws_route_table.tcb-public-rt[count].id}"
# }

# resource "aws_key_pair" "tcb-keypair" {
#   key_name   = "tcb-keypair"
#   public_key = "" # put your public key here
# }

resource "aws_instance" "ec2_instance-mgmt" {
  #count = length(local.vpcs)
  # https://aws.amazon.com/marketplace/server/configuration?productId=d9a3032a-921c-4c6d-b150-bde168105e42&ref_=psb_cfg_continue
  # Centos7 - us-east-1 
  ami = "ami-002070d43b0a4f171"
  # Centos7 - us-east-2
  # ami = "ami-05a36e1502605b4aa"
  instance_type  = "t3.medium"
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.ssh-allowed[0].id]
  subnet_id = "${aws_subnet.subnet-public.id}"
  key_name = "tcb-keypair"

  tags = {
    Name = "${local.vpcs[0].name}-instance"
  }

}

resource "aws_instance" "ec2_instance-web" {
  # https://aws.amazon.com/marketplace/server/configuration?productId=d9a3032a-921c-4c6d-b150-bde168105e42&ref_=psb_cfg_continue
  # Centos7 - us-east-1 
  ami = "ami-002070d43b0a4f171"
  # Centos7 - us-east-2
  # ami = "ami-05a36e1502605b4aa"
  instance_type  = "t3.medium"
  associate_public_ip_address = false
  vpc_security_group_ids = [aws_security_group.ssh-allowed[1].id]
  subnet_id = "${aws_subnet.subnet-private[1].id}"
  key_name = "tcb-keypair"

  tags = {
    Name = "${local.vpcs[1].name}-instance"
  }

}


resource "aws_instance" "ec2_instance-lob" {
  # https://aws.amazon.com/marketplace/server/configuration?productId=d9a3032a-921c-4c6d-b150-bde168105e42&ref_=psb_cfg_continue
  # Centos7 - us-east-1 
  ami = "ami-002070d43b0a4f171"
  # Centos7 - us-east-2
  # ami = "ami-05a36e1502605b4aa"
  instance_type  = "t3.medium"
  associate_public_ip_address = false
  vpc_security_group_ids = [aws_security_group.ssh-allowed[2].id]
  subnet_id = "${aws_subnet.subnet-private[2].id}"
  key_name = "tcb-keypair"

  tags = {
    Name = "${local.vpcs[2].name}-instance"
  }
}

output "ec2_ip_mgmt" {
    value = ["ssh -J centos@${aws_instance.ec2_instance-mgmt.public_ip} centos@${aws_instance.ec2_instance-mgmt.private_ip}"]
}

output "ec2_ip_web" {
    value = ["ssh -J centos@${aws_instance.ec2_instance-mgmt.public_ip} centos@${aws_instance.ec2_instance-web.private_ip}"]
}

output "ec2_ip_lob" {
    value = ["ssh -J centos@${aws_instance.ec2_instance-mgmt.public_ip} centos@${aws_instance.ec2_instance-lob.private_ip}"]
}