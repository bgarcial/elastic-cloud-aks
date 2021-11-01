# Postfacto Infrastructure Deployment

- **Infrastructure Repository:** [https://github.com/bgarcial/postfacto-infra](https://github.com/bgarcial/postfacto-infra)

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
bash script (which is being executed from the [azure pipeline infrastructure](https://github.com/bgarcial/postfacto-infra/blob/staging/azure-pipelines.yml#L22-L26)), 
an storage account and a blob container is being created in order to store the terraform state.

![Terraform state file stored on the blob container](https://cldup.com/TbWbCeeNmH.png)

talk here about tf state and that it can also be created from az tf devos task instead of use a shell approach

---

# Executing the terraform workflow - Azure DevOps Pipeline

- As I mentioned previously, an [azure pipeline](https://github.com/bgarcial/postfacto-infra/blob/staging/azure-pipelines.yml#L22-L26)
is created on Azure DevOps, and it is triggered every time a push is done on staging branch on the github repository

- I am using this [Azure pipelines terraform task](https://marketplace.visualstudio.com/items?itemName=charleszipp.azure-pipelines-tasks-terraform) 
to define and implement the terraform workflow (`init` | `validate` | `fmt` | `plan`| `apply`) to manage the above-mentioned infrastructure resources.
    - To make it work is necessary to install that task into the Az DevOps organization.

- [Click here](https://dev.azure.com/bgarcial/postfacto-infra/_build?definitionId=7) to access to the pipeline on Azure DevOps.

- This is how the pipeline looks like

![](https://cldup.com/PP6RjnQX_o.png)

- With the terraform task used, we can even create the storage account from the yaml pipeline definition since it has 
an automate remote backend creation feature and it is enabled by toggling on the `ensureBackend` input parameter to `true`
and providing the name of the resource group, storagr account and the key state file to be created. 
It takes in advance of the use of the Azure ARM Service connection that was needed to create previously in order to connect Azure DevOps with Azure platform
I created it by using an existing service principal created previously. 

Is opportune to mention I am just accessing to the existing storage account and blob container and key state file I created via bash approach.


---

# Infrastructure Requirements

- Postfacto persistent data must be stored in a way that in case of node or cluster failure, the same data will not be lost.

- The Postfacto app pods cannot be deployed on the same nodes as the database and Redis.

Since a fully managed Azure Database PostgreSQL service is created and [a connection from postfacto AKS pods is done](https://github.com/bgarcial/postfacto-platform/blob/staging/helm/charts/postfacto/templates/deployment.yaml#L67-L91),  
I don't need to worry about data persistence inside the cluster (the helm chart comes with a containerized postgres service and creates a pv)
So the data on the postgresql databases will be there.

![](https://cldup.com/9My3M-3q-y.png)
