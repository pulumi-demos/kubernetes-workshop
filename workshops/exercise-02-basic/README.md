# Workshop Exercise 2: Deploying Kubernetes Resources

## Goal
In this exercise, you will build upon Exercise 1 by using Pulumi to deploy standard Kubernetes resources (a Namespace and a Deployment from a YAML file) onto the EKS cluster you created previously.

## Prerequisites

- Completed Workshop Exercise 1.
- You are in the same Pulumi project directory used for Exercise 1.
- The EKS cluster from Exercise 1 is running.
- kubectl configured (Pulumi likely configured this for you, or use the exported kubeconfig from Exercise 1).

## Step 1: Verify Kubernetes SDK

Ensure the Pulumi Kubernetes SDK is installed in your project's virtual environment (it might have been installed during Exercise 1 depending on the template used, but let's confirm):

```bash
uv pip install pulumi-kubernetes
```

## Step 2: Create the Kubernetes Manifest (YAML File)

In your project directory (where your __main__.py file is), create a new file named nginx-deployment.yaml.

Paste the following content into nginx-deployment.yaml. Notice the namespace field matches the one we'll create in Python.

```yaml
# nginx-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-nginx-deployment
  namespace: workshop-app-ns # Matches the namespace we create below
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.21-alpine # Using a specific light-weight version
        ports:
        - containerPort: 80
```

## Step 3: Add Kubernetes Resources to Pulumi Code

Open your existing __main__.py file.

Do not delete the code that creates the VPC and EKS Cluster. We need the eks_cluster object.

Add the following Python code to the end of your __main__.py file:

```python
# --- Start of ADDED code for Exercise 2 ---

import pulumi_kubernetes as k8s
import pulumi_kubernetes.meta.v1 as meta

# 1. Create a Kubernetes Provider pointing to the EKS cluster
#    We use the kubeconfig output directly from the eks.Cluster resource defined earlier.
k8s_provider = k8s.Provider("k8s-provider",
    kubeconfig=eks_cluster.kubeconfig # Use the kubeconfig from the cluster object
)

# Define the name for our new namespace
app_namespace_name = "workshop-app-ns"

# 2. Create the Kubernetes Namespace using the EKS provider
app_namespace = k8s.core.v1.Namespace("app-ns",
    metadata=meta.ObjectMetaArgs(
        name=app_namespace_name,
    ),
    opts=pulumi.ResourceOptions(provider=k8s_provider) # Specify the provider
)

# 3. Deploy the Nginx workload from the YAML file into the created namespace
nginx_deployment = k8s.yaml.ConfigFile("nginx-deployment",
    file="nginx-deployment.yaml",
    # Ensure the namespace exists before applying the YAML
    # Pass the provider and set depends_on using .merge() or create new opts
    opts=pulumi.ResourceOptions(
        provider=k8s_provider,         # Specify the provider
        depends_on=[app_namespace]     # Depend on the namespace
    )
)

# 4. Export the namespace name
pulumi.export("appNamespace", app_namespace.metadata.apply(lambda m: m.name))

# --- End of ADDED code for Exercise 2 ---
```

### Code Explanation

1. We import the pulumi_kubernetes library.
2. We create a k8s.Provider configured with the kubeconfig obtained directly from the eks_cluster object created in Exercise 1.
3. We define the Namespace resource, ensuring it uses our specific k8s_provider.
4. We define the ConfigFile resource, telling it to use the nginx-deployment.yaml file.
5. Crucially, we pass opts to both Kubernetes resources, specifying the k8s_provider and making the ConfigFile explicitly depends_on the app_namespace.

## Step 4: Deploy the New Resources

Run pulumi up in your terminal:

```bash
pulumi up
```

Pulumi will compare the desired state (including the new Namespace and Deployment) with the current state. It should detect that only the new Kubernetes resources need to be created.

Review the preview and select yes to proceed.

## Step 5: Verify the Deployment

Once pulumi up completes, use kubectl to check the resources on your EKS cluster:

```bash
# Make sure kubectl is using the context for your EKS cluster
# You might need to point KUBECONFIG to the file exported in Exercise 1,
# or Pulumi might have set the current context for you.

# Check if the namespace exists
kubectl get namespace workshop-app-ns

# Check if the deployment was created in the namespace
kubectl get deployment -n workshop-app-ns

# Check if the Nginx pod is running
kubectl get pods -n workshop-app-ns
```

You should see the workshop-app-ns namespace, the my-nginx-deployment, and one running Nginx pod within your EKS cluster.

## Step 6: Clean Up (Important!)

When you are finished with both exercises and want to remove all created cloud resources (VPC, EKS Cluster, Namespace, Deployment):

```bash
pulumi destroy
```

Review the list of resources to be deleted (it will include everything from Exercise 1 and 2).

Select yes to confirm the destruction.

> **Warning__: Running pulumi destroy in this project will remove all resources defined in __main__.py, including the EKS cluster and VPC created in Exercise 1.

You have now extended your Pulumi project to deploy Kubernetes application resources onto the cluster managed by Pulumi!
