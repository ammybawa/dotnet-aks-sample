# Azure AKS Deployment Script for Sample .NET API
# Prerequisites: Azure CLI, Docker, kubectl

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory=$true)]
    [string]$AcrName,
    
    [Parameter(Mandatory=$true)]
    [string]$AksClusterName,
    
    [string]$ImageTag = "latest",
    
    [string]$Namespace = "sample-api"
)

$ErrorActionPreference = "Stop"

Write-Host "=== Azure AKS Deployment Script ===" -ForegroundColor Cyan

# Step 1: Login to Azure (if not already logged in)
Write-Host "`n[1/6] Checking Azure login..." -ForegroundColor Yellow
$account = az account show 2>$null | ConvertFrom-Json
if (-not $account) {
    Write-Host "Please login to Azure..."
    az login
}
Write-Host "Logged in as: $($account.user.name)" -ForegroundColor Green

# Step 2: Login to Azure Container Registry
Write-Host "`n[2/6] Logging into Azure Container Registry..." -ForegroundColor Yellow
az acr login --name $AcrName

# Step 3: Build and push Docker image
Write-Host "`n[3/6] Building Docker image..." -ForegroundColor Yellow
$imageFullName = "$AcrName.azurecr.io/sample-api:$ImageTag"
docker build -t $imageFullName .

Write-Host "`n[4/6] Pushing image to ACR..." -ForegroundColor Yellow
docker push $imageFullName

# Step 4: Get AKS credentials
Write-Host "`n[5/6] Getting AKS credentials..." -ForegroundColor Yellow
az aks get-credentials --resource-group $ResourceGroup --name $AksClusterName --overwrite-existing

# Step 5: Update deployment manifest with correct image
Write-Host "`n[6/6] Deploying to AKS..." -ForegroundColor Yellow

# Create namespace if it doesn't exist
kubectl apply -f k8s/namespace.yaml

# Update deployment.yaml with actual ACR name and apply
$deploymentContent = Get-Content -Path "k8s/deployment.yaml" -Raw
$updatedDeployment = $deploymentContent -replace "<your-acr-name>", $AcrName
$updatedDeployment | kubectl apply -n $Namespace -f -

# Apply service
kubectl apply -n $Namespace -f k8s/service.yaml

Write-Host "`n=== Deployment Complete ===" -ForegroundColor Green
Write-Host "`nWaiting for external IP..." -ForegroundColor Yellow

# Wait for external IP
$attempts = 0
$maxAttempts = 30
do {
    $service = kubectl get svc sample-api-service -n $Namespace -o json 2>$null | ConvertFrom-Json
    $externalIP = $service.status.loadBalancer.ingress[0].ip
    if (-not $externalIP) {
        Write-Host "." -NoNewline
        Start-Sleep -Seconds 10
        $attempts++
    }
} while (-not $externalIP -and $attempts -lt $maxAttempts)

Write-Host ""
if ($externalIP) {
    Write-Host "`nApplication is available at: http://$externalIP" -ForegroundColor Green
    Write-Host "Health check: http://$externalIP/health" -ForegroundColor Green
    Write-Host "Weather API: http://$externalIP/weatherforecast" -ForegroundColor Green
} else {
    Write-Host "`nExternal IP not yet assigned. Check with:" -ForegroundColor Yellow
    Write-Host "kubectl get svc sample-api-service -n $Namespace"
}

Write-Host "`n=== Useful Commands ===" -ForegroundColor Cyan
Write-Host "Check pods:     kubectl get pods -n $Namespace"
Write-Host "Check services: kubectl get svc -n $Namespace"
Write-Host "View logs:      kubectl logs -l app=sample-api -n $Namespace"
Write-Host "Delete all:     kubectl delete namespace $Namespace"

