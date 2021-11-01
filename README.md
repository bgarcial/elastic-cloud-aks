# Postfacto Infrastructure Deployment

A terraform workflow has been created to deploy the following infrastructure resources that support postfacto application deployment:

## Kubernetes Cluster: 

A HA Aks cluster (deployed within 3 availability zones) was created with the following features:

- **Logs Analytics Workspaces and Container Insights** (Optional): This is [monitoring for containers](https://docs.microsoft.com/en-gb/azure/azure-monitor/containers/container-insights-overview) 
    in order to track nodes, disks, CPUs and memory usage and to check the logs of the applications or workloads deployed. It is not entirely required, it will depends of the observability
    strategy for metrics, logs and tracing collections and tools used.  
    I personally prefer to work with cloud agnostic tools/products like Prometheus (for collecting metrics) and Fluentd/bit for collecting logs in the cluster
    and a logging backend independent of azure like loki or elasticsearch
    
- The nodes were created using **Virtual Machine Scale sets** compure resources, since they are required to work with Availability zones, 
    providing redundant power, cooling, and networking  
    
- The AKS cluster was created with a **User assigned managed identity**. 

Then this can be used when the cluster needs to access to another azure 
resources like Azure KeyVaults, Container Registry, amongs others.
With it, we don't need to authenticate to azure with a service principal  from the aks cluster and we avoid keeping an eye on when service 
principal client secrets expire.
Having a managed identity, we could use it to create role assignments over other azure services like Vnet (as I am doing it below), KeyVault and SQL instances, ACR, etcetera

- **RBAC has been enabled in the AKS cluster**
It is a way to access control from users to the kubernetes cluster, as the number of cluster nodes, applications, and team members increases, we might want to limit the resources the team members 
and applications can access, as well as the actions they can take.

For example we migh want to allow access just to the QA team to the `postfacto-4-1-0` and `postfacto-4-2-0` namespaces. It is done
via `Role` and `RoleBinding` k8s resources and `ClusterRole` and `ClusterRoleBinding` if an admin access is desired to be supplied.
We can take in advance of the [Azure Active Directory Integration](https://docs.microsoft.com/en-us/azure/aks/managed-aad) 
to use AAD as identity provider for this access. 

The cluster also is able to integrate with Azure Active Directory via its user assigned managed identity

    
- An **Standard SKU Load Balancer** has been created as part of the AKS deployment, since I selected three availability zones, then they require
a load balancer with this sku plan to to distribute request across Virtual Machines Scale sets.
    
- **Autoscaling:**
    
    - 1 Nodepool: The cluster was created with  1 nodepool, but the terraform configuration can be modified to create more nodepools if needed, by using
    the [azurerm_kubernetes_cluster_node_pool](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster_node_pool)
    
    Check [here](https://docs.microsoft.com/en-us/azure/aks/cluster-autoscaler#use-the-cluster-autoscaler-with-multiple-node-pools-enabled):
    
    AKS cluster can autoscale nodes, but also we can add dynamically node pools as long they can be required. 
    
    - Autoscaling is enabled inside nodes context, so is possible to add more pods according to the demand of traffic, by using Horizontal Pod Autoscaling for increasing/decreasing the number of replicas.
        
        - We can use here metrics like cpu or memory and define an `HorizontalPodAutoscaler` resource. But we can also create custom metrics and using
        something like Prometheus, to scrappe them and scale for example based on [requests counts](https://prometheus.io/docs/concepts/metric_types/#counter)   
        
        - Nodes autoscaling assigning `min_count` and `max_count` parameters. So far the cluster can have min 2 nodes and 6 as a maximum.  
    
    - **Networking:**
        - **Azure CNI Network Plugin**
            - Allow us to make the pods accessible from on premises network if needed
            - It is required to integrate additional nodepools or virtual nodes
            - Pods and services gets a private IP of the Vnet.
            - We avoid to use NAT to route traffic between pods and nodes (different logical namespace)
        
        - The cluster is deployed inside a Vnet, which one has the following subnets:
            - Aks vnet, where the cluster lives. This subnet is being whitelisted from postgresql vnet rules in order to
            allow aks subnet to communicate with postgres databases from pods.
            - My home ip address is being whitelisted in the postgresql firewall to allow access to manage it.

## PostgreSQL server

A PostgreSQL server instance is created with the databases needed for postfacto applications deployments
I decided to deploy postfacto as a stateless application instead of use the postgresql container that comes with the postfacto helm chart. 
In the same way the postgread headless service deployed alongside the helm chart is not needed as well.

## Storage account and blob container.

From the [`setup-resources-operations.sh`](https://github.com/bgarcial/postfacto-infra/blob/staging/terraform/setup-resources-operations.sh#L22-L42)
bash script (which is being executed from the azure pipeline infrastructure), 


# Infrastructure Requirements

- Postfacto persistent data must be stored in a way that in case of node or cluster failure, the same data will not be lost.

Since a fully managed Azure Database PostgreSQL service is created, I don't need to worry about persistence of data inside the cluster (pv)
The data on the postgresql database will be there 
