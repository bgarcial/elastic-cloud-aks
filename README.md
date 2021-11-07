# Elastic cloud deployment on AKS - A HA approach.

This README descrption will be driven by the objectives needed to pursue in the solution, giving to the
reader along the way an explanation of the solution while highlighting important details to operate it and
modify it.

## 1. Deploying a  highly available Elasticsearch (ES) cluster.

The following technologies were used:
- Terraform to provision and manage infrastructure as code.
- AKS Cluster (Azure Kubernetes Service) as a container orchestration service to deploy the elastic search cluster
- Elastic Cloud on Kubernetes operator to Elasticsearch management.


### 1.1. Using [Elastic Cloud on Kubernetes (ECK)](https://www.elastic.co/guide/en/cloud-on-k8s/current/index.html) solution

Since one of the requirements is use Docker/Kubernetes, I decided to
use it, which one comes with the CRDs needed and the elastic operator and the elastic cluster itself.

The use of an operator will help us to have the little manual tasks as much
we can, since it is in charge of deploy in the correct order 
resources like service accounts (so it will take care about roles)
roles and clusterroles, besides services that work alongside elasticsearch
service (like webhooks), configmaps secrets and so on.

Operators are mainly used to help to manage stateful applications where
we need to keep the state of them, like in our case by doing backups or
snapshots, since elasticsearch cluster use persistent volumes to
keep data across life's pods.

