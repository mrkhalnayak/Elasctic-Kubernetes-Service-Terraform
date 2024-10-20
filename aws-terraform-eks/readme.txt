# Step-1 :- Create IAM Role.

Frorm when the EKS tidly intigrated with aws service, mainly with IAM service (Indentity and Access management),

<!--Important:- A Amazon EKS cluster IAM role is required for each cluster. Kubernetes clusters managed by Amazon EKS use this role to manage nodes and the legacy Cloud Provider uses this role to create load balancers with Elastic Load Balancing for services.
Before you can create Amazon EKS clusters, you must create an IAM role with either of the following IAM policies: -->

Many AWS service interact with other aws services like ec2, loadbalance, so for that eks required some short of permission. to grant permission we create IAM role and define trust policy.

This is uasally done with the pricipal property in IAM role. In this case, we create an IAM role that can only be used by the EKS service and nothing else. 

An IAM Role is similar to an IAM User, you define what that entity can and cannot do in aws.

<!-- Importent:- The defrence is That IAM user usally uniquely associated with one person, But IAM Role assumable by anyone who needs it.
Similer IAM User is having a Long-term credentials (password/access and secret key). But at the same hand IAM Role have's short-term credentials (Token) for 1hr only.
That's why even to run terraform, an Iam role is preferred due to short-lived token. -->

Important:- And In some case if the IAM role token got compromissed (hacked), so it can only run's 1hr max.

Step-2 :- Attach permission to that IAM role.

1. Attach the policy :- AmazonEKSClusterPolicy (However this policy assume that we use a lagacy cloud provider that additionally required Load Balancing permission)
Because half of this policy is dedicated only to that legacy provider. For this lagacy provider we will install aws load balancer controller that would take on that responsibility, and for that we will create another separate IAM role.

2. AmazonEKSWorkerNodePolicy:- The worker Node required, Core EC2 functionality permissions, it also allows running pod Identity agent (which is used to grant granukar access to your application), for example you can grant your application read and write access to a specific s3 bucket. Before Pod Indentity provider we need to use OIDC(OpenID connect) provider and IAM roles for service accounts. 

3. AmazonEKS_CNI_Policy:- This will grant EKS access to modify the IP address configuration on your EKS worker nodes. 
Example- When we create a pod the IP is allocated from the secondary IP address range assigned to the worker node.(So we are not using virtual networks such as flannel or calico anymore) you get native AWS IP addresses for each pod. Later you'll see a benefit when we start  cerating load balancers and use IP mode to route traffic directly to the pod IP address. Brefore that cloud provider has to use NodePorts, behind the scenes when you created services of type load balancers. But now it's direct. By reducing the number of network hops, we reduce the latency of the requests.

4. AmazonEC2ContainerRegistReadOnly:- this policy is used to grant EKS permission to pull docker images from the aws managed contaner service called ECR.


# Steps for connecting to the cluster:-

1. Once the cluster is got created we'll check that we our a user in our loaal system to connect to the cluster or not. - { aws sts get-caller-identity }
2. for connecting to the cluster - { aws eks update-kubeconfig  --region <region value> --name <cluster-name> }
3. Install kubectl and check the nodes through command <kubectk get nodes>
4. check that we have read and write permission or not. <kubectl auth can-i "*" "*"> If the output is "yes" That means we have admin access.


# Add IAM user & IAM Role in EKS. 

If we have created the eks cluster as IAM User only we will be able to make changes or do thing inside the cluster, but there always will be an other team members, who will need the admin privilages to maintain the cluster, or we will have some specific team who need's the access for a specific namespace inside the cluster, we can create namespace to which we provide limited resouces, like 10 CPU, 20GB memory, and maximum 12 pods can be get created. You create quotas to avoid any interfarance between the teams, and if other teams try to deploy pods into someone other's namespace, so the pods will be go in pending state. And for this resouce limitation who has created the cluster get blamed for all of this, or we have onother team who need a specific namespace to deploy the application pods or other resources. So every time we need to give the permission to each and every one which is not a good approch.

Or we can create a specific IAM role and allow all the teams to use that IAM role for the cluster. 

But if suppose we created the cluster for the production so we can give the access to evey user or every teams, so for this we can give read permission to the other teams for debugging or check application logs on the specific namespaces by using the RBAC (Role Based Access Controle) inside the kubernetes cluster only, So there is a lot of flexibility in RBAC. 

Now, on aws side, we can use IAM users or IAM roles as objects that represent indentities. On Kubernetes for the indentities, we can use Kuberenetes service account users, and RBAC groups.

We'll map an IAM user and after an IAM role to custom RBAC group which will have different permissions. 

# Example-1 
We will use IAM user and IAM policy with a minimum set of permission for that user. It will only allow updating the local kubetnetes config and connecting to the EKS cluster.
On the kubernetes side, we'll create a viewer role with read-only permission to access certain objects form the core kubernets API, such as deployments and configmaps. Then we use cluster-role-binding to bind this viewer RBAC role to a new my-viewes RBAC group. And finally, in order to link the IAM user with this RBAC group, we will use EKS API insted of the old deprecated auth configmap. 

Using IAM user with long term credentials is not a good practice. Insited of IAM User, IAM role will be a better practice for the long term security, because it genrate a new token in every 1 hours. And to IAM role we will grant IAM policy that would grant that IAM role admin access to EKS on the AWS side.

