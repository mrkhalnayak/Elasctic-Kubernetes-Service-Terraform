# Add IAM User & IAM Role to AWS EKS: AWS EKS Kubernetes

### Let's assume that we have created Dev-EKS cluster and if we use IAM user, so only we can access that cluster.

#  It's very likely that you have other teams member, like the devops team wants an admin cluster, and there is a Development team which needs the specific namespace access.
#  like team-1 namespace, and we could create namespace resource quota. where the have only 10-CPU, 20GI-Memory, and the can only create 10-pods.
#  We create resource-quota to avoid any team interferance. so the one team could you the all EKS resource, and if the other team tires to deploy pods, so for sometimes the pods will go on the pending state. 

# here if we have differente development team which belongs to namespace team-2, where they needs the read and write, permission in the cluster, so here we can grant access to the individual user.
# but better approch will be to create a comman IAM-role for all the user's like devops admin, development team's for namespace team-1, and team-2. 
# assign all the permission to the role, and allows the team members to assume that role.

# Now if we create the prod-eks-cluster, so here we assign the admin permission to the devops team member and rest the developer of team-1 and team-2, will get read permission in case of debugging.
# And by using the RBAC, we can assign only application log permission in their specific namespace, so there is lot of flexibility in RBAC.


# from the AWS we can use either IAM user or IAM role as object that represent indentities on kubernetes. for the identities, we can kubernetes service account, user and RBAC group.

Example:- 1
We create an IAM user as well as IAM policy with a minimum set of permission for that IAM user. Which only allows updating the local kubernetes config and connection to the EKS-cluster.
On the kubernetes side, we'll create a viewer role with read-only permission to access certain objects from the core kubernetes API, such as deployments and configmaps.
After this we will use the cluster role binding to bind this viewer RBAC role, to a new my-viewer RBAC group. And finally in order to link the IAM user with this RBAC group,
will use EKS API instead of all deprecated auth configmap.  

The best practice is not to use identities such as IAM role as long term credential 
    
