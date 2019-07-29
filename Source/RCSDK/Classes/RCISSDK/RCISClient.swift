//
//  RCISClient.swift
//  iChange
//
//  Created by James Kizer on 6/25/18.
//  Copyright © 2018 James Kizer. All rights reserved.
//

import UIKit
import Alamofire
import CryptoSwift
import JWT

open class RCISClient: NSObject {

    public struct TokenResponse {
        public let APIToken: String
        public let recordID: String
        public let rcisJWT: String
    }
    
    public struct JWTResponse: Decodable {
        public let token: String
    }
    
    public struct MarkTokenRedeemedResponse: Decodable {
        public let redeemed: Bool
    }
    
    let baseURL: String
    let studyID: String
    let dispatchQueue: DispatchQueue?
    let encryptionKey: Data?
    
    public init(baseURL: String, studyID: String, encryptionKey: Data? = nil, dispatchQueue: DispatchQueue = DispatchQueue.main) {
        self.baseURL = baseURL
        self.studyID = studyID
        self.dispatchQueue = dispatchQueue
        self.encryptionKey = encryptionKey
        
        super.init()
    }
    
    
    open func redeemTokenResponse(completion: @escaping ((TokenResponse?, RCISClientError?) -> ())) -> (DataResponse<Any>) -> () {
        
        return { jsonResponse in
        
            //check for lower level errors
            if let error = jsonResponse.result.error as NSError? {
                if error.code == NSURLErrorNotConnectedToInternet {
                    completion(nil, RCISClientError.unreachableError(underlyingError: error))
                    return
                }
                else {
                    completion(nil, RCISClientError.otherError(underlyingError: error))
                    return
                }
            }
            
            //check for our errors
            //credentialsFailure
            guard let response = jsonResponse.response else {
                completion(nil, RCISClientError.malformedResponse(responseBody: jsonResponse))
                return
            }
            
            if response.statusCode == 502 {
                completion(nil, RCISClientError.badGatewayError)
                return
            }
            
            if response.statusCode == 400 {
                completion(nil, RCISClientError.malformedResponse(responseBody: jsonResponse))
                return
            }
            
            if response.statusCode == 403 || response.statusCode == 404 {
                completion(nil, RCISClientError.invalidToken)
                return
            }
            
            guard jsonResponse.result.isSuccess,
                let jsonData = jsonResponse.data,
                let jwtResponse = try? JSONDecoder().decode(JWTResponse.self, from: jsonData) else {
                    completion(nil, RCISClientError.malformedResponse(responseBody: jsonResponse))
                    return
            }
            
            let credentialsOpt: TokenResponse? = {
                
                do {
                    let token = jwtResponse.token
                    let claims: ClaimSet = try JWT.decode(token, algorithm: .none, verify: false)
                    guard let apiToken: String = claims["api_token"] as? String,
                        let recordId: String = claims["record_id"] as? String else {
                            completion(nil, RCISClientError.malformedResponse(responseBody: jsonResponse))
                            return nil
                    }
                    
                    return TokenResponse(APIToken: apiToken, recordID: recordId, rcisJWT: jwtResponse.token)
                }
                catch let e {
                    return nil
                }
                
            }()
            
            guard let credentials = credentialsOpt else {
                completion(nil, RCISClientError.malformedResponse(responseBody: jsonResponse))
                return
            }
            
            if let encryptionKey = self.encryptionKey {
                //
                let jwt = credentials.APIToken
                
                do {
                    let claims: ClaimSet = try JWT.decode(jwt, algorithm: .hs256(encryptionKey))
                    guard let encodedNonce: String = claims["nonce"] as? String,
                        let nonce = Data(base64Encoded: encodedNonce),
                        let encodedCipherText: String = claims["cipherText"] as? String,
                        let cipherText = Data(base64Encoded: encodedCipherText),
                        let cipher: String = claims["cipher"] as? String,
                        cipher == "AES256-GCM" else {
                            completion(nil, RCISClientError.malformedResponse(responseBody: jsonResponse))
                            return
                    }
                    
                    let gcm = GCM(iv: nonce.bytes, mode: .combined)
                    let aes = try AES(key: encryptionKey.bytes, blockMode: gcm, padding: .noPadding)
                    let decryptedAPITokenBytes = try aes.decrypt(cipherText.bytes)
                    
                    guard let decryptedAPIToken = String(bytes: decryptedAPITokenBytes, encoding: .utf8) else {
                        completion(nil, RCISClientError.malformedResponse(responseBody: jsonResponse))
                        return
                    }
                    
                    let decryptedCredentials = TokenResponse(APIToken: decryptedAPIToken, recordID: credentials.recordID, rcisJWT: jwtResponse.token)
                    completion(decryptedCredentials, nil)
                    
                } catch {
                    completion(nil, RCISClientError.malformedResponse(responseBody: jsonResponse))
                }
                
            }
            else {
                completion(credentials, nil)
            }
            
            
            
        }
        
    }
    
