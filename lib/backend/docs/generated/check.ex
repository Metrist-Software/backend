defmodule Backend.Docs.Generated.Checks do
  def name("awscloudfront", "PublishFile") do
    "Publish File"
  end

  def name("awscloudfront", "GetNewFile") do
    "Get New File"
  end

  def name("awscloudfront", "UpdateFile") do
    "Update File"
  end

  def name("awscloudfront", "PurgeFile") do
    "Purge File"
  end

  def name("awscloudfront", "GetUpdatedFile") do
    "Get Updated File"
  end

  def name("awscloudfront", "DeleteFile") do
    "Delete File"
  end

  def name("awscloudfront", "WaitForDeletionPropagation") do
    "WaitForDeletionPropagation"
  end

  def name("slack", "PostMessage") do
    "Post Message"
  end

  def name("slack", "ReadMessage") do
    "Read Message"
  end

  def name("gcpcomputeengine", "CreateInstance") do
    "Create Instance"
  end

  def name("gcpcomputeengine", "GetInstanceInfo") do
    "Get Instance Info"
  end

  def name("gcpcomputeengine", "DeleteInstance") do
    "Delete Instance"
  end

  def name("sendgrid", "SendEmail") do
    "Send Email"
  end

  def name("azureaks", "QueryExistingDNSRecord") do
    "Query Existing DNS Record"
  end

  def name("azureaks", "CreateCluster") do
    "Create Cluster"
  end

  def name("azureaks", "CreateDeployment") do
    "Create Deployment"
  end

  def name("azureaks", "RemoveDeployment") do
    "Remove Deployment"
  end

  def name("awseks", "CreateDeployment") do
    "Create Deployment"
  end

  def name("awseks", "RemoveDeployment") do
    "Remove Deployment"
  end

  def name("npm", "Ping") do
    "Ping"
  end

  def name("npm", "DownloadPackage") do
    "Download Package"
  end

  def name("googledrive", "CreateDocsFile") do
    "Create Docs File"
  end

  def name("googledrive", "GetDocsFile") do
    "Get Docs File"
  end

  def name("googledrive", "DeleteDocsFile") do
    "Delete Docs File"
  end

  def name("avalara", "Ping") do
    "Ping"
  end

  def name("github", "PullCode") do
    "Pull Code"
  end

  def name("github", "PushCode") do
    "Push Code"
  end

  def name("github", "RemoveRemoteBranch") do
    "Remove Remote Branch"
  end

  def name("github", "PullRequests") do
    "Pull Requests"
  end

  def name("github", "Issues") do
    "Issues"
  end

  def name("github", "Raw") do
    "Raw"
  end

  def name("gcpappengine", "AutoScaleUp") do
    "Auto Scale Up"
  end

  def name("gcpappengine", "PingApp") do
    "Ping App"
  end

  def name("gcpappengine", "CreateVersion") do
    "Create Version"
  end

  def name("gcpappengine", "MigrateTraffic") do
    "Migrate Traffic"
  end

  def name("gcpappengine", "AutoScaleDown") do
    "Auto Scale Down"
  end

  def name("gcpappengine", "DestroyVersion") do
    "Destroy Version"
  end

  def name("envoy", "GetEmployees") do
    "GetEmployees"
  end

  def name("envoy", "GetReservations") do
    "GetReservations"
  end

  def name("testsignal", "Zero") do
    "Zero"
  end

  def name("testsignal", "Normal") do
    "Normal"
  end

  def name("testsignal", "Poisson") do
    "Poisson"
  end

  def name("trello", "CreateCard") do
    "Create Card"
  end

  def name("trello", "DeleteCard") do
    "Delete Card"
  end

  def name("azuredevops", "CloneRepo") do
    "Clone Repo"
  end

  def name("azuredevops", "PushCode") do
    "Push Code"
  end

  def name("azuredevops", "RemoveRemoteBranch") do
    "Remove Remote Branch"
  end

  def name("awselb", "ChangeTargetGroup") do
    "Change Target Group"
  end

  def name("gke", "CreateDeployment") do
    "Create Deployment"
  end

  def name("gke", "RemoveDeployment") do
    "Remove Deployment"
  end

  def name("jira", "CreateIssue") do
    "Create Issue"
  end

  def name("jira", "DeleteIssue") do
    "Delete Issue"
  end

  def name("sentry", "CaptureEvent") do
    "Capture Event"
  end

  def name("sentry", "WaitForIssue") do
    "Wait For Issue"
  end

  def name("sentry", "ResolveIssue") do
    "Resolve Issue"
  end

  def name("sentry", "DeleteIssue") do
    "Delete Issue"
  end

  def name("pagerduty", "CreateIncident") do
    "Create Incident"
  end

  def name("pagerduty", "CheckForIncident") do
    "Check For Incident"
  end

  def name("pagerduty", "ReceiveWebhook") do
    "Receive Webhook"
  end

  def name("pagerduty", "ResolveIncident") do
    "Resolve Incident"
  end

  def name("okta", "GetToken") do
    "GetToken"
  end

  def name("hubspot", "GetContacts") do
    "Get Contacts"
  end

  def name("azurefncs", "RunHttpTrigger") do
    "RunHttpTrigger"
  end

  def name("awslambda", "TriggerLambdaAndWaitForResponse") do
    "Trigger Lambda And Wait For Response"
  end

  def name("awsiam", "CreateUser") do
    "Create User"
  end

  def name("awsiam", "CreateGroup") do
    "Create Group"
  end

  def name("awsiam", "AddUserToGroup") do
    "Add User To Group"
  end

  def name("awsiam", "RemoveUserFromGroup") do
    "Remove User From Group"
  end

  def name("awsiam", "DeleteGroup") do
    "Delete Group"
  end

  def name("awsiam", "AttachPolicy") do
    "Attach Policy"
  end

  def name("awsiam", "DetachPolicy") do
    "Detach Policy"
  end

  def name("awsiam", "DeleteUser") do
    "Delete User"
  end

  def name("awsrdspersistent", "PingInstance") do
    "Ping Instance"
  end

  def name("gmaps", "GetDirections") do
    "Get Directions"
  end

  def name("gmaps", "GetStaticMapImage") do
    "Get Static Map Image"
  end

  def name("gmaps", "GetGeocodingFromAddress") do
    "Get Geocoding From Address"
  end

  def name("asana", "Ping") do
    "Ping"
  end

  def name("asana", "CreateTask") do
    "Create Task"
  end

  def name("asana", "GetTask") do
    "Get Task"
  end

  def name("asana", "DeleteTask") do
    "Delete Task"
  end

  def name("azuread", "Authenticate") do
    "Authenticate"
  end

  def name("azuread", "WriteUser") do
    "Write User"
  end

  def name("azuread", "ReadUser") do
    "Read User"
  end

  def name("azuread", "DeleteUser") do
    "Delete User"
  end

  def name("azuredevopstestplans", "CreateTestCase") do
    "Create Test Case"
  end

  def name("azuredevopstestplans", "CreateTestPlan") do
    "Create Test Plan"
  end

  def name("azuredevopstestplans", "CreateTestSuite") do
    "Create Test Suite"
  end

  def name("azuredevopstestplans", "AddTestCasesToSuite") do
    "Add Test Cases To Suite"
  end

  def name("azuredevopstestplans", "CreateTestRun") do
    "Create Test Run"
  end

  def name("azuredevopstestplans", "AddResultsToTestRun") do
    "Add Results To Test Run"
  end

  def name("azuredevopstestplans", "GetResults") do
    "Get Results"
  end

  def name("azuredevopstestplans", "DeleteTestRun") do
    "Delete Test Run"
  end

  def name("azuredevopstestplans", "DeleteTestPlan") do
    "Delete Test Plan"
  end

  def name("azuredevopstestplans", "DeleteTestCase") do
    "Delete Test Case"
  end

  def name("azuredevopsboards", "CreateWorkItem") do
    "Create Work Item"
  end

  def name("azuredevopsboards", "GetWorkItem") do
    "Get Work Item"
  end

  def name("azuredevopsboards", "EditWorkItem") do
    "Edit Work Item"
  end

  def name("azuredevopsboards", "DeleteWorkItem") do
    "Delete Work Item"
  end

  def name("awsrds", "CreateInstance") do
    "Create Instance"
  end

  def name("awsrds", "PingInstance") do
    "Ping Instance"
  end

  def name("awsrds", "DestroyInstance") do
    "Destroy Instance"
  end

  def name("azuredevopspipelines", "StartMachineWorkflow") do
    "Start Machine Workflow"
  end

  def name("azuredevopspipelines", "WaitForMachineWorkflowRunToComplete") do
    "Wait For Machine Workflow Run To Complete"
  end

  def name("azuredevopspipelines", "StartDockerWorkflow") do
    "Start Docker Workflow"
  end

  def name("azuredevopspipelines", "WaitForDockerWorkflowRunToComplete") do
    "Wait For Docker Workflow Run To Complete"
  end

  def name("azurevm", "CreateInstance") do
    "Create Instance"
  end

  def name("azurevm", "RunInstance") do
    "Run Instance"
  end

  def name("azurevm", "TerminateInstance") do
    "Terminate Instance"
  end

  def name("azurevm", "DescribePersistentInstance") do
    "Describe Persistent Instance"
  end

  def name("nuget", "ListVersions") do
    "List Versions"
  end

  def name("nuget", "Download") do
    "Download"
  end

  def name("heroku", "AppPing") do
    "App Ping"
  end

  def name("heroku", "ConfigUpdate") do
    "Config Update"
  end

  def name("stripe", "CreateMethod") do
    "Create Method"
  end

  def name("stripe", "CreateIntent") do
    "Create Intent"
  end

  def name("stripe", "ConfirmIntent") do
    "Confirm Intent"
  end

  def name("azuresql", "TrackEvent") do
    "Track Event"
  end

  def name("azuresql", "CreateSqlServer") do
    "Create SQL Server"
  end

  def name("azuresql", "CreateDatabase") do
    "Create Database"
  end

  def name("azuresql", "CreateTable") do
    "Create Table"
  end

  def name("azuresql", "InsertItem") do
    "Insert Item"
  end

  def name("azuresql", "GetItem") do
    "Get Item"
  end

  def name("azuresql", "DeleteItem") do
    "Delete Item"
  end

  def name("azuresql", "DeleteDatabase") do
    "Delete Database"
  end

  def name("azuresql", "DeleteServer") do
    "Delete Server"
  end

  def name("azureblob", "CreateStorageAccount") do
    "Create Storage Account"
  end

  def name("azureblob", "CreateContainer") do
    "Create Container"
  end

  def name("azureblob", "CreateBlob") do
    "Create Blob"
  end

  def name("azureblob", "GetBlob") do
    "Get Blob"
  end

  def name("azureblob", "DeleteBlob") do
    "Delete Blob"
  end

  def name("awsroute53", "QueryExistingDNSRecord") do
    "Query Existing DNS Record"
  end

  def name("awsroute53", "QueryExistingDNSRecordAPI") do
    "Query Existing DNS Record Api"
  end

  def name("awsroute53", "CreateDNSRecord") do
    "Create DNS Record"
  end

  def name("awsroute53", "RemoveDNSRecord") do
    "Remove DNS Record"
  end

  def name("awsecs", "CreateService") do
    "Create Service"
  end

  def name("awsecs", "PingService") do
    "Ping Service"
  end

  def name("awsecs", "DestroyService") do
    "Destroy Service"
  end

  def name("neon", "CreateBranch") do
    "CreateBranch"
  end

  def name("neon", "DeleteBranch") do
    "DeleteBranch"
  end

  def name("azuremonitor", "TrackEvent") do
    "Track Event"
  end

  def name("azuremonitor", "TrackMetricValue") do
    "Track Metric Value"
  end

  def name("azuremonitor", "TrackExc") do
    "Track Exception"
  end

  def name("azuremonitor", "TrackTrace") do
    "Track Trace"
  end

  def name("azuremonitor", "SendLog") do
    "Send Log"
  end

  def name("snowflake", "CreateDatabase") do
    "CreateDatabase"
  end

  def name("snowflake", "CreateTable") do
    "CreateTable"
  end

  def name("snowflake", "PutFile") do
    "PutFile"
  end

  def name("snowflake", "GetData") do
    "GetData"
  end

  def name("snowflake", "DeleteData") do
    "DeleteData"
  end

  def name("snowflake", "DropTable") do
    "DropTable"
  end

  def name("snowflake", "DropDatabase") do
    "DropDatabase"
  end

  def name("datadog", "SubmitEvent") do
    "Submit Event"
  end

  def name("datadog", "GetEvent") do
    "Get Event"
  end

  def name("zendesk", "GetUsers") do
    "Get Users"
  end

  def name("zendesk", "CreateTicket") do
    "Create Ticket"
  end

  def name("zendesk", "SoftDeleteTicket") do
    "Soft Delete Ticket"
  end

  def name("zendesk", "PermanentlyDeleteTicket") do
    "Permanently Delete Ticket"
  end

  def name("azuredb", "CreateCosmosAccount") do
    "Create Cosmos Account"
  end

  def name("azuredb", "CreateDatabase") do
    "Create Database"
  end

  def name("azuredb", "CreateContainer") do
    "Create Container"
  end

  def name("azuredb", "InsertItem") do
    "Insert Item"
  end

  def name("azuredb", "GetItem") do
    "Get Item"
  end

  def name("azuredb", "DeleteItem") do
    "Delete Item"
  end

  def name("azuredb", "DeleteContainer") do
    "Delete Container"
  end

  def name("azuredb", "DeleteDatabase") do
    "Delete Database"
  end

  def name("gcpcloudstorage", "CreateBucket") do
    "Create Bucket"
  end

  def name("gcpcloudstorage", "UploadObject") do
    "Upload Object"
  end

  def name("gcpcloudstorage", "GetObject") do
    "Get Object"
  end

  def name("gcpcloudstorage", "DeleteObject") do
    "Delete Object"
  end

  def name("gcpcloudstorage", "DeleteBucket") do
    "Delete Bucket"
  end

  def name("azureappservice", "PingService") do
    "Ping Service"
  end

  def name("pubnub", "SubscribeToChannel") do
    "Subscribe To Channel"
  end

  def name("pubnub", "SendMessage") do
    "Send Message"
  end

  def name("pubnub", "ReceiveMessage") do
    "Receive Message"
  end

  def name("sqs", "WriteMessage") do
    "Write Message"
  end

  def name("sqs", "ReadMessage") do
    "Read Message"
  end

  def name("circleci", "StartPipeline") do
    "Start Pipeline"
  end

  def name("circleci", "RunMonitorDockerWorkflow") do
    "Run Monitor Docker Workflow"
  end

  def name("circleci", "RunMonitorMachineWorkflow") do
    "Run Monitor Machine Workflow"
  end

  def name("s3", "PutBucket") do
    "Put Bucket"
  end

  def name("s3", "PutObject") do
    "Put Object"
  end

  def name("s3", "GetObject") do
    "Get Object"
  end

  def name("s3", "DeleteObject") do
    "Delete Object"
  end

  def name("s3", "DeleteBucket") do
    "Delete Bucket"
  end

  def name("twiliovid", "CreateRoom") do
    "Create Room"
  end

  def name("twiliovid", "GetRoom") do
    "Get Room"
  end

  def name("twiliovid", "CompleteRoom") do
    "Complete Room"
  end

  def name("twiliovid", "JoinRoom") do
    "Join Room"
  end

  def name("moneris", "TestPurchase") do
    "Test Purchase"
  end

  def name("moneris", "TestRefund") do
    "Test Refund"
  end

  def name("awscloudwatch", "SubmitEvent") do
    "Submit Event"
  end

  def name("awscloudwatch", "GetEvent") do
    "Get Event"
  end

  def name("awssecretsmanager", "CreateSecret") do
    "Create Secret"
  end

  def name("awssecretsmanager", "GetSecretValue") do
    "Get Secret Value"
  end

  def name("awssecretsmanager", "DeleteSecret") do
    "Delete Secret"
  end

  def name("zoom", "GetUsers") do
    "Get Users"
  end

  def name("zoom", "CreateMeeting") do
    "Create Meeting"
  end

  def name("zoom", "GetMeeting") do
    "Get Meeting"
  end

  def name("zoom", "DeleteMeeting") do
    "Delete Meeting"
  end

  def name("zoom", "JoinCall") do
    "Join Call"
  end

  def name("cognito", "CreateUser") do
    "Create User"
  end

  def name("cognito", "DeleteUser") do
    "Delete User"
  end

  def name("ses", "SendEmail") do
    "Send Email"
  end

  def name("gcal", "CreateEvent") do
    "Create Event"
  end

  def name("gcal", "GetEvent") do
    "Get Event"
  end

  def name("gcal", "DeleteEvent") do
    "Delete Event"
  end

  def name("azurecdn", "GetLongCachedFile") do
    "Get Long Cached File"
  end

  def name("azurecdn", "GetNewFile") do
    "Get New File"
  end

  def name("azurecdn", "PurgeFile") do
    "Purge File"
  end

  def name("azurecdn", "UpdateFile") do
    "Update File"
  end

  def name("azurecdn", "DeleteFile") do
    "Delete File"
  end

  def name("ec2", "RunInstance") do
    "Run Instance"
  end

  def name("ec2", "TerminateInstance") do
    "Terminate Instance"
  end

  def name("ec2", "DescribePersistentInstance") do
    "Describe Persistent Instance"
  end

  def name("fastly", "PurgeCache") do
    "Purge Cache"
  end

  def name("fastly", "GetNonCachedFile") do
    "Get Non-Cached File"
  end

  def name("fastly", "GetCachedFile") do
    "Get Cached File"
  end

  def name("authzero", "GetAccessToken") do
    "Get Access Token"
  end

  def name("authzero", "GetBranding") do
    "Get Branding"
  end

  def name("azuredevopsartifacts", "Ping") do
    "Ping"
  end

  def name("azuredevopsartifacts", "DownloadPackage") do
    "Download Package"
  end

  def name("bambora", "TestPurchase") do
    "Test Purchase"
  end

  def name("bambora", "TestRefund") do
    "Test Refund"
  end

  def name("bambora", "TestVoid") do
    "Test Void"
  end

  def name("kinesis", "WriteToStream") do
    "Write To Stream"
  end

  def name("kinesis", "ReadFromStream") do
    "Read From Stream"
  end

  def name("newrelic", "SubmitEvent") do
    "SubmitEvent"
  end

  def name("newrelic", "CheckEvent") do
    "CheckEvent"
  end

  def name("newrelic", "CreateSyntheticMonitor") do
    "Create Synthetic Monitor"
  end

  def name("newrelic", "WaitForSyntheticMonitorResponse") do
    "Wait For Synthetic Monitor Response"
  end

  def name("newrelic", "DeleteSyntheticMonitor") do
    "Delete Synthetic Monitor"
  end

  def name("braintree", "SubmitSandboxTransaction") do
    "Submit Sandbox Transaction"
  end

  def name("cloudflare", "Ping") do
    "Ping"
  end

  def name("cloudflare", "DNSLookup") do
    "DNS Lookup"
  end

  def name("cloudflare", "CDN") do
    "CDN"
  end

  def name("easypost", "GetAddressesTest") do
    "Get Addresses Test"
  end

  def name("easypost", "GetAddressesProd") do
    "Get Addresses Prod"
  end

  def name("easypost", "VerifyInvalidAddress") do
    "Verify Invalid Address"
  end

  def name(_, check_id) do
    check_id
  end

  def description("asana", "Ping") do
    "This step pings Asana's users REST API."
  end

  def description("asana", "CreateTask") do
    "This step creates a task using Asana's REST API."
  end

  def description("asana", "GetTask") do
    "This step retrieves a task using Asana's REST API."
  end

  def description("asana", "DeleteTask") do
    "This step deletes a task using Asana's REST API."
  end

  def description("authzero", "GetAccessToken") do
    "Gets an access token using the API."
  end

  def description("authzero", "GetBranding") do
    "Gets branding information using the API."
  end

  def description("avalara", "Ping") do
    "Calls the ping endpoint on the AvaTax v2 API."
  end

  def description("awscloudfront", "PublishFile") do
    "This step attempts to asynchronously put a file in an S3 bucket."
  end

  def description("awscloudfront", "GetNewFile") do
    "This step attempts to retrieve the file created in the previous step."
  end

  def description("awscloudfront", "UpdateFile") do
    "This step attempts to update the file created in the previous step."
  end

  def description("awscloudfront", "PurgeFile") do
    "This step attempts to purge items from the distribution."
  end

  def description("awscloudfront", "GetUpdatedFile") do
    "This step attempts to retrieve a file updated in a previous step."
  end

  def description("awscloudfront", "DeleteFile") do
    "This step attempts to delete the file created in a previous step."
  end

  def description("awscloudfront", "WaitForDeletionPropagation") do
    "This step attempts to confirm the DeleteFile step was successful."
  end

  def description("awscloudwatch", "SubmitEvent") do
    "This step attempts to submit a metric using PutMetricData API call."
  end

  def description("awscloudwatch", "GetEvent") do
    "Using ListMetricsCommand API call, this step attempts to retrieve a list of metrics matching the event submitted in a previous step."
  end

  def description("awsecs", "CreateService") do
    "This step attempts to create an ECS service."
  end

  def description("awsecs", "PingService") do
    "This step attempts to ping a load balancer by domain name."
  end

  def description("awsecs", "DestroyService") do
    "This step attempts to destroy the service created in an earlier step."
  end

  def description("awseks", "CreateDeployment") do
    "This step attempts to deploy a container into a cluster."
  end

  def description("awseks", "RemoveDeployment") do
    "This step attempts to remove the container deployed in a previous step."
  end

  def description("awselb", "ChangeTargetGroup") do
    "This step attempts to change an ELB target group and measure how long it takes for the change to become effective."
  end

  def description("awsiam", "CreateUser") do
    "This step attempts to create a user, randomly named."
  end

  def description("awsiam", "CreateGroup") do
    "This step attempts to create a group, randomly named."
  end

  def description("awsiam", "AddUserToGroup") do
    "This step attempts to add the newly created user to the newly created group."
  end

  def description("awsiam", "RemoveUserFromGroup") do
    "This step attempts to remove the user from the group."
  end

  def description("awsiam", "DeleteGroup") do
    "This step attempts to delete the group."
  end

  def description("awsiam", "AttachPolicy") do
    "This step attempts to attach the user to the given policy arn."
  end

  def description("awsiam", "DetachPolicy") do
    "This step attempts to detach the user from the given policy arn."
  end

  def description("awsiam", "DeleteUser") do
    "This step attempts to delete the user created in an earlier step."
  end

  def description("awslambda", "TriggerLambdaAndWaitForResponse") do
    "This step attempts to invoke a request and send a payload from a Lambda function to a SQS Queue."
  end

  def description("awsrds", "CreateInstance") do
    "This step attempts to create a MySQL RDS instance."
  end

  def description("awsrds", "PingInstance") do
    "This step attempts to ping the RDS instance created in a previous step."
  end

  def description("awsrds", "DestroyInstance") do
    "This step attempts to destory the RDS instance created in a previous step."
  end

  def description("awsrdspersistent", "PingInstance") do
    "This step attempts to ping your postgres or mysql RDS instance."
  end

  def description("awsroute53", "QueryExistingDNSRecord") do
    "This step attempts to query an existing record on Route53 via DNS Lookup."
  end

  def description("awsroute53", "QueryExistingDNSRecordAPI") do
    "This step attempts to query an existing DNS record on Route53 via the AWS SDK for JavaScript v3."
  end

  def description("awsroute53", "CreateDNSRecord") do
    "This step attempts to create a DNS A record on Route53 via the AWS SDK for JavaScript v3."
  end

  def description("awsroute53", "RemoveDNSRecord") do
    "This step attempts to remove a DNS A Record on Route53 via the AWS SDK for JavaScript v3."
  end

  def description("awssecretsmanager", "CreateSecret") do
    "Create a secret."
  end

  def description("awssecretsmanager", "GetSecretValue") do
    "Retrieve the value of the secret just created."
  end

  def description("awssecretsmanager", "DeleteSecret") do
    "Delete the secret."
  end

  def description("azuread", "Authenticate") do
    "This step attempts to retrieve an authentication token for a Client/Application."
  end

  def description("azuread", "WriteUser") do
    "This step attempts to add a new user, randomly named, to the given domain."
  end

  def description("azuread", "ReadUser") do
    "This step attempts to retrieve the user account created in a previous step."
  end

  def description("azuread", "DeleteUser") do
    "This step attempts to delete the user account created in a previous step."
  end

  def description("azureaks", "QueryExistingDNSRecord") do
    "This step attempts to query an existing record on Route53 via DNS Lookup."
  end

  def description("azureaks", "CreateCluster") do
    "This step attempts to create a Kubernetes Cluster in a given Azure Region. Note: this monitor has cleanup routines that run when other steps are complete. If you run this monitor through several Orchestrators, you may choose which Orchestrator(s) shall perform the cleanup."
  end

  def description("azureaks", "CreateDeployment") do
    "This step attempts to deploy a container in a cluster created in a previous step."
  end

  def description("azureaks", "RemoveDeployment") do
    "This step attempts to remove the container deployed in a previous step."
  end

  def description("azureappservice", "PingService") do
    "This step attemps to ping Azure App Service API."
  end

  def description("azureblob", "CreateStorageAccount") do
    "Creates a storage account."
  end

  def description("azureblob", "CreateContainer") do
    "Creates a container."
  end

  def description("azureblob", "CreateBlob") do
    "Creates a blob in the container."
  end

  def description("azureblob", "GetBlob") do
    "Gets the blob from the container."
  end

  def description("azureblob", "DeleteBlob") do
    "Deletes the blob from the container."
  end

  def description("azurecdn", "GetLongCachedFile") do
    "This step attempts to retrieve an existing file from CDN cache."
  end

  def description("azurecdn", "GetNewFile") do
    "This step uploads a new file to the CDN and attempts to retrieve it from CDN cache."
  end

  def description("azurecdn", "PurgeFile") do
    "This step attempts to purge a file uploaded in a previous step."
  end

  def description("azurecdn", "UpdateFile") do
    "This step attempts to update an existing file, then retrieve the updated version from CDN cache."
  end

  def description("azurecdn", "DeleteFile") do
    "This step attempts to delete a file, purge the file from cache, then confirm the file no longer exists."
  end

  def description("azuredb", "CreateCosmosAccount") do
    "This step attempts to create a cosmos account, randomly named, in the given region."
  end

  def description("azuredb", "CreateDatabase") do
    "This step attempts to attach a database, randonmy named, to the cosmos account created in a previous step."
  end

  def description("azuredb", "CreateContainer") do
    "This step attempts to create a new SqlContainer in a database created in a previous step."
  end

  def description("azuredb", "InsertItem") do
    "This step attempts to insert an item in a container created in a previous step."
  end

  def description("azuredb", "GetItem") do
    "This step attempts to retrieve an item created in a previous step."
  end

  def description("azuredb", "DeleteItem") do
    "This step attempts to delete an item created in a previous step."
  end

  def description("azuredb", "DeleteContainer") do
    "This step attempts to delete a container created in a previous step."
  end

  def description("azuredb", "DeleteDatabase") do
    "This step attempts to delete a database created in a previous step."
  end

  def description("azuredevops", "CloneRepo") do
    "This step attempts to clone a given repository."
  end

  def description("azuredevops", "PushCode") do
    "This step attempts to checkout a new branch, write a file, add, commit, and push changes to a given repository."
  end

  def description("azuredevops", "RemoveRemoteBranch") do
    "This step attempts to remove the new branch created in a previous step."
  end

  def description("azuredevopsartifacts", "Ping") do
    "This step attempts to retrieve package metadata from a known artifact."
  end

  def description("azuredevopsartifacts", "DownloadPackage") do
    "This step attempts to download a known artifact."
  end

  def description("azuredevopsboards", "CreateWorkItem") do
    "This step attempts to create a work item on the given board."
  end

  def description("azuredevopsboards", "GetWorkItem") do
    "This step attempts to retrieve a work item created in a previous step."
  end

  def description("azuredevopsboards", "EditWorkItem") do
    "This step attempts to edit a work item created in a previous step."
  end

  def description("azuredevopsboards", "DeleteWorkItem") do
    "This step attempts to delete a work item created in a previous step."
  end

  def description("azuredevopspipelines", "StartMachineWorkflow") do
    "This step attempts to start a workflow on the given pipeline."
  end

  def description("azuredevopspipelines", "WaitForMachineWorkflowRunToComplete") do
    "This step attempts to read the result of a workflow started in a previous step."
  end

  def description("azuredevopspipelines", "StartDockerWorkflow") do
    "This step attempts to start a workflow using Docker on the given pipeline."
  end

  def description("azuredevopspipelines", "WaitForDockerWorkflowRunToComplete") do
    "This step attempts to read the result of a workflow started in a previous step."
  end

  def description("azuredevopstestplans", "CreateTestCase") do
    "This step attempts to create a test case in the given project."
  end

  def description("azuredevopstestplans", "CreateTestPlan") do
    "This step attempts to create a test plan in the given project."
  end

  def description("azuredevopstestplans", "CreateTestSuite") do
    "This step attempts to create a test suite in the given project."
  end

  def description("azuredevopstestplans", "AddTestCasesToSuite") do
    "This step attempts to add test cases to a suite created in a previous step."
  end

  def description("azuredevopstestplans", "CreateTestRun") do
    "This step attempts to create a test run of a suite created in a previous step."
  end

  def description("azuredevopstestplans", "AddResultsToTestRun") do
    "This step attempts to add test results to a test run created in a previous step."
  end

  def description("azuredevopstestplans", "GetResults") do
    "This step attempts to retrieve the test results produced in a previous step."
  end

  def description("azuredevopstestplans", "DeleteTestRun") do
    "This step attempts to delete a test run created in a previous step."
  end

  def description("azuredevopstestplans", "DeleteTestPlan") do
    "This step attempts to delete a test plan created in a previous step."
  end

  def description("azuredevopstestplans", "DeleteTestCase") do
    "This step attempts to delete a test case created in a previous step."
  end

  def description("azurefncs", "RunHttpTrigger") do
    "This step triggers a GET request to the given url and appends `?code={the_given_value}`."
  end

  def description("azuremonitor", "TrackEvent") do
    "This step attempts to track a known type of event."
  end

  def description("azuremonitor", "TrackMetricValue") do
    "This step attempts to track a metric with a given value."
  end

  def description("azuremonitor", "TrackExc") do
    "This step throws an exception and attempts to track it."
  end

  def description("azuremonitor", "TrackTrace") do
    "This step attempts to track a monitor trace."
  end

  def description("azuremonitor", "SendLog") do
    "This step attempts to send error details to a log."
  end

  def description("azuresql", "TrackEvent") do
    "This step attempts to track a known type of event."
  end

  def description("azuresql", "CreateSqlServer") do
    "This step attempts to create a SQL server on the given tenant."
  end

  def description("azuresql", "CreateDatabase") do
    "This step attempts to create a database in a SQL server created in a previous step."
  end

  def description("azuresql", "CreateTable") do
    "This step attempts to create a table in a database created in a previous step."
  end

  def description("azuresql", "InsertItem") do
    "This step attempts to insert an item in a table created in a previous step."
  end

  def description("azuresql", "GetItem") do
    "This step attempts to retrieve an item inserted in a previous step."
  end

  def description("azuresql", "DeleteItem") do
    "This step attempts to delete an item inserted in a previous step."
  end

  def description("azuresql", "DeleteDatabase") do
    "This step attempts to delete a database created in a previous step."
  end

  def description("azuresql", "DeleteServer") do
    "This step attempts to delete a server created in a previous step."
  end

  def description("azurevm", "CreateInstance") do
    "This step attempts to create a virtual machine instance."
  end

  def description("azurevm", "RunInstance") do
    "This step attempts to run a virtual machine instance created in a previous step."
  end

  def description("azurevm", "TerminateInstance") do
    "This step attempts to terminate a virtual machine instance created in a previous step."
  end

  def description("azurevm", "DescribePersistentInstance") do
    "This step attempts to retrieve information about a persistent virtual machine instance."
  end

  def description("bambora", "TestPurchase") do
    "Attempts a test purchase."
  end

  def description("bambora", "TestRefund") do
    "Attempts a test refund."
  end

  def description("bambora", "TestVoid") do
    "Attempts a test void."
  end

  def description("braintree", "SubmitSandboxTransaction") do
    "Attempts to submit a sandbox transaction."
  end

  def description("circleci", "StartPipeline") do
    "Starts a pipeline."
  end

  def description("circleci", "RunMonitorDockerWorkflow") do
    "Runs a Docker workflow."
  end

  def description("circleci", "RunMonitorMachineWorkflow") do
    "Runs a machine workflow."
  end

  def description("cloudflare", "Ping") do
    "Pings by requesting https://1.1.1.1/favicon.ico."
  end

  def description("cloudflare", "DNSLookup") do
    "Performs a DNS lookup."
  end

  def description("cloudflare", "CDN") do
    "Requests an asset from the CDN."
  end

  def description("cognito", "CreateUser") do
    "This step attempts to create a user account (randomly named) using Cognito Identity Provider Client."
  end

  def description("cognito", "DeleteUser") do
    "This step attempts to delete the user account created in a previous step."
  end

  def description("datadog", "SubmitEvent") do
    "Posts an event using the v1 events API."
  end

  def description("datadog", "GetEvent") do
    "Gets the event using the v1 events API."
  end

  def description("easypost", "GetAddressesTest") do
    "Gets addresses in the test environment."
  end

  def description("easypost", "GetAddressesProd") do
    "Gets addresses in the prod environment."
  end

  def description("easypost", "VerifyInvalidAddress") do
    "Verifies addresses in the prod environment."
  end

  def description("ec2", "RunInstance") do
    "This step attempts to launch an EC2 instance using the AMI for which you have permissions."
  end

  def description("ec2", "TerminateInstance") do
    "This step attempts to terminate the instance created in a previous step."
  end

  def description("ec2", "DescribePersistentInstance") do
    "This step attempts to retrieve description(s) of running instances."
  end

  def description("envoy", "GetEmployees") do
    "This step attempts to retrieve a list of employees."
  end

  def description("envoy", "GetReservations") do
    "This step attempts to retrieve a list of reservations."
  end

  def description("fastly", "PurgeCache") do
    "Purges a cache."
  end

  def description("fastly", "GetNonCachedFile") do
    "Gets a non-cached file."
  end

  def description("fastly", "GetCachedFile") do
    "Gets a cached file."
  end

  def description("gcal", "CreateEvent") do
    "Creates an event."
  end

  def description("gcal", "GetEvent") do
    "Gets an event."
  end

  def description("gcal", "DeleteEvent") do
    "Deletes an event."
  end

  def description("gcpappengine", "AutoScaleUp") do
    "Performs several rapid requests to trigger autoscaling."
  end

  def description("gcpappengine", "PingApp") do
    "Pings an existing instance."
  end

  def description("gcpappengine", "CreateVersion") do
    "Deploys a new version of the service."
  end

  def description("gcpappengine", "MigrateTraffic") do
    "Migrates traffic of a service from one version to another."
  end

  def description("gcpappengine", "AutoScaleDown") do
    "Waits for instance count to return to 0. Instances are created with a 10s idle timeout."
  end

  def description("gcpappengine", "DestroyVersion") do
    "Destroys a version of the service."
  end

  def description("gcpcloudstorage", "CreateBucket") do
    "Creating a bucket adds the bucket to your GCP account."
  end

  def description("gcpcloudstorage", "UploadObject") do
    "Stores a new object in a bucket."
  end

  def description("gcpcloudstorage", "GetObject") do
    "Gets the object's metadata."
  end

  def description("gcpcloudstorage", "DeleteObject") do
    "Objects are the individual pieces of data. Deleting an object removes it from the bucket."
  end

  def description("gcpcloudstorage", "DeleteBucket") do
    "Deletes the bucket and removes the associated data from the GCP account."
  end

  def description("gcpcomputeengine", "CreateInstance") do
    "Creates an instance."
  end

  def description("gcpcomputeengine", "GetInstanceInfo") do
    "Gets information about the instance."
  end

  def description("gcpcomputeengine", "DeleteInstance") do
    "Deletes the instance."
  end

  def description("github", "PullCode") do
    "Pulls code from a git repository."
  end

  def description("github", "PushCode") do
    "Pushes code to a git repository."
  end

  def description("github", "RemoveRemoteBranch") do
    "Removes a remote branch from a git repository."
  end

  def description("github", "PullRequests") do
    "Loads the pull requests web UI."
  end

  def description("github", "Issues") do
    "Loads the issues web UI."
  end

  def description("github", "Raw") do
    "Loads a file from raw.githubusercontent.com."
  end

  def description("gke", "CreateDeployment") do
    "Creates a deployment."
  end

  def description("gke", "RemoveDeployment") do
    "Removes a deployment."
  end

  def description("gmaps", "GetDirections") do
    "Gets directions."
  end

  def description("gmaps", "GetStaticMapImage") do
    "Gets a static image."
  end

  def description("gmaps", "GetGeocodingFromAddress") do
    "Gets gecoding from an address."
  end

  def description("googledrive", "CreateDocsFile") do
    "This step attempts to create a file."
  end

  def description("googledrive", "GetDocsFile") do
    "This step attempts to retrieve a file created in a previous step."
  end

  def description("googledrive", "DeleteDocsFile") do
    "This step attempts to delete a file created in a previous step."
  end

  def description("heroku", "AppPing") do
    "Pings an application."
  end

  def description("heroku", "ConfigUpdate") do
    "Updates an application's configuration."
  end

  def description("hubspot", "GetContacts") do
    "Lists contacts using the v1 REST API."
  end

  def description("jira", "CreateIssue") do
    "Creates an issue using the REST API."
  end

  def description("jira", "DeleteIssue") do
    "Deletes the issue using the REST API."
  end

  def description("kinesis", "WriteToStream") do
    "This step attempts to write streaming data using the PutRecordRequest class."
  end

  def description("kinesis", "ReadFromStream") do
    "This step attempts to read data from the stream created in a previous step."
  end

  def description("moneris", "TestPurchase") do
    "Attempts a test purchase."
  end

  def description("moneris", "TestRefund") do
    "Attempts a test refund."
  end

  def description("neon", "CreateBranch") do
    "Create a new branch"
  end

  def description("neon", "DeleteBranch") do
    "Delete a branch"
  end

  def description("newrelic", "SubmitEvent") do
    "This step attempts to submit an event through the Event API."
  end

  def description("newrelic", "CheckEvent") do
    "This step attempts to use the NerdGraph Graphql API to retrieve the event submitted in the previous step."
  end

  def description("newrelic", "CreateSyntheticMonitor") do
    "Creates a synthetic monitor that pings https://newrelic.com"
  end

  def description("newrelic", "WaitForSyntheticMonitorResponse") do
    "Waits for the result of the created synthetic monitor to be available."
  end

  def description("newrelic", "DeleteSyntheticMonitor") do
    "Deletes the previously created synthetic monitor."
  end

  def description("npm", "Ping") do
    "Retreives a package's metadata over HTTPS."
  end

  def description("npm", "DownloadPackage") do
    "Downloads the package over HTTPS."
  end

  def description("nuget", "ListVersions") do
    "Lists versions of a package."
  end

  def description("nuget", "Download") do
    "Downloads a package."
  end

  def description("okta", "GetToken") do
    "This step attempts to obtain an access token using Client ID and Client Secret."
  end

  def description("pagerduty", "CreateIncident") do
    "Submits a trigger event to the v2 events API."
  end

  def description("pagerduty", "CheckForIncident") do
    "Polls for incidents using the REST API until the submitted event results in an incident."
  end

  def description("pagerduty", "ReceiveWebhook") do
    "Waits for PagerDuty to send a webhook for the resulting incident."
  end

  def description("pagerduty", "ResolveIncident") do
    "Submits a resolve event for the incident using the v2 events API."
  end

  def description("pubnub", "SubscribeToChannel") do
    "Subscribes to a channel."
  end

  def description("pubnub", "SendMessage") do
    "Sends a message to the channel."
  end

  def description("pubnub", "ReceiveMessage") do
    "Receives a message from the channel."
  end

  def description("s3", "PutBucket") do
    "This step attempts to put a bucket, randomly named."
  end

  def description("s3", "PutObject") do
    "This step attempts to put an object in a bucket created in a previous step."
  end

  def description("s3", "GetObject") do
    "This step attempts to get an object placed in a previous step."
  end

  def description("s3", "DeleteObject") do
    "This step attempts to delete an object placed in a previous step."
  end

  def description("s3", "DeleteBucket") do
    "This step attempts to delete a bucket put in a previous step."
  end

  def description("sendgrid", "SendEmail") do
    "Sends an email using the v3 API."
  end

  def description("sentry", "CaptureEvent") do
    "Captures an event."
  end

  def description("sentry", "WaitForIssue") do
    "Waits for an issue to be created from the event."
  end

  def description("sentry", "ResolveIssue") do
    "Resolves the issue."
  end

  def description("sentry", "DeleteIssue") do
    "Deletes the issue."
  end

  def description("ses", "SendEmail") do
    "This step attempts to send a message via SES."
  end

  def description("slack", "PostMessage") do
    "Sends a message through the API."
  end

  def description("slack", "ReadMessage") do
    "Reads the previously sent message through the API."
  end

  def description("snowflake", "CreateDatabase") do
    "Creates a database."
  end

  def description("snowflake", "CreateTable") do
    "Creates a table in the database."
  end

  def description("snowflake", "PutFile") do
    "Puts a file into the table."
  end

  def description("snowflake", "GetData") do
    "Gets data from the table."
  end

  def description("snowflake", "DeleteData") do
    "Deletes data from the table."
  end

  def description("snowflake", "DropTable") do
    "Drops the table."
  end

  def description("snowflake", "DropDatabase") do
    "Drops the database."
  end

  def description("sqs", "WriteMessage") do
    "This step attempts to write a message to a queue."
  end

  def description("sqs", "ReadMessage") do
    "This step attempts to retrieve a message created in a previous step."
  end

  def description("stripe", "CreateMethod") do
    "Creates a method on a test card."
  end

  def description("stripe", "CreateIntent") do
    "Creates an intent a test card."
  end

  def description("stripe", "ConfirmIntent") do
    "Confirms an intent on a test card."
  end

  def description("testsignal", "Zero") do
    "Always returns a zero measurement."
  end

  def description("testsignal", "Normal") do
    "Returns a normal-distributed number from the distribution (μ=10.0, σ=2.0)."
  end

  def description("testsignal", "Poisson") do
    "Returns a sample from a Poisson distributed random variable."
  end

  def description("trello", "CreateCard") do
    "Creates a card using the REST API."
  end

  def description("trello", "DeleteCard") do
    "Deletes the card using the REST API."
  end

  def description("twiliovid", "CreateRoom") do
    "Creates a room using the Twilio C# library for the REST API."
  end

  def description("twiliovid", "GetRoom") do
    "Fetches the room using the Twilio C# library for the REST API."
  end

  def description("twiliovid", "CompleteRoom") do
    "Updates the room, setting its status to completed, using the Twilio C# library for the REST API."
  end

  def description("twiliovid", "JoinRoom") do
    "Joins the room using a headless Chrome browser."
  end

  def description("zendesk", "GetUsers") do
    "Lists users using the REST API."
  end

  def description("zendesk", "CreateTicket") do
    "Creates a ticket using the REST API."
  end

  def description("zendesk", "SoftDeleteTicket") do
    "Deletes the ticket, (soft deletion), using the REST API."
  end

  def description("zendesk", "PermanentlyDeleteTicket") do
    "Permanently deletes the ticket using the REST API."
  end

  def description("zoom", "GetUsers") do
    "Gets users using the REST API."
  end

  def description("zoom", "CreateMeeting") do
    "Create a meeting."
  end

  def description("zoom", "GetMeeting") do
    "Gets meeting details."
  end

  def description("zoom", "DeleteMeeting") do
    "Deletes a meeting."
  end

  def description("zoom", "JoinCall") do
    "Joins a call using the Zoom client and a headless Chrome browser."
  end

  def description(_, _) do
    ""
  end

  def docs_url("asana", "Ping") do
    "https://developers.asana.com/docs/get-multiple-users"
  end

  def docs_url("asana", "CreateTask") do
    "https://developers.asana.com/docs/create-a-task"
  end

  def docs_url("asana", "GetTask") do
    "https://developers.asana.com/docs/get-a-task"
  end

  def docs_url("asana", "DeleteTask") do
    "https://developers.asana.com/docs/delete-a-task"
  end

  def docs_url("authzero", "GetAccessToken") do
    "https://auth0.com/docs/secure/tokens/access-tokens/get-management-api-access-tokens-for-production"
  end

  def docs_url("authzero", "GetBranding") do
    "https://auth0.com/docs/api/management/v2#!/Branding/get_branding"
  end

  def docs_url("avalara", "Ping") do
    "https://developer.avalara.com/api-reference/avatax/rest/v2/methods/Utilities/Ping/"
  end

  def docs_url("awscloudfront", "PublishFile") do
    ""
  end

  def docs_url("awscloudfront", "GetNewFile") do
    ""
  end

  def docs_url("awscloudfront", "UpdateFile") do
    ""
  end

  def docs_url("awscloudfront", "PurgeFile") do
    ""
  end

  def docs_url("awscloudfront", "GetUpdatedFile") do
    ""
  end

  def docs_url("awscloudfront", "DeleteFile") do
    ""
  end

  def docs_url("awscloudfront", "WaitForDeletionPropagation") do
    ""
  end

  def docs_url("awscloudwatch", "SubmitEvent") do
    ""
  end

  def docs_url("awscloudwatch", "GetEvent") do
    ""
  end

  def docs_url("awsecs", "CreateService") do
    ""
  end

  def docs_url("awsecs", "PingService") do
    ""
  end

  def docs_url("awsecs", "DestroyService") do
    ""
  end

  def docs_url("awseks", "CreateDeployment") do
    ""
  end

  def docs_url("awseks", "RemoveDeployment") do
    ""
  end

  def docs_url("awselb", "ChangeTargetGroup") do
    "https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/clients/client-elastic-load-balancing-v2/classes/registertargetscommand.html"
  end

  def docs_url("awsiam", "CreateUser") do
    ""
  end

  def docs_url("awsiam", "CreateGroup") do
    ""
  end

  def docs_url("awsiam", "AddUserToGroup") do
    ""
  end

  def docs_url("awsiam", "RemoveUserFromGroup") do
    ""
  end

  def docs_url("awsiam", "DeleteGroup") do
    ""
  end

  def docs_url("awsiam", "AttachPolicy") do
    ""
  end

  def docs_url("awsiam", "DetachPolicy") do
    ""
  end

  def docs_url("awsiam", "DeleteUser") do
    ""
  end

  def docs_url("awslambda", "TriggerLambdaAndWaitForResponse") do
    ""
  end

  def docs_url("awsrds", "CreateInstance") do
    ""
  end

  def docs_url("awsrds", "PingInstance") do
    ""
  end

  def docs_url("awsrds", "DestroyInstance") do
    ""
  end

  def docs_url("awsrdspersistent", "PingInstance") do
    ""
  end

  def docs_url("awsroute53", "QueryExistingDNSRecord") do
    "https://nodejs.org/api/dns.html#dnsresolvehostname-rrtype-callback"
  end

  def docs_url("awsroute53", "QueryExistingDNSRecordAPI") do
    "https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/clients/client-route-53/classes/listresourcerecordsetscommand.html"
  end

  def docs_url("awsroute53", "CreateDNSRecord") do
    "https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/clients/client-route-53/classes/changeresourcerecordsetscommand.html"
  end

  def docs_url("awsroute53", "RemoveDNSRecord") do
    "https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/clients/client-route-53/classes/changeresourcerecordsetscommand.html"
  end

  def docs_url("awssecretsmanager", "CreateSecret") do
    "https://docs.aws.amazon.com/secretsmanager/latest/apireference/API_CreateSecret.html"
  end

  def docs_url("awssecretsmanager", "GetSecretValue") do
    "https://docs.aws.amazon.com/secretsmanager/latest/apireference/API_GetSecretValue.html"
  end

  def docs_url("awssecretsmanager", "DeleteSecret") do
    "https://docs.aws.amazon.com/secretsmanager/latest/apireference/API_DeleteSecret.html"
  end

  def docs_url("azuread", "Authenticate") do
    ""
  end

  def docs_url("azuread", "WriteUser") do
    ""
  end

  def docs_url("azuread", "ReadUser") do
    ""
  end

  def docs_url("azuread", "DeleteUser") do
    ""
  end

  def docs_url("azureaks", "QueryExistingDNSRecord") do
    ""
  end

  def docs_url("azureaks", "CreateCluster") do
    ""
  end

  def docs_url("azureaks", "CreateDeployment") do
    ""
  end

  def docs_url("azureaks", "RemoveDeployment") do
    ""
  end

  def docs_url("azureappservice", "PingService") do
    ""
  end

  def docs_url("azureblob", "CreateStorageAccount") do
    ""
  end

  def docs_url("azureblob", "CreateContainer") do
    ""
  end

  def docs_url("azureblob", "CreateBlob") do
    ""
  end

  def docs_url("azureblob", "GetBlob") do
    ""
  end

  def docs_url("azureblob", "DeleteBlob") do
    ""
  end

  def docs_url("azurecdn", "GetLongCachedFile") do
    ""
  end

  def docs_url("azurecdn", "GetNewFile") do
    ""
  end

  def docs_url("azurecdn", "PurgeFile") do
    ""
  end

  def docs_url("azurecdn", "UpdateFile") do
    ""
  end

  def docs_url("azurecdn", "DeleteFile") do
    ""
  end

  def docs_url("azuredb", "CreateCosmosAccount") do
    ""
  end

  def docs_url("azuredb", "CreateDatabase") do
    ""
  end

  def docs_url("azuredb", "CreateContainer") do
    ""
  end

  def docs_url("azuredb", "InsertItem") do
    ""
  end

  def docs_url("azuredb", "GetItem") do
    ""
  end

  def docs_url("azuredb", "DeleteItem") do
    ""
  end

  def docs_url("azuredb", "DeleteContainer") do
    ""
  end

  def docs_url("azuredb", "DeleteDatabase") do
    ""
  end

  def docs_url("azuredevops", "CloneRepo") do
    ""
  end

  def docs_url("azuredevops", "PushCode") do
    ""
  end

  def docs_url("azuredevops", "RemoveRemoteBranch") do
    ""
  end

  def docs_url("azuredevopsartifacts", "Ping") do
    ""
  end

  def docs_url("azuredevopsartifacts", "DownloadPackage") do
    ""
  end

  def docs_url("azuredevopsboards", "CreateWorkItem") do
    ""
  end

  def docs_url("azuredevopsboards", "GetWorkItem") do
    ""
  end

  def docs_url("azuredevopsboards", "EditWorkItem") do
    ""
  end

  def docs_url("azuredevopsboards", "DeleteWorkItem") do
    ""
  end

  def docs_url("azuredevopspipelines", "StartMachineWorkflow") do
    ""
  end

  def docs_url("azuredevopspipelines", "WaitForMachineWorkflowRunToComplete") do
    ""
  end

  def docs_url("azuredevopspipelines", "StartDockerWorkflow") do
    ""
  end

  def docs_url("azuredevopspipelines", "WaitForDockerWorkflowRunToComplete") do
    ""
  end

  def docs_url("azuredevopstestplans", "CreateTestCase") do
    ""
  end

  def docs_url("azuredevopstestplans", "CreateTestPlan") do
    ""
  end

  def docs_url("azuredevopstestplans", "CreateTestSuite") do
    ""
  end

  def docs_url("azuredevopstestplans", "AddTestCasesToSuite") do
    ""
  end

  def docs_url("azuredevopstestplans", "CreateTestRun") do
    ""
  end

  def docs_url("azuredevopstestplans", "AddResultsToTestRun") do
    ""
  end

  def docs_url("azuredevopstestplans", "GetResults") do
    ""
  end

  def docs_url("azuredevopstestplans", "DeleteTestRun") do
    ""
  end

  def docs_url("azuredevopstestplans", "DeleteTestPlan") do
    ""
  end

  def docs_url("azuredevopstestplans", "DeleteTestCase") do
    ""
  end

  def docs_url("azurefncs", "RunHttpTrigger") do
    ""
  end

  def docs_url("azuremonitor", "TrackEvent") do
    ""
  end

  def docs_url("azuremonitor", "TrackMetricValue") do
    ""
  end

  def docs_url("azuremonitor", "TrackExc") do
    ""
  end

  def docs_url("azuremonitor", "TrackTrace") do
    ""
  end

  def docs_url("azuremonitor", "SendLog") do
    ""
  end

  def docs_url("azuresql", "TrackEvent") do
    ""
  end

  def docs_url("azuresql", "CreateSqlServer") do
    ""
  end

  def docs_url("azuresql", "CreateDatabase") do
    ""
  end

  def docs_url("azuresql", "CreateTable") do
    ""
  end

  def docs_url("azuresql", "InsertItem") do
    ""
  end

  def docs_url("azuresql", "GetItem") do
    ""
  end

  def docs_url("azuresql", "DeleteItem") do
    ""
  end

  def docs_url("azuresql", "DeleteDatabase") do
    ""
  end

  def docs_url("azuresql", "DeleteServer") do
    ""
  end

  def docs_url("azurevm", "CreateInstance") do
    ""
  end

  def docs_url("azurevm", "RunInstance") do
    ""
  end

  def docs_url("azurevm", "TerminateInstance") do
    ""
  end

  def docs_url("azurevm", "DescribePersistentInstance") do
    ""
  end

  def docs_url("bambora", "TestPurchase") do
    ""
  end

  def docs_url("bambora", "TestRefund") do
    ""
  end

  def docs_url("bambora", "TestVoid") do
    ""
  end

  def docs_url("braintree", "SubmitSandboxTransaction") do
    ""
  end

  def docs_url("circleci", "StartPipeline") do
    ""
  end

  def docs_url("circleci", "RunMonitorDockerWorkflow") do
    ""
  end

  def docs_url("circleci", "RunMonitorMachineWorkflow") do
    ""
  end

  def docs_url("cloudflare", "Ping") do
    ""
  end

  def docs_url("cloudflare", "DNSLookup") do
    ""
  end

  def docs_url("cloudflare", "CDN") do
    ""
  end

  def docs_url("cognito", "CreateUser") do
    ""
  end

  def docs_url("cognito", "DeleteUser") do
    ""
  end

  def docs_url("datadog", "SubmitEvent") do
    "https://docs.datadoghq.com/api/latest/events/#post-an-event"
  end

  def docs_url("datadog", "GetEvent") do
    "https://docs.datadoghq.com/api/latest/events/#get-an-event"
  end

  def docs_url("easypost", "GetAddressesTest") do
    ""
  end

  def docs_url("easypost", "GetAddressesProd") do
    ""
  end

  def docs_url("easypost", "VerifyInvalidAddress") do
    ""
  end

  def docs_url("ec2", "RunInstance") do
    "https://docs.aws.amazon.com/AWSEC2/latest/APIReference/API_RunInstances.html"
  end

  def docs_url("ec2", "TerminateInstance") do
    "https://docs.aws.amazon.com/AWSEC2/latest/APIReference/API_TerminateInstances.html"
  end

  def docs_url("ec2", "DescribePersistentInstance") do
    "https://docs.aws.amazon.com/AWSEC2/latest/APIReference/API_DescribeInstances.html"
  end

  def docs_url("envoy", "GetEmployees") do
    ""
  end

  def docs_url("envoy", "GetReservations") do
    ""
  end

  def docs_url("fastly", "PurgeCache") do
    ""
  end

  def docs_url("fastly", "GetNonCachedFile") do
    ""
  end

  def docs_url("fastly", "GetCachedFile") do
    ""
  end

  def docs_url("gcal", "CreateEvent") do
    ""
  end

  def docs_url("gcal", "GetEvent") do
    ""
  end

  def docs_url("gcal", "DeleteEvent") do
    ""
  end

  def docs_url("gcpappengine", "AutoScaleUp") do
    ""
  end

  def docs_url("gcpappengine", "PingApp") do
    ""
  end

  def docs_url("gcpappengine", "CreateVersion") do
    "https://cloud.google.com/appengine/docs/admin-api/reference/rest/v1/apps.services.versions/create"
  end

  def docs_url("gcpappengine", "MigrateTraffic") do
    "https://cloud.google.com/appengine/docs/admin-api/reference/rest/v1/apps.services/patch"
  end

  def docs_url("gcpappengine", "AutoScaleDown") do
    ""
  end

  def docs_url("gcpappengine", "DestroyVersion") do
    "https://cloud.google.com/appengine/docs/admin-api/reference/rest/v1/apps.services.versions/delete"
  end

  def docs_url("gcpcloudstorage", "CreateBucket") do
    "https://cloud.google.com/storage/docs/creating-buckets"
  end

  def docs_url("gcpcloudstorage", "UploadObject") do
    "https://cloud.google.com/storage/docs/uploading-objects#upload-object-xml"
  end

  def docs_url("gcpcloudstorage", "GetObject") do
    "https://cloud.google.com/storage/docs/json_api/v1/objects/get"
  end

  def docs_url("gcpcloudstorage", "DeleteObject") do
    "https://cloud.google.com/storage/docs/json_api/v1/objects/delete"
  end

  def docs_url("gcpcloudstorage", "DeleteBucket") do
    "https://cloud.google.com/storage/docs/json_api/v1/buckets/delete"
  end

  def docs_url("gcpcomputeengine", "CreateInstance") do
    ""
  end

  def docs_url("gcpcomputeengine", "GetInstanceInfo") do
    ""
  end

  def docs_url("gcpcomputeengine", "DeleteInstance") do
    ""
  end

  def docs_url("github", "PullCode") do
    ""
  end

  def docs_url("github", "PushCode") do
    ""
  end

  def docs_url("github", "RemoveRemoteBranch") do
    ""
  end

  def docs_url("github", "PullRequests") do
    ""
  end

  def docs_url("github", "Issues") do
    ""
  end

  def docs_url("github", "Raw") do
    ""
  end

  def docs_url("gke", "CreateDeployment") do
    ""
  end

  def docs_url("gke", "RemoveDeployment") do
    ""
  end

  def docs_url("gmaps", "GetDirections") do
    ""
  end

  def docs_url("gmaps", "GetStaticMapImage") do
    ""
  end

  def docs_url("gmaps", "GetGeocodingFromAddress") do
    ""
  end

  def docs_url("googledrive", "CreateDocsFile") do
    "https://developers.google.com/drive/api/v3/reference/files/create"
  end

  def docs_url("googledrive", "GetDocsFile") do
    "https://developers.google.com/drive/api/v3/reference/files/get"
  end

  def docs_url("googledrive", "DeleteDocsFile") do
    "https://developers.google.com/drive/api/v3/reference/files/delete"
  end

  def docs_url("heroku", "AppPing") do
    ""
  end

  def docs_url("heroku", "ConfigUpdate") do
    ""
  end

  def docs_url("hubspot", "GetContacts") do
    "https://developers.hubspot.com/docs/api/crm/contacts"
  end

  def docs_url("jira", "CreateIssue") do
    "https://docs.atlassian.com/software/jira/docs/api/REST/7.0-SNAPSHOT/#api/2/issue-createIssue"
  end

  def docs_url("jira", "DeleteIssue") do
    "https://docs.atlassian.com/software/jira/docs/api/REST/7.0-SNAPSHOT/#api/2/issue-deleteIssue"
  end

  def docs_url("kinesis", "WriteToStream") do
    ""
  end

  def docs_url("kinesis", "ReadFromStream") do
    ""
  end

  def docs_url("moneris", "TestPurchase") do
    ""
  end

  def docs_url("moneris", "TestRefund") do
    ""
  end

  def docs_url("neon", "CreateBranch") do
    "https://api-docs.neon.tech/reference/createprojectbranch"
  end

  def docs_url("neon", "DeleteBranch") do
    "https://api-docs.neon.tech/reference/deleteprojectbranch"
  end

  def docs_url("newrelic", "SubmitEvent") do
    "https://docs.newrelic.com/docs/data-apis/ingest-apis/event-api/introduction-event-api/#submit-event"
  end

  def docs_url("newrelic", "CheckEvent") do
    "https://docs.newrelic.com/docs/apis/nerdgraph/examples/nerdgraph-nrql-tutorial/"
  end

  def docs_url("newrelic", "CreateSyntheticMonitor") do
    "https://docs.newrelic.com/docs/apis/synthetics-rest-api/monitor-examples/manage-synthetics-monitors-rest-api/"
  end

  def docs_url("newrelic", "WaitForSyntheticMonitorResponse") do
    "https://docs.newrelic.com/docs/apis/synthetics-rest-api/monitor-examples/manage-synthetics-monitors-rest-api/"
  end

  def docs_url("newrelic", "DeleteSyntheticMonitor") do
    "https://docs.newrelic.com/docs/apis/synthetics-rest-api/monitor-examples/manage-synthetics-monitors-rest-api/"
  end

  def docs_url("npm", "Ping") do
    "https://www.npmjs.com/package/vue-debounce-provider"
  end

  def docs_url("npm", "DownloadPackage") do
    "https://www.npmjs.com/package/vue-debounce-provider"
  end

  def docs_url("nuget", "ListVersions") do
    ""
  end

  def docs_url("nuget", "Download") do
    ""
  end

  def docs_url("okta", "GetToken") do
    "https://developer.okta.com/docs/guides/implement-grant-type/clientcreds/main/"
  end

  def docs_url("pagerduty", "CreateIncident") do
    "https://developer.pagerduty.com/api-reference/b3A6Mjc0ODI2Nw-send-an-event-to-pager-duty"
  end

  def docs_url("pagerduty", "CheckForIncident") do
    "https://developer.pagerduty.com/api-reference/b3A6Mjc0ODEzOA-list-incidents"
  end

  def docs_url("pagerduty", "ReceiveWebhook") do
    "https://developer.pagerduty.com/docs/ZG9jOjQ1MTg4ODQ0-overview"
  end

  def docs_url("pagerduty", "ResolveIncident") do
    "https://developer.pagerduty.com/api-reference/b3A6Mjc0ODI2Nw-send-an-event-to-pager-duty"
  end

  def docs_url("pubnub", "SubscribeToChannel") do
    ""
  end

  def docs_url("pubnub", "SendMessage") do
    ""
  end

  def docs_url("pubnub", "ReceiveMessage") do
    ""
  end

  def docs_url("s3", "PutBucket") do
    ""
  end

  def docs_url("s3", "PutObject") do
    ""
  end

  def docs_url("s3", "GetObject") do
    ""
  end

  def docs_url("s3", "DeleteObject") do
    ""
  end

  def docs_url("s3", "DeleteBucket") do
    ""
  end

  def docs_url("sendgrid", "SendEmail") do
    "https://docs.sendgrid.com/api-reference/mail-send/mail-send"
  end

  def docs_url("sentry", "CaptureEvent") do
    ""
  end

  def docs_url("sentry", "WaitForIssue") do
    ""
  end

  def docs_url("sentry", "ResolveIssue") do
    ""
  end

  def docs_url("sentry", "DeleteIssue") do
    ""
  end

  def docs_url("ses", "SendEmail") do
    ""
  end

  def docs_url("slack", "PostMessage") do
    "https://api.slack.com/methods/chat.postMessage"
  end

  def docs_url("slack", "ReadMessage") do
    "https://api.slack.com/methods/conversations.history"
  end

  def docs_url("snowflake", "CreateDatabase") do
    ""
  end

  def docs_url("snowflake", "CreateTable") do
    ""
  end

  def docs_url("snowflake", "PutFile") do
    ""
  end

  def docs_url("snowflake", "GetData") do
    ""
  end

  def docs_url("snowflake", "DeleteData") do
    ""
  end

  def docs_url("snowflake", "DropTable") do
    ""
  end

  def docs_url("snowflake", "DropDatabase") do
    ""
  end

  def docs_url("sqs", "WriteMessage") do
    ""
  end

  def docs_url("sqs", "ReadMessage") do
    ""
  end

  def docs_url("stripe", "CreateMethod") do
    ""
  end

  def docs_url("stripe", "CreateIntent") do
    ""
  end

  def docs_url("stripe", "ConfirmIntent") do
    ""
  end

  def docs_url("testsignal", "Zero") do
    "https://marketplace.zoom.us/docs/api-reference/zoom-api/methods#operation/users"
  end

  def docs_url("testsignal", "Normal") do
    "https://en.wikipedia.org/wiki/Normal_distribution"
  end

  def docs_url("testsignal", "Poisson") do
    "https://en.wikipedia.org/wiki/Poisson_distribution"
  end

  def docs_url("trello", "CreateCard") do
    "https://developer.atlassian.com/cloud/trello/rest/api-group-cards/#api-cards-post"
  end

  def docs_url("trello", "DeleteCard") do
    "https://developer.atlassian.com/cloud/trello/rest/api-group-cards/#api-cards-id-delete"
  end

  def docs_url("twiliovid", "CreateRoom") do
    "https://www.twilio.com/docs/libraries/reference/twilio-csharp/5.65.0/class_twilio_1_1_rest_1_1_video_1_1_v1_1_1_room_resource.html#a8ff7386b8109417ae9953ec02ede1167"
  end

  def docs_url("twiliovid", "GetRoom") do
    "https://www.twilio.com/docs/libraries/reference/twilio-csharp/5.65.0/class_twilio_1_1_rest_1_1_video_1_1_v1_1_1_room_resource.html#a8dd4b994f39366d141b2ba4da5b6e9fe"
  end

  def docs_url("twiliovid", "CompleteRoom") do
    "https://www.twilio.com/docs/libraries/reference/twilio-csharp/5.65.0/class_twilio_1_1_rest_1_1_video_1_1_v1_1_1_room_resource.html#af9cdd2f1929ad6278f8c7f3aeb5794a7"
  end

  def docs_url("twiliovid", "JoinRoom") do
    ""
  end

  def docs_url("zendesk", "GetUsers") do
    "https://developer.zendesk.com/api-reference/ticketing/users/users/#list-users"
  end

  def docs_url("zendesk", "CreateTicket") do
    "https://developer.zendesk.com/api-reference/ticketing/tickets/tickets/#create-ticket"
  end

  def docs_url("zendesk", "SoftDeleteTicket") do
    "https://developer.zendesk.com/api-reference/ticketing/tickets/tickets/#delete-ticket"
  end

  def docs_url("zendesk", "PermanentlyDeleteTicket") do
    "https://developer.zendesk.com/api-reference/ticketing/tickets/tickets/#delete-ticket-permanently"
  end

  def docs_url("zoom", "GetUsers") do
    "https://marketplace.zoom.us/docs/api-reference/zoom-api/methods#operation/users"
  end

  def docs_url("zoom", "CreateMeeting") do
    "https://marketplace.zoom.us/docs/api-reference/zoom-api/methods/#operation/meetingCreate"
  end

  def docs_url("zoom", "GetMeeting") do
    "https://marketplace.zoom.us/docs/api-reference/zoom-api/methods/#operation/meeting"
  end

  def docs_url("zoom", "DeleteMeeting") do
    "https://marketplace.zoom.us/docs/api-reference/zoom-api/methods/#operation/meetingDelete"
  end

  def docs_url("zoom", "JoinCall") do
    ""
  end

  def docs_url(_, _) do
    ""
  end
end