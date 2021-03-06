awsome
======

An Amazon Web Services (AWS) environment manager tool designed to automate EC2 instance reconfigurations, scaling, and software deployments. Just change your YAML requirements file and let awsome do all the planning and heavy lifting.

One drawback is that in order to leverage software deployment features, all software must be packaged in Debian archives and all instances must run dpkg-enabled operating systems such as Ubuntu. For help with packaging your software in Debian archives, see ```https://github.com/0x0539/debstep.git```. I use reprepro to manage Debian repositories in an automated fashion and would recommend it to a friend.

Prerequisites
=============

Install the gem.  It comes with a binary, so you may need to sudo.

```
gem install awsome
```

Next, download the EC2 api tools and the ELB api tools.

Getting Started
===============

awsome takes a YAML file that describes your EC2 requirements as input:

```
options:
  except_instance_ids:           # instances to be ignored by the planner
  - i-11111111
  - i-22222222
  volumes:                       # any volumes you plan to attach/detach go here
  - id: vol-11111111
    device: /dev/sdf             # desired device name
    dir: /var/lib/mongodb        # mount point
    preumount: sudo stop mongodb # command to execute before unmounting/detaching
filters:
  - "tag:environment": prod      # only get instances tagged with 'production'
traits:
  base_trait:
    availability_zone: us-southwest-4a
    ami_id: ami-11111111
    key: xyz
    security_group_ids: default
    tags:
      environment: prod
instances:
- packages:                      # debian packages to deploy (latest version)
    - debian-package-1           
    - debian-package-2
  traits:                        # inherit properties from these traits
    - base_trait
  instance_type: m1.small
  elbs: 
    - elb-1
    - elb-2
  volumes:
    - vol-11111111
  cnames:                        # cnames to assign to this instance's private IP
    - zone: somezone.com.
      private:                   # these will use the internal ip-A-B-C-D DNS
      - mongodb.somezone.com.
      - internal.somezone.com.
      public:                    # these will use the external ec2-A-B-C-D DNS
      - external.somezone.com.
```

You need to declare some environment variables before you run the tool. A shell script that exports those variables will suffice:

```
export AWS_ACCESS_KEY="..."
export AWS_SECRET_KEY="..."
export AWS_CREDENTIAL_FILE="/path/to/credentials"
export AWS_ELB_HOME="/path/to/elb-cli-dir"
export EC2_HOME="/path/to/ec2-cli-dir"
export JAVA_HOME="/path/to/java/home"
export PATH="$PATH:$EC2_HOME/bin"
export PATH="$PATH:$AWS_ELB_HOME/bin"
export REGION="us-north-7"
export EC2_URL="https://ec2.$REGION.amazonaws.com"
export SSH_KEY="$HOME/.ssh/xyz.pem"
export SSH_USER="root"
```

Note: When invoking a script like this, make sure you use ```. path/to/script.sh``` or ```source path/to/script.sh``` instead of ```/bin/sh path/to/script.sh```. Otherwise the environment variables will be defined in a subshell; they won't be there when the script ends.

The credentials file at AWS_CREDENTIAL_FILE is something you need to create for the ELB tools. It has the following format:

```
AWSAccessKeyId=...
AWSSecretKey=...
```

Running It
==========

Once your environment variables have been defined and your requirements file is ready, you are ready to run awsome. It's usage is:

```
Usage: awsome [options]
    -r, --requirements [FILE]        Use a requirements file from another location (default is ./requirements.yml)
    -v, --verbose                    Print commands as they are executed
    -d, --debug                      Run ec2 commands with --debug
    -s, --stacks                     Print out full stack traces when commands are executed
```

You can run ```awsome --help``` to see usage and options from the command line.

In the grand scheme of things, awsome should probably be run by Jenkins or some other CI server. This can be easily accomplished by checking your requirements file into version control and running awsome on a post-commit hook. 

Planning Algorithm
==================

awsome attempts to plan the least-destructive upgrade to your EC2 environment possible. You can find the matching logic in ```lib/awsome/matchmaker.rb```. Crudely speaking, it is performed in two basic steps.

```
1. Group instances and requirements by pool
2. For each pool, find the optimal mapping of running instances to requirements
```

Instances and requirements are assigned to the same pool if their compound keys match. The compound key of an instance or requirement is defined as:

``(ami_id, key, instance_type, availability_zone, security_group_ids)```

Those fields were chosen for the compound key because they are the only fields that cannot be changed once an instance has started (afaik).

The second component of the algorithm involves finding the optimal mapping of running instances to requirements. The only possible mapping of instances ```i1, i2``` to requirements ```r1, r2``` are:

```
1. {i1 => r1, i2 => r2}
2. {i1 => r2, i2 => r1}
```

All mappings are considered. I consider volume attachments/detachments to be more destructive than package removals/installations. awsome first chooses the mapping that minimizes volume attachments/detachments. In the event of a tie, awsome chooses the one that minimizes the number of package removals/installations.
