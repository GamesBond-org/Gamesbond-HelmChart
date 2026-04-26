# ArgoCD App-of-Apps Implementation Guide

Complete step-by-step instructions to deploy GamesBond microservices using ArgoCD.

## Prerequisites

- Kubernetes cluster (v1.19+) - minikube, EKS, GKE, or any Kubernetes cluster
- `kubectl` CLI installed and configured
- `argocd` CLI installed (optional but recommended)
- GitHub repository with the Gamesbond-HelmChart code

---

## Step 1: Install ArgoCD

### 1.1 Create ArgoCD Namespace
```powershell
kubectl create namespace argocd
```

### 1.2 Install ArgoCD Components
```powershell
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### 1.3 Verify Installation
```powershell
kubectl get pods -n argocd
```

Wait for all pods to be in `Running` state (may take 1-2 minutes).

### 1.4 Install ArgoCD CLI (Optional)
```powershell
# Windows (using Chocolatey)
choco install argocd-cli

# Or download from GitHub
# https://github.com/argoproj/argo-cd/releases
```

---

## Step 2: Create Kubernetes Namespaces

### 2.1 Create Dev Namespace
```powershell
kubectl create namespace dev
```

### 2.2 Create Prod Namespace
```powershell
kubectl create namespace prod
```

### 2.3 Verify Namespaces
```powershell
kubectl get namespaces
```

---

## Step 3: Configure GitHub Repository Access

### 3.1 Create SSH Key (Optional but Recommended)
```powershell
# Generate SSH key
ssh-keygen -t rsa -b 4096 -f ~/.ssh/argocd_key

# Get public key to add to GitHub
Get-Content ~/.ssh/argocd_key.pub
```

### 3.2 Add Public Key to GitHub
1. Go to GitHub → Settings → SSH and GPG keys → New SSH key
2. Paste the public key
3. Save

### 3.3 Create ArgoCD Secret for GitHub Access
```powershell
# Create secret with private key
kubectl create secret generic github-secret \
  -n argocd \
  --from-file=ssh-privatekey=$HOME/.ssh/argocd_key \
  --from-literal=type=git
