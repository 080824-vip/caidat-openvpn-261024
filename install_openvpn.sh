#!/bin/bash

# Cập nhật hệ thống và cài đặt các gói cần thiết
sudo apt update && sudo apt upgrade -y
sudo apt install openvpn easy-rsa curl zip -y

# Thiết lập Easy-RSA
make-cadir ~/openvpn-ca
cd ~/openvpn-ca

# Cấu hình biến môi trường
cat <<EOF > vars
export KEY_COUNTRY="VN"
export KEY_PROVINCE="SG"
export KEY_CITY="Singapore"
export KEY_ORG="YourOrg"
export KEY_EMAIL="youremail@example.com"
export KEY_OU="YourOU"
EOF

# Tạo chứng chỉ CA và khóa server
source vars
./clean-all
./build-ca --batch
./build-key-server --batch server
./build-dh
openvpn --genkey --secret keys/ta.key

# Cấu hình máy chủ OpenVPN
sudo cp /usr/share/doc/openvpn/examples/sample-config-files/server.conf.gz /etc/openvpn/
sudo gunzip /etc/openvpn/server.conf.gz
sudo sed -i 's|;push "redirect-gateway def1 bypass-dhcp"|push "redirect-gateway def1 bypass-dhcp"|' /etc/openvpn/server.conf
sudo sed -i 's|;user nobody|user nobody|' /etc/openvpn/server.conf
sudo sed -i 's|;group nogroup|group nogroup|' /etc/openvpn/server.conf

# Khởi động dịch vụ OpenVPN
sudo systemctl start openvpn@server
sudo systemctl enable openvpn@server

# Tạo khóa cho khách hàng
cd ~/openvpn-ca
./build-key --batch client1

# Lấy địa chỉ IP công cộng của VPS
SERVER_IP=$(curl -s ifconfig.me)

# Xuất tệp client.ovpn với mật khẩu mặc định
cat <<EOF > ~/client.ovpn
client
dev tun
proto udp
remote $SERVER_IP 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
auth SHA256
cipher AES-256-CBC
verb 3
auth-user-pass
<auth-user-pass>
client
honglee@vpn
</auth-user-pass>

<ca>
$(cat keys/ca.crt)
</ca>
<cert>
$(cat keys/client1.crt)
</cert>
<key>
$(cat keys/client1.key)
</key>
<tls-auth>
$(cat keys/ta.key)
</tls-auth>
EOF

# Nén file client.ovpn
zip -P honglee@vpn ~/client.zip ~/client.ovpn

# Tải file lên bashupload.com
UPLOAD_LINK=$(curl https://bashupload.com/client.zip --data-binary @~/client.zip)

echo "OpenVPN đã được cài đặt và cấu hình thành công."
echo "File client.ovpn đã được tạo với mật khẩu mặc định: honglee@vpn"
echo "Link tải file client.zip: $UPLOAD_LINK"
echo "Mật khẩu để giải nén file: honglee@vpn"
