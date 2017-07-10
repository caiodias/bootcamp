//
//  UserController.swift
//  ExampleApp
//
//  Created by Caio Dias on 2017-06-19.
//  Copyright © 2017 Caio Dias. All rights reserved.
//

import Foundation

public typealias ControllerSuccessScenario = () -> Void
public typealias ControllerFailScenario = (String) -> Void

public final class UserController {
    private typealias FetchSuccessScenario = (Data) -> Void
    private typealias FetchFailScenario = (String) -> Void
    
    private let baseUrl: String = "https://prodigi-bootcamp.firebaseio.com/BEN2ZlzXbpbQZviOuXKvQdybC1v1/messages"
    private let token: String = "eyJhbGciOiJSUzI1NiIsImtpZCI6ImFhNDZiNzkzOTUxZDZmZjcxOTY2MDU2MTE0ZTA0MWZmNjNjYjIxOWIifQ.eyJpc3MiOiJodHRwczovL3NlY3VyZXRva2VuLmdvb2dsZS5jb20vcHJvZGlnaS1ib290Y2FtcCIsImF1ZCI6InByb2RpZ2ktYm9vdGNhbXAiLCJhdXRoX3RpbWUiOjE0OTk3MjI0MjMsInVzZXJfaWQiOiJCRU4yWmx6WGJwYlFadmlPdVhLdlFkeWJDMXYxIiwic3ViIjoiQkVOMlpselhicGJRWnZpT3VYS3ZRZHliQzF2MSIsImlhdCI6MTQ5OTcyMjQyMywiZXhwIjoxNDk5NzI2MDIzLCJlbWFpbCI6Imtpb2JyZW5vK3Byb2RpZ2lAZ21haWwuY29tIiwiZW1haWxfdmVyaWZpZWQiOmZhbHNlLCJmaXJlYmFzZSI6eyJpZGVudGl0aWVzIjp7ImVtYWlsIjpbImtpb2JyZW5vK3Byb2RpZ2lAZ21haWwuY29tIl19LCJzaWduX2luX3Byb3ZpZGVyIjoicGFzc3dvcmQifX0.nthKJjDp1v7buLIYy3QwGRFFnC9Jke4LNT69xKSEDQSqpB7fv5c1jNsrYkVAHrFySmUwWMNtqdWwS0HHN1kRUxsRgjQm0JtwE9opm3aya0rGyNuR5qZzI1EzViNblWMDVW_tty7oPJ5V_DxkdD15ssjeem1zP7jV4msqcVNIv2VZl3NMHTHDUyQPLFTAOv9c8-Yes-v5ykPSy0HuSrv53vFmt3njxQle5WIlDhpYz5A_Qyw9VBNSW4D2C-FTNszQBNcH_QFo2NJerhFFv-xv4UKg1pUaoRJ6uSvlJPGBjuxENYM9aaKkgVttTdZbMcTkTUCPVKhYA83bTSr0cVx7tw"
    
    public private(set) var userList: [User]
    public var delegate: FetchDelegate? = nil
    
    // MARK: Singleton
    
    public static let shared: UserController = {
        let instance = UserController()
        return instance
    }()
    
    // Private Controller constructor due to implementation of Singleton Design Pattern
    
    private init() {
        self.userList = [User]()
    }
    
    // MARK: Fetch users from backend (Firebase)
    
    public func fetchUsers() {
        if let url = getUrl() {
            self.userList = [User]()
            
            var requestUrl = URLRequest(url: url)
            requestUrl.httpMethod = "GET"
            
            self.fetch(url: requestUrl, onSuccessScenario: onFetchUserSuccess, onFailScenario: onFetchUserFail)
        } else {
            self.delegate?.fetchUsersFailed(errorMessage: "Not possible to create the URL object")
        }
    }
    
    // MARK: Add user on backend (Firebase)
    
