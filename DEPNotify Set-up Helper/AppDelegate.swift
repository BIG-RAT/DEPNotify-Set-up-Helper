//
//  AppDelegate.swift
//  DEPNotify Set-up Helper
//
//  Created by Leslie Helou on 2/24/20.
//  Copyright © 2020 Leslie Helou. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }
    
    // quit the app if the window is closed - start
    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool {
        return true
    }
    // quit the app if the window is closed - end
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

}

