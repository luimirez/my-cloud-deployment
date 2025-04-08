# Google Cloud VM Deployment Script

With this script, a Google Compute Engine Virtual Machine (VM) instance will be deployed with a static external IP address and HTTP, SSH firewall rules. The deployment will conform to the given parameters.

## Prerequisites

Review the prerequisites listed below before executing the script:

1. **Google Cloud SDK (gcloud):** Follow the [official installation guide](https://cloud.google.com/sdk/docs/install) to set it up.

2. **Authentication:** Make use of `gcloud auth login` to verify your identity with the Google Cloud.

3. **Google Cloud Project:** An ID bearing Google billing enabled project is mandatory.

4. Enabled services – The following Services APIs are required for the project:
    * Compute Engine API (compute.googleapis.com)
    * Identity and Access Management API (iam.googleapis.com)

    Use `gcloud services enable compute.googleapis.com iam.googleapis.com` or the Cloud Console to enable the APIs.

5. **Permissions** - Attested user/service accounts need sufficient IAM permissions. In this case `roles/compute.admin,`roles/iam.serviceAccountUser`` and allowances for instance, address, firewall rule creation, and more.

6. **Bash Environment:** Any shell with support for Bash (Linux, macOS, Git Bash on Windows).

## Steps to Follow to Execute the Script

1. **Clone the repository:**

    ```bash
    git clone <your-repository-url>
    
    cd <directory-of-the-repository>
    ```

2. **Configure Variables:**

    * Open the `deploy_vm.sh` script on a text editor.

    * Adjust the configuration variables at the beginning of the script (for example, `PROJECT_ID`, `ZONE`, `VM_NAME`, `STATIC_IP_NAME`) to fit your setting and requirements.

3. **Make the script executable:**

    ```bash
    chmod a+x deploy_vm.sh
    ```

4. **Run the script:**

    ```bash
    ./deploy_vm.sh
    ```

## Expected Output

The expected output of the script is that the progress messages will be printed on the terminal which includes the:

* Target project.
* Reserving Static IP Address
* Creation of VM Instance
* Firewall rules creation for HTTP and SSH use.
* Deployed Resources summary including VM name and static IP
* Commands for SSH and the URL for HTTP(after a web server is set up).

## Troubleshooting

* **Permission Denied:** This is very likely due to the script not being set as executable (`chmod +x deploy_vm.sh`). If any of the errors watered down to the Google Cloud resources, double-check the IAM permissions present in the Cloud Console.

* **API Not Enabled:** Check if there are errors of the format “API not enabled”, this means you should run the command `gcloud services enable ...` that was mentioned in the prerequisites.

* **Resource Already Exists:** The script has basic checks, but if a resource with the same name already exists (and was not created by this script in a previous run), you will likely need to either pick another name or delete the existing resource manually.

* **Quota Exceeded:** Check your project quotas at Google Cloud Console using IAM & Admin -> Quotas. You may need to submit a request to increase limitations, or you may need to scale down the resources used.

* **Invalid Zone/Region:** Verify that the specified `ZONE` is accurate and allows the selected `MACHINE_TYPE`. Zones can be checked via `gcloud compute zones list`.

* **Typos:** Verify spelling of variables and commands within the script.

## Cleanup (Important!)

To avoid incurring recurring costs, ensure that all resources associated with this script are removed once completed.

```bash
# 1. Delete the VM instance

gcloud compute instances delete YOUR_VM_NAME --zone=YOUR_ZONE --quiet

# 2. Delete the static IP address

gcloud compute addresses delete YOUR_STATIC_IP NAME --region=YOUR_REGION --quiet

# (Replace YOUR_REGION with the region derived from your zone, e.g., us-central1)

# 3. Delete the firewall rules

gcloud compute firewall-rules delete YOUR_FIREWALL_RULE_HTTP --quiet

gcloud compute firewall-rules delete YOUR_FIREWALL_RULE_SSH --quiet

That is what originally had for accessing via bash. I made on Visual studio
running with gcloud and it was facing issues to execute. I had to use powershell to install
the deployment.