On the Kuberenetes site we can't use built-in RBAC groups that start with system prefix, so we'll use the default cluster-admin cluster role and bind it with our new my-admin group. 

Next we'll create a manager IAM user and an additional IAM policy that would allow this user to assume the eks-admin IAM role, Finally we'll bind the IAM role with the kubernetes my-admin RBAC group using the EKS-API.

4. Horizontal Pod Auto Scaler

In this we will see about the pod auto scaler and what required to work.
Generally we need to monitor the CPU and memory usage to scale the application, for this it's important that when we create deployment or state full sets so we define the resource block.
Because the HPA (Horizontal Pod AutoScaler) use the requests section to calculate CPU or memory usage of the pod, not the limits.
SO, if we forgot update the resource then the "HPA" object wont work.

We use GitOps Tools like (ArgoCD or FluxCD) to continiously compare the state of kubernetes object with what we have define in the git repository.
Now when we are using the HPA, so we should naver update the replica property in deployment and stateful sets, because then we'll get the race condition.

Example:- ArgoCD will keep applying 1 replica count and HPA (Horizontal Pod AutoScaler), will keep scaling to 5. Also to target deployment for HPA we use the name property not the labels.

Now if we want to use custome metrics, for example, the number of requests per second, so we need additional component.

For using the Auto Scaler we need to use some metrics-server. We usually deploy a metrics server that would scrap each kubelet and publish those metrics to the metrics.k8s.io kubernetes API.
This component rarely needs any maintenance, so it's safe to use a helm-chart to deploy it metrics-server. 

So we are deploying the "metrics-server" through "helm-release" with terraform for eks.

If we have setup the metrics-server through helm chart so we will do it inside the kube-system namespace and when it's got created and wanted to check it's log so use below command.
<< kubectl logs -l app.kubernetes.io/instance=metrics-server -f -n kube-system >>.

Now we have created a sepret folder where we have created some object like namespace and in that space we have created a service and deployment. 
where in the deployment we have updated the resource request and limite both, and after that we have created the "HorizontalPodAutoscaler" object where we have define, 
that when HorizontalPodAutoscaler can scale the pod.

# Now when we have created the HPA we have setup the limitation scaling the pods from 1 to 5 in case if the memory and cpu utilization goes more then 70%.


spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp
  minReplicas: 1
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 70


# Deployment resouce limitation setup is like below. 

spec:
containers:
- name: myapp
  image: nginx:latest
  ports:
    - name: http
      containerPort: 80
  resources:
    requests:
      memory: "128Mi"
      cpu: "100m"
    limits:
      memory: "128Mi"
      cpu: "100m"

here we given that the pods can take upto 128MB memory and cpu can be 100 milli cpu unit,
1,000 milliCPU (m): This means 1 CPU = 1,000 m.

The image we have used in for the deployment is "vikash1997/loadcheckerimage:v1", now to test this load checking application we hit on this url "curl localhost:8080/api/cpu?index=44"


5. Cluster-AutoScaler

The cluster-autoscaler is an external component, that we need to additionally install in our EKS cluster. To automatically scale up and down our cluster.
We had created EKS node-group as regular AWS autoscaling groups with maximum, minimum , and desired size properties. 
When the autoscaler detects any pending pods in our cluster, it will adjust in the desired size property on the autoscaling group to fit all the pods.
If we have created our eks cluster using terraform then we need to ignore the below given property.

lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
}

Otherwise terraform and autoscaler will keep applying the same property when you run terraform apply.

Additionally the cluster autoscaler needs permission to interact with AWS and adjust the desired size. So we need to authorize it some how. So, for this we were creating 
OIDC (Open ID Connect Provider) on the IAM side then create an IAM role and establish trust with the particular namespace and the RBAC service account.
The most annoying thing about the OpenID Connect provider is to use an annotation with the IAM role ARN on the service account.

But Now, the EKS team has developed a new approach called EKS pod Identity that we can use to grant access. 
To enable it we can use the EKS addon, which is super easy to install. We still need to create IAM role for the kubernetes service account , 
but for the trust, we use the same "pods.eks.amazonaws.com". Also, to bind the IAM role with the service account, we don't use annotation anymore. 
Instead, we use the EKS API and the "pod_indentity_association" resource.

A. First we need to create the Pod-Indentity-Agent as DeamonSet. # Pod Identity Agent is an Add-ons of EKS.

For this we create a seprate yaml will with the name "13-pod-indentity-addon.tf" This agent will run on every single node in our cluster.

When it comes get the current version of any addon's in eks we can run the below mentioned commands
<< aws eks describe-addon-versions --region us-east-2 --addon-name eks-pod-identity-agent >>
<< aws eks describe-addon-versions --region <name> --addon-name <addon name vakue> >>

Once we have created the Pod-indentity agent we can check inside the "kube-system" namesapce, that is got created or not << kubectl get pods -n kube-system >>.
And it does exist there. But if it's not created or running, we need to make sure that it should be running, as of now we have a single node only in the cluster, 
so we have only one agent pod. We can also check the DeamonSet, << kubectl get daemonset eks-pod-identity-agent -n kube-system >>, so just check that all the agent are running.
Without the agent running we won't be able to authorize our this client with AWS services. 
This clinet means our node will become the client-servers to aws, so if the agent is not running in our nodes, so the aws will not able to authorized it.

