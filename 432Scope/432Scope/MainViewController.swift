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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print( "----ViewController.viewDidLoad")
        // Do any additional setup after loading the view.
        
        // let the app know i'm alive ...
        (NSApplication.sharedApplication().delegate as! AppDelegate).mvc = self
        
        // enumerate the children so we can pass channels to them as they load.
        for controller in self.childViewControllers {
            if controller is NSSplitViewController {
                splitViewController = controller as! NSSplitViewController
            }
            if controller is ScopeViewController {
                scopeView = controller as! ScopeViewController
            }
        }
    }
    
    func loadChannel( newChannel:Channel ) throws {

        // create a channel view controller for the new channel
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        let newChannelViewController = storyboard.instantiateControllerWithIdentifier("channelViewController") as! ChannelViewController
        splitViewController.addChildViewController(newChannelViewController)
        
        // load the new channel into its controller view and the scope view.
        try newChannelViewController.loadChannel(newChannel)
        scopeView.loadChannel(newChannel)
    }

    override var representedObject: AnyObject? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