    open func redeemToken(
        token: String,
        completion: @escaping ((TokenResponse?, RCISClientError?) -> ())) {
        
        let urlString = "\(self.baseURL)/studies/\(self.studyID)/redeem_token"
        let parameters = [
            "token": token
        ]
    
        
        let request = Alamofire.request(
            urlString,
            method: .post,
            parameters: parameters,
            encoding: JSONEncoding.default
        )
        
        request.responseJSON(
            queue: self.dispatchQueue,
            completionHandler: self.redeemTokenResponse(completion: completion)
        )
        
    }
    
    open func markTokenRedeemed(
        token: String,
        completion: @escaping ((RCISClientError?) -> ())) {
        
        let urlString = "\(self.baseURL)/studies/\(self.studyID)/mark_token_redeemed"
        let parameters = [
            "token": token
        ]
        
        
        let request = Alamofire.request(
            urlString,
            method: .post,
            parameters: parameters,
            encoding: JSONEncoding.default
        )
        
        request.responseJSON(
            queue: self.dispatchQueue,
            completionHandler: self.markTokenRedeemedResponse(completion: completion)
        )
        
    }
    
    open func markTokenRedeemedResponse(completion: @escaping ((RCISClientError?) -> ())) -> (DataResponse<Any>) -> () {
        
        return { jsonResponse in
            
            //check for lower level errors
            if let error = jsonResponse.result.error as NSError? {
                if error.code == NSURLErrorNotConnectedToInternet {
                    completion(RCISClientError.unreachableError(underlyingError: error))
                    return
                }
                else {
                    completion(RCISClientError.otherError(underlyingError: error))
                    return
                }
            }
            
            //check for our errors
            //credentialsFailure
            guard let response = jsonResponse.response else {
                completion(RCISClientError.malformedResponse(responseBody: jsonResponse))
                return
            }
            
            if response.statusCode == 502 {
                completion(RCISClientError.badGatewayError)
                return
            }
            
            if response.statusCode == 400 {
                completion(RCISClientError.malformedResponse(responseBody: jsonResponse))
                return
            }
            
            if response.statusCode == 403 || response.statusCode == 404 {
                completion(RCISClientError.invalidToken)
                return
            }
            
            guard jsonResponse.result.isSuccess,
                let jsonData = jsonResponse.data,
                let redeemedResponse = try? JSONDecoder().decode(MarkTokenRedeemedResponse.self, from: jsonData),
                redeemedResponse.redeemed else {
                    completion(RCISClientError.malformedResponse(responseBody: jsonResponse))
                    return
            }
            
            completion(nil)
            
        }
        
    }
    
    open func refreshToken(
        token: String,
        completion: @escaping ((TokenResponse?, RCISClientError?) -> ())
    ) {
        
        let urlString = "\(self.baseURL)/studies/\(self.studyID)/refresh_token"
        let parameters = [
            "token": token
        ]
        
        
        let request = Alamofire.request(
            urlString,
            method: .post,
            parameters: parameters,
            encoding: JSONEncoding.default
        )
        
        request.responseJSON(
            queue: self.dispatchQueue,
            completionHandler: self.refreshTokenResponse(completion: completion)
        )
        
    }
    
