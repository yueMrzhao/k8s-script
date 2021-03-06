mkdir /root/ssl
cd /root/ssl
cat >  ca-config.json <<EOF
{
"signing": {
"default": {
  "expiry": "8760h"
},
"profiles": {
  "kubernetes-Soulmate": {
    "usages": [
        "signing",
        "key encipherment",
        "server auth",
        "client auth"
    ],
    "expiry": "8760h"
  }
}
}
}
EOF

cat >  ca-csr.json <<EOF
{
"CN": "kubernetes-Soulmate",
"key": {
"algo": "rsa",
"size": 2048
},
"names": [
{
  "C": "CN",
  "ST": "guangzhou",
  "L": "guangzhou",
  "O": "k8s",
  "OU": "System"
}
]
}
EOF

cfssl gencert -initca ca-csr.json | cfssljson -bare ca

cat > etcd-csr.json <<EOF
{
  "CN": "etcd",
  "hosts": [
    "127.0.0.1",
    "${KUBEM1_IP}",
    "${KUBEM2_IP}",
    "${KUBEM3_IP}"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "guangzhou",
      "L": "guangzhou",
      "O": "k8s",
      "OU": "System"
    }
  ]
}
EOF

cfssl gencert -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes-Soulmate etcd-csr.json | cfssljson -bare etcd
  

#检验证书
openssl x509  -noout -text -in etcd.pem
openssl x509  -noout -text -in etcd-key.pem
openssl x509  -noout -text -in ca.pem

# 3.kubem1分发etcd证书到kubem2,kubem3
cd /root/ssl
mkdir -p /etc/kubernetes/pki/etcd/
cp etcd.pem etcd-key.pem ca.pem  /etc/kubernetes/pki/etcd/
ssh -n ${KUBEM2_NAME} "mkdir -p /etc/kubernetes/pki/etcd/ && rm -rf etc/kubernetes/pki/etcd/* && exit"
ssh -n ${KUBEM3_NAME} "mkdir -p /etc/kubernetes/pki/etcd/ && rm -rf etc/kubernetes/pki/etcd/* && exit"
scp -r /etc/kubernetes/pki/etcd/*.pem ${KUBEM2_NAME}:/etc/kubernetes/pki/etcd/
scp -r /etc/kubernetes/pki/etcd/*.pem ${KUBEM3_NAME}:/etc/kubernetes/pki/etcd/
