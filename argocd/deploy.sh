#!/bin/bash

# Deploy GamesBond ArgoCD App-of-Apps

set -e

echo "🚀 Deploying GamesBond ArgoCD App-of-Apps..."

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if ArgoCD is installed
echo -e "${YELLOW}Checking if ArgoCD is installed...${NC}"
if ! kubectl get namespace argocd &> /dev/null; then
    echo -e "${YELLOW}Installing ArgoCD...${NC}"
    kubectl create namespace argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    echo -e "${GREEN}✓ ArgoCD installed${NC}"
else
    echo -e "${GREEN}✓ ArgoCD namespace exists${NC}"
fi

# Wait for ArgoCD to be ready
echo -e "${YELLOW}Waiting for ArgoCD to be ready...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Create dev and prod namespaces
echo -e "${YELLOW}Creating namespaces...${NC}"
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace prod --dry-run=client -o yaml | kubectl apply -f -
echo -e "${GREEN}✓ Namespaces created${NC}"

# Deploy root application
echo -e "${YELLOW}Deploying root application...${NC}"
kubectl apply -f app-of-apps/root-app.yaml
echo -e "${GREEN}✓ Root application deployed${NC}"

# Deploy dev applications
echo -e "${YELLOW}Deploying dev applications...${NC}"
kubectl apply -f applications/dev/kustomization.yaml
echo -e "${GREEN}✓ Dev applications deployed${NC}"

# Deploy prod applications (optional)
read -p "Deploy production applications? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Deploying prod applications...${NC}"
    kubectl apply -f applications/prod/kustomization.yaml
    echo -e "${GREEN}✓ Prod applications deployed${NC}"
fi

# Get initial admin password
echo ""
echo -e "${GREEN}ArgoCD deployed successfully!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Port forward to ArgoCD UI:"
echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo ""
echo "2. Get admin password:"
echo "   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
echo ""
echo "3. Access ArgoCD at: https://localhost:8080"
echo ""
echo -e "${YELLOW}Check application status:${NC}"
echo "   kubectl get applications -n argocd"
echo "   argocd app list"
