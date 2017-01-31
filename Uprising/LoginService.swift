//
//  LoginService.swift
//  Uprising
//
//  Created by Emily Hough-Kovacs on 1/31/17.
//  Copyright © 2017 Emily Hough-Kovacs. All rights reserved.
//

import Foundation
import UIKit

public class LoginService {
    
    // MARK: Properties
    
    internal let session:URLSession
    private var tokenInfo:OAuthInfo?
    
    // MARK: Types
    
    struct OAuthInfo {
        let token: String
        let tokenExpiresAt: Date
        let refreshToken: String
        let refreshTokenExpiresAt: Date
        
        // MARK: Initializers
        
        init(issuedAt: TimeInterval, refreshTokenIssuedAt: TimeInterval, tokenExpiresIn: TimeInterval, refreshToken: String, token: String, refreshTokenExpiresIn: Double, refreshCount: Int) {
            
            // Store OAuth token and associated data
            self.refreshTokenExpiresAt = Date(timeInterval: refreshTokenExpiresIn, since: Date(timeIntervalSince1970: issuedAt))
            self.tokenExpiresAt = Date(timeInterval: tokenExpiresIn, since: Date(timeIntervalSince1970: issuedAt))
            self.token = token
            self.refreshToken = refreshToken
            
            // Persist the OAuth token and associated data to NSUserDefaults
            UserDefaults.standard.set(self.refreshTokenExpiresAt, forKey: "refreshTokenExpiresAt")
            UserDefaults.standard.set(self.tokenExpiresAt, forKey: "tokenExpiresAt")
            UserDefaults.standard.set(self.token, forKey: "token")
            UserDefaults.standard.set(self.refreshToken, forKey: "refreshToken")
            UserDefaults.standard.synchronize()
        }
        
        init?() {
            // Retrieve OAuth info from UserDefaults if available
            if let refreshTokenExpiresAt = UserDefaults.standard.value(forKey: "refreshTokenExpiresAt") as? Date,
                let tokenExpiresAt = UserDefaults.standard.value(forKey: "tokenExpiresAt") as? Date,
                let token = UserDefaults.standard.value(forKey: "token") as? String,
                let refreshToken = UserDefaults.standard.value(forKey: "refreshToken") as? String {
                self.refreshTokenExpiresAt = refreshTokenExpiresAt
                self.tokenExpiresAt = tokenExpiresAt
                self.token = token
                self.refreshToken = refreshToken
            } else {
                return nil
            }
        }
        
        // MARK: Sign Out
        
        func signOut() -> () {
            
            // Clear OAuth Info from UserDefaults
            UserDefaults.standard.removeObject(forKey: "refreshTokenExpiresAt")
            UserDefaults.standard.removeObject(forKey: "tokenExpiresAt")
            UserDefaults.standard.removeObject(forKey: "token")
            UserDefaults.standard.removeObject(forKey: "refreshToken")
        }
    }
    
    // MARK: Singleton Support
    
    class var sharedInstance: LoginService {
        struct Singleton {
            static let instance = LoginService ()
        }
        
        // Check whether we already have an OAuthInfo instance
        // attached; if so, don't initialize another one
        if Singleton.instance.tokenInfo == nil {
            // Initialize new OAuthInfo object
            Singleton.instance.tokenInfo = OAuthInfo()
        }
        
        // Return singleton instance
        return Singleton.instance
    }
    
