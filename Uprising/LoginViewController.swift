//
//  LoginViewController.swift
//  Uprising
//
//  Created by Emily Hough-Kovacs on 1/30/17.
//  Copyright © 2017 Emily Hough-Kovacs. All rights reserved.
//

import Foundation
import UIKit

class LoginViewController: UIViewController {
    @IBOutlet weak var loginTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var loginButton: UIButton!
    
    @IBAction func login(sender: AnyObject) {
        let username = self.loginTextField.text
        let password = self.passwordTextField.text
        
        LoginService.sharedInstance.loginWithCompletionHandler(username: username!, password: password!) { (error) -> Void in
            
            if((error) != nil) {
                // something fucked up
                DispatchQueue.main.async(execute: { () -> Void in
                    let alert = UIAlertController(title: "Why are you doing this to me?!", message: error, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "Click", style: UIAlertActionStyle.default, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                })
            
                } else {
                
                DispatchQueue.main.async(execute: { () -> Void in
                    let controllerId = LoginService.sharedInstance.isLoggedIn() ? "Welcome" : "Login";
                    
                    let storyboard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
                    let initViewController: UIViewController = storyboard.instantiateViewController(withIdentifier: controllerId) as UIViewController
                    self.present(initViewController, animated: true, completion: nil)
                })
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
}