B. Now we will create the necessary componetes for the cluster-autoscaler. # "14-cluster-autoscaler.tf"
    a. First we need a iam-role 

    resource "aws_iam_role" "cluster-autoscaler" {
        name = "${aws_eks_cluster.eks.name}-cluster-autoscaler"
      
        assume_role_policy = jsondecode({
          version = "2012-10-17"
          Statement = [
              {
                  Effect = "Allow"
                  Action = [
                    "sts:AssumeRole",
                    "sts:TagSession"
                  ]
                  Principal   =   {
                      Service = "pods.eks.amazonaws.com"   # this "pods.eks.amazonaws.com" we use to the trust relationship., we can use other type also here like ec2.amazonaws.com etc. But we should always use this for the auto-scaler option, it's an best choice. 
                  }
              }
          ]
        })
    }

    b. then we create the IAM policy with cluster-autoscaler name and attach the policy with it. we need to search "IAM policy for cluster autoscaler" on google for this policy.
    c. Now once we have created IAM role and IAM policy, so we need to attach both "aws_iam_role_policy_attachment".
    d. Now we need to setup the credentials for cluster-autoscaler, so we use "aws_eks_pod_identity_association", resource to give access to the cluster-autoscaler.
    e. Then we create helm-release resource for cluster-autoscaler.

    resource "helm_release" "cluster-autoscaler" {
        name = "autoscaler"
      
        repository = "https://kubernetes.github.io/autoscaler"
        chart = "cluster-autoscaler"
        version = "9.40.0"
        namespace = "kube-system"
      
      # creating the rbac service account with the name of Cluster-autoscaler.  
        set {
          name = "rbac.serviceAccount.name"
          value = "cluster-autoscaler"
        }
      
        set {
          name = "autoDiscovery.clusterName"
          value = aws_eks_cluster.eks.name
        }
      
      
      # region is must to be update here.
        set {
          name = "awsRegion"
          value = "us-east-2"
        }
      
        depends_on = [ helm_release.matrics-server ] # We could have used node-group here if we wanted to deploy multiple helm-chart parallal.
      
      }
Once we have created this we need to check the < kubectl get pods -n kube-system > that pod-idenity has been got created or not and check the logs also for the same using below command.
<< kubectl logs -l app.kubernetes.io/instance=autoscaler -f -n kube-system >>.

If we have done this authorization with the "OIDC" rather then "Pod_identity", so we need to pass alot of annotation, in every step.

    f. Now we would create a deployment and of 10 replica set and check and logs through this commnnd < kubectl logs -l app.kubernetes.io/instance=autoscaler -f -n kube-system >>.
       That if the load is gettng increased and some pod will be comes under the pending status, so the auto-scaler will trigger and create a new node, automatically, 
       and it doesn't come under the pending status so we will increse the replica count then watch the podes < kubect get pods --watch and kubectl get nodes --watch>


6. AWS Load-Balancer Controller.

In this we learn about how we can expose our application to the internet is some cases, only within a VPC, when we create a service type load balancer for our applicatin, 
kubernetes know how to create cloud load balancer no metter which cloud we are using (AWS, Azure, GCP, etc), this task perfommed by cloud controller manager that ships with 
kubernetes and contains the logic for creating basic resources in different clouds. For aws it create classic load balancer by-default. We can use specific annotation to 
change the type, scheme, and other configurations.

Currently this Cloud Controller Manager features are depcricate in AWS, only used for receving only bug & security fixes, and it also use to add all our kubernetes worker nodes
to target group and uses nodeports behind to route traffics. This approach adds addnitinal network hops and if your using very larget kubernetes cluster,
there is a hard limit of 500 nodes or so that yoy can add to the target group.

Now since kubernetes became so popular, cloud providers started to develop their own controller to handle the specific cloud logic, for example,
AWS has an AWS Load Balancer Controller that we can additionally install in kubernetes, usally using helm charts. This controller can create a Load balancers and ingresses,
a this feature that was never added to the original cloud controller. Since it's an separate project hosted in it's own repository, it's has independent release cycle. 
This allows cloud providers to develop a new features and quickly release them to the public. one of my favorite feature is that since we use the native VPC network when we create an EKS cluster, 
each pod gets VPC-routable IP addresses. this means you can directly add pods IP addresses to the load balancer target group 

# In this there are 2 types of ingresses available to us, and each has it's pros and cons.

1. When we create ALB (Application Load Balancer) it create layer 7 load balancer. it understand HTTP protocol, and we can use it to route requests based on the HOST Header, HTTP path,
or even HTTP verbs such as GET and POST. As a target group it directly adds the pod's IP addresses. In this Instance mode is still available but IP mode is more efficient.

The logic for routing requests is outside of the Kuberenetes cluster. 

For example:- When we decide to secure our application with TLS and HTTPS, you need to obtain a TLS Certificate from the AWS certificate Manager service and use annotation to attach it.
This was you don't have to keep the certificate and private key inside kubernetes to terminate the TLS.

2. On the other hand we have traditional ingress controller, such as Nginx, Traefik, HAproxy, and etc. All of them are deployed in kubernetes as regular applications.
When you install an external ingress controller it creates a layer 4 network load balancer, which will be a gateway for our application. 
Each request will go through, in this example, the nginx controller pod and then to be routed to your application. the logic for routing request is indie the nginx pod.
To secure your application with TLS, you need to deploy cert manager with automatically obtains and renews certificates from let's encrypt.
Keep in mind that we have to store the certificates and private key inside the kubernetes and mount them to the nginx pod.
This was it can termicate TLS and route traffic to your application. Since we have a proxy, 
it adds complexity but we can collect prometheus metrics from a single place for all applications.

