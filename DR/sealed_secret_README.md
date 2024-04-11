# Deploy OpenLDAP

This repo includes a Helm chart for [OpenLdap](https://github.com/osixia/docker-openldap). The chart `values.yaml`
includes the set of principal definitions that Confluent Platform needs for RBAC.

Befor install ldap first you need to create the namespace

```console
kubectl create namespace confluent-dr
```

Deploy OpenLdap:

```
helm upgrade --install -f $TUTORIAL_HOME/assets/openldap/ldaps-rbac.yaml test-ldap $TUTORIAL_HOME/assets/openldap --namespace confluent-dr
```

Validate that OpenLDAP is running:

```
kubectl get pods --namespace confluent-dr
```

Log in to the LDAP pod:

```
kubectl --namespace confluent-dr exec -it ldap-0 -- bash

# Run the LDAP search command
ldapsearch -LLL -x -H ldap://ldap.confluent-dr.svc.cluster.local:389 -b 'dc=test,dc=com' -D "cn=mds,dc=test,dc=com" -w 'Developer!'

# Exit out of the LDAP pod
exit
```

# Security setup

In this workflow scenario, you'll set up a Confluent Platform cluster with the following security:

- Full TLS network encryption using both user provided certificates for external domains and auto-generated certs for internal domains
- mTLS authentication
- Confluent RBAC authorization

This scenario uses static host based routing with an ingress controller to provide external access to certain
REST based Confluent Platform components. View the [static host based routing scenario doc](https://github.com/confluentinc/confluent-kubernetes-examples/tree/master/networking/external-access-static-host-based) for a comprehensive walkthrough of that.

Before continuing with the scenario, ensure that you have set up the [prerequisites](https://github.com/confluentinc/confluent-kubernetes-examples/blob/master/README.md#prerequisites).

This scenario workflow requires the following CLI tools to be available on the machine you are using:

- openssl
- cfssl

## Set the current tutorial directory

Set the tutorial directory for this tutorial under the directory you downloaded the tutorial files:

```
export TUTORIAL_HOME_DR=/Users/juansoto/Documents/GitHub/cfk-gitops/DR
```

## Create TLS certificates

In this scenario, you'll configure authentication using the mTLS mechanism. With mTLS, Confluent components and clients use TLS certificates for authentication. The certificate has a CN that identifies the principal name.

## Deploy configuration secrets

You'll use Kubernetes secrets to provide credential configurations.

With Kubernetes secrets, credential management (defining, configuring, updating)
can be done outside of the Confluent For Kubernetes. You define the configuration
secret, and then tell Confluent For Kubernetes where to find the configuration.

To support the above deployment scenario, you need to provide the following
credentials:

* Component TLS Certificates
* Authentication credentials for Zookeeper, Kafka, Control Center, remaining CP components
* RBAC principal credentials

In this scenario, you'll use both:

- auto-generated certificates for internal network encryption
- user provided certificates for external network encryption

### Configure auto-generated certificates

Confluent For Kubernetes provides auto-generated certificates for Confluent Platform
components to use for TLS network encryption. You'll need to generate and provide a
Certificate Authority (CA).

Generate a CA pair to use:

```
openssl genrsa -out $TUTORIAL_HOME/ca-key.pem 2048

openssl req -new -key $TUTORIAL_HOME/ca-key.pem -x509 \
  -days 1000 \
  -out $TUTORIAL_HOME/ca.pem \
  -subj "/C=US/ST=CA/L=MountainView/O=Confluent/OU=Operator/CN=TestCA"
```

Set environment varible for the sealed secret environment

```console
SEALED_SECRET_DR=/Users/juansoto/Documents/Github/cfk-gitops/overlays/dr/sealed-secrets
```



Create a Kubernetes sealed secret for the certificate authority:

```console
kubectl create secret tls ca-pair-sslcerts-dr --dry-run=client \
  --cert=$TUTORIAL_HOME/ca.pem \
  --key=$TUTORIAL_HOME/ca-key.pem -n confluent-dr -o json > $TUTORIAL_HOME_DR/ca-pair-sslcerts-dr.json
```
NECESARIO!!

```console
kubeseal --cert mycert.pem -f $TUTORIAL_HOME_DR/ca-pair-sslcerts-dr.json -w $SEALED_SECRET_DR/ca-pair-sslcerts-sealed-dr.json --controller-name sealed-secrets --controller-namespace kube-system
```


### Provide external component TLS certificates for Kafka

In this scenario, you'll be allowing Kafka clients to connect with Kafka through the external-to-Kubernetes network.

For that purpose, you'll provide a server certificate that secures the external domain used for Kafka access.

```console
# If you don't have one, create a root certificate authority for the external component certs
openssl genrsa -out $TUTORIAL_HOME/externalRootCAkey.pem 2048

openssl req -x509  -new -nodes \
  -key $TUTORIAL_HOME/externalRootCAkey.pem \
  -days 3650 \
  -out $TUTORIAL_HOME/externalCacerts.pem \
  -subj "/C=US/ST=CA/L=MVT/O=TestOrg/OU=Cloud/CN=TestCA"

# Create Kafka server certificates
cfssl gencert -ca=$TUTORIAL_HOME/externalCacerts.pem \
-ca-key=$TUTORIAL_HOME/externalRootCAkey.pem \
-config=$TUTORIAL_HOME/assets/certs/ca-config.json \
-profile=server $TUTORIAL_HOME/kafka-server-domain.json | cfssljson -bare $TUTORIAL_HOME/kafka-server
```

Provide the certificates to Kafka through a Kubernetes Sealed Secret:

NECESARIO!!!!

```console
kubectl create secret generic tls-kafka-dr --dry-run=client \
  --from-file=fullchain.pem=$TUTORIAL_HOME/kafka-server.pem \
  --from-file=cacerts.pem=$TUTORIAL_HOME/externalCacerts.pem \
  --from-file=privkey.pem=$TUTORIAL_HOME/kafka-server-key.pem \
  --namespace confluent-dr -o json > $TUTORIAL_HOME_DR/tls-kafka-dr.json
```

```console
kubeseal --cert mycert.pem -f $TUTORIAL_HOME_DR/tls-kafka-dr.json -w $SEALED_SECRET_DR/tls-kafka-sealed-dr.json --controller-name sealed-secrets --controller-namespace kube-system
```



### Provide authentication credentials

Create a Kubernetes secret object for Control Center.

This secret object contains file based properties. These files are in the
format that each respective Confluent component requires for authentication
credentials.


```console
kubectl create secret generic credential-dr --dry-run=client \
  --from-file=basic.txt=$TUTORIAL_HOME/creds-control-center-users.txt \
  --from-file=ldap.txt=$TUTORIAL_HOME/ldap.txt \
  --namespace confluent-dr -o json > $TUTORIAL_HOME_DR/credential-dr.json
```

NECESARIO!!
```console
kubeseal --cert mycert.pem -f $TUTORIAL_HOME_DR/credential-dr.json -w $SEALED_SECRET_DR/credential-sealed-dr.json --controller-name sealed-secrets --controller-namespace kube-system
```



### Provide RBAC principal credentials

Create a Kubernetes secret object for MDS:


```console
kubectl create secret generic mds-token-dr --dry-run=client \
  --from-file=mdsPublicKey.pem=$TUTORIAL_HOME/assets/certs/mds-publickey.txt \
  --from-file=mdsTokenKeyPair.pem=$TUTORIAL_HOME/assets/certs/mds-tokenkeypair.txt \
  --namespace confluent-dr -o json > $TUTORIAL_HOME_DR/mds-token-dr.json

# Kafka RBAC credential
kubectl create secret generic mds-client-dr --dry-run=client \
  --from-file=bearer.txt=$TUTORIAL_HOME/kafka-client.txt \
  --namespace confluent-dr -o json > $TUTORIAL_HOME_DR/mds-client-dr.json
# Control Center RBAC credential
kubectl create secret generic c3-mds-client-dr --dry-run=client \
  --from-file=bearer.txt=$TUTORIAL_HOME/c3-mds-client.txt \
  --namespace confluent-dr -o json > $TUTORIAL_HOME_DR/c3-mds-client-dr.json
# Connect RBAC credential
kubectl create secret generic connect-mds-client-dr --dry-run=client \
  --from-file=bearer.txt=$TUTORIAL_HOME/connect-mds-client.txt \
  --namespace confluent-dr -o json > $TUTORIAL_HOME_DR/connect-mds-client-dr.json
# Schema Registry RBAC credential
kubectl create secret generic sr-mds-client-dr --dry-run=client \
  --from-file=bearer.txt=$TUTORIAL_HOME/sr-mds-client.txt \
  --namespace confluent-dr -o json > $TUTORIAL_HOME_DR/sr-mds-client-dr.json
# ksqlDB RBAC credential
kubectl create secret generic ksqldb-mds-client-dr --dry-run=client \
  --from-file=bearer.txt=$TUTORIAL_HOME/ksqldb-mds-client.txt \
  --namespace confluent-dr -o json > $TUTORIAL_HOME_DR/ksqldb-mds-client-dr.json
# Kafka REST credential
kubectl create secret generic rest-credential-dr --dry-run=client \
  --from-file=bearer.txt=$TUTORIAL_HOME/kafka-client.txt \
  --from-file=basic.txt=$TUTORIAL_HOME/kafka-client.txt \
  --namespace confluent-dr -o json >$TUTORIAL_HOME_DR/rest-credential-dr.json
```

```console
kubeseal --cert mycert.pem -f $TUTORIAL_HOME_DR/mds-token-dr.json -w $SEALED_SECRET_DR/mds-token-sealed-dr.json --controller-name sealed-secrets --controller-namespace kube-system

# Kafka RBAC credential
kubeseal --cert mycert.pem -f $TUTORIAL_HOME_DR/mds-client-dr.json -w $SEALED_SECRET_DR/mds-client-sealed-dr.json --controller-name sealed-secrets --controller-namespace kube-system

# Control Center RBAC credential
kubeseal --cert mycert.pem -f $TUTORIAL_HOME_DR/c3-mds-client-dr.json -w $SEALED_SECRET_DR/c3-mds-client-sealed-dr.json --controller-name sealed-secrets --controller-namespace kube-system

# Connect RBAC credential
kubeseal --cert mycert.pem -f $TUTORIAL_HOME_DR/connect-mds-client-dr.json -w $SEALED_SECRET_DR/connect-mds-client-sealed-dr.json --controller-name sealed-secrets --controller-namespace kube-system

# Schema Registry RBAC credential
kubeseal --cert mycert.pem -f $TUTORIAL_HOME_DR/sr-mds-client-dr.json -w $SEALED_SECRET_DR/sr-mds-client-sealed-dr.json --controller-name sealed-secrets --controller-namespace kube-system

# ksqlDB RBAC credential
kubeseal --cert mycert.pem -f $TUTORIAL_HOME_DR/ksqldb-mds-client-dr.json -w $SEALED_SECRET_DR/ksqldb-mds-client-sealed-dr.json --controller-name sealed-secrets --controller-namespace kube-system

# Kafka REST credential
kubeseal --cert mycert.pem -f $TUTORIAL_HOME_DR/rest-credential-dr.json -w $SEALED_SECRET_DR/rest-credential-sealed-dr.json --controller-name sealed-secrets --controller-namespace kube-system
```




## Deploy Confluent Platform

Create a new ArgoCD application using the UI

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cfk-dr
  annotations:
  argocd.argoproj.io/sync-wave: "3"
spec:
  destination:
    name: ''
    namespace: confluent-dr
    server: 'https://kubernetes.default.svc'
  source:
    path: overlays/dr
    repoURL: 'https://github.com/sotojuan2/cfk-gitops'
    targetRevision: dr
  sources: []
  project: dr
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

Or create a new ArgoCD application using the CLI

```shell
argocd app create -f cfk.yaml
```

![ArgoCD UI](./images/all_app.png)

![ArgoCD UI](./images/argo-all.png)

Check that all Confluent Platform resources are deployed:

```
kubectl get pods --namespace confluent-dr
```

If any component does not deploy, it could be due to missing configuration information in secrets.
The Kubernetes events will tell you if there are any issues with secrets. For example:

```
kubectl get events --namespace confluent-dr
Warning  KeyInSecretRefIssue  kafka/kafka  required key [ldap.txt] missing in secretRef [credential] for auth type [ldap_simple]
```

The default required RoleBindings for each Confluent component are created
automatically, and maintained as `confluentrolebinding` custom resources.

```
kubectl get confluentrolebinding --namespace confluent-dr
```

## Create RBAC Rolebindings for Control Center admin

Create Control Center Role Binding for a Control Center `testadmin` user.

```
kubectl apply -f $TUTORIAL_HOME/controlcenter-testadmin-rolebindings.yaml --namespace confluent-dr
```

# Configure External Access through Ingress Controller

The Ingress Controller will support TLS encryption. For this, you'll need to provide a server certificate
to use for encrypting traffic.

```
# Generate a server certificate from the external root certificate authority
cfssl gencert -ca=$TUTORIAL_HOME/externalCacerts.pem \
-ca-key=$TUTORIAL_HOME/externalRootCAkey.pem \
-config=$TUTORIAL_HOME/assets/certs/ca-config.json \
-profile=server $TUTORIAL_HOME/ingress-server-domain.json | cfssljson -bare $TUTORIAL_HOME/ingress-server

kubectl create secret tls tls-nginx-cert \
  --cert=$TUTORIAL_HOME/ingress-server.pem \
  --key=$TUTORIAL_HOME/ingress-server-key.pem \
  --namespace confluent-dr
```

## Install the Nginx Ingress Controller

```
# Add the Kubernetes NginX Helm repo and update the repo
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install the Nginx controller
helm upgrade  --install ingress-nginx ingress-nginx/ingress-nginx
```

## Create Ingress Resources

Create internal bootstrap services for each Confluent Platform component that will round-robin route to each
components' server pods.

```
# Create Confluent Platform component bootstrap services
kubectl apply -f $TUTORIAL_HOME/connect-bootstrap-service.yaml
kubectl apply -f $TUTORIAL_HOME/ksqldb-bootstrap-service.yaml
kubectl apply -f $TUTORIAL_HOME/mds-bootstrap-service.yaml
```

Create an Ingress resource that includes a collection of rules that the Ingress controller uses to route the inbound
traffic to each Confluent Platform component. These will point to the bootstrap services created above.

In the resource file, `$TUTORIAL_HOME/ingress-service-hostbased.yaml`, replace `mydomain.com` with the value of your
external domain.

```
# Create the Ingress resource:
kubectl apply -f $TUTORIAL_HOME/ingress-service-hostbased.yaml
```

## Set up DNS

Create DNS records for Confluent Platform component HTTP endpoints using the ingress controller load balancer externalIP.

```
# Retrieve the external IP addresses of the ingress load balancer:
kubectl get svc
NAME                                 TYPE           CLUSTER-IP     EXTERNAL-IP       PORT(S)
...
ingress-nginx-controller             LoadBalancer   10.98.82.133   104.197.186.121   80:31568/TCP,443:31295/TCP
```

| DNS name                   | IP address                                                  |
| ---------------------------- | ------------------------------------------------------------- |
| controlcenter.mydomain.com | The`EXTERNAL-IP` value of the ingress load balancer service |
| connect.mydomain.com       | The`EXTERNAL-IP` value of the ingress load balancer service |
| ksqldb.mydomain.com        | The`EXTERNAL-IP` value of the ingress load balancer service |

## Validate

### Validate in Control Center

Use Control Center to monitor the Confluent Platform, and see the created topic
and data. You can visit the external URL you set up for Control Center, or visit the URL
through a local port forwarding like below:

Set up port forwarding to Control Center web UI from local machine:

```
kubectl port-forward controlcenter-0 9021:9021 --namespace confluent-dr
```

Browse to Control Center. You will log in as the `testadmin` user, with `testadmin` password.

```
https://localhost:9021
```

The `testadmin` user (`testadmin` password) has the `SystemAdmin` role granted and will have access to the
cluster and broker information.

### Validate component REST Access

You should be able to access the REST endpoint over the external domain name.

Use curl to access ksqldb cluster status. Provide the certificates you created to authenticate:

```
curl -sX GET "https://ksqldb.mydomain.com:443/clusterStatus" --cacert $TUTORIAL_HOME/externalCacerts.pem --key $TUTORIAL_HOME/kafka-server-key.pem --cert $TUTORIAL_HOME/kafka-server.pem
```

### Validate MDS Access

```
confluent login \
 --url https://mds.mydomain.com \
 --ca-cert-path $TUTORIAL_HOME/externalCacerts.pem
```

## Tear down

```
kubectl delete confluentrolebinding --all --namespace confluent-dr
  
kubectl delete -f $TUTORIAL_HOME/confluent-platform-mtls-rbac.yaml --namespace confluent-dr

kubectl delete secret rest-credential ksqldb-mds-client sr-mds-client connect-mds-client c3-mds-client mds-client --namespace confluent-dr

kubectl delete secret mds-token --namespace confluent-dr

kubectl delete secret credential --namespace confluent-dr

kubectl delete secret tls-kafka --namespace confluent-dr

helm delete test-ldap --namespace confluent-dr

helm delete operator --namespace confluent-dr
```

## Appendix: Troubleshooting

### Gather data to troubleshoot

```
# Check for any error messages in events
kubectl get events --namespace confluent-dr

# Check for any pod failures
kubectl get pods --namespace confluent-dr

# For pod failures, check logs
kubectl logs <pod-name> --namespace confluent-dr
```

