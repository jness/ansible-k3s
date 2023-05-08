# Ansible k3s playbooks

Simple provision of k3s cluster on Raspberry Pi 3 hosts using ansible

> Run ansible playbook using our docker-compose pinned ansible binary

> This is an local/private lab environment with the sole purpose
  or exploration, with that said security is not a top concern.
  and secrets may be unencrypted for time being.

Set up a base Raspberry Pi OS with proper hostnames
and ip addresses (referenced in ./hosts file).

Configure the k3s server (kubernetes) by running the
`k3s-server` playbook:

```
$ docker-compose run app ansible-playbook --vault-password-file vault_password_file.txt k3s-server.yml
```

Once the server is up configure the k3s node (kubelet) using
the `k3s-agent` playbook.

```
$ docker-compose run app ansible-playbook --vault-password-file vault_password_file.txt k3s-agent.yml
```

Once complete you should have two kubernetes nodes,
and a working `kubectl` from your server:

```
user@k3server1:~ $ sudo kubectl get node
NAME        STATUS   ROLES                  AGE    VERSION
k3server1   Ready    control-plane,master   27h    v1.26.3+k3s1
k3node1     Ready    <none>                 8m9s   v1.26.3+k3s1
```

## Deploying our registry

In order to host a local registry we need to create a certificate authority, and sign some application
certificates. This is documented in `roles/ca/README.md`, but to make it easier you can also execute
the `generate_certs.sh` in this project's root.


First tag our node with kubectl, this will be the same host in ansible (`k3registry`):

```
user@k3server1:~ $ sudo kubectl label nodes k3node1 registry=true
node/k3node1 labeled
```

And confirm the tag took effect:

```
user@k3server1:~ $ sudo kubectl get nodes --show-labels
NAME        STATUS   ROLES                  AGE   VERSION        LABELS
k3server1   Ready    control-plane,master   28d   v1.26.3+k3s1   beta.kubernetes.io/arch=arm,beta.kubernetes.io/instance-type=k3s,beta.kubernetes.io/os=linux,kubernetes.io/arch=arm,kubernetes.io/hostname=k3server1,kubernetes.io/os=linux,node-role.kubernetes.io/control-plane=true,node-role.kubernetes.io/master=true,node.kubernetes.io/instance-type=k3s
k3node1     Ready    <none>                 27d   v1.26.3+k3s1   beta.kubernetes.io/arch=arm,beta.kubernetes.io/instance-type=k3s,beta.kubernetes.io/os=linux,kubernetes.io/arch=arm,kubernetes.io/hostname=k3node1,kubernetes.io/os=linux,node.kubernetes.io/instance-type=k3s,registry=true
```

Apply our `k3registry` playbook, this will place the expected certificate and private keys to run the registry over https:

```
$ docker-compose run app ansible-playbook --vault-password-file vault_password_file.txt k3s-registry.yml
```

We can now use kubectl to apply our deployment:

```
user@k3server1:~ $ sudo kubectl apply -f /etc/k3s-deployments/registry-deployment.yml
service/docker-registry-service configured
deployment.apps/docker-registry configured
```

If everything went well you should have a new deployment & pod running successfully:

```
user@k3server1:~ $ sudo kubectl get deployments
NAME              READY   UP-TO-DATE   AVAILABLE   AGE
docker-registry   1/1     1            1           25s

user@k3server1:~ $ sudo kubectl get pods -o wide
NAME                               READY   STATUS    RESTARTS   AGE   IP           NODE      NOMINATED NODE   READINESS GATES
docker-registry-5c89b8d75c-4t8sq   1/1     Running   0          12m   10.42.1.13   k3node1   <none>           <none>
```

We can now find which port our service is running (externally accessible on 30640)

```
user@k3server1:~ $ sudo kubectl get services
NAME                      TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
kubernetes                ClusterIP   10.43.0.1       <none>        443/TCP          28d
docker-registry-service   NodePort    10.43.125.222   <none>        5000:30640/TCP   12s
```

You can try to hit this without FQDN through the kube controller, but you will notice
the certificate isn't valid by IP address:

```
user@k3server1:~ $ curl https://192.168.1.250:30640 -I
curl: (60) SSL: certificate subject name 'foo.bar' does not match target host name '192.168.1.250'
More details here: https://curl.se/docs/sslcerts.html
```

I've went ahead and setup this domain in `/etc/hosts` via roles/common to route to my kube controller:

```
user@k3server1:~ $ ping foo.bar -c 1
PING foo.bar (192.168.1.250) 56(84) bytes of data.
64 bytes from foo.bar (192.168.1.250): icmp_seq=1 ttl=64 time=0.337 ms
```

And like that everything should be working and trusted:

```
user@k3server1:~ $ curl https://foo.bar:30640 -I
HTTP/2 200
cache-control: no-cache
date: Tue, 02 May 2023 14:56:07 GMT
```