For example:- we can get metrics such as request per second, latency, availablility, and other metrics. With an Application load Balancer, 
you would need to get matrics from the AWS side. Also when we use a traditional ingress such as Nginx, we share a single load balancer, 
it create one application Load balancer per application(ingress). There are some workarounds, but in production you would most likely stock with that approch.

So for this we should definitely install AWS Load Balancer Controller and create a network load balancer for the nginx ingress controller using IP mode.

# Now we need to create the necessary terraform components. "15-aws-lbc.tf"

a. This controller needs to access to AWS to create Load balancers. To grant access, we'll use pod idenities as well. earliear we used assume_role_policy property on the role itself. 
in this case we do exactly same but for creating the assume policy we use a data resource this time.

data "aws_iam_policy_document" "aws_lbc" {
    statement {
      effect = "Allows"
  
      principals {
        type = "Service"
        identifiers = ["pods.eks.amazonaws.com"]
      }
  
      actions = [
          "sts:AssumeRole",
          "sts:TagSession"
      ]
    }
  }

b. Now we create an IAM role and attach the above created assume_role_policy to it. "aws_iam_role".

c. In this we create the IAM policy for the AWS Laod balancer controller "aws_iam_policy". We can do this 2 way either attach the policy in terraform file only or create 
different json file and attach it through there.

d. Now we have created the "aws_iam_policy" and "aws_iam_role" for the Load balancer controller, so we will attach them "aws_iam_role_policy_attachment".

e. Finally we will attach the IAM role with the pod-identity for Load Balancer controller for access credentials, "aws_eks_pod_identity-association", 
And here we update the "kube-system" namespace also, becayuse we want to deploy the AWS Load Balancer Controller, inside the 'kube-system' namespace only.

f. And the last we need to install the "AWS Load Balancer Controller" through helm chart.

resource "helm_release" "aws_lbc" {
    name = "aws-load-balancer-controller"
  
    repository = "https://aws.github.io/eks-charts"
    chart      = "aws-load-balancer-controller"
    namespace  = "kube-system"
    version    = "1.8.4"
  
    set {
      name = "clusterName"
      value = aws_eks_cluster.eks.name  # This helm chart required eks cluster name
    }
    
    set {
      name = "serviceAccount.name"           # This kubernetes service account name must macth the one linked in EKS. It also depend on the node group or previous helm-chart
      value = "aws-load-balancer-controller"
    }
  
    depends_on = [ helm_release.cluster-autoscaler ]
  }

Once we have created resource we will check that load balancer controller is got created inside the "kube-system" namespace or not. <kubectl get pods -n kube-system>

Now once we have done everything we will be creating a deployment and services, in the service we take service as Load Balancer and give some annotations.
Once its created we need to check that svc got the external-url or external-ip or not.

# service.kubernetes.io/aws-load-balancer-type: external
# service.kubernetes.io/aws-load-balancer-nlb-target-type: ip
# service.kubernetes.io/aws-load-balancer-scheme: Internet-facing
# # service.kubernetes.io/aws-load-balancer-proxy-protocol: "*"

This all the annotations and it's value we are using, but we don't need to use the Internet-facing load balancer to expose our internal services and dashboard such prometheus and grafana.

Once the load balancer is got created, we can see it's information on the AWS dashboard that it has got the target group, and it's allocated in public ip and many more information.
in the listeners it has target group and we have allocated the nlb target type "IP" not the instance so it shows that also. rather attaching the node group it has attached the IP of the Pod.

The Aws load balancer controller also create the ingresses and it already has by-defualt ingress class name "alb" << kubetcl get ingressclass >>.

Now we will deploy our application and expose it with ingress.

For this we have created the deployment, service as cluster type and provided port 8080 and target is http, now created ingress, where we have update our host "cloudlabexperts.site"
Now we need

Now once we have deployed the deployment, service, and ingress, now we can see that our application is working fine and we haven't used the DNS records as of now, 
so what we are doing here is we are checking it by locally.
<< curl -i --header "Host: cloudlabexperts.site" http://k8s-example6-myapp-7bccaef31d-1580395491.us-east-2.elb.amazonaws.com/about >> 
here curl is command (-i) tells curl to include the HTTP response headers in output. (--header "Host: cloudlabexperts.site") this set's the custom HTTP header to the request.
and rest is a external url of Application load balancer.

Now we delete namespace in which we have created the deployment, services, and ingress, so by deleteing the namespace all the resouces will get delete by itself.

# Include the TLS certificate.

Now in the final we need to add the TLS certificate to secure our ingress. For the application load balancer, Let's encrypt and need to obtain a TLS certificate from certificate managr, a managed AWS service.
We can use this even if we host our domain outside of AWS, But if we have did it inside the aws Route 53 it will be good. 

So for adding certificate to our domian name, we open the AWS certificate manager and create a request for the same. 
By updating the domain name and if we have sub domain we can do that as well, and request it. Now it will task some time to allocate the certificate to the domain name.

While creating the request we need to set-up some configuration like DNS validation and key type as RSA, and once the request is created we need to prove that we onw our domain. 
In the case of DNS validation. Like we need to create a couple of CNAME record for each domain on teh certificate.IF we host our domain in Route 53, 
so we just need to create records from Route 53, it will give us rthe option "create record in route 53" and once we click there it will already had created the record for our domain name.

