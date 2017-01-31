//
//  WelcomeViewController.swift
//  Uprising
//
//  Created by Emily Hough-Kovacs on 1/31/17.
//  Copyright © 2017 Emily Hough-Kovacs. All rights reserved.
//

import Foundation
import UIKit

class WelcomeViewController: UIViewController {
    @IBOutlet weak var signOutButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func signOut(sender: AnyObject) {
        LoginService.sharedInstance.signOut()
        
        let controllerId = LoginService.sharedInstance.isLoggedIn() ? "Welcome" : "login";
        let storyboard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        let initViewController: UIViewController = storyboard.instantiateViewController(withIdentifier: controllerId) as UIViewController
        self.present(initViewController, animated: true, completion: nil)
    }
}