    // MARK: Initalizers
    init() {
        let sessionConfig = URLSessionConfiguration.default
        session = URLSession(configuration: sessionConfig)

        // Ensure we only have one instance of this class and that it is the Singleton instance
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(10)) / Double(NSEC_PER_SEC),
            execute: {
            assert(self === LoginService.sharedInstance, "Only one instance of LoginManager allowed!")
        })
    }
    
    // MARK: Login Utilities
    
    public func loginWithCompletionHandler(username: String, password: String, completionHandler: @escaping ((error: String?)) -> Void) -> () {
        
        // Try and get an OAuth token
        exchangeTokenForUserAccessTokenWithCompletionHandler(username: username, password: password) { (oauthInfo, error) -> () in
            if (error == nil) {
                
                // Everything worked and nothing hurt and OAuthInfo was returned
                self.tokenInfo = oauthInfo!
                completionHandler((error: nil))
            } else {
                
                // Something has gone terribly wrong
                self.tokenInfo = nil
                completionHandler((error: error))
            }
            
        }
    }
    
    public func signOut() {
        
        // Clear the OAuth Info
        self.tokenInfo?.signOut()
        self.tokenInfo = nil
    }
    
    public func isLoggedIn() -> Bool {
        var loggedIn:Bool = false
        if let info = self.tokenInfo {
    
            // Check to see if OAuth token is still valid
            if fabs(info.tokenExpiresAt.timeIntervalSinceNow) > 60 {
                loggedIn = true
            }
            
        }
        
        return loggedIn
    }
    
    // MARK: Token Utilities
    
    public func token() -> String? {
        return self.tokenInfo?.token
        
    }
    
    public func refreshToken() -> String {
        var refreshToken: String = ""
        
        if self.tokenInfo != nil {
            if let tokenInfo = tokenInfo, fabs(tokenInfo.refreshTokenExpiresAt.timeIntervalSinceNow) > 60 {
                refreshToken = tokenInfo.refreshToken
            }
        }
        
        return refreshToken
    }

    // MARK: Private Methods
    
    private func exchangeTokenForUserAccessTokenWithCompletionHandler (username: String, password: String, completion: @escaping (OAuthInfo?, _: String?) -> ()) {
        let path = "/oauthfake/token/"
        let url = ConnectionSettings.apiURLWithPathComponents(components: path)
        let request = NSMutableURLRequest(url: url as URL)
        request.httpMethod = "POST"
        
        let params =  "client_id=\(ConnectionSettings.clientId)&client_secret=\(ConnectionSettings.clientSecret)&grant_type=password&login=\(username)&password=\(password)"

        request.httpBody = params.data(using: String.Encoding.utf8, allowLossyConversion: false)
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let task = session.dataTask(with: request as URLRequest) { (data, response, error) -> Void in
            guard let data = data else {
                completion(nil, "No data")
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data)
                guard let parseJSON = json as? Dictionary<String, String> else {
                    completion(nil, "Invalid JSON")
                    return
                }
                
                if let token = parseJSON["access_token"], let issuedAt = parseJSON["issued_at"],
                    let tokenExpiresIn = parseJSON["expires_in"], let refreshTokenIssuedAt = parseJSON["refresh_token_issued_at"],
                        let refreshToken = parseJSON["refresh_token"], let refreshTokenExpiresIn = parseJSON["refresh_token_expires_in"],
                            let refreshCount = parseJSON["refresh_count"] {
                    
                    let epochIssuedAt:Double = (issuedAt as NSString).doubleValue / 1000.0
                    let epochRefreshTokenIssuedAt:Double = (refreshTokenIssuedAt as NSString).doubleValue / 1000.0
                    
                    let oauthInfo = OAuthInfo(issuedAt: epochIssuedAt, refreshTokenIssuedAt: epochRefreshTokenIssuedAt, tokenExpiresIn: (tokenExpiresIn as NSString).doubleValue, refreshToken: refreshToken, token: token, refreshTokenExpiresIn: (refreshTokenExpiresIn as NSString).doubleValue, refreshCount: (refreshCount as NSString).integerValue)
                    
                    completion(oauthInfo, nil)
                } else if let error = parseJSON["error"] {
                    completion(nil, error)
                } else {
                    completion(nil, "idk")
                }
            } catch let error {
                // Something has gone terribly wrong. Log the error to console.
                print("Something went wrong: '\(error)")
                
                completion(nil, (error as NSError).localizedDescription)
            }

        
        }
        task.resume()
    
    }
    
}
