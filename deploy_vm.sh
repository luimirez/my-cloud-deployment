#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration Variables ---
PROJECT_ID="my-first-cloud-deployment"          # Replace with your Project ID
ZONE="europe-west1-b"                 # Choose a zone (e.g., us-central1-a, europe-west1-b)
VM_NAME="my-machine-vm"             # Choose a name for your VM
MACHINE_TYPE="e2-standard-2"         # 2 vCPUs, 8GB RAM (meets minimum requirement)
IMAGE_FAMILY="ubuntu-2004-lts"       # Ubuntu 20.04 LTS
IMAGE_PROJECT="ubuntu-os-cloud"      # Project where the image resides
BOOT_DISK_SIZE="250GB"               # Storage size
STATIC_IP_NAME="my-machine-ip"        # Name for your static IP address resource
FIREWALL_RULE_HTTP="allow-http-script" # Name for HTTP firewall rule
FIREWALL_RULE_SSH="allow-ssh-script"   # Name for SSH firewall rule
NETWORK_TAG_HTTP="http-server"       # Network tag for HTTP rule
NETWORK_TAG_SSH="allow-ssh"          # Network tag for SSH rule

# --- Script Logic ---

echo "Starting Google Cloud resource deployment..."

# 1. Set the project context (optional if already set via gcloud init/config)
echo "Setting project to $PROJECT_ID..."
gcloud config set project $PROJECT_ID

# 2. Reserve a static external IP address
echo "Reserving static IP address: $STATIC_IP_NAME..."
# Check if IP already exists, create if not
if ! gcloud compute addresses describe $STATIC_IP_NAME --global --project=$PROJECT_ID > /dev/null 2>&1; then
  # Note: Use --region=REGION if you need a regional static IP instead of global
  # For VM external IPs, regional is more common. Let's adjust. Find region from zone:
  REGION=$(gcloud compute zones describe $ZONE --format='get(region)')
  REGION=${REGION##*/} # Extract region name from the full URL

  echo "Creating regional static IP in region $REGION..."
  gcloud compute addresses create $STATIC_IP_NAME --project=$PROJECT_ID --region=$REGION
else
  echo "Static IP address $STATIC_IP_NAME already exists."
fi
# Get the reserved IP address value
RESERVED_IP=$(gcloud compute addresses describe $STATIC_IP_NAME --project=$PROJECT_ID --region=$REGION --format='get(address)')
echo "Reserved IP Address: $RESERVED_IP"

# 3. Create the Compute Engine VM instance
echo "Creating VM instance: $VM_NAME..."
gcloud compute instances create $VM_NAME \
    --project=$PROJECT_ID \
    --zone=$ZONE \
    --machine-type=$MACHINE_TYPE \
    --image-project=$IMAGE_PROJECT \
    --image-family=$IMAGE_FAMILY \
    --boot-disk-size=$BOOT_DISK_SIZE \
    --address=$RESERVED_IP \
    --tags=$NETWORK_TAG_HTTP,$NETWORK_TAG_SSH # Add tags for firewall rules

echo "VM instance $VM_NAME created."

# 4. Create Firewall Rule for HTTP (Port 80)
echo "Creating firewall rule: $FIREWALL_RULE_HTTP..."
# Check if rule exists, create if not
if ! gcloud compute firewall-rules describe $FIREWALL_RULE_HTTP --project=$PROJECT_ID > /dev/null 2>&1; then
  gcloud compute firewall-rules create $FIREWALL_RULE_HTTP \
      --project=$PROJECT_ID \
      --direction=INGRESS \
      --priority=1000 \
      --network=default \
      --action=ALLOW \
      --rules=tcp:80 \
      --source-ranges=0.0.0.0/0 \
      --target-tags=$NETWORK_TAG_HTTP
  echo "Firewall rule $FIREWALL_RULE_HTTP created."
else
  echo "Firewall rule $FIREWALL_RULE_HTTP already exists."
fi

# 5. Create Firewall Rule for SSH (Port 22)
echo "Creating firewall rule: $FIREWALL_RULE_SSH..."
# Check if rule exists, create if not
if ! gcloud compute firewall-rules describe $FIREWALL_RULE_SSH --project=$PROJECT_ID > /dev/null 2>&1; then
  gcloud compute firewall-rules create $FIREWALL_RULE_SSH \
      --project=$PROJECT_ID \
      --direction=INGRESS \
      --priority=1000 \
      --network=default \
      --action=ALLOW \
      --rules=tcp:22 \
      --source-ranges=0.0.0.0/0 \
      --target-tags=$NETWORK_TAG_SSH # Use the specific SSH tag here
  echo "Firewall rule $FIREWALL_RULE_SSH created."
else
   echo "Firewall rule $FIREWALL_RULE_SSH already exists."
fi

echo "--- Deployment Summary ---"
echo "Project:       $PROJECT_ID"
echo "VM Name:       $VM_NAME"
echo "Zone:          $ZONE"
echo "Machine Type:  $MACHINE_TYPE"
echo "Static IP:     $RESERVED_IP ($STATIC_IP_NAME)"
echo "Firewall HTTP: $FIREWALL_RULE_HTTP (Tag: $NETWORK_TAG_HTTP)"
echo "Firewall SSH:  $FIREWALL_RULE_SSH (Tag: $NETWORK_TAG_SSH)"
echo "--------------------------"
echo "Deployment script finished successfully!"
echo "You can SSH into the VM using: gcloud compute ssh $VM_NAME --zone $ZONE"
echo "Access HTTP via: http://$RESERVED_IP (after installing a web server)"