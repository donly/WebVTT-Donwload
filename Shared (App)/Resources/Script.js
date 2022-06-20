function show(message, enabled) {
    const p = document.querySelector("p.message");
    p.innerText = message;
    if (typeof enabled === "boolean") {
        p.classList.toggle(`state-off`, !enabled);
    } else {
        p.classList.remove(`state-off`);
    }
}

function openPreferences() {
    webkit.messageHandlers.controller.postMessage("open-preferences");
}

function refreshState() {
    webkit.messageHandlers.controller.postMessage("refresh-state");
}

document.querySelector("button.open-preferences").addEventListener("click", openPreferences);
document.querySelector("button.open-refresh").addEventListener("click", refreshState);
