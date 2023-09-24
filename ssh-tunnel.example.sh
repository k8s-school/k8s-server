# Auth
ssh-keygen
ssh-copy-id -p 16042 k8s0@178.170.42.15

# Create cluster
./k8s-create.sh -n $USER

# Tunnel
ssh -p 16042 k8s0@178.170.42.15 -L 8080:localhost:8080 -N
ssh -p 16042 k8s1@178.170.42.15 -L 8081:localhost:8081 -N
