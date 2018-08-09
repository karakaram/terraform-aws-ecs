# terraform-aws-vpc

This repository contains the terraform scripts to create an ECS.

### Installing

Install AWS Command Line Interface. See the installing guide [Installing the AWS Command Line Interface \- AWS Command Line Interface](https://docs.aws.amazon.com/cli/latest/userguide/installing.html)

Install tfenv

```
brew install tfenv
```

Install Terraform

```
tfenv install
```

## Getting Started

Initializing

```
make init
```

Running the tests

```
make plan [env=production]
```

Deployment

```
make apply [env=production]
```
