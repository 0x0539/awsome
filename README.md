awsome
======

is an EC2 environment manager tool. It is designed to completely automate scaling, reconfigurations, and software deployments in your EC2 environment. Just change your YAML requirements file and let awsome do all the planning and heavy lifting.

One drawback is that, in order to leverage software deployment features, all software must be packaged in Debian archives and all instances must run Debian operating systems. For help with packaging your software in Debian archives, see ```https://github.com/0x0539/debstep.git```

Prerequisites
=============

Install the gem:

```
gem install awsome
```

It comes with a binary, so you may need to sudo.

Next, download the EC2 api tools and the ELB api tools.

Getting Started
===============

awsome takes a YAML file that describes your EC2 requirements as input. The following example is similar to what is used on foodocs.com:

```
options:
  except_instance_ids:           # instances to be ignored by the planner
  - i-11111111
  - i-22222222
  volumes:                       # register any volumes you plan to attach/detach here
  - id: vol-11111111
    device: /dev/sdf             # desired device name
    dir: /var/lib/mongodb        # mount point
    preumount: sudo stop mongodb # command to execute before unmounting/detaching
instances:
- packages:                      # names of debian packages to deploy (latest version)
    - debian-package-1           
    - debian-package-2
  availability_zone: us-southwest-4a
  ami_id: ami-11111111
  instance_type: m1.small
  security_group_ids: default
  key: xyz                       # if your private key is xyz.pem
  elbs: 
    - elb-1
    - elb-2
  volumes:
    - vol-11111111
  cnames:                        # specify cnames to bind to this instance
    - zone: somezone.com.
      names:
      - mongodb.somezone.com.
      - internal.somezone.com.
```

You also need to declare some environment variables before you run the tool. I accomplished this with a shell script that exports those variables:

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

All mappings are considered. I consider volume attachments/detachments to be more destructive than package removals/installations. awsome first chooses the mapping that minimizes volume attachments/detachments. And, in the event of a tie, awsome chooses the one that minimizes the number of package removals/installations.
