#!/usr/bin/env sh

# Create a directory for CRD YAML files
mkdir -p crds

# Download cert-manager CRD definitions for a specific version (e.g., v1.15.3)
echo "Downloading cert-manager CRDs..."
wget -q -O crds/crd-certificaterequests.yaml https://github.com/cert-manager/cert-manager/raw/refs/tags/v1.15.3/deploy/crds/crd-certificaterequests.yaml
wget -q -O crds/crd-certificates.yaml https://github.com/cert-manager/cert-manager/raw/refs/tags/v1.15.3/deploy/crds/crd-certificates.yaml
wget -q -O crds/crd-challenges.yaml https://github.com/cert-manager/cert-manager/raw/refs/tags/v1.15.3/deploy/crds/crd-challenges.yaml
wget -q -O crds/crd-clusterissuers.yaml https://github.com/cert-manager/cert-manager/raw/refs/tags/v1.15.3/deploy/crds/crd-clusterissuers.yaml
wget -q -O crds/crd-issuers.yaml https://github.com/cert-manager/cert-manager/raw/refs/tags/v1.15.3/deploy/crds/crd-issuers.yaml
wget -q -O crds/crd-orders.yaml https://github.com/cert-manager/cert-manager/raw/refs/tags/v1.15.3/deploy/crds/crd-orders.yaml
echo "Downloads complete."

# Generate strongly-typed Python code from the CRDs using crd2pulumi
echo "Generating Pulumi Python types using crd2pulumi..."
crd2pulumi \
   --pythonPath ./ \
   --pythonName certmanager \
   --force \
   ./crds/crd-orders.yaml \
   ./crds/crd-issuers.yaml \
   ./crds/crd-clusterissuers.yaml \
   ./crds/crd-challenges.yaml \
   ./crds/crd-certificates.yaml \
   ./crds/crd-certificaterequests.yaml
echo "Pulumi types generated in './pulumi_certmanager' directory."