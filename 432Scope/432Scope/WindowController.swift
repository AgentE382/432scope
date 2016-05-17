//
//  WindowController.swift
//  432scope
//
//  Created by Nicholas Cordle on 5/2/16.
//  Copyright © 2016 Nicholas Cordle. All rights reserved.
//

import Cocoa

class WindowController: NSWindowController {

    override func windowDidLoad() {
        super.windowDidLoad()
        print( "----WindowController.windowDidLoad")
        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
        
        // get that nice unified title bar + toolbar look!
        //window!.titleVisibility = .Hidden;
    }
}
