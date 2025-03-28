# Workshop Exercise 3: Deploying Applications with Helm Charts

## Goal

In this exercise, you will deploy applications to your existing Kubernetes cluster using Helm charts with Pulumi. You will explore two different approaches: using the kubernetes.helm.v3.Chart resource and the kubernetes.helm.v3.Release resource. This exercise uses a new Pulumi project.

## Prerequisites

- Completed Workshop Exercise 1 & 2 OR have access to any Kubernetes cluster.
- Your kubectl command is configured to point to your target Kubernetes cluster (Pulumi will use this same configuration by default).
- Pulumi CLI installed and logged in.
- Python 3.7+ installed.

## Step 1: Set Up a New Pulumi Project

Since we are exploring different ways to deploy Helm charts, let's start a fresh project. Do not use the project from Exercise 1 & 2.

Create a new directory for this exercise and navigate into it:

```bash
mkdir pulumi-helm-deploy && cd pulumi-helm-deploy
```

Create a new Pulumi Python project:

```bash
pulumi new python --name pulumi-helm-deploy --description "Deploy Helm charts using Chart and Release resources"
# Accept defaults when prompted
```

Install the Pulumi Kubernetes SDK:

```bash
pip install pulumi-kubernetes
```

## Step 2: Write the Pulumi Python Code (__main__.py)

Open the __main__.py file created in the new project directory.

Replace its contents with the following Python code. This code defines deployments using both Chart and Release.

```python
import pulumi
import pulumi_kubernetes as k8s
from pulumi_kubernetes.helm.v3 import Chart, ChartOpts, FetchOpts, Release, ReleaseArgs, RepositoryOptsArgs

# --- Example 1: Deploying using the 'Chart' resource ---
# The 'Chart' resource is simpler and renders Helm templates locally, then applies them.
# Good for straightforward deployments or when you want Pulumi to manage individual resources.

nginx_ingress_chart = Chart(
    "nginx-ingress-chart", # Pulumi resource name
    ChartOpts(
        chart="ingress-nginx",
        version="4.7.1", # Pinning the version is recommended
        namespace="ingress-nginx-chart", # Specify the namespace for deployment
        fetch_opts=FetchOpts(
            repo="https://kubernetes.github.io/ingress-nginx", # Helm repository URL
        ),
        # Override default chart values
        values={
            "controller": {
                "replicaCount": 1, # Keep it small for the workshop
                "service": {
                    "type": "ClusterIP", # Use ClusterIP instead of LoadBalancer for simplicity
                },
            },
        },
    ),
    # No explicit provider needed if using the default KUBECONFIG context
)

# --- Example 2: Deploying using the 'Release' resource ---
# The 'Release' resource uses the Helm SDK directly, mimicking 'helm install/upgrade'.
# Good for leveraging full Helm lifecycle features (history, rollback via Helm).

prometheus_release = Release(
    "prometheus-release", # Pulumi resource name
    ReleaseArgs(
        chart="prometheus",
        version="15.18.0", # Pinning the version
        namespace="monitoring-release", # Specify a different namespace
        repository_opts=RepositoryOptsArgs(
            repo="https://prometheus-community.github.io/helm-charts", # Helm repository URL
        ),
        # Let Helm create the namespace if it doesn't exist
        create_namespace=True,
        # Override default chart values
        values={
            "alertmanager": {
                "enabled": False, # Disable alertmanager for simplicity
            },
            "server": {
                "persistentVolume": {
                    "enabled": False, # Disable persistence for the workshop
                },
            },
        },
        # skip_await=False (default) waits for resources to become ready
    ),
    # No explicit provider needed if using the default KUBECONFIG context
)

# --- Exports ---
pulumi.export("nginx_chart_namespace", nginx_ingress_chart.namespace)
pulumi.export("prometheus_release_namespace", prometheus_release.namespace)
pulumi.export("prometheus_release_name", prometheus_release.name)
pulumi.export("prometheus_release_status", prometheus_release.status)
```

## Code Explanation

**Chart Resource (nginx_ingress_chart):__

- Deploys the ingress-nginx chart from its repository.
- We specify a version, namespace, and repository using ChartOpts and FetchOpts.
- We override default values to set the replica count and service type. Pulumi renders the templates and applies the resulting manifests.

**Release Resource (prometheus_release):__

- Deploys the prometheus chart using the Helm engine.
- We specify the chart, version, namespace, and repository using ReleaseArgs and RepositoryOptsArgs.
- create_namespace=True tells Helm to create the namespace if needed.
- We override values to disable persistence and alertmanager.

**Provider:__ Notice we don't explicitly create a k8s.Provider. Pulumi automatically uses the cluster configured in your current kubectl context (via the KUBECONFIG environment variable or ~/.kube/config).

**Exports:__ We export the namespaces and some status information from the Helm deployments.

## Step 3: Deploy the Helm Charts

Run pulumi up in your terminal from the pulumi-helm-deploy project directory:

```bash
pulumi up
```

Pulumi will show you a preview of the Helm Chart and Release resources it plans to create.

Review the plan and select yes to deploy the charts to your Kubernetes cluster. Pulumi will fetch the charts, potentially render templates (for Chart), and apply them or instruct Helm (for Release) to perform the installation.

## Step 4: Verify the Deployments

Once pulumi up completes successfully, use kubectl to inspect the resources created by the Helm charts:

```bash
# Check the namespaces
kubectl get namespaces | grep -E 'ingress-nginx-chart|monitoring-release'

# Check the NGINX Ingress Controller deployment
kubectl get all -n ingress-nginx-chart

# Check the Prometheus deployment
kubectl get all -n monitoring-release
```

## Step 5: Clean Up

When you're done experimenting, you can destroy the resources:

```bash
pulumi destroy
```

## Key Differences Between Chart and Release

1. **Resource Management:__
   - Chart: Pulumi manages each Kubernetes resource individually
   - Release: Pulumi manages the Helm release as a single unit

2. **Helm History:__
   - Chart: No Helm release history (Pulumi manages resources directly)
   - Release: Full Helm release history (can use `helm list` and `helm rollback`)

3. **Debugging:__
   - Chart: Easier to debug individual resources in Pulumi
   - Release: Easier to debug using Helm CLI tools

4. **Use Cases:__
   - Chart: Better for simple deployments or when you want fine-grained control
   - Release: Better for complex charts or when you want Helm's lifecycle management
