# terraform-vcluster-starter



# Manual Testing
## Test k8s can deploy a service

```
kubectl apply -f files/tests/nginx-deployment.yaml
kubectl apply -f files/tests/nginx-service.yaml
```

Then all VMs should be able to 
```
nslookup nginx-service
```

