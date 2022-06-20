var isDownloading = false;
var portFromCS;

function handleMessage(m) {
    if (m.action == "query_status") {
        portFromCS.postMessage({message: isDownloading ? "WebVTT is already downloading..." : "Ready Go!"});
    }
}

function connected(p) {
  portFromCS = p;
  portFromCS.postMessage({greeting: "hi there content script!"});
  portFromCS.onMessage.addListener(function(m) {
      console.log("In background script, received message:");
      console.log(m);
      handleMessage(m);
  });
}

browser.runtime.onConnect.addListener(connected);

browser.runtime.onMessage.addListener((request, sender) => {
    console.log("Received request: ", request);
    
    if (request.action == "webvtt_dl" && request.src) {
        console.log("sendNativeMessage, isDownloading=", isDownloading);
        if (!isDownloading) {
            isDownloading = true;
            browser.runtime.sendNativeMessage("application.id", { src: request.src, type: request.type }, function(response) {
                console.log("Received sendNativeMessage response:", response);
                isDownloading = false;
                portFromCS.postMessage(response);
                console.log(response);
            });
        } else {
            portFromCS.postMessage({message: "WebVTT is already downloading..."});
        }
    }
});
