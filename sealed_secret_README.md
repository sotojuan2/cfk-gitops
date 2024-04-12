# Install ArgoCD

ArgoCD can be installed using either kubectl or Helm. Choose one of the following methods:

## Using kubectl

```shell
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

## Verify argo status

```console
kubectl get all -n argocd
```

The output will be similar to

```console
NAME                                                    READY   STATUS    RESTARTS   AGE
pod/argocd-application-controller-0                     1/1     Running   0          2m18s
pod/argocd-applicationset-controller-7b9c4dfb77-j6j7z   1/1     Running   0          2m18s
pod/argocd-dex-server-9b5c6dccd-r9ndm                   1/1     Running   0          2m18s
pod/argocd-notifications-controller-756764ddd5-7vt26    1/1     Running   0          2m18s
pod/argocd-redis-69f8795dbd-7nqpm                       1/1     Running   0          2m18s
pod/argocd-repo-server-565fb47c89-49txx                 1/1     Running   0          2m18s
pod/argocd-server-86f64667bc-z29lc                      1/1     Running   0          2m18s

NAME                                              TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
service/argocd-applicationset-controller          ClusterIP   10.111.117.180   <none>        7000/TCP,8080/TCP            2m18s
service/argocd-dex-server                         ClusterIP   10.108.32.9      <none>        5556/TCP,5557/TCP,5558/TCP   2m18s
service/argocd-metrics                            ClusterIP   10.102.142.243   <none>        8082/TCP                     2m18s
service/argocd-notifications-controller-metrics   ClusterIP   10.97.251.128    <none>        9001/TCP                     2m18s
service/argocd-redis                              ClusterIP   10.98.98.139     <none>        6379/TCP                     2m18s
service/argocd-repo-server                        ClusterIP   10.104.222.35    <none>        8081/TCP,8084/TCP            2m18s
service/argocd-server                             ClusterIP   10.109.35.157    <none>        80/TCP,443/TCP               2m18s
service/argocd-server-metrics                     ClusterIP   10.102.228.115   <none>        8083/TCP                     2m18s

NAME                                               READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/argocd-applicationset-controller   1/1     1            1           2m18s
deployment.apps/argocd-dex-server                  1/1     1            1           2m18s
deployment.apps/argocd-notifications-controller    1/1     1            1           2m18s
deployment.apps/argocd-redis                       1/1     1            1           2m18s
deployment.apps/argocd-repo-server                 1/1     1            1           2m18s
deployment.apps/argocd-server                      1/1     1            1           2m18s

NAME                                                          DESIRED   CURRENT   READY   AGE
replicaset.apps/argocd-applicationset-controller-7b9c4dfb77   1         1         1       2m18s
replicaset.apps/argocd-dex-server-9b5c6dccd                   1         1         1       2m18s
replicaset.apps/argocd-notifications-controller-756764ddd5    1         1         1       2m18s
replicaset.apps/argocd-redis-69f8795dbd                       1         1         1       2m18s
replicaset.apps/argocd-repo-server-565fb47c89                 1         1         1       2m18s
replicaset.apps/argocd-server-86f64667bc                      1         1         1       2m18s

NAME                                             READY   AGE
statefulset.apps/argocd-application-controller   1/1     2m18s
```

## Get password

```console
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

## Access ArgoCD UI

After installing ArgoCD, access the ArgoCD web UI using port-forwarding:

```console
kubectl port-forward svc/argocd-server -n argocd 8080:443
````

Then, open your web browser and navigate to http://localhost:8080. The user is admin and the password is the output of the step [above](get_password).

![ArgoCD UI](./images/argocd-ui.png)

Further detail in the  following [link](https://apexlemons.com/devops/argocd-on-minikube-on-macos/)


# Install Sealed Secrets with Helm

## Add Helm Repository

Use the following command to add the Sealed Secrets Helm repository:

```console
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
```

## Update Helm Repositories (Optional)

It's a good practice to update your Helm repositories to ensure you have the latest information. Run:

```console
helm repo update
```

## Install Sealed Secrets

Use Helm to install Sealed Secrets into your Kubernetes cluster. You can install it into a specific namespace if needed. For example:

```console
helm install sealed-secrets-controller sealed-secrets/sealed-secrets  --namespace kube-system
```

Replace sealed-secrets-controller with your preferred release name.

## Verify Installation

Once the installation is complete, verify that Sealed Secrets has been installed correctly by checking the resources in the target namespace. Run:

```console
kubectl get pods -n kube-system
```

Replace <namespace> with the namespace where Sealed Secrets was installed (default is usually kube-system).

## Fetch Sealed Secrets Controller Public Key

To encrypt secrets using Sealed Secrets, you'll need to fetch the public key of the Sealed Secrets controller. Run the following command:

```console
kubeseal --fetch-cert --controller-name sealed-secrets-controller --controller-namespace kube-system > mycert.pem
```

This command fetches the public key of the Sealed Secrets controller and saves it to a file named mycert.pem.

## (Optional) Access Sealed Secrets UI

Sealed Secrets also provides a web UI for managing sealed secrets. If you want to access the UI, you may need to set up port-forwarding or expose the service externally depending on your cluster configuration.

# Deploy OpenLDAP

This repo includes a Helm chart for [OpenLdap](https://github.com/osixia/docker-openldap). The chart `values.yaml`
includes the set of principal definitions that Confluent Platform needs for RBAC.

Befor install ldap first you need to create the namespace

```console
kubectl create namespace confluent-dev
```

Deploy OpenLdap:

```
helm upgrade --install -f $TUTORIAL_HOME/assets/openldap/ldaps-rbac.yaml test-ldap $TUTORIAL_HOME/assets/openldap --namespace confluent-dev
```

Validate that OpenLDAP is running:

```
kubectl get pods --namespace confluent-dev
```

Log in to the LDAP pod:

```
kubectl --namespace confluent-dev exec -it ldap-0 -- bash

