# PowerShell deployment script for ArgoCD App-of-Apps

param(
    [ValidateSet("dev", "prod", "both")]
    [string]$Environment = "dev"
)

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $colors = @{
        "INFO"    = "Cyan"
        "SUCCESS" = "Green"
        "WARNING" = "Yellow"
        "ERROR"   = "Red"
    }
    $color = $colors[$Level]
    Write-Host "[$Level] $Message" -ForegroundColor $color
}

Write-Log "🚀 Deploying GamesBond ArgoCD App-of-Apps (Environment: $Environment)"

# Check if ArgoCD namespace exists
Write-Log "Checking ArgoCD installation..."
$argocdNs = kubectl get namespace argocd -o json 2>$null
if (-not $argocdNs) {
    Write-Log "Installing ArgoCD..." "WARNING"
    kubectl create namespace argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    Write-Log "ArgoCD installed" "SUCCESS"
}
else {
    Write-Log "ArgoCD namespace found" "SUCCESS"
}

# Wait for ArgoCD
Write-Log "Waiting for ArgoCD to be ready..." "WARNING"
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Create namespaces
Write-Log "Creating Kubernetes namespaces..."
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -
if ($Environment -eq "prod" -or $Environment -eq "both") {
    kubectl create namespace prod --dry-run=client -o yaml | kubectl apply -f -
}
Write-Log "Namespaces created" "SUCCESS"

# Deploy root application
Write-Log "Deploying root application..."
kubectl apply -f app-of-apps/root-app.yaml
Write-Log "Root application deployed" "SUCCESS"

# Deploy dev applications
if ($Environment -eq "dev" -or $Environment -eq "both") {
    Write-Log "Deploying dev applications..."
    kubectl apply -f applications/dev/kustomization.yaml
    Write-Log "Dev applications deployed" "SUCCESS"
}

# Deploy prod applications
if ($Environment -eq "prod" -or $Environment -eq "both") {
    Write-Log "Deploying prod applications..."
    kubectl apply -f applications/prod/kustomization.yaml
    Write-Log "Prod applications deployed" "SUCCESS"
}

# Display next steps
Write-Log ""
Write-Log "🎉 Deployment complete!" "SUCCESS"
Write-Log ""
Write-Log "📋 Next steps:" "WARNING"
Write-Log "1. Port forward to ArgoCD UI:"
Write-Log "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
Write-Log ""
Write-Log "2. Get admin password:"
Write-Log "   `$password = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
Write-Log ""
Write-Log "3. Access ArgoCD at: https://localhost:8080"
Write-Log ""
Write-Log "📊 Check application status:" "WARNING"
Write-Log "   kubectl get applications -n argocd"
Write-Log "   argocd app list"
