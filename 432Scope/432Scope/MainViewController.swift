//
//  ViewController.swift
//  432Scope
//
//  Created by Nicholas Cordle on 5/2/16.
//
//

import Cocoa

class MainViewController: NSViewController {
    
    // list our UI children here ...
    var channelViewControllers:[ChannelViewController] = []
    var scopeView: ScopeViewController!
    var splitViewController: NSSplitViewController!
    
    // keep a reference to any channels ...
    var channels:[Channel] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print( "----ViewController.viewDidLoad")
        // Do any additional setup after loading the view.
        
        // let the app know i'm alive ...
        (NSApplication.sharedApplication().delegate as! AppDelegate).mvc = self
        
        // enumerate the children
        for controller in self.childViewControllers {
            if controller is NSSplitViewController {
                splitViewController = controller as! NSSplitViewController
            }
            if controller is ScopeViewController {
                scopeView = controller as! ScopeViewController
            }
        }
    }
    
    func channelIsReady( newChannel:Channel ) {
        
        // we must pass this new channel to our children!
        channels.append(newChannel)
        scopeView.loadChannel(newChannel)
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        let newChannelViewController = storyboard.instantiateControllerWithIdentifier("channelViewController") as! ChannelViewController
        splitViewController.addChildViewController(newChannelViewController)
        newChannelViewController.loadChannel(newChannel)
    }

    override var representedObject: AnyObject? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

