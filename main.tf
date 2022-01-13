 # Accessing the provider
  2 provider "aws" {
  3         access_key = "AKIA2YDW43DQ4QZNR"
  4         secret_key = "j1DQfOr/mJ16OV9"
  5         region = "us-west-2"
  6 }
  7 resource "aws_vpc" "my_vpc" {
  8         cidr_block = "10.0.0.0/16"
  9         enable_dns_hostnames = true
 10         tags = {
 11             Name = "My VPC"
 12  }
 13 }
 14 resource "aws_subnet" "public_ap_northeast_2a" {
 15         vpc_id = aws_vpc.my_vpc.id
 16         cidr_block = "10.0.0.0/24"
 17         availability_zone = "us-west-2a"
 18         tags = {
 19           Name = "Public Subnet-2a"
 20  }
 21
 22 }
 23 resource "aws_subnet" "public_ap_north_east_2b"{
 24         vpc_id = aws_vpc.my_vpc.id
 25         cidr_block = "10.0.1.0/24"
 26         availability_zone = "us-west-2b"
 27         tags = {
 28           Name = "public-2b"
 29  }
 30 }
 31 resource "aws_internet_gateway" "my_vpc_igw" {
 32         vpc_id = aws_vpc.my_vpc.id
 33         tags = {
 34           Name = "my vpc igw"
 35  }
 36
 37 }
 38 resource "aws_route_table" "my_vpc_public" {
 39         vpc_id = aws_vpc.my_vpc.id
 40         route {
 41           cidr_block = "0.0.0.0/0"
 42           gateway_id = aws_internet_gateway.my_vpc_igw.id
 43  }
 44         tags = {
 45           Name = "Public Subnets route table"
 46  }
 47 }
resource "aws_route_table_association" "my_vpc_us_east_2a_public" {
 49         subnet_id = aws_subnet.public_ap_northeast_2a.id
 50         route_table_id = aws_route_table.my_vpc_public.id
 51 }
 52 resource "aws_route_table_association" "my_vpc_us_east_2b_public" {
 53         subnet_id = aws_subnet.public_ap_north_east_2b.id
 54         route_table_id = aws_route_table.my_vpc_public.id
 55 }
 56 resource "aws_security_group" "allow_http" {
 57         name = "allow_http"
 58         description = "Allow HTTP inbound connections"
 59         vpc_id = aws_vpc.my_vpc.id
 60
 61         ingress {
 62          from_port = 80
 63          to_port = 80
 64          protocol = "tcp"
 65          cidr_blocks = ["0.0.0.0/0"]
 66
 67         }
 68         egress {
 69          from_port = 0
 70          to_port = 0
 71          protocol = "-1"
 72          cidr_blocks = ["0.0.0.0/0"]
 73         }
 74         tags = {
 75           Name = "Allow HTTPS Security Group"
 76         }
 77 }
 78 resource "aws_launch_configuration" "elb_http" {
 79         name_prefix = "web-"
 80         image_id = "ami-0edff9d98e3716556"
 81         instance_type = "t2.micro"
 82         security_groups = [ aws_security_group.allow_http.id ]
 83         associate_public_ip_address = true
 84         lifecycle {
 85          create_before_destroy = true
 86         }
 87 }
 88 resource "aws_security_group" "elb_http" {
 89         name = "elb_http"
 90         description = "Allow HTTP traffic to instance through Elstic load balancer"
 91         vpc_id = aws_vpc.my_vpc.id
 92
 93         ingress {
 from_port = 80
 95          to_port = 80
 96          protocol = "tcp"
 97          cidr_blocks = ["0.0.0.0/0"]
 98         }
 99         egress {
100          from_port = 0
101          to_port = 0
102          protocol = "-1"
103          cidr_blocks = ["0.0.0.0/0"]
104         }
105         tags = {
106          Name = "Allow HTTP thorgh ELB Security Group"
107         }
108 }
109 resource "aws_elb" "web_elb" {
110         name = "web-elb"
111         security_groups = [
112           aws_security_group.elb_http.id
113         ]
114         subnets = [
115           aws_subnet.public_ap_northeast_2a.id,
116           aws_subnet.public_ap_north_east_2b.id
117         ]
118
119         cross_zone_load_balancing = true
120
121         health_check {
122          healthy_threshold = 2
123          unhealthy_threshold = 2
124          timeout = 3
125          interval = 30
126          target = "HTTP:80/"
127         }
128         listener {
129          lb_port = 80
130          lb_protocol = "http"
131          instance_port = "80"
132          instance_protocol = "http"
133         }
134 }
135 resource "aws_autoscaling_group" "web" {
136         name = "aws_public-asg"
137
138         min_size = 3
139         desired_capacity = 5
140         max_size = 8

142         health_check_type = "ELB"
143         load_balancers = [
144          aws_elb.web_elb.id
145         ]
146         launch_configuration = aws_launch_configuration.elb_http.name
147
148         enabled_metrics = [
149          "GroupMinSize",
150          "GroupMaxSize",
151          "GroupDesiredCapacity",
152          "GroupInServiceInstances",
153          "GroupTotalInstances"
154         ]
155         metrics_granularity = "1Minute"
156
157         vpc_zone_identifier = [
158           aws_subnet.public_ap_northeast_2a.id,
159           aws_subnet.public_ap_north_east_2b.id
160         ]
161
162         lifecycle {
163          create_before_destroy = true
164         }
165       }
