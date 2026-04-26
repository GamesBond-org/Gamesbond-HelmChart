# ArgoCD Quick Reference

## Folder Structure

```
argocd/
├── README.md                      # Complete documentation
├── deploy.sh                      # Linux/Mac deployment script
├── deploy.ps1                     # PowerShell deployment script
├── app-of-apps/
│   └── root-app.yaml             # Root application (entry point)
└── applications/
    ├── dev/
    │   ├── kustomization.yaml    # Kustomize config for dev
    │   └── [service-apps]        # Individual service applications
    └── prod/
        ├── kustomization.yaml    # Kustomize config for prod
        └── [service-apps]        # Individual service applications
```

## One-Liner Deployment Commands

### Deploy Everything (Dev)
```bash
# Linux/Mac
bash deploy.sh dev

# PowerShell
./deploy.ps1 -Environment dev
```

### Deploy Everything (Dev + Prod)
```bash
# Linux/Mac
bash deploy.sh both

# PowerShell
./deploy.ps1 -Environment both
```

### Manual Kubectl Commands
```bash
# Deploy root app only
kubectl apply -f app-of-apps/root-app.yaml

# Deploy all dev apps
kubectl apply -f applications/dev/kustomization.yaml

# Deploy all prod apps
kubectl apply -f applications/prod/kustomization.yaml
```

## Monitor Deployment

```bash
# Watch all applications
kubectl get applications -n argocd -w

# Get detailed status
argocd app list
argocd app status gamesbond-root

# Check specific application
kubectl describe application gamesbond-user-service-dev -n argocd

# View logs
kubectl logs -n argocd deployment/argocd-application-controller
```

## Sync & Rollback

```bash
# Manual sync
argocd app sync gamesbond-root

# Sync with force (discard local changes)
argocd app sync gamesbond-root --force

# Show history
argocd app history gamesbond-root

# Rollback to previous sync
argocd app rollback gamesbond-root 1
```

## Access ArgoCD UI

```bash
# Port forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# URL: https://localhost:8080
# Username: admin
# Password: [from above command]
```

## Update Helm Values

### Method 1: Edit values files directly
```bash
# Edit devvalues.yaml or prodvalues.yaml
# Push to git
# ArgoCD auto-syncs
```

### Method 2: Update via ArgoCD UI
```bash
# 1. Access ArgoCD UI
# 2. Select application
# 3. Edit parameters
# 4. Sync
```

### Method 3: ArgoCD CLI
```bash
# Update replica count
argocd app set gamesbond-user-service-dev -p service.replicas=3
argocd app sync gamesbond-user-service-dev
```

## Debugging

### App won't sync
```bash
# Check application logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller

# Check application events
kubectl describe application gamesbond-user-service-dev -n argocd | tail -20
```

### Resources not deploying
```bash
# Check if Helm can render the chart
helm template gamesbond ./templates/services/user-service -f templates/services/user-service/values.yaml

# Check if resources exist
kubectl get all -n dev
```

### Clear sync/error status
```bash
# Delete and recreate application
kubectl delete application gamesbond-user-service-dev -n argocd
kubectl apply -f applications/dev/user-service-app.yaml
```

## Key Concepts

| Term | Explanation |
|------|---|
| **App of Apps** | Root app manages multiple apps (this pattern) |
| **Helm Charts** | Templates for deploying services |
| **Kustomization** | Combines multiple resources (used for dev/prod) |
| **Sync Policy** | How ArgoCD keeps cluster in sync with git |
| **Auto Sync** | Automatically deploy changes from git |
| **Self-Heal** | Restore resources if manually deleted |
| **Prune** | Delete resources if removed from git |

## Environment Differences

### Dev
- Namespaces: `dev`
- Replicas: 1 per service
- MongoDB storage: 5Gi
- Auto-sync: Enabled

### Prod
- Namespaces: `prod`
- Replicas: 3 per service
- MongoDB storage: 50Gi
- Auto-sync: Enabled
- More resources allocated

## Add New Service

1. Create Helm chart in `templates/services/new-service/`
2. Create applications file: `argocd/applications/dev/new-service-app.yaml`
3. Create applications file: `argocd/applications/prod/new-service-app.yaml`
4. Add to `kustomization.yaml` in both dev and prod
5. Push to git
6. ArgoCD auto-syncs

## Delete Everything

```bash
# Delete all applications (cascades to all resources)
kubectl delete applications --all -n argocd

# Or delete specific namespace
kubectl delete namespace dev
kubectl delete namespace prod
```

## Common Tasks

| Task | Command |
|------|---------|
| Deploy all services | `kubectl apply -f applications/dev/kustomization.yaml` |
| Sync apps | `argocd app sync gamesbond-root` |
| Check status | `argocd app list` |
| Get admin password | `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" \| base64 -d` |
| Delete all apps | `kubectl delete applications -n argocd --all` |
| View logs | `kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller` |