# Run the LDAP search command
ldapsearch -LLL -x -H ldap://ldap.confluent-dev.svc.cluster.local:389 -b 'dc=test,dc=com' -D "cn=mds,dc=test,dc=com" -w 'Developer!'

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
export TUTORIAL_HOME=<Tutorial directory>/security/internal_external-tls_mtls_confluent-rbac
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
SEALED_SECRET=/Users/juansoto/Documents/Github/cfk-gitops/overlays/dev/sealed-secrets
```



Create a Kubernetes sealed secret for the certificate authority:

```console
kubectl create secret tls ca-pair-sslcerts --dry-run=client \
  --cert=$TUTORIAL_HOME/ca.pem \
  --key=$TUTORIAL_HOME/ca-key.pem -n confluent-dev -o json > ca-pair-sslcerts.json
```

```console
kubeseal --cert mycert.pem -f ca-pair-sslcerts.json -w $SEALED_SECRET/ca-pair-sslcerts-sealed.json --controller-name sealed-secrets --controller-namespace kube-system
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

```console
kubectl create secret generic tls-kafka --dry-run=client \
  --from-file=fullchain.pem=$TUTORIAL_HOME/kafka-server.pem \
  --from-file=cacerts.pem=$TUTORIAL_HOME/externalCacerts.pem \
  --from-file=privkey.pem=$TUTORIAL_HOME/kafka-server-key.pem \
  --namespace confluent-dev -o json >tls-kafka.json
```

```console
kubeseal --cert mycert.pem -f tls-kafka.json -w $SEALED_SECRET/tls-kafka-sealed.json --controller-name sealed-secrets --controller-namespace kube-system
```



### Provide authentication credentials

Create a Kubernetes secret object for Control Center.

This secret object contains file based properties. These files are in the
format that each respective Confluent component requires for authentication
credentials.

```console
kubectl create secret generic credential --dry-run=client \
  --from-file=basic.txt=$TUTORIAL_HOME/creds-control-center-users.txt \
  --from-file=ldap.txt=$TUTORIAL_HOME/ldap.txt \
  --namespace confluent-dev -o json >credential.json
```

```console
kubeseal --cert mycert.pem -f credential.json -w $SEALED_SECRET/credential-sealed.json --controller-name sealed-secrets --controller-namespace kube-system
```



### Provide RBAC principal credentials

Create a Kubernetes secret object for MDS:

```console
kubectl create secret generic mds-token --dry-run=client \
  --from-file=mdsPublicKey.pem=$TUTORIAL_HOME/assets/certs/mds-publickey.txt \
  --from-file=mdsTokenKeyPair.pem=$TUTORIAL_HOME/assets/certs/mds-tokenkeypair.txt \
  --namespace confluent-dev -o json > mds-token.json

# Kafka RBAC credential
kubectl create secret generic mds-client --dry-run=client \
  --from-file=bearer.txt=$TUTORIAL_HOME/kafka-client.txt \
  --namespace confluent-dev -o json > mds-client.json
# Control Center RBAC credential
kubectl create secret generic c3-mds-client --dry-run=client \
  --from-file=bearer.txt=$TUTORIAL_HOME/c3-mds-client.txt \
  --namespace confluent-dev -o json > c3-mds-client.json
# Connect RBAC credential
kubectl create secret generic connect-mds-client --dry-run=client \
  --from-file=bearer.txt=$TUTORIAL_HOME/connect-mds-client.txt \
  --namespace confluent-dev -o json > connect-mds-client.json
# Schema Registry RBAC credential
kubectl create secret generic sr-mds-client --dry-run=client \
  --from-file=bearer.txt=$TUTORIAL_HOME/sr-mds-client.txt \
  --namespace confluent-dev -o json > sr-mds-client.json
# ksqlDB RBAC credential
kubectl create secret generic ksqldb-mds-client --dry-run=client \
  --from-file=bearer.txt=$TUTORIAL_HOME/ksqldb-mds-client.txt \
  --namespace confluent-dev -o json >ksqldb-mds-client.json
# Kafka REST credential
kubectl create secret generic rest-credential --dry-run=client \
  --from-file=bearer.txt=$TUTORIAL_HOME/kafka-client.txt \
  --from-file=basic.txt=$TUTORIAL_HOME/kafka-client.txt \
  --namespace confluent-dev -o json >rest-credential.json
```

