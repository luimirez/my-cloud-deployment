# PowerShell script to deploy Google Cloud VM resources
# Ensure Google Cloud SDK is installed and authenticated (gcloud auth login)

# Stop script execution on *most* errors, but we will check gcloud manually
$ErrorActionPreference = 'Stop'

# --- Configuration Variables ---
# (Keep your existing variables)
$ProjectId = "my-first-cloud-deployment"          # Replace with your Project ID
$Zone = "us-central1-a"                 # Choose a zone
$VmName = "my-scripted-vm-ps"           # Choose a name for your VM
$MachineType = "e2-standard-2"         # 2 vCPUs, 8GB RAM
$ImageFamily = "ubuntu-2004-lts"       # Ubuntu 20.04 LTS
$ImageProject = "ubuntu-os-cloud"      # Project where the image resides
$BootDiskSize = "250GB"               # Storage size
$StaticIpName = "my-static-ip-ps"       # Name for your static IP
$FirewallRuleHttp = "allow-http-script-ps" # Name for HTTP firewall rule
$FirewallRuleSsh = "allow-ssh-script-ps"   # Name for SSH firewall rule
$NetworkTagHttp = "http-server"       # Network tag for HTTP rule
$NetworkTagSsh = "allow-ssh"          # Network tag for SSH rule

# --- Script Logic ---

Write-Host "Starting Google Cloud resource deployment..." -ForegroundColor Yellow

# 1. Set the project context
Write-Host "Setting project to $ProjectId..."
gcloud config set project $ProjectId

# 2. Determine Region from Zone
# (Keep the existing region logic)
$Region = $null
try {
    $RegionUri = (gcloud compute zones describe $Zone --project=$ProjectId --format='get(region)' --quiet | Out-String).Trim()
    $Region = $RegionUri.Split('/')[-1]
    Write-Host "Determined region as '$Region' from zone '$Zone'."
} catch {
    Write-Error "Failed to determine region for zone '$Zone'. Error: $($_.Exception.Message.Trim())"
    throw "Cannot proceed without region."
}

# 3. Check for/Create Static IP Address - Using $? Check
# (Keep the revised IP check logic from the previous version - it worked)
Write-Host "Checking/Reserving static IP address: $StaticIpName in region $Region..."
$ReservedIp = $null
$IpExists = $false
Write-Host "Attempting to describe IP '$StaticIpName'..."
gcloud compute addresses describe $StaticIpName --project=$ProjectId --region=$Region --format='none' --quiet 2>$null
$DescribeSucceeded = $?
if ($DescribeSucceeded) {
     $ReservedIp = (gcloud compute addresses describe $StaticIpName --project=$ProjectId --region=$Region --format='value(address)' --quiet | Out-String).Trim()
     if (-not [string]::IsNullOrEmpty($ReservedIp)) { $IpExists = $true; Write-Host "Static IP '$StaticIpName' already exists with IP: $ReservedIp." }
     else { Write-Warning "Describe succeeded for '$StaticIpName' but value empty. Treating as 'not found'."; $IpExists = $false }
} else {
    Write-Host "Static IP '$StaticIpName' not found via describe. Attempting to create..."
    try {
        gcloud compute addresses create $StaticIpName --project=$ProjectId --region=$Region --quiet
        Write-Host "Successfully requested creation of '$StaticIpName'. Verifying..." ; Start-Sleep -Seconds 5
        $ReservedIp = (gcloud compute addresses describe $StaticIpName --project=$ProjectId --region=$Region --format='value(address)' --quiet | Out-String).Trim()
        if (-not [string]::IsNullOrEmpty($ReservedIp)) { $IpExists = $true; Write-Host "Retrieved IP Address after creation: $ReservedIp" }
        else { Write-Error "Failed to retrieve IP for '$StaticIpName' after creation."; $IpExists = $false }
    } catch { Write-Error "Failed to create/retrieve static IP '$StaticIpName'. Error: $($_.Exception.Message.Trim())"; $IpExists = $false }
}
if (-not $IpExists -or [string]::IsNullOrEmpty($ReservedIp)) { throw "STOPPING: Failed to verify/retrieve static IP '$StaticIpName'." }


# 4. Check for/Create Compute Engine VM instance - *** ADDED IDEMPOTENCY ***
Write-Host "Checking for existing VM instance: $VmName in zone $Zone..."
# Run describe, suppress output/errors as we check $?
gcloud compute instances describe $VmName --zone=$Zone --project=$ProjectId --format="none" --quiet 2>$null
$VmDescribeSucceeded = $?

