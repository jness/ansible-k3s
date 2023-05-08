#!/bin/bash

pushd roles/ca/files

# generate new CA private key and certificate
openssl genrsa -out ca.key.enc 4096
openssl req -x509 -new -nodes -key ca.key.enc -sha256 -days 365 -out ca.crt -subj "/CN=ca.bar"

# generate new application private key and certificate
openssl genrsa -out server.key.enc 4096
openssl req -new -key server.key.enc -out server.csr -subj "/CN=foo.bar" -addext "subjectAltName = DNS:foo.bar"

# sign application certificate with our CA
openssl x509 -req -days 365 -in server.csr -CA ca.crt -CAkey ca.key.enc -CAcreateserial -out server.crt -extfile v3.ext

popd

# encrypt private keys with ansible vault
docker-compose run app ansible-vault encrypt roles/ca/files/server.key.enc
docker-compose run app ansible-vault encrypt roles/ca/files/ca.key.enc

# copy ca certificate to common role
cp roles/ca/files/ca.crt roles/common/files/

# move application certificate and private key into registry role
mv roles/ca/files/server.crt roles/registry/files/
mv roles/ca/files/server.key.enc roles/registry/files/
rm -rf roles/ca/files/server.csr
