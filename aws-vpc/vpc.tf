provider "aws" {
  region     = "ap-south-1"
  access_key = ""
  secret_key = ""
}

resource "aws_vpc" "eksvpc" {
cidr_block = "11.0.0.0/16"
instance_tenancy = "default"
enable_dns_hostnames= true


tags = {
 Name = "Cloud-VPC"
   }
}

variable "public" {
  type = map(object({
    name = string
    cidr_block = string
    availability_zone = string 
  }))
   default = {
     "public-subnet-1" = {
        cidr_block = "11.0.1.0/24"
        availability_zone = "ap-south-1a"
        name = "Public-Subnet-1"
     }
      "public-subnet-2" = {
        cidr_block= "11.0.2.0/24"
        availability_zone = "ap-south-1b"
        name =  "Public-Subnet-2"
      } 
   }
  
}


variable "private" {
  type = map(object({
    name = string
    cidr_block = string
    availability_zone = string 
  }))
   default = {
      "private-subnet" = {
        cidr_block= "11.0.3.0/24"
        availability_zone = "ap-south-1a"
        name =  "Private-Subnet-1"
      }
   }
  
}

#Subnet Creation 
resource "aws_subnet" "privatesubnet" {
  for_each = var.private
  vpc_id = aws_vpc.eksvpc.id
  cidr_block = each.value.cidr_block
  availability_zone = each.value.availability_zone

  tags = {
    Name = each.value.name
    Type = "Private"
  }
}

resource "aws_subnet" "publicsubnet" {
  for_each = var.public
  vpc_id = aws_vpc.eksvpc.id
  cidr_block = each.value.cidr_block
  availability_zone = each.value.availability_zone

  tags = {
    Name = each.value.name
    Type = "Public"
  }
}
 
resource "aws_eip" "nat_eip" {
count = 1
domain = "vpc"
}
resource "aws_nat_gateway" "nat_gateway" {
count = 1
depends_on = [aws_eip.nat_eip]
allocation_id = aws_eip.nat_eip[0].id
subnet_id = values(aws_subnet.publicsubnet)[0].id
tags = {
  Name = "Private NAT GW"
}
}

resource "aws_internet_gateway" "iwg" {
vpc_id = aws_vpc.eksvpc.id
}

resource "aws_route_table" "public_route" {
vpc_id = aws_vpc.eksvpc.id
route {
cidr_block = "0.0.0.0/0"
gateway_id = aws_internet_gateway.iwg.id
}

tags = {
 Name = "Public Route Table"

}
}

resource "aws_route_table" "private_route" {
count = length(keys(aws_subnet.privatesubnet))
vpc_id = aws_vpc.eksvpc.id
depends_on = [aws_nat_gateway.nat_gateway]
route {
cidr_block = "0.0.0.0/0"
nat_gateway_id = aws_nat_gateway.nat_gateway[count.index].id
}
tags = {
Name = "private-route-${count.index + 1}"
}
}


resource "aws_route_table_association" "public_sub_ass" {
count = length(keys(aws_subnet.publicsubnet))
subnet_id = values(aws_subnet.publicsubnet)[count.index].id
route_table_id = aws_route_table.public_route.id 

}

resource "aws_route_table_association" "private_sub_ass" {
count = length(keys(aws_subnet.privatesubnet))
subnet_id = values(aws_subnet.privatesubnet)[count.index].id
route_table_id = aws_route_table.private_route[count.index].id
}