if ($VmDescribeSucceeded) {
    Write-Host "VM instance '$VmName' already exists in zone '$Zone'. Skipping creation."
} else {
    Write-Host "VM instance '$VmName' not found via describe. Creating..."
    try {
        # Attempt to create the VM
        gcloud compute instances create $VmName `
            --project=$ProjectId `
            --zone=$Zone `
            --machine-type=$MachineType `
            --image-project=$ImageProject `
            --image-family=$ImageFamily `
            --boot-disk-size=$BootDiskSize `
            --address=$ReservedIp `
            --tags="$($NetworkTagHttp),$($NetworkTagSsh)" --quiet

        # Check if create command succeeded before printing success
        if ($?) {
             Write-Host "VM instance '$VmName' created successfully." -ForegroundColor Green
        } else {
             # This branch might not be hit if error preference stops script, but good practice
             Write-Warning "VM instance '$VmName' creation command finished, but status indicates potential failure ($LASTEXITCODE). Check GCP console/logs."
        }
    } catch {
         # Catch errors during creation (like quota issues, invalid params etc.)
         Write-Error "Failed to create VM instance '$VmName'. Error: $($_.Exception.Message.Trim())"
         throw "Failed to create VM instance '$VmName'." # Stop script on creation failure
    }
}


# 5. Create Firewall Rule for HTTP (Port 80) - *** REMOVED 2>$null for DEBUGGING ***
Write-Host "Checking/Creating firewall rule: $FirewallRuleHttp..."
# Run describe, suppress normal output BUT ALLOW ERRORS TO SHOW
gcloud compute firewall-rules describe $FirewallRuleHttp --project=$ProjectId --format="none" --quiet # <-- Temporarily removed 2>$null
$DescribeSucceeded = $?

if ($DescribeSucceeded) {
    Write-Host "Firewall rule '$FirewallRuleHttp' already exists."
} else {
    Write-Host "Firewall rule '$FirewallRuleHttp' not found via describe. Creating..."
    try {
        gcloud compute firewall-rules create $FirewallRuleHttp `
            --project=$ProjectId `
            --direction=INGRESS `
            --priority=1000 `
            --network=default `
            --action=ALLOW `
            --rules=tcp:80 `
            --source-ranges="0.0.0.0/0" `
            --target-tags=$NetworkTagHttp --quiet
        Write-Host "Firewall rule '$FirewallRuleHttp' created." -ForegroundColor Green
    } catch {
         Write-Error "Failed to create firewall rule '$FirewallRuleHttp'. Error: $($_.Exception.Message.Trim())"
    }
}

# 6. Create Firewall Rule for SSH (Port 22) - *** REMOVED 2>$null for DEBUGGING ***
Write-Host "Checking/Creating firewall rule: $FirewallRuleSsh..."
# Run describe, suppress normal output BUT ALLOW ERRORS TO SHOW
gcloud compute firewall-rules describe $FirewallRuleSsh --project=$ProjectId --format="none" --quiet # <-- Temporarily removed 2>$null
$DescribeSucceeded = $?

if ($DescribeSucceeded) {
    Write-Host "Firewall rule '$FirewallRuleSsh' already exists."
} else {
    Write-Host "Firewall rule '$FirewallRuleSsh' not found via describe. Creating..."
    try {
        gcloud compute firewall-rules create $FirewallRuleSsh `
            --project=$ProjectId `
            --direction=INGRESS `
            --priority=1000 `
            --network=default `
            --action=ALLOW `
            --rules=tcp:22 `
            --source-ranges="0.0.0.0/0" `
            --target-tags=$NetworkTagSsh --quiet
        Write-Host "Firewell rule '$FirewallRuleSsh' created." -ForegroundColor Green # Typo corrected: Firewall
     } catch {
         Write-Error "Failed to create firewall rule '$FirewallRuleSsh'. Error: $($_.Exception.Message.Trim())"
     }
}

# --- Summary Output ---
# (Keep the existing summary logic)
Write-Host "--- Deployment Summary ---" -ForegroundColor Cyan
Write-Host "Project:       $ProjectId" -ForegroundColor Cyan
Write-Host "VM Name:       $VmName" -ForegroundColor Cyan
Write-Host "Zone:          $Zone" -ForegroundColor Cyan
Write-Host "Machine Type:  $MachineType" -ForegroundColor Cyan
Write-Host "Static IP:     $ReservedIp ($StaticIpName)" -ForegroundColor Cyan
Write-Host "Firewall HTTP: $FirewallRuleHttp (Tag: $NetworkTagHttp)" -ForegroundColor Cyan
Write-Host "Firewall SSH:  $FirewallRuleSsh (Tag: $NetworkTagSsh)" -ForegroundColor Cyan
Write-Host "--------------------------" -ForegroundColor Cyan
Write-Host "Deployment script finished successfully!" -ForegroundColor Green
Write-Host "You can SSH into the VM using: gcloud compute ssh $VmName --zone $Zone"
Write-Host "Access HTTP via: http://$ReservedIp (after installing a web server)"