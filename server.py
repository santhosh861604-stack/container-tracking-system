import network
import ujson
import urequests
import time
import usocket as socket
import ustruct as struct
import sys
import uselect

# CONFIG SECTION
WIFI_SSID = 'SANTHOSH'
WIFI_PASSWORD = 'Santhosh'
GOOGLE_API_KEY = 'AIzaSyDgnLe_6ErHrxU6ZX6ByufAcjPuhr1r0TQ'
PORT = 8266

def connect_wifi(ssid, password):
    wlan = network.WLAN(network.STA_IF)
    wlan.active(True)
    if not wlan.isconnected():
        print("Connecting to WiFi...")
        wlan.connect(ssid, password)
        while not wlan.isconnected():
            time.sleep(1)
    print("Connected:", wlan.ifconfig())

def scan_networks():
    wlan = network.WLAN(network.STA_IF)
    wlan.active(True)
    nets = wlan.scan()
    access_points = []
    for net in nets:
        ap = {
            "macAddress": ':'.join('%02x' % b for b in net[1]),
            "signalStrength": net[3]
        }
        access_points.append(ap)
    return access_points

def get_geolocation(api_key, wifi_data):
    url = "https://www.googleapis.com/geolocation/v1/geolocate?key=" + api_key
    headers = {'Content-Type': 'application/json'}
    payload = ujson.dumps({"wifiAccessPoints": wifi_data})
    try:
        response = urequests.post(url, data=payload, headers=headers)
        if response.status_code == 200:
            data = response.json()
            location = data['location']
            return {
                "latitude": location['lat'],
                "longitude": location['lng'],
                "accuracy": data['accuracy']
            }
        else:
            print("Geolocation API Error:", response.status_code)
            return None
    except Exception as e:
        print("Error in geolocation:", str(e))
        return None

# Simple WebSocket handshake
def websocket_handshake(client):
    try:
        request = client.recv(1024)
        headers = request.decode().split('\r\n')
        for h in headers:
            if 'Sec-WebSocket-Key' in h:
                key = h.split(': ')[1]
        import ubinascii
        import hashlib
        GUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'
        accept = ubinascii.b2a_base64(hashlib.sha1((key + GUID).encode()).digest()).decode().strip()
        handshake = \
            'HTTP/1.1 101 Switching Protocols\r\n' \
            'Upgrade: websocket\r\n' \
            'Connection: Upgrade\r\n' \
            'Sec-WebSocket-Accept: {}\r\n\r\n'.format(accept)
        client.send(handshake.encode())
        print("WebSocket handshake done.")
    except Exception as e:
        print("Handshake failed:", str(e))

def send_ws_message(client, message):
    # Frame for small text message
    msg_bytes = message.encode()
    length = len(msg_bytes)
    frame = bytearray()
    frame.append(0x81)  # FIN + text frame
    if length < 126:
        frame.append(length)
    else:
        frame.append(126)
        frame.extend(struct.pack(">H", length))
    frame.extend(msg_bytes)
    client.send(frame)

def websocket_server():
    addr = socket.getaddrinfo('0.0.0.0', PORT)[0][-1]
    s = socket.socket()
    s.bind(addr)
    s.listen(1)
    print("WebSocket server running on port", PORT)

    while True:
        client, addr = s.accept()
        print("Client connected from:", addr)
        websocket_handshake(client)

        # Fetch location
        wifi_info = scan_networks()
        location = get_geolocation(GOOGLE_API_KEY, wifi_info)

        if location:
            message = ujson.dumps(location)
            send_ws_message(client, message)
            print("Location sent:", message)
        else:
            send_ws_message(client, '{"error": "Location failed"}')

        client.close()
        print("Client disconnected\n")

# MAIN
connect_wifi(WIFI_SSID, WIFI_PASSWORD)
websocket_server()