Now we just need to wait till it's verify and validation part and DNS record get created. 
Once the certificate is created we need to copy the certificate ARN. And update into our the Ingress resource. In this allong with the "HTTP=80" we can add "HTTPS=443",
That if any request comes with the "https://" so it can route in "443" port. And if we provided the both's annotation togather, so any request comming to 80 will route to 443.

But In this ingress we haven't included the TLS section. Because TLS will be terminated outside if the Kubernetes cluster on the Application Load Balancer. 
So There is no need to keep the certificate and private key inside the kubernetes. Because this AWS load balancer controller is very different from the nginx ingress controller.

And in the ingress we also update the "ingressclass: alb", because we are using the AWS Load Balancer Controller, And we will add our "dev.cloudlabexperts.site", 
because the "cloudlabexperts.site" CNAME is alreay created in the route 53 through ACM (AWS Certificate Manager), so we need to give sub domain "dev" with the "cloudlabexperts.site"
So we have created the CNAME with "dev.cloudlabexperts.site" and update the application load balancer external Url to route the request through load balancer.

Important:- When we will deploy the ingress resource then only the Application load balancer will get created and we can update into the CNAME records.

How we can use the < dig dev.cloudlabexperts.site > to check the host name information. After this we will check into the browser also "dev.cloudlabexperts.site"


######################################################## 7. Nginx Ingress Controller Tutorial (Cert-Manager & TLS) ############################################################

In this we talk about the Nginx Controller, When we install Nginx Ingress controller, it also create layer 4 network load balancer in the cloud,
this Load balancer will be used to route every single request set to your application. by using the particular ingressclass. The network Load balancer does not understand the
HTTP protocol and will not terminate TLS. It will pass everything to Nginx Controller itself. 

When we create an ingress object to expose your application that object is parsed and converted by the nginx controller into the native Nginx configuration (modifies configutaion).
So, when a request comes from the load Balancer, and then the Nginx will act as reverse proxy and, based on the routes define in the Nginx, it route the request to our specific
application. Since we'll use the AWS Load balancer controller to create the network load balancer for the Nginx ingress controller, we'll use IP mode.

This means AWS will not use NodePort Service type and add all our kubernetes workers nodes to the target group. Instead, it will use Nginx controller pod IP addresses 
only in the target group. This helps avoid some limitation, removes an additional network hop (time of data tranaction between 2 network device), and increase performance. 
So we should install the AWS Load Balancer Controller before deploying the nginx ingress controller.

Now since we have a middleman such as the Nginx proxy, we can collect many metrics for each destination application without additional effort. we can scrap nginx Prometheus
metrics and create dashboards with latency, requests per second, availablility, and other metrics. 

In the large orgnizations, it's very common to deploy a public-facing ingress controller that uses an external load balancer with a publicly routable IP. You would
use that ingress to expose clinet-facing application another Nginx ingress controller with only a private load balancer this load balancer will get a private IP that
is only routable within your VPC. You would use it for your internal services as well as internal dashboard such as grafana. We frequestly use this type of ingress with 
private route 53 hosted zones and client VPN's for the dashboards. 

Another benefit that not many people know is that you can use the Nginx ingress controller to route, custom TCP and UDP services. 
Usually we would expose them with a service of type Load Balancer, resulting in as many load balancers as you have services. The Nginx ingress controller allows sharing
a single load balancer to expose all our custom services. This is mostly used because the load balancer have hourly charges, so by limiting the number of load balancer,
we are reduing the cost of our infrastructure. 

In the majority of cases, we want to secure our application's HTTP endpoint with a TLS certificate. it is possible to provide our own certificate and private key to Nginx
as a kubernetes secret, but in the most cases, we want to automate this process. To automate, we deploy an additional component called "cert-manager". It integrates with the
Nginx via annotations and automatically obtains and renews our certificates. If it fails to renew the certificate, we'll get a warning via email from let's encrypt ahead of time,
giving us a chance to debug and fix the issue to ontain the certificate, "cert-manager" uses a a custom resources. First it creates a certificate and checks if we already have 
a certificate for the domain. if not, it creates a certificate request custom resource. Befind the scenes it generates a private key and stores it in a kubernetes secret. Then 
cert-manager will create another custom resource called an order. Finally, the order custom resource will create a challenge. 
There are two main challeges that you can use. HTTP-01 is the simplest one to configure. "Cert-Manager" will obtain a secret token from let's encrypt and expose it on 
a custom path on our domain. Then let's encrypt will verify it and issue a certificate. 

Another challege, DNS-01, is a little bit more complex to configure because you need to grant cret-manager IAM permission to create TXT records in route 53. 
However it preferred in production because  it allows you to get a certificate even before routing and changing live DNS to point to the Nginx ingress load balancer. 
With the DNS-01 challenge, cert-manager will get the same secret token, but to prove that you own the domain, cert-manager needs to create custom TXT records. 
When let's encrypt can query your domain and verify those records, you'll get a certificate. Certificates are valid for 90 days, but approximately
every 60 days, cert-manager will try to renew them, There are two main reasons for the short expriration on the certificate. If the certificate is compromised, then the
attackers would have a limited amount of time to cause damage. Another reasons is that this short interval forces you to automate this process insted of manually updating
certificates. 

# Practical (resource creation for this)

1. First create necessary components to deploy Nginx Ingress Controller. # 16-nginx-ingress.tf 

resource "helm_release" "external_nginx" {
  name = "external"

  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress"
  create_namespace = true
  version          = "4.10.1"

  values = [file("${path.module}/values/nginx-ingress.yaml")] 

  depends_on = [helm_release.aws_lbc]
}

