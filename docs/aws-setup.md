# AWS Setup

Mavis is deployed to AWS using Terraform. Developer need access to the running
services on AWS to diagnose and debug issues. This document describes how to set
up AWS access for developers.

## AWS CLI

- First install the AWS command-line interface (CLI) to interact with
  AWS services. You can find installation instructions in the [AWS CLI User
  Guide](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html).

## AWS Account

- You will need an AWS account and be given access to the appropriate groups. Contact one of the group admins to have yourself added to the groups.

## AWS CLI configuration

- Create a `~/.aws/config` file if you don't already have one and ask a Mavis developer for the details to enter into the `default` and `sso-session mavis` sections. It should look something like this:

```
[default]
sso_session = mavis
sso_account_id = xxxxxxxxxxxx
sso_role_name = Admin
region = eu-west-2

[sso-session mavis]
sso_start_url = https://xxxxxxxxxxxx.awsapps.com/start#
sso_region = eu-west-2
sso_registration_scopes = sso:account:access
```

- Check that you can log into AWS Console via the `sso_start_url` URL under `sso-session mavis` in the config file. You will need the access keys available in the AWS console to authenticate via the AWS CLI for the following steps.
- Run `aws configure sso`. This will prompt you to log in to your AWS account and grant the necessary permissions for the CLI to access AWS services. When prompted for a region enter `eu-west-2` and for output format enter `json`.
- Install the Session Manager plugin for the AWS CLI by following the instructions in the [AWS Systems Manager Session Manager documentation](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html).
- Run `aws sso login` to log in to your AWS account and establish a session. This will allow you to access AWS resources using the CLI.
- You should now be able to shell into a running service. The simplest way to do this is using the `bin/mavis-server shell` command, e.g. `bin/mavis-server shell qa`.
