import network
import ujson
import urequests
import time

# Replace these
WIFI_SSID = 'SureshWifi'
WIFI_PASSWORD = 'ssskk007'
GOOGLE_API_KEY = 'AIzaSyDQuKBANCfVWHbOSKejLFg7TH9hx0_zlRE'

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
    payload = ujson.dumps({
        "wifiAccessPoints": wifi_data
    })
    try:
        response = urequests.post(url, data=payload, headers=headers)
        if response.status_code == 200:
            location = response.json()['location']
            accuracy = response.json()['accuracy']
            print("Latitude:", location['lat'])
            print("Longitude:", location['lng'])
            print("Accuracy (m):", accuracy)
        else:
            print("Error:", response.status_code, response.text)
        response.close()
    except Exception as e:
        print("Request failed:", str(e))

# Run everything
connect_wifi(WIFI_SSID, WIFI_PASSWORD)
wifi_info = scan_networks()
get_geolocation(GOOGLE_API_KEY, wifi_info)
