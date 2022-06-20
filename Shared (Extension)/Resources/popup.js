var myPort = browser.runtime.connect({name:"port-from-cs"});

myPort.onMessage.addListener(function(m) {
    console.log(m);
    if (m.message) {
        showResult(m);
    }
});

myPort.postMessage({action: "query_status"});

const sendAction = async (action) => {
    const [tab] = await browser.tabs.query({currentWindow: true, active: true})
    chrome.tabs.sendMessage(tab.id, { action }).then((response) => {
        console.log("response=" + response.message)
        if (response) {
            showResult(response)
        }
    })
}


const button = document.createElement('button')
button.innerText = "Download WebVTT"
document.querySelector('#button-container').appendChild(button)
button.addEventListener('click', e => {
    document.querySelector('#result-text').innerText = "Downloading..."
    sendAction("webvtt_dl")
})

//function logTabs(tabs) {
//  // tabs[0].url requires the `tabs` permission or a matching host permission.
//  console.log(tabs[0].url);
//}
//
//function onError(error) {
//  console.log(`Error: ${error}`);
//}

function openUrl(obj) {
    let url = obj.currentTarget.getAttribute("href");
    window.open(url, "_blank");
    return false;
}

function downloadSRT(url) {
//    var xhr = new XMLHttpRequest();
//    xhr.open('GET', url, true);
//    xhr.responseType = 'blob';
//    xhr.onload = function(e) {
//        if (this.status == 200) {
//            var myBlob = this.response;
//            var link = document.createElement('a');
//            link.href = window.URL.createObjectURL(myBlob);
//            link.download = "English.srt";
//            link.click();
//        }
//    };
//    xhr.send();
    
    var ul = document.querySelector('#srt-list');
    var li = document.createElement('li');
    ul.appendChild(li);
    var pom = document.createElement('a');
    li.appendChild(pom);
    pom.setAttribute('href', url);
    pom.setAttribute('download', "English.srt");
    pom.addEventListener("click", openUrl);
//    pom.setAttribute('onclick', "openUrl(this); return false;")
    pom.setAttribute('target', "_blank");
    pom.innerText = "English.srt";
    
//    if (document.createEvent) {
//        var event = document.createEvent('MouseEvents');
//        event.initEvent('click', true, true);
//        pom.dispatchEvent(event);
//    }
//    else {
//        pom.click();
//    }
    
//    const [tab] = await browser.tabs.query({currentWindow: true, active: true})
//    let querying = browser.tabs.query({currentWindow: true, active: true});
//    querying.then(logTabs, onError);
}

function showResult(response) {
    document.querySelector('#result-text').innerText = response.message;
//    var ul = document.querySelector('#srt-list');
//    var li = document.createElement('li');
//    li.innerText = response.url;
//    ul.appendChild(li);
}
