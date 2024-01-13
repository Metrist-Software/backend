# Using AWS SSO with the backend

The simplest way to run the backend using your duo based AWS access is to utilize the aws cli sso capabilities.
Below we will discuss how to set this up with some examples and a few gotchas that were encountered along the way.

## The AWS cli
This technique requires the AWS CLI to be [installed](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

## The AWS cli profile config

You will require some profile entries in your `~/.aws/config` for this to function.

You can copy the following entries as a starting point.

`[default]` will be used by the CLI when no profile is selected and `AWS_PROFILE` is not set

`exaws` is not smart enough at the moment to use `[default]` if no `AWS_PROFILE` is set but
it will use a profile named `default` in that case

```
[default]
sso_start_url = https://metrist-software.awsapps.com/start
sso_region = us-west-2
sso_account_id = 123456789
sso_role_name = AdministratorAccess
region = us-east-1

# exaws in elixir desn't use [default] if no AWS_PROFILE environment variable is set.
# It will however use an explicit profile with the name default so....
[profile default]
sso_start_url = https://metrist-software.awsapps.com/start
sso_region = us-west-2
sso_account_id = 123456789
sso_role_name = AdministratorAccess
region = us-east-1

[profile metrist-sandbox]
sso_start_url = https://metrist-software.awsapps.com/start
sso_region = us-west-2
sso_account_id = 046400679278
sso_role_name = AdministratorAccess
region = us-east-1

[profile metrist-monitoring]
sso_start_url = https://metrist-software.awsapps.com/start
sso_region = us-west-2
sso_account_id = 907343345003
sso_role_name = AdministratorAccess
region = us-east-1
```
## Launching backend with AWS SSO

To launch the backend with AWS SSO perform the following steps

1. Run `aws sso login`
2. Follow the prompts on the screen to authenticate and authorize the application after which you will be presented with `Successfully logged into Start URL: https://metrist-software.awsapps.com/start`
3. Launch the backend

## Troubleshooting

* **Running in WSL**

   If you're running through WSL, the `aws sso login` command will hang after you successfully authorize the application.
   Setting the BROWSER env var to `/usr/bin/true` and unsetting the `DISPLAY` var will allow it to complete. ex. `BROWSER=/usr/bin/true DISPLAY= aws sso login`
