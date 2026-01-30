# Sample .NET API for Azure AKS

A sample .NET 8 Web API application configured for deployment to Azure Kubernetes Service (AKS).

## Prerequisites

Before deploying, ensure you have the following installed:

1. **[.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)** - To build and run locally
2. **[Docker Desktop](https://www.docker.com/products/docker-desktop)** - To build container images
3. **[Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)** - To interact with Azure
4. **[kubectl](https://kubernetes.io/docs/tasks/tools/)** - To manage Kubernetes

## Project Structure

```
├── Program.cs              # Main application entry point
├── SampleApi.csproj        # Project file
├── appsettings.json        # Application settings
├── Dockerfile              # Container build instructions
├── deploy-to-aks.ps1       # Automated deployment script
└── k8s/
    ├── namespace.yaml      # Kubernetes namespace
    ├── deployment.yaml     # Kubernetes deployment
    └── service.yaml        # Kubernetes service (LoadBalancer)
```

## API Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /` | Root endpoint - returns welcome message |
| `GET /health` | Health check endpoint for Kubernetes probes |
| `GET /weatherforecast` | Sample weather forecast data |
| `GET /swagger` | Swagger UI (Development only) |

## Local Development

```powershell
# Restore dependencies
dotnet restore

# Run the application
dotnet run

# Application will be available at http://localhost:5000
```

## Deploy to Azure AKS

### Option 1: Automated Deployment (Recommended)

```powershell
.\deploy-to-aks.ps1 -ResourceGroup "your-rg" -AcrName "youracr" -AksClusterName "your-aks"
```

### Option 2: Manual Deployment

#### Step 1: Login to Azure

```powershell
az login
```

#### Step 2: Create Azure Container Registry (if needed)

```powershell
# Set variables
$RESOURCE_GROUP="your-resource-group"
$ACR_NAME="youracrname"
$AKS_NAME="your-aks-cluster"
$LOCATION="eastus"

# Create ACR
az acr create --resource-group $RESOURCE_GROUP --name $ACR_NAME --sku Basic
```

#### Step 3: Build and Push Docker Image

```powershell
# Login to ACR
az acr login --name $ACR_NAME

# Build image
docker build -t "$ACR_NAME.azurecr.io/sample-api:latest" .

# Push image
docker push "$ACR_NAME.azurecr.io/sample-api:latest"
```

#### Step 4: Configure AKS to Pull from ACR

```powershell
# Attach ACR to AKS (allows AKS to pull images from ACR)
az aks update -n $AKS_NAME -g $RESOURCE_GROUP --attach-acr $ACR_NAME
```

#### Step 5: Get AKS Credentials

```powershell
az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_NAME
```

#### Step 6: Update Deployment Manifest

Edit `k8s/deployment.yaml` and replace `<your-acr-name>` with your actual ACR name.

#### Step 7: Deploy to AKS

```powershell
# Create namespace
kubectl apply -f k8s/namespace.yaml

# Deploy application
kubectl apply -f k8s/deployment.yaml -n sample-api
kubectl apply -f k8s/service.yaml -n sample-api
```

#### Step 8: Get External IP

```powershell
kubectl get svc sample-api-service -n sample-api --watch
```

Wait for the `EXTERNAL-IP` to be assigned, then access your API at `http://<EXTERNAL-IP>/`

## Useful kubectl Commands

```powershell
# Check pod status
kubectl get pods -n sample-api

# View pod logs
kubectl logs -l app=sample-api -n sample-api

# Describe deployment
kubectl describe deployment sample-api -n sample-api

# Scale deployment
kubectl scale deployment sample-api --replicas=3 -n sample-api

# Delete everything
kubectl delete namespace sample-api
```

## Troubleshooting

### Image Pull Errors
If pods fail with `ImagePullBackOff`, ensure AKS is attached to ACR:
```powershell
az aks update -n $AKS_NAME -g $RESOURCE_GROUP --attach-acr $ACR_NAME
```

### Pod CrashLoopBackOff
Check pod logs for errors:
```powershell
kubectl logs <pod-name> -n sample-api
```

### Service No External IP
If using a development cluster, you may need to use `NodePort` instead of `LoadBalancer` in `service.yaml`.

