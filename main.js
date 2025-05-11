let map;
let marker;
let mapInitialized = false;

async function initMap() {
  const ws = new WebSocket("ws://192.168.1.9:8765");

  ws.onopen = () => {
    console.log("Connected to WebSocket");
  };

  ws.onmessage = async (event) => {
    const data = JSON.parse(event.data);
    const position = { lat: 13.0620412, lng: 80.2046822 };

    document.getElementById("locationData").textContent = JSON.stringify(data, null, 2);
    console.log("Position:", position);

    if (!mapInitialized) {
      // Import map libraries
      const { Map } = await google.maps.importLibrary("maps");
      const { AdvancedMarkerElement } = await google.maps.importLibrary("marker");

      // Initialize the map
      map = new Map(document.getElementById("map"), {
        zoom: 15,
        center: position,
        mapId: "DEMO_MAP_ID",
      });

      // Add the marker
      marker = new AdvancedMarkerElement({
        map: map,
        position: position,
        title: "ESP32",
      });

      mapInitialized = true;
    } else {
      // Update marker position
      marker.position = position;
      map.setCenter(position);
    }
  };

  ws.onerror = (err) => {
    console.error("WebSocket error:", err);
  };
}

initMap();


/*
let center =  { lat: -34.397, lng: 150.644 };

async function initMap() {
  await google.maps.importLibrary("maps");
  await google.maps.importLibrary("marker");

  map = new google.maps.Map(document.getElementById("map"), {
    center,
    zoom: 8,
    mapId: "DEMO_MAP_ID",
  });
}

initMap();
async function init() {
    // Wait until Google Maps is fully loaded
    await new Promise(resolve => {
        if (window.google && window.google.maps) resolve();
        else window.addEventListener('load', resolve);
    });

    // Import the marker library
    const { AdvancedMarkerElement } = await google.maps.importLibrary("marker");

    const ws = new WebSocket("ws://192.168.1.9:8765");

    ws.onopen = () => {
        console.log("Connected to WebSocket");
    };

    ws.onmessage = (event) => {
        const data = JSON.parse(event.data);
        document.getElementById("locationData").textContent = JSON.stringify(data, null, 2);

        const position = { lat: data.latitude, lng: data.longitude };

        const marker = new AdvancedMarkerElement({
            map,
            position,
            title: "Location",
            content: document.getElementById("markerContent"),
        });
        marker.setMap(map);
        map.setCenter(position);
    };

    ws.onerror = (err) => {
        console.error("WebSocket error:", err);
    };

    ws.onclose = () => {
        console.log("WebSocket connection closed");
    };
}

// Start everything
init();
*/
