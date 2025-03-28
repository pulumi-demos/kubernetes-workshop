# Workshop Exercise 4: Managing Custom Resources (CRDs)

## Goal

In this exercise, you will learn how to manage Kubernetes Custom Resource Definitions (CRDs) using Pulumi. You'll use the crd2pulumi tool to generate strongly-typed Python classes from cert-manager CRDs and then use those classes to deploy custom resources (ClusterIssuer, Certificate) to your cluster. This exercise uses a new Pulumi project.

## Prerequisites

- Access to a Kubernetes cluster (like the one from Exercise 1/2, or any other cluster).
- Your kubectl command is configured to point to your target Kubernetes cluster.
- Pulumi CLI installed and logged in.
- Python 3.7+ installed.
- crd2pulumi tool installed:
  - macOS: Use Homebrew: `brew install pulumi/tap/crd2pulumi`
  - Other OS: Download the appropriate binary from the crd2pulumi Releases page and ensure it's in your system's PATH.
  (Note: `npm install -g crd2pulumi` is NOT the correct installation method as per the official README).
- wget command available: Needed by the generation script (usually pre-installed on Linux/macOS; Windows users might need to install it or adapt the script).

## Step 1: Set Up a New Pulumi Project

We'll start a fresh project for managing CRDs. Do not use the projects from previous exercises.

Create a new directory for this exercise and navigate into it:

```bash
mkdir pulumi-crd-example && cd pulumi-crd-example
```

Create a new Pulumi Python project:

```bash
pulumi new python --name pulumi-crd-example --description "Manage K8s CRDs (cert-manager) with crd2pulumi"
# Accept defaults when prompted
```

Install the Pulumi Kubernetes SDK:

```bash
pip install pulumi-kubernetes
```

## Step 2: Review the CRD Generation Script

The script [generate.sh](generate.sh) is provided to download the cert-manager CRDs and generate the Pulumi Python types.

### Script Explanation

- It creates a crds directory.
- It downloads the YAML definitions for cert-manager's CRDs.
- It runs crd2pulumi specifying the output path (--pythonPath ./) and the desired package name (--pythonName certmanager). This generates Python classes based on these CRDs, placing them in a ./pulumi_certmanager directory. The --force flag allows overwriting existing generated files.

## Step 3: Run the Generation Script

Execute the script to download the CRDs and generate the Pulumi Python types:

```bash
# Make the script executable
chmod +x generate.sh

# Run the script
./generate.sh
```

After this script completes, you should have a pulumi_certmanager directory in your project, containing the generated Python code.

## Step 4: Write the Pulumi Python Code (__main__.py)

Open the __main__.py file in your project directory.

Replace its contents with the following Python code. This code first deploys cert-manager using Helm (which installs the CRDs into the cluster) and then uses the generated types to create custom resources.

