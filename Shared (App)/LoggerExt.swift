//
//  LoggerExt.swift
//  WebvttDownloader
//
//  Created by Tung Lim Chan on 10/6/2022.
//

import OSLog

extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier!

    static let viewCycle = Logger(subsystem: subsystem, category: "WebVTTDownload")
}
