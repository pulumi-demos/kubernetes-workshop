# Workshop Exercise: Creating an Amazon EKS Cluster

In this exercise, you'll learn how to create an Amazon Elastic Kubernetes Service (EKS) cluster using Pulumi. You'll set up a complete infrastructure including a Virtual Private Cloud (VPC) and an EKS cluster with configurable node groups.

## Exercise Overview

You will create the following resources:

1. **Virtual Private Cloud (VPC):**
   - A dedicated network environment with public and private subnets
   - DNS hostname support enabled
   - Configurable CIDR block

2. **EKS Cluster:**
   - Deployed within the VPC
   - API authentication mode for access entries
   - Configurable node instance types and scaling parameters
   - Public endpoint for cluster management

3. **Kubernetes Provider:**
   - Configured to interact with the newly created EKS cluster

## Detailed Implementation

### Configuration Setup

The implementation begins by retrieving configuration values with sensible defaults:

```python
# Get some values from the Pulumi configuration (or use defaults)
config = pulumi.Config()
min_cluster_size = config.get_int("minClusterSize", 3)
max_cluster_size = config.get_int("maxClusterSize", 6)
desired_cluster_size = config.get_int("desiredClusterSize", 3)
eks_node_instance_type = config.get("eksNodeInstanceType", "t3.nano")
vpc_network_cidr = config.get("vpcNetworkCidr", "10.40.0.0/16")
```

This allows you to customize your deployment by setting these values in your Pulumi configuration file, or rely on the defaults if not specified.

### VPC Creation

The first infrastructure component is a VPC that will contain the EKS cluster:

```python
# Create a VPC for the EKS cluster
eks_vpc = awsx.ec2.Vpc("eks-vpc",
    enable_dns_hostnames=True,
    cidr_block=vpc_network_cidr)
```

The VPC is created with:
- A configurable CIDR block (default: 10.40.0.0/16)
- DNS hostname support enabled
- Automatic creation of public and private subnets across availability zones

### EKS Cluster Creation

Next, we create the EKS cluster within our VPC:

```python
# Create the EKS cluster
eks_cluster = eks.Cluster("eks-cluster",
    # Put the cluster in the new VPC created earlier
    vpc_id=eks_vpc.vpc_id,
    # Use the "API" authentication mode to support access entries
    authentication_mode=eks.AuthenticationMode.API,
    # Public subnets will be used for load balancers
    public_subnet_ids=eks_vpc.public_subnet_ids,
    # Private subnets will be used for cluster nodes
    private_subnet_ids=eks_vpc.private_subnet_ids,
    # Change configuration values to change any of the following settings
    instance_type=eks_node_instance_type,
    desired_capacity=desired_cluster_size,
    min_size=min_cluster_size,
    max_size=max_cluster_size,
    # Do not give worker nodes a public IP address
    node_associate_public_ip_address=False,
    # Change these values for a private cluster (VPN access required)
    endpoint_private_access=False,
    endpoint_public_access=True
    )
```

Key aspects of the EKS cluster configuration:

- **Network Configuration:**
  - Placed within our custom VPC
  - Worker nodes in private subnets for security
  - Load balancers in public subnets for accessibility
  - Worker nodes do not receive public IP addresses

- **Authentication:**
  - Uses the "API" authentication mode to support access entries
  - Public endpoint enabled for cluster management

- **Node Group Configuration:**
  - Instance type is configurable (default: t3.nano)
  - Auto-scaling parameters are configurable:
    - Minimum size: 3 nodes (default)
    - Maximum size: 6 nodes (default)
    - Desired capacity: 3 nodes (default)

### Kubernetes Provider Setup

Finally, we create a Kubernetes provider that uses our newly created cluster:

```python
# Create a Kubernetes provider instance that uses our cluster from above.
cluster = k8s.Provider("cluster",
    kubeconfig=eks_cluster.kubeconfig)
```

This provider allows you to deploy Kubernetes resources to your EKS cluster using Pulumi.

### Exported Values

The program exports important values that can be used by other stacks or for cluster access:

```python
# Export values to use elsewhere
pulumi.export("kubeconfig", eks_cluster.kubeconfig)
pulumi.export("vpcId", eks_vpc.vpc_id)
```

- **kubeconfig:** Used to connect to your cluster with kubectl
- **vpcId:** The ID of the VPC containing your cluster

## How It Works

- **VPC Creation:**
  The `awsx.ec2.Vpc` resource creates a VPC with public and private subnets across multiple availability zones. Public subnets have routes to an Internet Gateway, while private subnets use NAT Gateways for outbound internet access.

- **EKS Cluster:**
  The `eks.Cluster` resource creates an EKS control plane and a managed node group. The control plane manages the Kubernetes API server and etcd data store, while the node group provides the compute capacity for your workloads.

- **Authentication:**
  The API authentication mode enables IAM authentication for your cluster, allowing you to manage access using IAM roles and users.

- **Networking:**
  Worker nodes are placed in private subnets for security, while the cluster endpoint is publicly accessible for management. Load balancers created by Kubernetes services will be placed in public subnets.

## Next Steps

1. **Deploy the Infrastructure:**
   Run `pulumi up` to create the EKS cluster and VPC.

2. **Connect to Your Cluster:**
   Use the exported kubeconfig to connect to your cluster with kubectl.

3. **Deploy Applications:**
   Use the Kubernetes provider to deploy applications to your cluster.

4. **Explore Advanced Features:**
   - Add IAM roles for service accounts
   - Configure cluster autoscaler
   - Set up monitoring and logging
   - Implement network policies

Happy Kubernetes clustering!
