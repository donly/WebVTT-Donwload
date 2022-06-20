const getVideoSrc = (action) => {
    const videoElem = document.querySelector("#video"); // eg. https://developer.apple.com/videos/
    const trackElem = document.querySelector("track");  // eg. https://brenopolanski.github.io/html5-video-webvtt-example/
    
    var message = {};
    if (trackElem && (trackElem.getAttribute("kind") == "subtitles" || trackElem.getAttribute("kind") == "captions")) {
        message = {src: trackElem.src, action: action, type: "track"}
    }
    else if (videoElem) {
        message = {src: videoElem.src, action: action, type: "m3u8"}
    }

    console.log("message=", message);
    
    return new Promise(resolve => {
        if (Object.keys(message).length === 3) {
            // send message to background.js
            browser.runtime.sendMessage(message).then((response) => {
                console.log("Received response: ", response);
                if (response) {
                    resolve(response);
                }
            });
        } else {
            console.log("WebVTT Not Found!");
            resolve({message: "WebVTT Not Found!"});
        }
    });
}

browser.runtime.onMessage.addListener((request, sender, response) => {
    console.log("Received request = ", request);
    console.log("from sender = ", sender);
    if (request.action) {
        return new Promise(resolve => {
            resolve(getVideoSrc(request.action));
        });
    }
});