    public func addUser(_ user: User, onSuccess: @escaping ControllerSuccessScenario, onFail: @escaping ControllerFailScenario) {
        
        if let url = getUrl() {
            let jsonData = try! JSON(user.toJSON()).rawData()
            
            var requestUrl = URLRequest(url: url)
            requestUrl.httpMethod = "POST"
            requestUrl.httpBody = jsonData
            
            requestUrl.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            self.fetch(url: requestUrl,
                       onSuccessScenario: { data in
                        self.fetchUsers()
                        
                        onSuccess()
            },
                       onFailScenario: { errorMessage in
                        onFail(errorMessage)
            })
        } else {
            onFail("Not possible to create the URL object")
        }
    }
    
    // MARK: Update user on backend (Firebase)
    
    public func updateUser(_ user: User, onSuccess: @escaping ControllerSuccessScenario, onFail: @escaping ControllerFailScenario) {
        if let url = getUrl() {
            let jsonData = try! JSON([
                user.objectId: [
                    "user_id": user.name,
                    "text": user.description
                ]
                ]).rawData()
            
            var requestUrl = URLRequest(url: url)
            requestUrl.httpMethod = "PATCH"
            requestUrl.httpBody = jsonData
            
            self.fetch(url: requestUrl,
                       onSuccessScenario: { data in
                        self.fetchUsers()
                        
                        onSuccess()
            },
                       onFailScenario: { errorMessage in
                        onFail(errorMessage)
            })
        } else {
            onFail("Not possible to create the URL object")
        }
    }
    
    // MARK: Delete user on backend (Firebase)
    
    public func deleteUser(_ user: User, onSuccess: @escaping ControllerSuccessScenario, onFail: @escaping ControllerFailScenario) {
        guard let url = URL(string: String(format: "%@/%@.json?auth=%@", self.baseUrl, user.objectId, self.token)) else {
            onFail("Not possible to create the URL object")
            return
        }

        var requestUrl = URLRequest(url: url)
        requestUrl.httpMethod = "DELETE"
        
        self.fetch(url: requestUrl,
                   onSuccessScenario: { data in
                    self.fetchUsers()
                    
                    onSuccess()
        },
                   onFailScenario: { errorMessage in
                    onFail(errorMessage)
        })
    }
    
    // MARK: Private Methods
    
    // MARK: Fetch Users callbacks
    private func onFetchUserSuccess(data: Data) {
        do {
            let userList = try self.convertToUsers(withData: data)
            self.userList = userList

            self.delegate?.fetchedAllUsers()
        } catch {
            self.delegate?.fetchUsersFailed(errorMessage: "Not possible to convert the JSON to User objects")
        }
    }
    
    private func onFetchUserFail(error: String) {
        self.delegate?.fetchUsersFailed(errorMessage: error)
    }
    
    // MARK: Generic methods
    
    private func getUrl() -> URL? {
        guard let url = URL(string: String(format: "%@.json?auth=%@", self.baseUrl, self.token)) else {
            print("Not capable to create the URL")
            return nil
        }

        return url
    }
    
    private func fetch(url: URLRequest, onSuccessScenario onSuccess: @escaping FetchSuccessScenario, onFailScenario onFail: @escaping FetchFailScenario) {
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config)
        
        let task = session.dataTask(with: url, completionHandler: { (data, response, error) in
            if let errorUnwrapped = error {
                onFail(errorUnwrapped.localizedDescription)
            } else {
                guard let httpResponse = response as? HTTPURLResponse else {
                    onFail("Failed to parse HTTPURLResponse object")
                    return
                }
                
                guard httpResponse.statusCode == 200 else {
                    onFail("Failed to receive status code 200. Received: \(httpResponse.statusCode)")
                    return
                }
                
                if let dataUnwrapped = data {
                    onSuccess(dataUnwrapped)
                } else {
                    onFail("No data from response.")
                }
            }
        })
        
        task.resume()
    }
    
    private func convertToUsers(withData data: Data) throws -> [User] {
        var tempList = [User]()

        let jsonParsed = try JSON(data: data)
        
        if let resultsInJson = jsonParsed.dictionary {
            for (key, value) in resultsInJson {
                let userFromJSON = User(withName: value["user_id"].stringValue, description: value["text"].stringValue, objectId: key)
                
                tempList.append(userFromJSON)
            }
        }
        
        return tempList
    }
}