```console
kubeseal --cert mycert.pem -f mds-token.json -w $SEALED_SECRET/mds-token-sealed.json --controller-name sealed-secrets --controller-namespace kube-system

# Kafka RBAC credential
kubeseal --cert mycert.pem -f mds-client.json -w $SEALED_SECRET/mds-client-sealed.json --controller-name sealed-secrets --controller-namespace kube-system

# Control Center RBAC credential
kubeseal --cert mycert.pem -f c3-mds-client.json -w $SEALED_SECRET/c3-mds-client-sealed.json --controller-name sealed-secrets --controller-namespace kube-system

# Connect RBAC credential
kubeseal --cert mycert.pem -f connect-mds-client.json -w $SEALED_SECRET/connect-mds-client-sealed.json --controller-name sealed-secrets --controller-namespace kube-system

# Schema Registry RBAC credential
kubeseal --cert mycert.pem -f sr-mds-client.json -w $SEALED_SECRET/sr-mds-client-sealed.json --controller-name sealed-secrets --controller-namespace kube-system

# ksqlDB RBAC credential
kubeseal --cert mycert.pem -f ksqldb-mds-client.json -w $SEALED_SECRET/ksqldb-mds-client-sealed.json --controller-name sealed-secrets --controller-namespace kube-system

# Kafka REST credential
kubeseal --cert mycert.pem -f rest-credential.json -w $SEALED_SECRET/rest-credential-sealed.json --controller-name sealed-secrets --controller-namespace kube-system
```


## Deploy Confluet for kubernetes

Login in argo UI and add a new application. Copy and paste the following yaml.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: operator
  annotations:
    argocd.argoproj.io/sync-wave: "1"
spec:
  destination:
    name: ''
    namespace: confluent-dev
    server: 'https://kubernetes.default.svc'
  source:
    path: ''
    repoURL: 'https://packages.confluent.io/helm'
    targetRevision: 0.824.40
    chart: confluent-for-kubernetes
    helm:
      setValues:
        namespaced: false
  sources: []
  project: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - ServerSideApply=true

```

Or you can use the argocd cli

```shell
argocd login localhost:8080
argocd app create -f cfk-helm2.yaml
```

At the end you will see the following in argocd UI
![ArgoCD UI](./images/operator.png)

## Deploy Confluent Platform

Create a new ArgoCD application using the UI

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cfk
  annotations:
  argocd.argoproj.io/sync-wave: "2"
spec:
  destination:
    name: ''
    namespace: confluent-dev
    server: 'https://kubernetes.default.svc'
  source:
    path: overlays/dev
    repoURL: 'https://github.com/sotojuan2/cfk-gitops'
    targetRevision: HEAD
  sources: []
  project: default
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
kubectl get pods --namespace confluent-dev
```

If any component does not deploy, it could be due to missing configuration information in secrets.
The Kubernetes events will tell you if there are any issues with secrets. For example:

```
kubectl get events --namespace confluent-dev
Warning  KeyInSecretRefIssue  kafka/kafka  required key [ldap.txt] missing in secretRef [credential] for auth type [ldap_simple]
```

The default required RoleBindings for each Confluent component are created
automatically, and maintained as `confluentrolebinding` custom resources.

```
kubectl get confluentrolebinding --namespace confluent-dev
```

## Create RBAC Rolebindings for Control Center admin

Create Control Center Role Binding for a Control Center `testadmin` user.

```
kubectl apply -f $TUTORIAL_HOME/controlcenter-testadmin-rolebindings.yaml --namespace confluent-dev
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
  --namespace confluent-dev
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
kubectl port-forward controlcenter-0 9021:9021 --namespace confluent-dev
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
kubectl delete confluentrolebinding --all --namespace confluent-dev
  
kubectl delete -f $TUTORIAL_HOME/confluent-platform-mtls-rbac.yaml --namespace confluent-dev

kubectl delete secret rest-credential ksqldb-mds-client sr-mds-client connect-mds-client c3-mds-client mds-client --namespace confluent-dev

kubectl delete secret mds-token --namespace confluent-dev

kubectl delete secret credential --namespace confluent-dev

kubectl delete secret tls-kafka --namespace confluent-dev

helm delete test-ldap --namespace confluent-dev

helm delete operator --namespace confluent-dev
```

## Appendix: Troubleshooting

### Gather data to troubleshoot

```
# Check for any error messages in events
kubectl get events --namespace confluent-dev

# Check for any pod failures
kubectl get pods --namespace confluent-dev

# For pod failures, check logs
kubectl logs <pod-name> --namespace confluent-dev
```

