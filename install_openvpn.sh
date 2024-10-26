#!/bin/bash

# ... (phần đầu script giữ nguyên)

# Khởi tạo PKI và tạo chứng chỉ
if [ ! -f "pki/ca.crt" ]; then
    ./easyrsa init-pki
    echo -e "







" | ./easyrsa build-ca nopass
    ./easyrsa gen-dh
    echo -e "







" | ./easyrsa build-server-full server nopass
    openvpn --genkey --secret pki/ta.key
fi

# ... (phần còn lại của script giữ nguyên)

# Tạo khóa cho khách hàng
echo -e "







" | ./easyrsa build-client-full client1 nopass

# ... (phần cuối script giữ nguyên)
