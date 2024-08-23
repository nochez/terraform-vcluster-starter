# terraform-vcluster-starter



# Manual Testing
## Nomad

```
export NOMAD_TOKEN=<find it in nomad_bootstrap_token.json>
export NOMAD_ADDR="http://192.168.11.2:4646"
nomad node status
```

## Test k8s can deploy a service

```
export KUBECONFIG=k3s-192.168.11.2.yaml
kubectl get nodes
kubectl apply -f files/tests/nginx-deployment.yaml
kubectl apply -f files/tests/nginx-service.yaml
```

Then all VMs should be able to 
```
nslookup nginx-service
```

