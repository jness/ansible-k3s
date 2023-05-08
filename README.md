# Ansible k3s playbooks

Simple provision of k3s cluster on Raspberry Pi hosts.

> Run ansible cli via Docker & docker-compose, this avoid differences
  in system configuration, and version parity.

Set up a base Raspberry Pi OS with proper host names
and ip addresses (referenced in this repo's `hosts` file).

> You will need to obtain a copy of our `.env` and `.password` files,
  these contain secrets for SSH access, and vault encryption.

`.env` (example)

```
$ cat .env
K3S_PASSWORD=SUPER-SECRET-PASSWORD
ANSIBLE_VAULT_PASSWORD_FILE=.password
```

`.password` (example)

```
$ .password
SUPER-SECRET-SSH-PASSWORD
```

Configure the k3s server (kubernetes) by running the `k3s-server` playbook:

```
$ scripts/ansible-playbook.sh k3s-server.yml
```

Once the server is up, configure the k3s agent nodes (kubelet) using the `k3s-agent` playbook.

```
$ scripts/ansible-playbook.sh k3s-agent.yml
```

Once complete you should have two kubernetes nodes,
and a working `kubectl` from your server:

```
user@k3s-server1:~ $ sudo kubectl get nodes
NAME          STATUS   ROLES                  AGE    VERSION
k3s-agent2    Ready    <none>                 78m    v1.26.4+k3s1
k3s-agent1    Ready    <none>                 78m    v1.26.4+k3s1
k3s-server1   Ready    control-plane,master   119m   v1.26.4+k3s1
```

## Deploying our registry

In order to host a local registry we need to create a certificate authority, and sign some application
certificates. This is documented in `roles/ca/README.md`, but to make it easier you can also execute
the `scripts/generate_certs.sh` in this project's root to generate new certs and keys.

Our `k3s-server` playbook sets up our registrie's prerequisite, all we need to do is run our deployment.

```
user@k3s-server1:~ $ sudo kubectl apply -f /etc/k3s-deployments/registry-deployment.yml
service/docker-registry-service configured
deployment.apps/docker-registry configured
```

If everything went well you should have a new deployment & pod running successfully:

```
user@k3s-server1:~ $ sudo kubectl get deployments
NAME              READY   UP-TO-DATE   AVAILABLE   AGE
docker-registry   1/1     1            1           87m

user@k3s-server1:~ $ sudo kubectl get pods -o wide
NAME                               READY   STATUS    RESTARTS   AGE   IP          NODE          NOMINATED NODE   READINESS GATES
docker-registry-7599dfc484-v6pf9   1/1     Running   0          88m   10.42.0.9   k3s-server1   <none>           <none>
```

We can now find which port our service is running (externally accessible on 30640)

```
user@k3s-server1:~ $ sudo kubectl get services
NAME                      TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)          AGE
kubernetes                ClusterIP   10.43.0.1      <none>        443/TCP          122m
docker-registry-service   NodePort    10.43.59.151   <none>        5000:30495/TCP   88m
```

You can try to hit this without FQDN through the kube controller, but you will notice
the certificate isn't valid by IP address:

```
user@k3s-server1:~ $ curl https://192.168.1.250:30495 -I
curl: (60) SSL: certificate subject name 'foo.bar' does not match target host name '192.168.1.250'
More details here: https://curl.se/docs/sslcerts.html
```

I've went ahead and setup this domain in `/etc/hosts` via roles/common to route to my kube controller:

```
user@k3s-server1:~ $ ping foo.bar -c 1
PING foo.bar (192.168.1.250) 56(84) bytes of data.
64 bytes from foo.bar (192.168.1.250): icmp_seq=1 ttl=64 time=0.337 ms
```

And like that everything should be working and trusted:

```
user@k3s-server1:~ $ curl https://foo.bar:30495 -I
HTTP/2 200
cache-control: no-cache
date: Mon, 08 May 2023 18:13:27 GMT
```