# GamesBond ArgoCD App-of-Apps

This folder contains the ArgoCD GitOps configurations for the GamesBond microservices platform using the "app of apps" pattern.

## Architecture

```
argocd/
├── app-of-apps/
│   └── root-app.yaml          # Root application that manages all other apps
├── applications/
│   ├── dev/
│   │   ├── kustomization.yaml # Kustomization for dev apps
│   │   ├── mongodb-app.yaml
│   │   ├── redis-app.yaml
│   │   ├── network-app.yaml
│   │   ├── user-service-app.yaml
│   │   ├── player-service-app.yaml
│   │   ├── team-service-app.yaml
│   │   ├── tournament-service-app.yaml
│   │   ├── ground-service-app.yaml
│   │   ├── shop-service-app.yaml
│   │   ├── admin-service-app.yaml
│   │   └── frontend-app.yaml
│   └── prod/
│       ├── kustomization.yaml # Kustomization for prod apps
│       └── [same structure as dev]
```

## How It Works

### App of Apps Pattern

1. **Root Application** (`root-app.yaml`) manages all other applications
2. **Environment Applications** (dev, prod) are individual ArgoCD Applications
3. **Service Applications** deploy specific Helm charts for each microservice

```
root-app (argocd) 
  ↓
  ├→ mongodb-app (dev namespace)
  ├→ redis-app (dev namespace)
  ├→ network-app (dev namespace)
  ├→ user-service-app (dev namespace)
  ├→ player-service-app (dev namespace)
  └→ [all other services]
```

## Prerequisites

- ArgoCD installed on your cluster
- Kubernetes cluster with `dev` and `prod` namespaces
- GitHub repository cloned with this path

## Installation Steps

### 1. Install ArgoCD (if not already installed)

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### 2. Update Repository URL

Edit the `repoURL` in all files to point to your GitHub repository:

```bash
# Find and replace
sed -i 's|https://github.com/yourusername/Gamesbond-HelmChart|YOUR_REPO_URL|g' argocd/**/*.yaml
```

### 3. Deploy Root Application

```bash
kubectl apply -f argocd/app-of-apps/root-app.yaml
```

### 4. Deploy Development Environment

```bash
kubectl apply -f argocd/applications/dev/
```

### 5. Deploy Production Environment

```bash
kubectl apply -f argocd/applications/prod/
```

### 6. Access ArgoCD UI

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Access at https://localhost:8080
# Default password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Deployment Flow

### Development Deployment
```bash
# Single command deploys all dev services
kubectl apply -f argocd/applications/dev/kustomization.yaml

# ArgoCD automatically:
# - Creates dev namespace
# - Deploys MongoDB, Redis
# - Deploys all microservices (1 replica each)
# - Sets up networking/gateway
```

### Production Deployment
```bash
# Single command deploys all prod services with higher replicas
kubectl apply -f argocd/applications/prod/kustomization.yaml

# ArgoCD automatically:
# - Creates prod namespace
# - Deploys MongoDB, Redis
# - Deploys all microservices (3 replicas each)
# - Sets up networking/gateway
```

## Key Features

✅ **Single Root App** - Deploy entire platform with one command  
✅ **Environment Segregation** - Dev and prod in separate namespaces  
✅ **Automatic Sync** - GitOps: changes in repo automatically deployed  
✅ **Self-Healing** - Automatically corrects drift from desired state  
✅ **Helm Integration** - Uses Helm charts with environment overrides  
✅ **Kustomization** - Combines multiple apps using Kustomize  

## Monitoring

```bash
# Check root application status
kubectl get application gamesbond-root -n argocd

# Check all applications
kubectl get applications -n argocd

# Watch sync progress
argocd app list
argocd app sync gamesbond-root

# Get detailed status
kubectl describe application gamesbond-root -n argocd
```

## Updating Services

1. Update Helm chart in `templates/` folder
2. Push changes to git
3. ArgoCD automatically detects and syncs changes
4. Services redeploy with new configuration

```bash
# Or manually sync
argocd app sync gamesbond-root
```

## Rollback

```bash
# ArgoCD maintains history of syncs
argocd app history gamesbond-root

# Rollback to previous sync
argocd app rollback gamesbond-root 1
```

## Delete Everything

```bash
# Delete all applications (cascades to resources)
kubectl delete application -n argocd --all

# Or delete specific environment
kubectl delete application -n argocd -l env=dev
```

## Troubleshooting

### App stuck in "OutOfSync"
```bash
# Manual sync
argocd app sync gamesbond-root --force
```

### Resources not deploying
```bash
# Check ArgoCD logs
kubectl logs -n argocd deployment/argocd-application-controller

# Check application details
kubectl describe application gamesbond-user-service-dev -n argocd
```

### Permission denied errors
```bash
# Ensure argocd service account has permissions
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: argocd-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: argocd-application-controller
  namespace: argocd
EOF
```

## Best Practices

1. **Use GitOps** - Make all changes via git commits
2. **Auto-sync enabled** - Keeps cluster in sync with repo
3. **Prune enabled** - Removes resources deleted from git
4. **Self-heal enabled** - Recovers from manual changes
5. **Separate values** - Use devvalues.yaml and prodvalues.yaml

## Next Steps

- Set up GitHub webhook for automatic triggers
- Configure ArgoCD notifications (Slack, teams)
- Add Prometheus/Grafana monitoring
- Set up image update automation