```

---

## Step 4: Update Repository URLs

### 4.1 Edit All Application Files

Update the repository URL in all YAML files. Replace `yourusername` with your GitHub username.

**Files to update:**
- `argocd/app-of-apps/root-app.yaml`
- `argocd/applications/dev/*.yaml`
- `argocd/applications/prod/*.yaml`

### 4.2 Option A: Using PowerShell
```powershell
# Navigate to argocd folder
cd Gamesbond-HelmChart/argocd

# Replace all occurrences
Get-ChildItem -Recurse -Include "*.yaml" | ForEach-Object {
    (Get-Content $_.FullName) -replace "yourusername", "YOUR_GITHUB_USERNAME" | 
    Set-Content $_.FullName
}

# Verify
Get-ChildItem -Recurse -Include "*.yaml" | 
  Select-String "github.com" | 
  Select-Object -First 5
```

### 4.3 Option B: Manual Edit
Open each file and replace:
```
https://github.com/yourusername/Gamesbond-HelmChart
```
with:
```
https://github.com/YOUR_USERNAME/Gamesbond-HelmChart
```

---

## Step 5: Deploy Root Application

### 5.1 Apply Root Application
```powershell
kubectl apply -f argocd/app-of-apps/root-app.yaml
```

### 5.2 Verify Root Application
```powershell
kubectl get application -n argocd
```

You should see `gamesbond-root` application.

---

## Step 6: Deploy Dev Environment

### 6.1 Apply All Dev Applications
```powershell
kubectl apply -f argocd/applications/dev/kustomization.yaml
```

### 6.2 Monitor Application Status
```powershell
# Watch applications being created
kubectl get applications -n argocd -w

# In another terminal, watch pods
kubectl get pods -n dev -w
```

### 6.3 Wait for All Services to Start

Wait until all pods in the `dev` namespace are in `Running` state. This may take 5-10 minutes.

```powershell
# Check pod status
kubectl get pods -n dev

# Check application sync status
kubectl get application -n argocd
```

### 6.4 Verify All Services
```powershell
# List all services in dev
kubectl get svc -n dev

# Check MongoDB is running
kubectl get statefulset -n dev

# Check Redis deployment
kubectl get deployment -n dev | grep redis

# Check all services
kubectl get all -n dev
```

---

## Step 7: Access ArgoCD Dashboard

### 7.1 Port Forward to ArgoCD UI
```powershell
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

### 7.2 Get Admin Password
```powershell
# Get the password
$password = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
Write-Host "ArgoCD Admin Password: $password"
```

### 7.3 Login to Dashboard
- Open browser: `https://localhost:8080`
- Username: `admin`
- Password: [from above command]

### 7.4 View Applications in Dashboard
1. Click "Applications" in sidebar
2. You'll see all deployed applications
3. Each app shows sync status, health, and resources

---

## Step 8: Test the Deployment

### 8.1 Check MongoDB Connection
```powershell
# Forward MongoDB port
kubectl port-forward -n dev svc/mongo-service 27017:27017

# In another terminal, test connection (if mongosh installed)
mongosh --host localhost --username admin --password password123
```

### 8.2 Check Redis Connection
```powershell
# Forward Redis port
kubectl port-forward -n dev svc/redis-service 6379:6379

# Test with redis-cli (if installed)
redis-cli -h localhost
> ping
```

### 8.3 Check User Service Health
```powershell
# Forward user service port
kubectl port-forward -n dev svc/user-service 4001:4001

# Test health endpoint
Invoke-WebRequest http://localhost:4001/health
```

---

## Step 9: Deploy Production Environment (Optional)

### 9.1 Apply Prod Applications
```powershell
kubectl apply -f argocd/applications/prod/kustomization.yaml
```

### 9.2 Monitor Prod Deployment
```powershell
# Watch prod pods
kubectl get pods -n prod -w

# Check prod applications
kubectl get application -n argocd | grep prod
```

---

## Step 10: Configure Auto-Sync and Notifications (Optional)

### 10.1 Enable GitHub Webhook (For Auto-Sync)

1. Go to GitHub repo → Settings → Webhooks → Add webhook
2. Payload URL: `https://argocd.yourdomain.com/api/webhook`
3. Content type: `application/json`
4. Events: Select "Push events"
5. Save

### 10.2 Setup Slack Notifications (Optional)

```powershell
# Create Slack webhook notification
kubectl set env deployment/argocd-application-controller \
  -n argocd \
  ARGOCD_NOTIFICATION_WEBHOOK_URL=YOUR_SLACK_WEBHOOK_URL
```

---

## Troubleshooting

### Problem: Applications stuck in "OutOfSync"
```powershell
# Force sync
kubectl patch application gamesbond-root -n argocd -p '{"metadata":{"finalizers":null}}' --type merge

# Or via CLI
argocd app sync gamesbond-root --force
```

### Problem: Pods not starting
```powershell
# Check pod logs
kubectl logs -n dev deployment/user-service --tail=50

# Check events
kubectl describe pod -n dev -l app=user-service

# Check configmap
kubectl get configmap -n dev
kubectl describe configmap user-service-devconfig -n dev
```

### Problem: ImagePullBackOff
```powershell
# Images may not exist or be private
# Use ArgoCD UI to check image URLs
# Verify image names match your Docker registry
```

### Problem: Connection refused errors
```powershell
# Check MONGO_URL and REDIS_URL in configmaps
kubectl get configmap user-service-devconfig -n dev -o yaml

# Should show:
# MONGO_URL: mongodb://admin:password123@mongo-service.dev.svc.cluster.local:27017/user_db?authSource=admin
# REDIS_URL: redis://redis-service.dev.svc.cluster.local:6379
```

---

## Useful Commands

### Monitoring
```powershell
# Watch all applications
kubectl get applications -n argocd -w

# Get application details
kubectl describe application gamesbond-root -n argocd

# Check ArgoCD logs
kubectl logs -n argocd deployment/argocd-application-controller --tail=50

# View resource events
kubectl get events -n dev --sort-by='.lastTimestamp'
```

### Management
```powershell
# Sync all apps
kubectl patch application gamesbond-root -n argocd -p '{"spec":{"syncPolicy":{"syncOptions":["Refresh=hard"]}}}' --type merge

# Delete all applications
kubectl delete applications --all -n argocd

# Rollback application
kubectl patch application gamesbond-user-service-dev -n argocd -p '{"spec":{"source":{"targetRevision":"HEAD~1"}}}' --type merge
```

### Debugging
```powershell
# Get all resources in dev namespace
kubectl get all -n dev

# Check ConfigMaps
kubectl get configmap -n dev

# Check Secrets
kubectl get secret -n dev

# Check PVC status
kubectl get pvc -n dev
```

---

## Next Steps

After successful deployment:

1. **Configure Ingress**
   - Set up Ingress controller
   - Configure Gateway API routing
   - Map domain names

2. **Setup Monitoring**
   - Install Prometheus
   - Install Grafana
   - Create dashboards

3. **Configure Backup**
   - Backup MongoDB data regularly
   - Backup etcd

4. **Enable RBAC**
   - Create ArgoCD users
   - Set per-project permissions

5. **Setup CI/CD**
   - GitHub Actions or GitLab CI
   - Auto-build and push Docker images
   - ArgoCD auto-syncs with new versions

---

## Success Criteria

✅ All namespaces created (dev, prod)  
✅ ArgoCD installed and running  
✅ All applications show in ArgoCD UI  
✅ All pods in dev namespace are Running  
✅ MongoDB StatefulSet is Ready  
✅ Redis Deployment is Ready  
✅ All services have Endpoints  
✅ Services can communicate (health checks pass)  

---

## Quick Reference

| Task | Command |
|------|---------|
| Install ArgoCD | `kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml` |
| Deploy all dev apps | `kubectl apply -f argocd/applications/dev/kustomization.yaml` |
| Check application status | `kubectl get applications -n argocd` |
| View ArgoCD UI | `kubectl port-forward svc/argocd-server -n argocd 8080:443` |
| Get admin password | `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" \| base64 -d` |
| View pod logs | `kubectl logs -n dev deployment/user-service` |
| Delete all apps | `kubectl delete applications --all -n argocd` |

---

## Support

If you encounter issues:

1. Check pod logs: `kubectl logs -n dev [pod-name]`
2. Check events: `kubectl get events -n dev --sort-by='.lastTimestamp'`
3. Check ArgoCD application status: `kubectl describe application [app-name] -n argocd`
4. Review this guide's troubleshooting section
