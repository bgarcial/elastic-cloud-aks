# Elastic cloud deployment on AKS - A HA approach

This README descrption will be driven by the objectives needed to pursue in the solution, giving to the
reader along the way an explanation of the solution while highlighting important details to operate it and
modify it.

## 1. Deploying a  highly available Elasticsearch (ES) cluster

The following technologies were used:

- Terraform to provision and manage infrastructure as code.
- AKS Cluster (Azure Kubernetes Service) as a container orchestration service to deploy the elastic search cluster
- Elastic Cloud on Kubernetes operator to Elasticsearch management.

### 1.1. Using [Elastic Cloud on Kubernetes (ECK)](https://www.elastic.co/guide/en/cloud-on-k8s/current/index.html) solution

Since one of the requirements is use Docker/Kubernetes, I decided to
use Elastic cloud on Kubernetes solution, which one comes with the CRDs
needed and the elastic operator and the elastic cluster itself.

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

### 1.2. Kubernetes Cluster Requirements

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
  that is used to manage changes on the terraform workflow. It is supported by the
  [elastic-cloud-aks/azure-pipelines.yml](https://github.com/bgarcial/elastic-cloud-aks/blob/staging/azure-pipelines.yml)
  file.
  
  Every time a change takes place over that file or over terraform files under `elastic-cloud-aks/terraform` directory
  this pipeline will be triggered. Basically it manages the `terraform | init | validate | format | plan | apply`
  workflow with the infrastructure in azure.

- The terraform state is being managed from the pipeline as well, [by contacting a blob container created in azure](https://github.com/bgarcial/elastic-cloud-aks/blob/staging/azure-pipelines.yml#L46-L52).
That container is created previously before to initiate the terraform workflow, through the  [`elastic-cloud-aks/scripts/create-sa-blob-container.sh`](https://github.com/bgarcial/elastic-cloud-aks/blob/staging/scripts/create-sa-blob-container.sh)bash file

- This bash file also creates [the blob container](https://github.com/bgarcial/elastic-cloud-aks/blob/staging/scripts/create-sa-blob-container.sh#L46-L50)
which will be used to store elasticsearch snapshots when
a backups of the es-cluster takes place.

So the management of the infrastructure provisioning is done via the pipeline mentioned, and where a terraform plan is applied,
[it is how it looks like](https://dev.azure.com/bgarcial/elastic-cloud-aks/_build/results?buildId=159&view=logs&j=12f1170f-54f2-53f3-20dd-22fc7dff55f9&t=a15be6fc-5bda-52fa-0c03-7adf6e1a4d77).

---

## 2. Deploying ES-Cluster on multiple nodes

- The cluster should be on multiple hosts/worker nodes, rather than just multiple pods/containers.

As long the cluster is provisioned, we can see the three nodes share many labels.  

![](https://cldup.com/yIzMQnuMOt.png)

- In the same way I decided to deploy an elasticsearch cluster with [three nodes](https://github.com/bgarcial/elastic-cloud-aks/blob/staging/eck-manifests/es-cluster.yml#L9)

- I decided to implement the behavior that the elastic search cluster pods can only be placed on a node with a label whose key is `agentpool`
and whose value is `default` (since it is [the name of the nodepool](https://github.com/bgarcial/elastic-cloud-aks/blob/staging/terraform/main.tf#L70-L71)).

- The `requiredDuringSchedulingIgnoredDuringExecution` type of affinity will allow me to enforce this rule always, it means if in runtime
the value of the label `agentpool` change, and this rule is no longer met, the pods keeps running on that node.  

- So in this way, by applying the [`nodeAffinity`](https://github.com/bgarcial/elastic-cloud-aks/blob/staging/eck-manifests/es-cluster.yml#L32-L39)
is configured the guarantee that pods are going to be deployed only to `default` nodes, which ones are all the three worker nodes.

Since nodes are an essential factor for autoscaling, let me elaborate a bit about scaling capabilities on the cluster here:

- The nodegroup that is gathering the nodes [has autoscaling configured](https://github.com/bgarcial/elastic-cloud-aks/blob/staging/terraform/main.tf#L75-L77)
so the nodes are able to progressively support things like Horizontal pod autoscaling for increasing/decreasing number of replicas. This at pod level.

### But how the nodes are autoscaled?

- Having a kind of autoscaling group supporting them, I installed on the cluster the **[cluster-autoscaler](https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/azure/README.md)**
component which one automatically will adjust the size of the cluster (the nodes) in order alll pods can have a place to run and there are no unneeded nodes.
The helm chart for the autoscaler component is deployed from [a new pipeline created](https://github.com/bgarcial/elastic-cloud-aks/blob/staging/azure-pipelines-aks.yml#L94-L105) to execute all kubernetes deployments

- You can find this pipeline [here](https://dev.azure.com/bgarcial/elastic-cloud-aks/_build?definitionId=9), it is supported by the
[`elastic-cloud-aks/azure-pipelines-aks.yml`](https://github.com/bgarcial/elastic-cloud-aks/blob/staging/azure-pipelines-aks.yml)
 it is also in charge of deploy
third party applications like `nginx ingress controller`, `cert-manager`, and for sure the `elasticsearch crds`, `operator` and `es-cluster`.

It means any changes over the [`elastic-cloud-aks/eck-manifests`](https://github.com/bgarcial/elastic-cloud-aks/tree/staging/eck-manifests) directory or from
the `elastic-cloud-aks/azure-pipelines-aks.yml` itself, will trigger that pipeline.

Then having deployed as a part of the solution the Kubernetes autoscaler component, I am making sure with this, the AKS cluster can scale in the case
additional elasticsearch nodes need to be added.

- For example, let's modify the `nodeSets.count` parameter [from 3 to 4](https://github.com/bgarcial/elastic-cloud-aks/commit/231c28bef8a9418eaecd30ef664cd28ca225812c):

We will see a new node will be added to the cluster when the pipeline [is being executed](https://dev.azure.com/bgarcial/elastic-cloud-aks/_build/results?buildId=177&view=logs&j=79c55128-1e81-5faf-651b-c5327d72d52f&t=845e70b3-90f5-57a6-4b24-e3325e94780e&l=192):

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
> curl -u "elastic:$PASSWORD" -k "https://20.54.147.163:9200/_cat/health"

1636303800 16:50:00 elasticsearch green 4 4 2 1 0 0 0 0 - 100.0%
```

So if you go to <https://20.54.147.163:9200> you will get it as long overcome the basic-auth process.

![](https://cldup.com/l7Ir8hF5ir.png)

---

### 2.2. Storage class selected to elasticsearch PVs creation

The elasticsearch cluster, by applying [`volumeClaimTemplates`](https://github.com/bgarcial/elastic-cloud-aks/blob/staging/eck-manifests/es-cluster.yml#L11-L20)
configuration, it is creating a `pvc` resource for every elasticsearch pod created at every node:

![](https://cldup.com/aGHNF9G7rp.png)

It means persistent volumes will be created dynamically at runtime, and when doing this,
the process will look for an storageclass to be selected in order to create them.
Normally every K8s cloud provider come with a pre-built storageclass that allows flexibility in terms of
storage to the PVs that will use it.

In AKS case, there are [4 storage classes](https://docs.microsoft.com/en-us/azure/aks/concepts-storage#storage-classes)
which ones are shipped with the cluster:  

![](https://cldup.com/5rPIuW0aDb.png)

I am using [azurefile](https://github.com/bgarcial/elastic-cloud-aks/blob/staging/eck-manifests/es-cluster.yml#L20) storage class due to the following reasons:

- It allows to [update at any time the size of the pv created](https://docs.microsoft.com/en-us/azure/aks/azure-disks-dynamic-pv#built-in-storage-classes
), since it has the `allowVolumeExpansion: true` attribute:

![](https://cldup.com/dulGyLfAko.png)

- It is created using azurefiles, so it means [the volume will be backed by an storage account](https://docs.microsoft.com/en-us/azure/aks/concepts-storage#azure-files)
(s3 bucket in aws)

- Azure files allow to [share a persistent volume across multiple nodes](https://docs.microsoft.com/en-us/azure/aks/azure-disks-dynamic-pv) if needed

---

#### **IMPORTANT:**

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

All instance/elastic-search node have the same roles ([master, data, ingest](https://github.com/bgarcial/elastic-cloud-aks/blob/staging/eck-manifests/es-cluster.yml#L26-L28))

## 4. Elasticsearch recovering data

- An storage account blob container is created from the pipeline to be used to store elasticsearch snapshots.

- If the reclaim policy on PVCs is `Delete`, [as long a elasticsearch node is down, the PVC in it will be deleted](https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-volume-claim-templates.html#k8s_controlling_volume_claim_deletion)
ended up this in the PV deletion. So is good to change the policy.

But thinking outside the cluster, is not good backups depend of this kind of operations, so is opportune to think about how
to create and store elasticsearch snapshots somewhere outside the cluster.  

- [I will use the azure repository plugin in elasticsearch](https://www.elastic.co/guide/en/elasticsearch/plugins/7.15/repository-azure.html#repository-azure) to
communicate with an azure blob storage container previously created:

- Create a secret: This K8s secret needs to be created, it has the name of the storage account and the access key.
  - The `STORAGE_ACCOUNT_NAME` variable is the name of the storage account, it is eck-terraform
  - The `SA_ACCESS_KEY` variable is the access key of the storage account.

```
 k create secret generic azure-sa-credentials --from-literal=sa-client-id=$(STORAGE_ACCOUNT_NAME) --from-literal=sa-access-key=$(SA_ACCESS_KEY)
secret/azure-sa-credentials created
```

- Then a couple of actions were added as `initContainer` to the `elastic-search-cluster.yaml` file called `install-plugins` and `add-sa-credentials`.

That they do is to install the `repository-azure` plugin, [define the above variables as storage settings](https://www.elastic.co/guide/en/elasticsearch/plugins/master/repository-azure-usage.html#repository-azure-usage)
and consuming the secret created previously. This is [how it looks like](https://github.com/bgarcial/elastic-cloud-aks/blob/staging/eck-manifests/elastic-search-cluster.yml#L48-L71)

- In addition a snapshot repository should be registered in the blob container. It is really just a storage location where the
backups will be stored:

```
> curl -k -u "elastic:$PASSWORD" -X PUT "https://localhost:9200/_snapshot/eck-snapshots?pretty" -H 'Content-Type: application/json' -d'
{
  "type": "azure",
  "settings": {
    "container": "eck-snapshots",
    "base_path": "/",
    "compress": true
  }
}
'
{
  "acknowledged" : true
}
```

- After this, we can create our first snapshot from the cluster:

```
> curl -k -u "elastic:$PASSWORD" -X PUT "https://localhost:9200/_snapshot/eck-snapshots/snapshots_1?wait_for_completion=true"
{
 "snapshot": {
  "snapshot": "snapshots_1",
  "uuid": "SqxJMfVBR9yoVeFVv0-gLQ",
  "repository": "eck-snapshots",
  "version_id": 7150199,
  "version": "7.15.1",
  "indices": [".geoip_databases"],
  "data_streams": [],
  "include_global_state": true,
  "state": "SUCCESS",
  "start_time": "2021-11-07T21:45:20.120Z",
  "start_time_in_millis": 1636321520120,
  "end_time": "2021-11-07T21:45:24.723Z",
  "end_time_in_millis": 1636321524723,
  "duration_in_millis": 4603,
  "failures": [],
  "shards": {
   "total": 1,
   "failed": 0,
   "successful": 1
  },
  "feature_states": [{
   "feature_name": "geoip",
   "indices": [".geoip_databases"]
  }]
 }
}
```

- If we check the blob container, the snapshot files are there:

![](https://cldup.com/49vLBeF8za.png)

---

### 4.1. Creating periodic snapshots with a `CronJob` K8s resource

To automate the creation of backups a [`CronJob`](https://github.com/bgarcial/elastic-cloud-aks/blob/staging/eck-manifests/es-snapshotter.yaml) tab was created
It makes an HTTP request against the appropriate endpoint `service/elasticsearch-es-http` by consuming the elastic user secret.

---

## 5. Metrics to keep in mind

If we want to monitor elastic eck cluster, [the documentation](https://www.elastic.co/guide/en/kibana/current/elasticsearch-metrics.html) presents how to check metrics for:

- elastic nodes
- indexes
- Jobs
in order to get a good overview of health of the es-cluster

Under this idea, the elasticsearch exporter could be added to export this metrics so they can be fetched for
prometheus for example. This [helm chart](https://github.com/prometheus-community/helm-charts/blob/main/charts/prometheus-elasticsearch-exporter/README.md#install-chart) is a good thing to include in the solution

## Software needed

- Azure account subscription
- AZ cli tool configured with the azure account
- Kubectl
- Helm
- Terraform
- Curl

---

## Variabes needed

- Is necessary to create a service principal on azure cloud. Its credentials and information will be used to connect
to azure cloud from the pipeline in Azure DevOps. It is created in this way:

```
az ad sp create-for-rbac -n "eck-picnic" --role contributor

Creating 'contributor' role assignment under scope '/subscriptions/9148bd11-f32b-4b5d-a6c0-5ac5317f29ca'
The output includes credentials that you must protect. Be sure that you do not include these credentials in your code or check the credentials into your source control. For more information, see https://aka.ms/azadsp-cli
'name' property in the output is deprecated and will be removed in the future. Use 'appId' instead.
{
  "appId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "displayName": "eck-picnic",
  "name": "77505f0a-698a-48d9-9a73-62e198392b09",
  "password": "*********************************",
  "tenant": "4e6b0716-50ea-4664-90a8-998f60996c44"
}
```

- The `appId` value was taken to put it to the `ARM_CLIENT_ID` variable created and used in the pipeline
- The `password` value was taken to put it to the `ARM_CLIENT_SECRET` variable created and used in the pipeline
- The `tenant` value was taken to put it to the `ARM_TENANT_ID` variable created and used in the pipeline
- In addition the subscriptionId was taken from azure portal to create the `ARM_SUBSCRIPTION_ID` variable created and used in the pipeline

The above variables were used in the [terraform infrastructure pipeline](https://dev.azure.com/bgarcial/elastic-cloud-aks/_build/results?buildId=160&view=results)
and in the [aks deployment pipeline](https://dev.azure.com/bgarcial/elastic-cloud-aks/_build?definitionId=9)

In addition the following variable environments were created to be used in the aks deployment pipeline

- `azureNodeResourceGroup` which is the internal large resource group name that is created when an aks cluster is created.
- `azureResourceGroup`, to point to the resource group where the aks cluster is
- `helmVersion` to download the v3.7.1 helm tool
- `kubernetesCluster` to pass the name of the aks cluster
- `loadBalancerIp` to pass the public ip address of the load balancer to configure nginx ingress controller.
- `SA_ACCESS_KEY` to pass the access key of the eck-terraform storage account which is used to store es snapshots
- `STORAGE_ACCOUNT_NAME`, for the name of the storage account (eck-terraform)

---

## Deploying the stack

Being this solution driven by the infra and aks deployments pipeline mentioned previously, every change on the respective files will trigger those pipelines
and either the terraform workflow and the elasticsearch manifest files will be applied.

For more details about the pipelines please refer to:

- [1.4 Description of the files](https://github.com/bgarcial/elastic-cloud-aks/blob/staging/README.md#14-description-of-directoryfiles) section
for infrastructure provisioning pipeline
- [2. Deploying ES-cluster and scaling nodes](https://github.com/bgarcial/elastic-cloud-aks/blob/staging/README.md#but-how-the-nodes-are-autoscaled) section
for aks deployment pipeline.

## Upgrading the solution

Elasticsearch can usually be upgraded using a Rolling upgrade process so upgrading does not interrupt service. Rolling upgrades are supported:

[Here](https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-upgrading-eck.html#k8s-ga-upgrade), detailed info about how to upgrade the CRDs, the operator and the elastic stack

---

## Troubleshooting

Sometimes when scaling up the elasticsearch nodes, the `initContainer` `add-sa-credentials` cannot perform
the actions it does (create a keystore with the access key and name of the blob container),
then we saw the new elasticsearch pod placed in a node, cannot initialize.

If we inspect the initContainer  `add-sa-credentials` in that pod, we will see:

```
The elasticsearch keystore does not exist. Do you want to create it?
```

And deeping dive we will see this java exception is being thrown:

```
Exception in thread "main" java.lang.IllegalStateException: unable to read from standard input; is standard input open and a tty attached?
```

This is due that the way elasticsearch is done, the commands require a confirmation
via `tty` about actions to add like executing `./bin/elasticsearch-keystore` command.

If we add `--force` command the command will be executed without ask for a confirmation
via cli. So something like this:

```
./bin/elasticsearch-keystore add --force azure.client.default.account
./bin/elasticsearch-keystore add --force azure.client.default.key
```

A reference about this issue:

- [Unable to read from standard input](https://discuss.elastic.co/t/unable-to-read-from-standard-input-is-standard-input-open-and-a-tty-attached/138449/8)
