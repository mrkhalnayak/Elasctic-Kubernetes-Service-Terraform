resource "helm_release" "matrics-server" {
  name = "metrics-server"

  chart      = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  namespace  = "kube-system" # The metrics server pod always will be get created inside the "kube-system" namespace. 
  version    = "3.12.1"

  values = [file("${path.module}/values/metrics-server.yaml")]
  # here in the values folder inside the metrics-server.yaml file we have updated some of the argument which it will take as input for the template folder inside the metrics-server helm-chart.atomic 

  depends_on = [aws_eks_node_group.general]
}