```python
import pulumi
import pulumi_kubernetes as k8s
import pulumi_kubernetes.meta.v1 as meta
from pulumi_kubernetes.helm.v3 import Release, ReleaseArgs, RepositoryOptsArgs

# Import the generated cert-manager types
# The 'generate.sh' script created the 'pulumi_certmanager' directory
# The structure allows importing the specific API version module (v1)
from pulumi_certmanager.certmanager import v1 as certmanagerv1

# --- Step 1: Deploy cert-manager itself using Helm ---
# This is required to install the actual CRDs into the cluster before we can create
# custom resources based on them.
cert_manager_release = Release("cert-manager",
    ReleaseArgs(
        chart="cert-manager",
        repository_opts=RepositoryOptsArgs(
            repo="https://charts.jetstack.io",
        ),
        namespace="cert-manager", # Deploy into its own namespace
        version="v1.15.3", # Match the CRD version downloaded
        create_namespace=True, # Have Helm create the namespace
        # CRITICAL: Ensure Helm installs the CRDs.
        # If this is false, the subsequent resources will fail.
        values={
            "installCRDs": True,
        },
        # Wait for Helm resources to be ready before proceeding
        wait=True,
    )
)

# --- Step 2: Create a self-signed ClusterIssuer ---
# This uses the generated types from crd2pulumi
# A ClusterIssuer is a cert-manager resource that represents a certificate authority
self_signed_issuer = certmanagerv1.ClusterIssuer(
    "selfsigned-issuer",
    metadata=meta.ObjectMetaArgs(
        name="selfsigned-issuer",
    ),
    spec=certmanagerv1.ClusterIssuerSpecArgs(
        self_signed={}, # Empty dict is sufficient for self-signed
    ),
    # Important: This depends on the cert-manager Helm release
    # to ensure cert-manager is fully deployed before creating this resource
    opts=pulumi.ResourceOptions(depends_on=[cert_manager_release])
)

# --- Step 3: Create a Certificate ---
# This will use our self-signed issuer to create a certificate
example_cert = certmanagerv1.Certificate(
    "example-cert",
    metadata=meta.ObjectMetaArgs(
        name="example-com",
        namespace="default", # Create in the default namespace
    ),
    spec=certmanagerv1.CertificateSpecArgs(
        # The secret name where the certificate will be stored
        secret_name="example-com-tls",
        # Duration the certificate is valid for
        duration="2160h", # 90 days
        # Renew before expiration
        renew_before="360h", # 15 days
        # Common Name and DNS names for the certificate
        common_name="example.com",
        dns_names=["example.com", "www.example.com"],
        # Reference to our ClusterIssuer
        issuer_ref=certmanagerv1.CertificateSpecIssuerRefArgs(
            name=self_signed_issuer.metadata.name,
            kind="ClusterIssuer",
        ),
        # PKCS1 or PKCS8 private key encoding
        private_key=certmanagerv1.CertificateSpecPrivateKeyArgs(
            algorithm="RSA",
            size=2048,
        ),
    ),
    # This depends on our ClusterIssuer
    opts=pulumi.ResourceOptions(depends_on=[self_signed_issuer])
)

# Export the name of the certificate secret
pulumi.export("certificate_secret_name", example_cert.spec.secret_name)
```

### Code Explanation

1. **Imports__: We import the standard Pulumi Kubernetes packages and the generated cert-manager types.

2. **Deploy cert-manager__: We use the Helm Release resource to deploy cert-manager itself, which installs the actual CRD implementations into the cluster.

3. **Create a ClusterIssuer__: We use the generated `certmanagerv1.ClusterIssuer` type to create a self-signed certificate issuer.

4. **Create a Certificate__: We use the generated `certmanagerv1.Certificate` type to create a certificate for example.com, signed by our self-signed issuer.

5. **Export__: We export the name of the secret where the certificate will be stored.

## Step 5: Deploy the Stack

Now you can deploy your stack to create the resources in your Kubernetes cluster:

```bash
pulumi up
```

Review the proposed changes and confirm the deployment.

## Step 6: Verify the Resources

After deployment completes, you can verify that the resources were created:

```bash
# Check that cert-manager pods are running
kubectl get pods -n cert-manager

# Check that our ClusterIssuer exists
kubectl get clusterissuers

# Check that our Certificate exists and is ready
kubectl get certificates -n default

# Check the generated secret with the certificate
kubectl get secret example-com-tls -n default
```

## Conclusion

In this exercise, you've learned how to:

1. Use crd2pulumi to generate strongly-typed Pulumi classes from Kubernetes CRDs
2. Deploy cert-manager using Helm via Pulumi
3. Create and manage custom resources (ClusterIssuer, Certificate) using the generated types

This approach gives you type safety and IDE auto-completion when working with custom resources, making it easier to create and manage them correctly.

## Clean Up

When you're done with the exercise, you can clean up the resources:

```bash
pulumi destroy
```

Confirm the destruction when prompted.
