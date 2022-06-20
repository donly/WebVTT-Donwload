//
//  SafariWebExtensionHandler.swift
//  Shared (Extension)
//
//  Created by Tung Lim Chan on 8/6/2022.
//

import SafariServices
import os.log
import Pantomime

class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    func beginRequest(with context: NSExtensionContext) {
        let item = context.inputItems[0] as! NSExtensionItem
        let message = item.userInfo?[SFExtensionMessageKey] as? Dictionary<String, String>
        
        if let src = message?["src"],
           let url = URL(string: src),
           let type = message?["type"],
           let folder = try? FileManager.default
            .url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true) {
            
            Logger.viewCycle.info("type=\(type, privacy: .public), url=\(url, privacy: .public)")
            
            if type == "track" {
                downloadVttInTrack([url], to: folder, context: context)
            }
            else if type == "m3u8" {
                downloadWebVttInM3u8(url, to: folder, context: context)
            }
        } else {
            let response = NSExtensionItem()
            response.userInfo = [ SFExtensionMessageKey: [ "message": "Failed to download WebVTT." ] ]
            context.completeRequest(returningItems: [response], completionHandler: nil)
        }
    }
    
    private func downloadVttInTrack(_ urls: [URL], to folder: URL, context: NSExtensionContext) {
        Task {
            let dirContents = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            
            for fileUrl in dirContents where fileUrl.pathExtension == "vtt" {
                try FileManager.default.removeItem(at: fileUrl)
            }
            
            let savedVttUrls = try await downloadWebVtt(urls, folder: folder)
            Logger.viewCycle.info("download vtt finish.")
            
            if let srtContent = convertWebVTTs2Srt(savedVttUrls), let container = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
                let srtFileName = "\(savedVttUrls.first!.lastPathComponent).srt"
                let srtUrl = container.appendingPathComponent(srtFileName)
                try srtContent.write(to: srtUrl, atomically: true, encoding: String.Encoding.utf8)
                Logger.viewCycle.info("srtUrl=\(srtUrl, privacy: .public)")
                
                let response = NSExtensionItem()
                response.userInfo = [
                    SFExtensionMessageKey:
                        [
                            "message": "Convert WebVTT to srt successful.",
                            "url": srtUrl.absoluteString
                        ]
                ]
                context.completeRequest(returningItems: [response], completionHandler: nil)
            }
        }
    }
    
    private func downloadWebVttInM3u8(_ url: URL, to folder: URL, context: NSExtensionContext) {
        let masterPlaylist = ManifestBuilder().parse(url)
        
        Logger.viewCycle.info("subtitle count=\(masterPlaylist.getPlaylistCount(), privacy: .public)")
        
        if let subtitle = masterPlaylist.getPlaylists(type: .subtitles).first,
           let name = subtitle.name,
           let uri = subtitle.path {
            Logger.viewCycle.info("use default subtitle \(name, privacy: .public), uri = \(uri, privacy: .public)")
            
            let subtitleUrl = url.deletingLastPathComponent().appendingPathComponent(uri)
            
            Logger.viewCycle.info("subtitle full url = \(subtitleUrl, privacy: .public)")
            Logger.viewCycle.info("subtitle segment count = \(subtitle.getSegmentCount(), privacy: .public)")
            
            let urls = subtitle.getAllSegments().compactMap {
                subtitleUrl.deletingLastPathComponent().appendingPathComponent($0.path!)
            }
            
            Task {
                do {
                    Logger.viewCycle.info("donloading webvtt..., count = \(urls.count, privacy: .public)")
                    
                    var dirContents = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
                    
                    for fileUrl in dirContents where fileUrl.pathExtension == "webvtt" {
                        try FileManager.default.removeItem(at: fileUrl)
                    }
                    
                    _ = try await downloadWebVtt(urls, folder: folder)
                    Logger.viewCycle.info("download webvtt finish.")
                    
                    dirContents = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
                    let webvttUrls = dirContents.filter { $0.pathExtension == "webvtt" }
                    if webvttUrls.count == subtitle.getSegmentCount() { // make sure all subtitles were downloaded
                        let urls = subtitle.getAllSegments().map {
                            folder.appendingPathComponent($0.path!)
                        }
                        if let srt = convertWebVTTs2Srt(urls), let container = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
                            let srtFileName = "\(name.replacingOccurrences(of: "\"", with: "")).srt"
                            let srtUrl = container.appendingPathComponent(srtFileName)
                            try srt.write(to: srtUrl, atomically: true, encoding: String.Encoding.utf8)
                            Logger.viewCycle.info("srtUrl=\(srtUrl, privacy: .public)")
                            
                            let response = NSExtensionItem()
                            response.userInfo = [
                                SFExtensionMessageKey:
                                    [
                                        "message": "Convert WebVTT to srt successful.",
                                        "url": srtUrl.absoluteString
                                    ]
                            ]
                            context.completeRequest(returningItems: [response], completionHandler: nil)
                        }
                    } else {
                        let response = NSExtensionItem()
                        response.userInfo = [ SFExtensionMessageKey: [ "message": "Failed to download WebVTT." ] ]
                        context.completeRequest(returningItems: [response], completionHandler: nil)
                    }
                } catch {
                    Logger.viewCycle.info("error = \(error.localizedDescription, privacy: .public)")
                    let response = NSExtensionItem()
                    response.userInfo = [ SFExtensionMessageKey: [ "message": error.localizedDescription ] ]
                    context.completeRequest(returningItems: [response], completionHandler: nil)
                }
            } // Task end
        }
    }

    private func downloadWebVtt(_ urls: [URL], folder: URL) async throws -> [URL] {
        var pathUrls: [URL] = []
        for url in urls {
            let (source, _) = try await URLSession.shared.download(with: url)
            let destination = folder.appendingPathComponent(url.lastPathComponent)
            Logger.viewCycle.info("source = \(source, privacy: .public), destination = \(destination, privacy: .public)")
            if !FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.moveItem(at: source, to: destination)
            }
            
            pathUrls.append(destination)
        }
        
        return pathUrls
    }
    
    private func convertWebVTTs2Srt(_ urls: [URL]) -> String? {
        do {
            var seqNum = 1
            var srtContent = ""
            for url in urls {
                if let srt = try parseWebVTTCue2Srt(url, seqNum: &seqNum) {
                    srtContent += srt
                }
            }

            return srtContent
        } catch {
            Logger.viewCycle.info("convertWebVTTs2Srt error = \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
    
    private func parseWebVTTCue2Srt(_ url: URL, seqNum: inout Int) throws -> String? {
        let content = try String(contentsOf: url)
        let reader = StringBufferedReader(string: content)
        var isValid = false
        var srtContent = ""
        var hasSeqNum = false
        while let line = reader.readLine() {
            if line.isEmpty {
                srtContent += "\n"
            } else if line == "WEBVTT" {
                isValid = true
            } else if line.contains("-->") {
                if !hasSeqNum {
                    srtContent += "\(seqNum)\n"
                    seqNum += 1
                }
                let timeInfos = line.split(separator: " ").prefix(3).joined(separator: " ") // get 00:00:15.716 --> 00:00:19.519
                let srtTime = timeInfos.replacingOccurrences(of: ".", with: ",") // 00:00:15,716 --> 00:00:19,519
                srtContent += srtTime
                srtContent += "\n"
            } else if line.hasPrefix("X-TIMESTAMP-MAP") {
                // skip
            } else if line.isNumber {
                hasSeqNum = true
                srtContent += line
                srtContent += "\n"
            } else { // must be subtitle text
                srtContent += line
                srtContent += "\n"
            }
        }
        
        return isValid ? srtContent : nil
    }
}

extension String  {
    var isNumber: Bool {
        return !isEmpty && rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil
    }
}