In summary the operator will be helpful to avoid to get manual intervention
related with the above resources mentioned or even the order to upgrade components when
scaling concerns comes up regarding to cluster and storage capacity
in addition to manage the configuration.
You can find more about the operator [here](https://operatorhub.io/operator/elastic-cloud-eck).

---

### 1.2. Kubernetes Cluster Requirements.

I decided to use an AKS cluster to support the ES-cluster, which was deployed
with the following features/properties:

- RBAC enabled, as the ECK operator [has some RBAC rules](https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-deploy-eck.html) that require it.
- To achieve HA, the cluster K8s components (Vnet and subnets and a nodegroup composed of three nodes) are deployed across 3 availability zones in west europe region, so it means
the elasticsearch nodes will get this property as well
- A layer 4 Load Balancer has been created as part of the K8s deployment
to distribute requests across the 3 availability zones.
- The compute unit of VMs that support the three nodes of the cluster support autoscaling, so they
are like a kind of EC2 autoscale group to grow if needed. Later on I will elaborate
on autoscaling concerns.

---

### 1.3. Provisioning the above infrastructure 

I used terraform for AKS cluster provisioning, being responsible for creating the
Vnet (and subnet where the cluster is placed), the AKS cluster worker nodes along the master node
or control plane which is created implicitly by Azure when provisioning the cluster.

---
**NOTE:**

I am using Azure Kubernetes service, there the architecture for deployment 
is pretty similar to Amazon EKS in the sense that control plane is managed by the 
provider, either in Azure where [it is totally abstracted from the user perspective](https://docs.microsoft.com/en-us/azure/aks/concepts-clusters-workloads#control-plane),
or in Amazon EKS where when a EKS is created, [a VPC managed by AWS is created for managing the control plane](https://aws.amazon.com/blogs/containers/de-mystifying-cluster-networking-for-amazon-eks-worker-nodes/).

---

### 1.4. Description of directory/files

- Under [`elastic-cloud-aks/terraform`](https://github.com/bgarcial/elastic-cloud-aks/tree/staging/terraform) 
directory are located all files belong to the terraform workflow.

- There is [a pipeline](https://dev.azure.com/bgarcial/elastic-cloud-aks/_build/results?buildId=160&view=results)
  that is used to maanage changes on the terraform workflow. It is supported by the 
  [elastic-cloud-aks/azure-pipelines.yml](https://github.com/bgarcial/elastic-cloud-aks/blob/staging/azure-pipelines.yml)
  file. Every time a change takes place over that file or over terraform files under `elastic-cloud-aks/terraform` directory
  this pipeline will be triggered. Basically it manages the `terraform | init | validate | format. | plan | apply`
  workflow with the infrastructure in azure. 

- The terraform state is being managed from the pipeline as well, [by contacting a blob container created in azure](https://github.com/bgarcial/elastic-cloud-aks/blob/staging/azure-pipelines.yml#L46-L52).
That container is created previously before to initiate the terraform workflow, through the  [`elastic-cloud-aks/scripts/create-sa-blob-container.sh`](https://github.com/bgarcial/elastic-cloud-aks/blob/staging/scripts/create-sa-blob-container.sh)bash file

- This bash file also creates [the blob container](https://github.com/bgarcial/elastic-cloud-aks/blob/staging/scripts/create-sa-blob-container.sh#L46-L50) 
which will be used to store elasticsearch snapshots when 
a backups of the es-cluster takes place.

So the management of the infrastructure provisioning is via the pipeline mentioned, and where a terraform plan is applied, 
[it is how it looks like](https://dev.azure.com/bgarcial/elastic-cloud-aks/_build/results?buildId=159&view=logs&j=12f1170f-54f2-53f3-20dd-22fc7dff55f9&t=a15be6fc-5bda-52fa-0c03-7adf6e1a4d77).

---

## 2. Deploying ES-Cluster on multiple nodes

- The cluster should be on multiple hosts/worker nodes, rather than just multiple pods/containers.

As long the cluster is provisioned, we can see the three nodes share many labels.  

![](https://cldup.com/yIzMQnuMOt.png)

- In the same way I decided to deploy an elasticsearch cluster with [three nodes](https://github.com/bgarcial/elastic-cloud-aks/blob/staging/eck-manifests/elastic-search-cluster.yml#L8-L9) 

I decided to implement the behavior that the elastic search cluster pods can only be placed on a node with a label whose key is `agentpool` 
and whose value is `default` (since it is [the name of the nodepool](https://github.com/bgarcial/elastic-cloud-aks/blob/staging/terraform/main.tf#L70-L71)).

The `requiredDuringSchedulingIgnoredDuringExecution` type of affinity will allow me to enforce this rule always, it means if in runtime
the value of the label `agentpool` change, ant this rule is no longer met, the pods keeps running on that node.  

So in this way, by applying the [`nodeAffinity`](https://github.com/bgarcial/elastic-cloud-aks/blob/staging/eck-manifests/elastic-search-cluster.yml#L32-L39) 
is configured the guarantee that pods are going to be deployed only to `default` nodes, which ones are all the three worker nodes.

Since nodes is an essential factor for autoscaling, let me elaborate a bit about scaling capabilities on the cluster here:

- The nodegroup that is gathering the nodes [has autoscaling configured](https://github.com/bgarcial/elastic-cloud-aks/blob/staging/terraform/main.tf#L75-L77)
so the nodes are able to progressively support things like Horizontal pod autoscaling for increasing/decreasing number of replicas. This at pod level.

**But how the nodes are autoscaled?**

- Having a kind of autoscaling group supporting them, I installed on the cluster the **[cluster-autoscaler](https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/azure/README.md)** 
component which one automatically will adjust the size of the cluster (the nodes) in order alll pods can have a place to run and there are no unneeded nodes.
The helm chart for the autoscaler component is deployed from [a new pipeline created](https://github.com/bgarcial/elastic-cloud-aks/blob/staging/azure-pipelines-aks.yml#L94-L105) to execute all kubernetes deployments

- You can find this pipeline [here](https://dev.azure.com/bgarcial/elastic-cloud-aks/_build?definitionId=9), it is supported by the
[`elastic-cloud-aks/azure-pipelines-aks.yml`](https://github.com/bgarcial/elastic-cloud-aks/blob/staging/azure-pipelines-aks.yml)
 it is also in charge of deploy
third party applications like nginx ingress controller, cert-manager, and for sure the elasticsearch crds, operator and es-cluster. It means
any changes over the `[elastic-cloud-aks/eck-manifests](https://github.com/bgarcial/elastic-cloud-aks/tree/staging/eck-manifests)` directory or from
the `elastic-cloud-aks/azure-pipelines-aks.yml` itself, will trigger that pipeline.

Then having deployed as a part of the solution the Kubernetes autoscaler component, I am making sure, the AKS cluster can scale in the case
additional elasticsearch nodes need to be added.

- For example, let's modify the `nodeSets.count` parameter [from 3 to 4](https://github.com/bgarcial/elastic-cloud-aks/commit/231c28bef8a9418eaecd30ef664cd28ca225812c):

We will see a new node will be added to the cluster when the pipeline [is being executed](https://dev.azure.com/bgarcial/elastic-cloud-aks/_build/results?buildId=177&view=results):

![](https://cldup.com/5BJDVj3Qcj.png)

```
kubectl get elasticsearches.elasticsearch.k8s.elastic.co

+ kubectl get elasticsearches.elasticsearch.k8s.elastic.co
NAME            HEALTH   NODES   VERSION   PHASE   AGE
elasticsearch   green    4       7.15.1    Ready   18h
```

---

### 2.1. Testing the Elasticsearch Deployment

- Getting the elasticsearch password directly fron the user secret created with the deployment:

```
> PASSWORD=$(kubectl get secret elasticsearch-es-elastic-user -o go-template='{{.data.elastic | base64decode}}')
+ kubectl get secret elasticsearch-es-elastic-user -o go-template={{.data.elastic | base64decode}}
```

- Making port forwarding of the service: 

```
kpf service/elasticsearch-es-http 9200:9200 &
[1] 98200
+ kubectl port-forward service/elasticsearch-es-http 9200:9200

 ~ ----------------------------------------------------------------------------------------------------------------- %  at 17:43:14
> Forwarding from 127.0.0.1:9200 -> 9200
Forwarding from [::1]:9200 -> 9200
```
- Authenticating to the cluster:

```
> curl -u "elastic:$PASSWORD" -k "https://localhost:9200"

{
  "name" : "elasticsearch-es-es-picnic-2",
  "cluster_name" : "elasticsearch",
  "cluster_uuid" : "TZcLkPpQR5ekEijLG83gUw",
  "version" : {
    "number" : "7.15.1",
    "build_flavor" : "default",
    "build_type" : "docker",
    "build_hash" : "83c34f456ae29d60e94d886e455e6a3409bba9ed",
    "build_date" : "2021-10-07T21:56:19.031608185Z",
    "build_snapshot" : false,
    "lucene_version" : "8.9.0",
    "minimum_wire_compatibility_version" : "6.8.0",
    "minimum_index_compatibility_version" : "6.0.0-beta1"
  },
  "tagline" : "You Know, for Search"
}
```

- Checking the cluster health.

```
> curl -u "elastic:$PASSWORD" -k "https://localhost:9200/_cat/health"

1636303708 16:48:28 elasticsearch green 4 4 2 1 0 0 0 0 - 100.0%
```

**NOTE:**

Since I deployed elasticsearch cluster as LoadBalancer type service, you can access directly to it from outside:

```
> curl -u "elastic:$PASSWORD" -k "https://52.236.145.137:9200/_cat/health"

1636303800 16:50:00 elasticsearch green 4 4 2 1 0 0 0 0 - 100.0%
```

So if you go to https://52.236.145.137:9200 you will get it as long overcome the basic-auth process.

![](https://cldup.com/MqYdAmITYV.png)


### 2.2. Storage class selected to elasticsearch PVs creation

The elasticsearch cluster, by applying [`volumeClaimTemplates`](https://github.com/bgarcial/elastic-cloud-aks/blob/staging/eck-manifests/elastic-search-cluster.yml#L11-L20)
configuration, it is creating a `pvc` resource for every elasticsearch pod created at every node:

![](https://cldup.com/aGHNF9G7rp.png)

It means persistent volumes will be created dynamically at runtime, and when doing this, 
the process will look for an storageclass to be selected in order to create them. 
Normally every K8s cloud provider come with a pre-built storageclass that allows flexibility in terms of
storage to the PVs that will use it. 

In AKS case, there are [4 storage classes](https://docs.microsoft.com/en-us/azure/aks/concepts-storage#storage-classes) 
which ones are shipped with the cluster:  

![](https://cldup.com/5rPIuW0aDb.png)

I am using [azurefile](https://github.com/bgarcial/elastic-cloud-aks/blob/staging/eck-manifests/elastic-search-cluster.yml#L20) storage class due to the following reasons:

- It allows to [update at any time the size of the pv created](https://docs.microsoft.com/en-us/azure/aks/azure-disks-dynamic-pv#built-in-storage-classes
), since it has the `allowVolumeExpansion: true` attribute:

![](https://cldup.com/dulGyLfAko.png)

- It is created using azurefiles, so it means [the volume will be backed by an storage account](https://docs.microsoft.com/en-us/azure/aks/concepts-storage#azure-files)
(s3 bucket in aws)

- Azure files allow to [share a persistent volume across multiple nodes](https://docs.microsoft.com/en-us/azure/aks/azure-disks-dynamic-pv) if needed

---

**IMPORTANT:**

Since the PVs that are backing up the es-cluster inside the K8s cluster are  dynamically provisioned PersistentVolumes, 
the default reclaim policy is "Delete". This means that a dynamically provisioned volume is automatically deleted when a user 
deletes the corresponding PersistentVolumeClaim.  

![](https://cldup.com/SoyAx-w-QY.png)

That policy [can be changed](https://kubernetes.io/docs/tasks/administer-cluster/change-pv-reclaim-policy/#why-change-reclaim-policy-of-a-persistentvolume
):
>This automatic behavior might be inappropriate if the volume contains precious data. In that case, it is more appropriate to use the "Retain" policy. With the "Retain" policy, if a user deletes a PersistentVolumeClaim, the corresponding PersistentVolume will not be deleted. Instead, it is moved to the Released phase, where all of its data can be manually recovered.




---


## 3. Elasticsearch roles assigned 

- The Elasticsearch roles assigned to the each cluster instance should be the same 

All instance/elastic-search node have the same roles ([master, data, ingest](https://github.com/bgarcial/elastic-cloud-aks/blob/staging/eck-manifests/elastic-search-cluster.yml#L26-L28))

## 4. Elasticsearch recovering data 


## Software needed

## Deploying the stack

## Variabes needed

## Upgrading the solution