here we are passing some annotation that what kind of ingress we need and what kind of load balancer this ingress should create. 

---
controller:
  ingressClassResource:
    name: external-nginx
  service:
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: external
      service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
      service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing

In the past, we had to use ingressclass and the lagacy annotation so that cert-manager could create an ingress to validate the HTTP-01 challenge. But it's not necessary now.
After cert-manager was update to use ingressClassName property as well. Usually, we would have an external ingress that exposes application to the internet as well as an 
internal ingress with private DNS to expose some internal dashboard such Grafana and prometheus. 

Now we have created the controller file and helm-release resource so we will apply and once the nginx-ingress-controller is created we will see < kubectl get svc -n ingress >,
because by-default create it's own namespace and create the resource inside it. so we just check service. it shows that created 2 svc with the cluster IP service and Load-Balancer
service type. 

The Nginx-Ingress-Controller, also have got the External Load Balancer URL. Nginx-ingress will use this load balancer for each application, that we configure with this ingress.
We will always to create CNAME record with the value pointing to this load balancer by-default, it expose only ports 80 and 443. 

There are some option to expose the custome TCP and UDP services using a single Load Balancer, usefull for those who want to save on load-balancer houly charges. 
Now we will check the created load balancer and it's target group uses the IP mode and route traffic directlt to the nginx ingress controller. The target group IP address
in Load balancer will match with the pod running inside the ingress namespace, because this it the Nginx-ingress-controller pod's IP.

The Load balancer will always route the traffic to your application thorugh the nginx-ingress-controller pod beause all the logic is inside the nginx-controller pod, not in
the load-balancer like with the AWS Load Balancer Controller.  

Now in the folder example-8 we have created some resource like deployement, service and ingress, now we will check all the resources <kubectl get pods,svc,ingress -n example-8 >.
Once we get all the resouces, in ingress we will get the Load-Balanacer external URL which we tried to access our application. by using the below command.
<< curl -i --header "Host: www.cloudlabexperts.site" http://k8s-ingress-external-e2dcb84d04-0bf520464d0b7641.elb.us-east-2.amazonaws.com>> This will shows that our application 
is locally accessable or not.

Now we'll delete this namespace example-8 and all resource, inside the example-8 we had created all our resources. For the next example to use HTTPS and issue a certificate from 
let's encrypt, we need to additionally install "cert-manager", in this we'll use the HTTP-01, challenge to prove ownership.

Now we will create "helm_release" resouce for the "cert-manager" in # 17-cert-manager.tf 

"Cert-manager" uses custome resources to automatically obtain and renew certificates, so we need to install them during the deployment. 

resource "helm_release" "cert_manager" {
  name = "cert-manager"

  repository = "https://charts.jetstack.io"
  chart = "cert-manager"
  namespace = "cert-manager"
  create_namespace = true
  version = "1.15.3"

  set {
    name = "installCRDs"   # this section we are asking for intallation of custom resource defination. 
    value = "true"
  }

  depends_on = [ helm_release.external_nginx ]
}

Now we apply to install this "cert-manager" through helm chart, and now we need to create a "Clusterissuer" that you can use in all namespace to obtain certificates.
We will create every resource inside the example-9 folder.

---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: http-01-production
spec:
  acme:
    email: your-email@devopsbyexample.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: http-01-production-cluster-issuer
    solvers:
      - http01:
          ingress:
            ingressClassName: external-nginx

This is the ClusterIssuer resource, which create the certtificate in every namespace that's we didn't update the namespace in this also, now here we have update email also
that in case if the certificate creation getting failed it can warn as a head of time.

And we are using the solver type as http01 resolver, and in this we are using the ingress to resolve those certification related challenges. We use this specific name property
we'll use it in the ingress annotation to reference this issuer.

Apart from this we have a deployment resource and service objects. In the namespace called example-9, And we have the ingress aslo inside the same namespace. 
In the ingress we give the annotation for cert-manager clusterissuer, to secure this ingress with HTTPS, we need an additional TLS section, where we need to add all
DNS names that we want to use and the secret name within this namespace for the certificate and the private key. It will be automatically mounted to the Nginx ingress controller,
enabling it to terminate TLS and route requests to your application. That's all, let's apply it. 

Now once we have created all the resources, and now we will verify the resource inside the example-9 namespaces. < kubectl get certificate -n example-9 >. 
The certificate status is showing false, then it's not in the ready state so we need to debug this. So first we need to describe the certificate.
< kubectl describe certificate -n example-9 >.

When we describe the certificate, we find that the certificate created a Certificate Request custom resource which in the backend generated a private key and stored it in the
kubernetes secret, which we specified in the ingress resource. 

Now we try to describe the CertificateRequest, << kubectl describe CertificateRequest -n example-9 >>, In this we can see that certificate request creates a custom resource 
called "order", now we try to describe "order" as well for why the certificate ready state is showing false. And for describing the "order" we need to run the command.
< kubectl describe Order -n example-9 >, And now we can see that "Order" is also created last custome resource that we need to investigate called "Challenge", which we need
to describe that particular resource. < kubectl describe Challenge -n example-9 >, Now here in the reason section it define the issue of the certificate not being in the 
ready state.