    open func refreshTokenResponse(
        completion: @escaping ((TokenResponse?, RCISClientError?) -> ())
    ) -> (DataResponse<Any>) -> () {
        
        return { jsonResponse in
            
            //check for lower level errors
            if let error = jsonResponse.result.error as NSError? {
                if error.code == NSURLErrorNotConnectedToInternet {
                    completion(nil, RCISClientError.unreachableError(underlyingError: error))
                    return
                }
                else {
                    completion(nil, RCISClientError.otherError(underlyingError: error))
                    return
                }
            }
            
            //check for our errors
            guard let response = jsonResponse.response else {
                completion(nil, RCISClientError.malformedResponse(responseBody: jsonResponse))
                return
            }
            
            if response.statusCode == 502 {
                completion(nil, RCISClientError.badGatewayError)
                return
            }
            
            if response.statusCode == 400 {
                completion(nil, RCISClientError.invalidToken)
                return
            }
            
            if response.statusCode == 403 || response.statusCode == 404 {
                completion(nil, RCISClientError.invalidStudy)
                return
            }
            
            guard jsonResponse.result.isSuccess,
                let jsonData = jsonResponse.data,
                let jwtResponse = try? JSONDecoder().decode(JWTResponse.self, from: jsonData) else {
                    completion(nil, RCISClientError.malformedResponse(responseBody: jsonResponse))
                    return
            }
            
            let credentialsOpt: TokenResponse? = {
                
                do {
                    let token = jwtResponse.token
                    let claims: ClaimSet = try JWT.decode(token, algorithm: .none, verify: false)
                    guard let apiToken: String = claims["api_token"] as? String,
                        let recordId: String = claims["record_id"] as? String else {
                            completion(nil, RCISClientError.malformedResponse(responseBody: jsonResponse))
                            return nil
                    }
                    
                    return TokenResponse(APIToken: apiToken, recordID: recordId, rcisJWT: jwtResponse.token)
                }
                catch let e {
                    return nil
                }
                
            }()
            
            guard let credentials = credentialsOpt else {
                completion(nil, RCISClientError.malformedResponse(responseBody: jsonResponse))
                return
            }
            
            if let encryptionKey = self.encryptionKey {
                //
                let jwt = credentials.APIToken
                
                do {
                    let claims: ClaimSet = try JWT.decode(jwt, algorithm: .hs256(encryptionKey))
                    guard let encodedNonce: String = claims["nonce"] as? String,
                        let nonce = Data(base64Encoded: encodedNonce),
                        let encodedCipherText: String = claims["cipherText"] as? String,
                        let cipherText = Data(base64Encoded: encodedCipherText),
                        let cipher: String = claims["cipher"] as? String,
                        cipher == "AES256-GCM" else {
                            completion(nil, RCISClientError.malformedResponse(responseBody: jsonResponse))
                            return
                    }
                    
                    let gcm = GCM(iv: nonce.bytes, mode: .combined)
                    let aes = try AES(key: encryptionKey.bytes, blockMode: gcm, padding: .noPadding)
                    let decryptedAPITokenBytes = try aes.decrypt(cipherText.bytes)
                    
                    guard let decryptedAPIToken = String(bytes: decryptedAPITokenBytes, encoding: .utf8) else {
                        completion(nil, RCISClientError.malformedResponse(responseBody: jsonResponse))
                        return
                    }
                    
                    let decryptedCredentials = TokenResponse(APIToken: decryptedAPIToken, recordID: credentials.recordID, rcisJWT: jwtResponse.token)
                    completion(decryptedCredentials, nil)
                    
                } catch {
                    completion(nil, RCISClientError.malformedResponse(responseBody: jsonResponse))
                }
                
            }
            else {
                completion(credentials, nil)
            }
            
            
            
        }
        
    }

}
