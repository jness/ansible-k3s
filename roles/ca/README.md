# Create certificates authority for registry

Create private key for CA

```
openssl genrsa -out ca.key 4096
```

Next create your certificate for CA

```
openssl req -x509 -new -nodes -key ca.key -sha256 -days 365 -out ca.crt
```

Create a key for your application

```
openssl genrsa -out server.key 4096
```

Create a certificate signing request (CSR) for your application

```
openssl req -new -key server.key -out server.csr -subj "/CN=foo.bar" -addext "subjectAltName = DNS:foo.bar" -extensions v3_req
```

Sign the CSR with our CA

```
openssl x509 -req -days 365 -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -extfile v3.ext
```

Trust the CA on each linux host

```
sudo cp ca.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates
```