{
  Reason:      Waiting for HTTP-01 challenge propagation: failed to perform self check GET request 'http://www.cloudlabexperts.site/.well-known/acme-challenge/dNUusDrrDgzBvBKNveWp6_eWD0opgSKHPUdPr9DvOYY': 
  Get "http://www.cloudlabexperts.site/.well-known/acme-challenge/dNUusDrrDgzBvBKNveWp6_eWD0opgSKHPUdPr9DvOYY": dial tcp: lookup www.cloudlabexperts.site on 172.20.0.10:53: no such host
  State:       pending
}

Here it shows the above based reason, it happen because we have created the Ingress, but never created the DNS records, so that let's encrypt can verify that we own this domain.
The solution is very simple, we just need to create a CNAME record pointing to the NGINX Ingress Load Balanacer. Once we created CNAME it cert-manager take few minutes to obtain
a certificate.

Now when we check the certificate created or not using this command, < kubectl get certificate -n example-9 > and the value is showing true that means it's attached to our website.
When we are checking our domain it's showing our website as secure also, and properly routed. And by checking the certificate on browser it's showing that we have validity of 90
days for the certificate. And after the 60 days "cert-manager" try to renew it automatically and if it fails to renew certificate, it will gives us the warning at the email ID. 

Note:- If we check that cert-manager has also created an additional temporary Ingress to expose the token provided by "let's encrypt". 

########################################################################### 8th {EKS CSI Driver} ###############################################################################

In this we learn about the storage and how we run statefull application in EKS. Now if you try to deploy a statefulset in EKS right after you provision a cluster, our pods will 
get stuck in the pending state. And if we define the persistent volume claim, you'll find that the driver or provisioner is missing. 

To allocate a volume from one of the cloud storage providers, such as EBS, so we need to additionally install something called a CSI driver. CSI, or Container Storage Interface,
is a Kubernetes extension that allows storage verdors to integrate with Kubernetes. With CSI, storage vendors no longer need to write code in kubernetes itself. This interface
allows them to develop storage plugins independently and deploy those drivers to Kuberenetes using Kuberenetes primitives, such as Kubernetes pods. 

One of the most common storage providers people use in AWS, and in EKS specifically is EBS (Elastic Block Storage). It's one of the cheapest option and very reliable. 
By default, EKS ships with a default storage class GP2. You can use it with ReadWriteOnce access mode, which allows mounting an EBS volume to a single Pod. Technially, 
it's a single Node, but you should only rely on it if we have a specific requirement and have the pod Affinity property on our Statefulset.

It's very common to increase the size of the disks for your EC2 Inatance, for example when we run statefull system allow the expansion of EBS volumes attached to Kubernetes 
nodes you need to create custom storage class. We suggest using the GP3 storage class and explicitly allowing expansion. In this case, we still won't be able to change the
StatefulSet template because it's an immutable property, but in an emergency, we can manually edit persistent volume. And in a few seconds, the CSI driver will ingrease the 
volume. We generally use this feature with Prometheus and Thanos deployments. 

In excersizes we also use the (Elastic File System). It's elastic meaning we don't need to manually increase the size, and it's supports the ReadWriteMany access mode, allowing
us to mount it to multiple pods at the same time. 

For creating creating eks EBS-CSI-Driver we need to create the trust policy, since we'll use EKS Pod idenities. # 18-ebs-csi-driver.tf

1. aws_iam_policy_document # creating the trust policy with pod idenities
2. aws_iam_role  # creating IAM role for the ebs-csi-driver.
3. aws_iam_role_policy_attachment # attaching the trust policy with the IAM role and provided some permission.
4. aws_iam_pocily" "ebs_csi_driver_encryption" # creating the IAM policy for the csi-driver encryption.
5. aws_iam_role_policy_attachment # Attaching the encryption policy for with IAM role to secure ebs-csi-driver.
6. aws_eks_pod_identity_association # attaching the EBS-csi-driver with the pod-identity.
7. "aws_eks_addon" "ebs_csi_driver" # creating the ebs-csi-drivers.

Now we will apply and create this above resource and once it will get created we will create a example-10 folder and create the statefulset resource.
And in the statefulset file we have set-up that which will allocate as mant persistent volumes as you have replicas. We just need to deploy Statefulset successfully and
configure everything correctly. 

We are basically deploying the statefull set application inside the example-10 namespace also, which we have created yaml file inside the folder example-10 only.
Now we'll try to get the pods inside the example-10 namespace. And we need to keep in mind that if we do not deploy the CSI driver, all our pod will stack in pending state.

And if it's deployed the CSI driver than it will just take few seconds, to attach the volume to the kubernetes node. Let's check the "pvc" which is a persistent volume claim,
and it look like it's already bound. < kubectl get pvc -n example-10 >, it will create inside the example-10 namespace only because our application was inside the same
namespace.

And at the last will see < kubectl describe pvc <pvc-name> -n example-10 >, And in the last if it's shows successfully provisioned, that means it's allocated with the 
statefulset. And if it's not provisioned then our pod will be in the pending state.

###########################################################################  9th EKS EFS CSI Driver ##############################################################################

In this section we'll learn about the EFS File system. Lets see over some main features of this file system. 

1. It's fully Elastic File Storage:- This file system will scale automcatically when we add or remove the files. So we don't need to worry about the capacity.
When we create a persistent volume claim or a statefulset template we don't need to provide the storage capacity on template if we use the "EFS" file systems.
Because in kubernets it's require to specify the size for the volume, but since we use EFS that size dosen't mean anything. 

