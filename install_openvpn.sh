#!/bin/bash

# Kiểm tra và cài đặt OpenVPN nếu chưa có
if ! command -v openvpn &> /dev/null; then
    sudo apt update && sudo apt upgrade -y
    sudo apt install openvpn easy-rsa curl zip nginx -y
else
    echo "OpenVPN đã được cài đặt."
fi

# Kiểm tra và tạo thư mục openvpn-ca nếu chưa tồn tại
if [ ! -d "/root/openvpn-ca" ]; then
    make-cadir /root/openvpn-ca
fi

cd /root/openvpn-ca

# Kiểm tra và tạo lại các file chứng chỉ và khóa nếu chúng không tồn tại
if [ ! -f "keys/ca.crt" ] || [ ! -f "keys/server.crt" ] || [ ! -f "keys/server.key" ] || [ ! -f "keys/dh2048.pem" ]; then
    echo "Một hoặc nhiều file chứng chỉ/khóa không tồn tại. Tạo lại..."
    
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
else
    echo "Các file chứng chỉ và khóa đã tồn tại."
fi

# Cấu hình máy chủ OpenVPN
if [ ! -f "/etc/openvpn/server.conf" ]; then
    sudo cp /usr/share/doc/openvpn/examples/sample-config-files/server.conf.gz /etc/openvpn/
    sudo gunzip /etc/openvpn/server.conf.gz
    sudo sed -i 's|;push "redirect-gateway def1 bypass-dhcp"|push "redirect-gateway def1 bypass-dhcp"|' /etc/openvpn/server.conf
    sudo sed -i 's|;user nobody|user nobody|' /etc/openvpn/server.conf
    sudo sed -i 's|;group nogroup|group nogroup|' /etc/openvpn/server.conf
else
    echo "File cấu hình server.conf đã tồn tại."
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

# Tạo khóa cho khách hàng nếu chưa tồn tại
if [ ! -f "keys/client1.key" ]; then
    ./build-key --batch client1
fi

# Xuất tệp client.ovpn với mật khẩu mặc định
SERVER_IP=$(curl -s ifconfig.me)
cat <<EOF > /root/client.ovpn
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
honglee
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
EOF

# Nén file client.ovpn
zip -P honglee@vpn /root/client.zip /root/client.ovpn

# Tạo thư mục cho OpenVPN files
sudo mkdir -p /var/www/html/openvpn

# Di chuyển file client.zip
sudo mv /root/client.zip /var/www/html/openvpn/

# Cấu hình Nginx để phục vụ file
sudo tee /etc/nginx/sites-available/openvpn <<EOF
server {
    listen 80;
    server_name _;
    
    location /openvpn/ {
        root /var/www/html;
        autoindex off;
    }
}
EOF

# Kích hoạt cấu hình Nginx
sudo ln -sf /etc/nginx/sites-available/openvpn /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo systemctl restart nginx

# Tạo link tải HTTP
DOWNLOAD_LINK="http://$SERVER_IP/openvpn/client.zip"

echo "OpenVPN đã được cài đặt và cấu hình thành công."
echo "File client.ovpn đã được tạo với thông tin đăng nhập mặc định:"
echo "  Tên người dùng: honglee"
echo "  Mật khẩu: honglee@vpn"
echo "Link tải file client.zip: $DOWNLOAD_LINK"
echo "Mật khẩu để giải nén file: honglee@vpn"
