#!/bin/bash

# ... (phần đầu script giữ nguyên)

# Tạo và cấu hình thư mục Easy-RSA
EASYRSA_DIR="/etc/openvpn/easy-rsa"
if [ ! -d "$EASYRSA_DIR" ]; then
    sudo mkdir -p "$EASYRSA_DIR"
    sudo cp -r /usr/share/easy-rsa/* "$EASYRSA_DIR"
    sudo chown -R $USER:$USER "$EASYRSA_DIR"
fi

cd "$EASYRSA_DIR"

# Khởi tạo PKI và tạo chứng chỉ
if [ ! -f "pki/ca.crt" ] || [ ! -f "pki/issued/server.crt" ] || [ ! -f "pki/private/server.key" ] || [ ! -f "pki/dh.pem" ]; then
    ./easyrsa init-pki
    echo -e "







" | ./easyrsa build-ca nopass
    ./easyrsa gen-dh
    echo -e "







" | ./easyrsa build-server-full server nopass
    openvpn --genkey --secret pki/ta.key
fi

# Cấu hình máy chủ OpenVPN
if [ ! -f "/etc/openvpn/server.conf" ] || ! grep -q "ca $EASYRSA_DIR/pki/ca.crt" "/etc/openvpn/server.conf"; then
    sudo cp /usr/share/doc/openvpn/examples/sample-config-files/server.conf.gz /etc/openvpn/
    sudo gunzip -f /etc/openvpn/server.conf.gz
    sudo sed -i 's|;push "redirect-gateway def1 bypass-dhcp"|push "redirect-gateway def1 bypass-dhcp"|' /etc/openvpn/server.conf
    sudo sed -i 's|;user nobody|user nobody|' /etc/openvpn/server.conf
    sudo sed -i 's|;group nogroup|group nogroup|' /etc/openvpn/server.conf
    sudo sed -i "s|dh dh2048.pem|dh $EASYRSA_DIR/pki/dh.pem|" /etc/openvpn/server.conf
    sudo sed -i "s|ca ca.crt|ca $EASYRSA_DIR/pki/ca.crt|" /etc/openvpn/server.conf
    sudo sed -i "s|cert server.crt|cert $EASYRSA_DIR/pki/issued/server.crt|" /etc/openvpn/server.conf
    sudo sed -i "s|key server.key|key $EASYRSA_DIR/pki/private/server.key|" /etc/openvpn/server.conf
    sudo sed -i "s|tls-auth ta.key 0|tls-auth $EASYRSA_DIR/pki/ta.key 0|" /etc/openvpn/server.conf
else
    echo "File cấu hình server.conf đã tồn tại và được cấu hình đúng."
fi

# Khởi động dịch vụ OpenVPN
sudo systemctl start openvpn@server
if ! sudo systemctl is-active --quiet openvpn@server; then
    echo "Không thể khởi động dịch vụ OpenVPN. Kiểm tra log để biết thêm chi tiết:"
    sudo journalctl -xe --no-pager | tail -n 50
    echo "Trạng thái dịch vụ OpenVPN:"
    sudo systemctl status openvpn@server
else
    echo "Dịch vụ OpenVPN đã được khởi động thành công."
fi
sudo systemctl enable openvpn@server

# ... (phần còn lại của script giữ nguyên)