2. We can use the ReadWriteMany access mode:- We can mount the same volume to the multiple pods as the same time. 
When one pods write data to that colume, the other pod can will immediately read that file. 

3. More expensive than EBS:- This EFS is much more expensive then a regular EBS volumes, so we need to keep this in mind before using it. 

To integrate this "EFS" File system in EKS, we need to create an "EFS" file system in AWS. Then, mount target (point) in all availability zones, where we deployed our 
kubernetes workers. Suppose we have 2 private subnets in 2 different availability zones, So we need to create 2 mount target (point). Additionally, since it's a network
file system, we need to use the EKS security group to allow kubernetes workers to connect to the EFS file system. Finally, We'll create a kubernetes storage class and use 
the "EFS" storage class to allocate volumes using persistent volume claims or statefulset volume templates.

In this point of time, the EFS CSI driver does not support EKS Pod Identities. In the future they will update the AWS SDK but as of now we only have 2 option.

1. Either attach all permissions to the kubernetes nodes,
                            or
2. The better option to use OIDC (Open ID connect provider). And link the kubernetes service account with an IAM role. 

First the OIDC approch. we need to extract the certificatefrom the EKS cluster and use it to create an Open ID connect provider on the AWS side. And use it to create an
OpenID Connect Provider on the AWS side. "19-openid-connect-provider.tf"

# we are extracting the tls certificate from eks to create ODIC for EFS. 
data "tls_certificate" "eks" {
  url = aws_eks_cluster.eks.identity[0].oidc[0].issuer
}
 
resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificate[0].sha1_fingerprint]
  url             = aws_eks_cluster.eks.identity[0].oidc[0].issuer
}

After this we will create the "EFS" file system. 

resource "aws_efs_file_system" "eks" {
  creation_token = "eks"

  performance_mode = "generalPurpose"
  throughput_mode = "brusting"
  encrypted = true

#    lifecycle_policy {
#        transition_to_ia = "AFTER_30_DAYS"
#   }
}

We can modify some of the field but we have mostly kept it default. Next we need to create mount target (point). In each subnet where we deploy our kubernetes worker 
nodes, Additionally, we need to open a firewall for those worker to connect to the file system. In our case. we'll use the EKS security group that was created by EKS
itself when we provisioned the cluster Now, since we created 2 private subents.

# providing the mount point to the efs and providing the private-subenet-zone1 security group access also.
resource "aws_efs_mount_target" "zone_a" {
  file_system_id  = aws_efs_file_system.eks.id
  subnet_id       = aws_subnet.private_zone1.id
  security_groups = [aws_eks_cluster.eks.vpc_config[0].cluster_security_group_id]  # here basically we are opening the firewall to connect to the EFS file system in this
  # case we have used EKS security group that was created by itself when we provisioned the cluster.
}

resource "aws_efs_mount_target" "zone_b" {
  file_system_id  = aws_efs_file_system.eks.id
  subnet_id       = aws_subnet.private_zone2.id
  security_groups = [aws_eks_cluster.eks.vpc_config[0].cluster_security_group_id]
}

We have created both mount target for both the private subnet where our worker node's were there. In this way all the worker node will able to connect with the EFS 
file system.

Now we provide all the necessary permission for the EFS CSI driver to attach volume to our worker nodes, Because we use an Open ID connect provider, we need to create a 
trust policy and specify the EFS CSI driver Kubernetes service account and the namespace where we will deploy it. 

# we are using the OIDC to connct with EFS to worker node so we are creating the trust policy to provide necessary permission. 
data "aws_iam_policy_document" "efs_csi_driver" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub 
      values   = ["system:serviceaccount:kube-system:efs-csi-controller-sa"]  #specify the EFS CSI driver Kubernetes service account and the namespace where we will deploy it.
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
      type        = "Federated"
    }
  }
}



Now we will create the IAM role and attach the trust policy with it. 
# Iam role for the efs-csi-driver
resource "aws_iam_role" "efs_csi_driver" {
  name        = "${aws_eks_cluster.eks.name}-efs-csi_driver"
  assume_role_policy = data.aws_iam_policy_document.efs_csi_driver.json 
}

# Attaching the trust policy with efs-csi-driver. 
resource "aws_iam_role_policy_attachment" "efs_csi_driver" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy" #This policy manages by AWS for the EFS driver, so let's use that finally. 
  role       = aws_iam_role.efs_csi_driver.name
}

Now we need to deploy ut using a Helm Chart. Where we need to specify the service account name, and most important part is to link the kubernetes, service account with
AWS using the IAM role ARN annotation. In this case, we can dyanmically pass it using a terraform resource refrence. Now, we need to initialize the kubernbetes provider
and use the same data resources that we used before to initialize Helm. 

# Optional since we already init helm provider (just to make it self contained)
data "aws_eks_cluster" "eks_v2" {
  name = aws_eks_cluster.eks.name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.eks_v2.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks_v2.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.eks_v2.token
}

We'll use this new kuberneres terraform provider to create cutome kubernetes storage class that uses the EFS file system. 

resource "kubernetes_storage_class_v1" "efs" {
  metadata {
    name = "efs"
  }

  storage_provisioner = "efs.csi.aws.com"

  parameters = {
    provisioningMode = "efs-ap"
    fileSystemId     = aws_efs_file_system.eks.id
    directoryPerms   = "700"
  }

  mount_options = ["iam"]

  depends_on = [helm_release.efs_csi_driver]
}

Now we'll initalize the terraform again because we have added the new provider. 



