//
//  NeoClient.swift
//  NeoSwift
//
//  Created by Andrei Terentiev on 8/19/17.
//  Copyright © 2017 drei. All rights reserved.
//

import Foundation


typealias JSONDictionary = [String : Any]

public enum NeoClientError: Error {
    case invalidSeed, invalidBodyRequest, invalidData, invalidRequest, noInternet
    
    var localizedDescription: String {
        switch self {
        case .invalidSeed:
            return "Invalid seed"
        case .invalidBodyRequest:
            return "Invalid body Request"
        case .invalidData:
            return "Invalid response data"
        case .invalidRequest:
            return "Invalid server request"
        case .noInternet:
            return "No Internet connection"
        }
    }
}

public enum NeoClientResult<T> {
    case success(T)
    case failure(NeoClientError)
}

public enum Network: String {
    case test
    case main
}

public class NEONetworkMonitor {
    private init() {
        self.network =  self.load()
    }
    public static let sharedInstance = NEONetworkMonitor()
    public var network: NEONetwork?
    
    private func load() -> NEONetwork? {
        guard let path = Bundle(for: type(of: self)).path(forResource: "nodes", ofType: "json") else {
            return nil
        }
        guard let fileData = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return nil
        }
        let decoder = JSONDecoder()
        
        guard let json = try? JSONSerialization.jsonObject(with: fileData, options: []) as! JSONDictionary else {
            return nil
        }
        
        guard let data = try? JSONSerialization.data(withJSONObject: json, options: []),
            let result = try? decoder.decode(NEONetwork.self, from: data) else {
                return nil
        }
        return result
    }
    
}

public class NeoClient {
    public var network: Network = .test
    public var seed = "http://seed1.neo.org:10332"
    public var fullNodeAPI = "http://testnet-api.wallet.cityofzion.io/v2/"
    public static let sharedTest = NeoClient(network: .test)
    public static let sharedMain = NeoClient(network: .main)
    private init() {}
    
    let tokenInfoCache = NSCache<NSString, AnyObject>()
    
    enum RPCMethod: String {
        case getBestBlockHash = "getbestblockhash"
        case getBlock = "getblock"
        case getBlockCount = "getblockcount"
        case getBlockHash = "getblockhash"
        case getConnectionCount = "getconnectioncount"
        case getTransaction = "getrawtransaction"
        case getTransactionOutput = "gettxout"
        case getUnconfirmedTransactions = "getrawmempool"
        case sendTransaction = "sendrawtransaction"
        case validateAddress = "validateaddress"
        case getAccountState = "getaccountstate"
        case getAssetState = "getassetstate"
        case getPeers = "getpeers"
        case invokeFunction = "invokefunction"
        //The following routes can't be invoked by calling an RPC server
        //We must use the wrapper for the nodes made by COZ
        case getBalance = "getbalance"
    }
    
    enum NEP5Method: String {
        case totalSupply = "totalSupply"
        case name = "name"
        case balanceOf = "balanceOf"
        case decimals = "decimals"
        case symbol = "symbol"
        case transfer = "transfer"
    }
    
    enum apiURL: String {
        case getBalance = "address/balance/"
        case getClaims = "address/claims/"
        case getTransactionHistory = "address/history/"
        case getBestNode = "network/best_node"
    }
    
    public init(seed: String) {
        self.seed = seed
    }
    
    public init(network: Network) {
        self.network = network
        switch self.network {
        case .test:
            fullNodeAPI = "http://testnet-api.wallet.cityofzion.io/v2/"
            seed = "http://test4.cityofzion.io:8880"
        case .main:
            fullNodeAPI = "http://api.wallet.cityofzion.io/v2/"
            seed = "http://seed1.neo.org:10332"
        }
        
        self.getBestNode() { result in
            switch result {
            case .failure:
                fatalError("Could not initialize Neo Client")
            case .success(let value):
                self.seed = value
            }
        }
    }
    
    public init(network: Network, seedURL: String) {
        self.network = network
        switch self.network {
        case .test:
            fullNodeAPI = "http://testnet-api.wallet.cityofzion.io/v2/"
            seed = seedURL
        case .main:
            fullNodeAPI = "http://api.wallet.cityofzion.io/v2/"
            seed = seedURL
        }
    }
    
    func sendRequest(_ method: RPCMethod, params: [Any]?, completion: @escaping (NeoClientResult<JSONDictionary>) -> ()) {
        guard let url = URL(string: seed) else {
            completion(.failure(.invalidSeed))
            return
        }
        
        let request = NSMutableURLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json-rpc", forHTTPHeaderField: "Content-Type")
        
        let requestDictionary: [String: Any?] = [
            "jsonrpc" : "2.0",
            "id"      : 2,
            "method"  : method.rawValue,
            "params"  : params ?? []
        ]
        
        guard let body = try? JSONSerialization.data(withJSONObject: requestDictionary, options: []) else {
            completion(.failure(.invalidBodyRequest))
            return
        }
        request.httpBody = body
        let task = URLSession.shared.dataTask(with: request as URLRequest) { (data, _, err) in
            if err != nil {
                completion(.failure(.invalidRequest))
                return
            }
            
            guard let json = try? JSONSerialization.jsonObject(with: data!, options: []) as! JSONDictionary else {
                completion(.failure(.invalidData))
                return
            }
            
            let result = NeoClientResult.success(json)
            completion(result)
        }
        task.resume()
    }
    
    func sendFullNodeRequest(_ url: String, params: [Any]?, completion :@escaping (NeoClientResult<JSONDictionary>) -> ()) {
        let request = NSMutableURLRequest(url: URL(string: url)!)
        request.httpMethod = "GET"
        
        let task = URLSession.shared.dataTask(with: request as URLRequest) { (data, _, err) in
            if err != nil {
                completion(.failure(.invalidRequest))
                return
            }
            
            guard let json = try? JSONSerialization.jsonObject(with: data!, options: []) as! JSONDictionary else {
                completion(.failure(.invalidData))
                return
            }
            
            let result = NeoClientResult.success(json)
            completion(result)
        }
        task.resume()
    }
    
    public func getBestBlockHash(completion: @escaping (NeoClientResult<String>) -> ()) {
        sendRequest(.getBestBlockHash, params: nil) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let response):
                guard let hash = response["result"] as? String else {
                    completion(.failure(.invalidData))
                    return
                }
                let result = NeoClientResult.success(hash)
                completion(result)
            }
        }
    }
    
    public func getBlockBy(hash: String, completion: @escaping (NeoClientResult<Block>) -> ()) {
        sendRequest(.getBlock, params: [hash, 1]) { result in //figure out why you need the 1
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let response):
                let decoder = JSONDecoder()
                guard let data = try? JSONSerialization.data(withJSONObject: (response["result"] as! JSONDictionary), options: .prettyPrinted),
                    let block = try? decoder.decode(Block.self, from: data) else {
                        completion(.failure(.invalidData))
                        return
                }
                
                let result = NeoClientResult.success(block)
                completion(result)
            }
        }
    }
    
    public func getBlockBy(index: Int64, completion: @escaping (NeoClientResult<Block>) -> ()) {
        sendRequest(.getBlock, params: [index, 1]) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let response):
                let decoder = JSONDecoder()
                guard let data = try? JSONSerialization.data(withJSONObject: (response["result"] as! JSONDictionary), options: .prettyPrinted),
                    let block = try? decoder.decode(Block.self, from: data) else {
                        completion(.failure(.invalidData))
                        return
                }
                
                let result = NeoClientResult.success(block)
                completion(result)
            }
        }
    }
    
    public func getBlockCount(completion: @escaping (NeoClientResult<Int64>) -> ()) {
        sendRequest(.getBlockCount, params: nil) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let response):
                guard let count = response["result"] as? Int64 else {
                    completion(.failure(.invalidData))
                    return
                }
                
                let result = NeoClientResult.success(count)
                completion(result)
            }
        }
    }
    
    public func getPeers(completion:  @escaping (NeoClientResult<GetPeersResult>) -> ()) {
        sendRequest(.getPeers, params: nil) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let response):
                let decoder = JSONDecoder()
                guard let data = try? JSONSerialization.data(withJSONObject: (response["result"] as! JSONDictionary), options: .prettyPrinted),
                    let block = try? decoder.decode(GetPeersResult.self, from: data) else {
                        completion(.failure(.invalidData))
                        return
                }
                
                let result = NeoClientResult.success(block)
                completion(result)
            }
        }
    }
    
    public func getBlockHash(for index: Int64, completion: @escaping (NeoClientResult<String>) -> ()) {
        sendRequest(.getBlockHash, params: [index]) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let response):
                guard let hash = response["result"] as? String else {
                    completion(.failure(.invalidData))
                    return
                }
                
                let result = NeoClientResult.success(hash)
                completion(result)
            }
        }
    }
    
    public func getConnectionCount(completion: @escaping (NeoClientResult<Int64>) -> ()) {
        sendRequest(.getConnectionCount, params: nil) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let response):
                guard let count = response["result"] as? Int64 else {
                    completion(.failure(.invalidData))
                    return
                }
                
                let result = NeoClientResult.success(count)
                completion(result)
            }
        }
    }
    
    public func getTransaction(for hash: String, completion: @escaping (NeoClientResult<Transaction>) -> ()) {
        sendRequest(.getTransaction, params: [hash, 1]) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let response):
                let decoder = JSONDecoder()
                guard let data = try? JSONSerialization.data(withJSONObject: (response["result"] as! JSONDictionary), options: .prettyPrinted),
                    let block = try? decoder.decode(Transaction.self, from: data) else {
                        completion(.failure(.invalidData))
                        return
                }
                
                let result = NeoClientResult.success(block)
                completion(result)
            }
        }
    }
    
    //NEED TO GUARD ON THE VALUE OUTS
    public func getTransactionOutput(with hash: String, and index: Int64, completion: @escaping (NeoClientResult<ValueOut>) -> ()) {
        sendRequest(.getTransaction, params: [hash, index]) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let response):
                let decoder = JSONDecoder()
                guard let data = try? JSONSerialization.data(withJSONObject: (response["result"] as! JSONDictionary), options: .prettyPrinted),
                    let block = try? decoder.decode(ValueOut.self, from: data) else {
                        completion(.failure(.invalidData))
                        return
                }
                
                let result = NeoClientResult.success(block)
                completion(result)
            }
        }
    }
    
    public func getUnconfirmedTransactions(completion: @escaping (NeoClientResult<[String]>) -> ()) {
        sendRequest(.getUnconfirmedTransactions, params: nil) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let response):
                guard let txs = response["result"] as? [String] else {
                    completion(.failure(.invalidData))
                    return
                }
                
                let result = NeoClientResult.success(txs)
                completion(result)
            }
        }
    }
    
    public func getAssets(for address: String, params: [Any]?, completion: @escaping(NeoClientResult<Assets>) -> ()) {
        let url = fullNodeAPI + apiURL.getBalance.rawValue + address
        sendFullNodeRequest(url, params: params) { result in
            
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let response):
                let decoder = JSONDecoder()
                guard let data = try? JSONSerialization.data(withJSONObject: response, options: .prettyPrinted),
                    let assets = try? decoder.decode(Assets.self, from: data) else {
                        completion(.failure(.invalidData))
                        return
                }
                
                let result = NeoClientResult.success(assets)
                completion(result)
            }
        }
    }
    
    public func getClaims(address: String, completion: @escaping(NeoClientResult<Claims>) -> ()) {
        let url = fullNodeAPI + apiURL.getClaims.rawValue + address
        sendFullNodeRequest(url, params: nil) { result in
            
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let response):
                let decoder = JSONDecoder()
                guard let data = try? JSONSerialization.data(withJSONObject: response, options: .prettyPrinted),
                    let claims = try? decoder.decode(Claims.self, from: data) else {
                        completion(.failure(.invalidData))
                        return
                }
                
                let result = NeoClientResult.success(claims)
                completion(result)
            }
        }
    }
    
    public func getTransactionHistory(for address: String, completion: @escaping (NeoClientResult<TransactionHistory>) -> ()) {
        let url = fullNodeAPI + apiURL.getTransactionHistory.rawValue + address
        sendFullNodeRequest(url, params: nil) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let response):
                let decoder = JSONDecoder()
                guard let data = try? JSONSerialization.data(withJSONObject: response, options: .prettyPrinted),
                    let history = try? decoder.decode(TransactionHistory.self, from: data) else {
                        completion(.failure(.invalidData))
                        return
                }
                
                let result = NeoClientResult.success(history)
                completion(result)
            }
        }
    }
    
    public func sendRawTransaction(with data: Data, completion: @escaping(NeoClientResult<Bool>) -> ()) {
        sendRequest(.sendTransaction, params: [data.fullHexString]) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let response):
                guard let success = response["result"] as? Bool else {
                    completion(.failure(.invalidData))
                    return
                }
                let result = NeoClientResult.success(success)
                completion(result)
            }
        }
    }
    
    public func validateAddress(_ address: String, completion: @escaping(NeoClientResult<Bool>) -> ()) {
        sendRequest(.validateAddress, params: [address]) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let response):
                guard let jsonResult: [String: Any] = response["result"] as? JSONDictionary else {
                    completion(.failure(.invalidData))
                    return
                }
                
                guard let isValid = jsonResult["isvalid"] as? Bool else {
                    completion(.failure(.invalidData))
                    return
                }
                
                let result = NeoClientResult.success(isValid)
                completion(result)
            }
        }
    }
    
    public func getAccountState(for address: String, completion: @escaping(NeoClientResult<AccountState>) -> ()) {
        sendRequest(.getAccountState, params: [address]) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let response):
                let decoder = JSONDecoder()
                guard let data = try? JSONSerialization.data(withJSONObject: (response["result"] as! JSONDictionary), options: .prettyPrinted),
                    let accountState = try? decoder.decode(AccountState.self, from: data) else {
                        completion(.failure(.invalidData))
                        return
                }
                
                let result = NeoClientResult.success(accountState)
                completion(result)
            }
        }
    }
    
    public func getAssetState(for asset: String, completion: @escaping(NeoClientResult<AssetState>) -> ()) {
        sendRequest(.getAssetState, params: [asset]) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let response):
                let decoder = JSONDecoder()
                guard let data = try? JSONSerialization.data(withJSONObject: (response["result"] as! JSONDictionary), options: .prettyPrinted),
                    let assetState = try? decoder.decode(AssetState.self, from: data) else {
                        completion(.failure(.invalidData))
                        return
                }
                
                let result = NeoClientResult.success(assetState)
                completion(result)
            }
        }
    }
    
    public func getBestNode(completion: @escaping (NeoClientResult<String>) -> ()) {
        let url = fullNodeAPI + apiURL.getBestNode.rawValue
        sendFullNodeRequest(url, params: nil) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let response):
                guard let node = response["node"] as? String else {
                    completion(.failure(.invalidData))
                    return
                }
                let result = NeoClientResult.success(node)
                completion(result)
            }
        }
    }
    
    public func getNEP5TokenName(token hash: String, completion: @escaping (NeoClientResult<String>) -> ()) {
        let cacheKey = hash + NEP5Method.name.rawValue
        if let v = tokenInfoCache.object(forKey: cacheKey as NSString) as? String {
            let result = NeoClientResult.success(v)
            completion(result)
            return
        }
        
        var params:[Any] = []
        params.append(hash)
        params.append(NEP5Method.name.rawValue)
        sendRequest(.invokeFunction, params: params) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let response):
                let decoder = JSONDecoder()
                #if DEBUG
                    print(response)
                #endif
                guard let data = try? JSONSerialization.data(withJSONObject: (response["result"] as! JSONDictionary), options: .prettyPrinted),
                    let invokeResponse = try? decoder.decode(BalanceOfResult.self, from: data) else {
                        completion(.failure(.invalidData))
                        return
                }
                if invokeResponse.stack?.count == 1 {
                    let v = invokeResponse.stack?.first
                    if v?.value == "" {
                        completion(.failure(.invalidData))
                        return
                    }
                    let byteArray = v?.value!.dataWithHexString()
                    let symbol = String(data:byteArray!,encoding: .utf8)
                    self.tokenInfoCache.setObject(symbol as AnyObject, forKey: cacheKey as NSString)
                    let result = NeoClientResult.success(symbol!)
                    completion(result)
                    return
                }
                completion(.failure(.invalidData))
            }
        }
    }
    
    public func getNEP5TokenSymbol(token hash: String, completion: @escaping (NeoClientResult<String>) -> ()) {
        let cacheKey = hash + NEP5Method.symbol.rawValue
        if let v = tokenInfoCache.object(forKey: cacheKey as NSString) as? String {
            let result = NeoClientResult.success(v)
            completion(result)
            return
        }
        
        var params:[Any] = []
        params.append(hash)
        params.append(NEP5Method.symbol.rawValue)
        sendRequest(.invokeFunction, params: params) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let response):
                let decoder = JSONDecoder()
                #if DEBUG
                print(response)
                #endif
                guard let data = try? JSONSerialization.data(withJSONObject: (response["result"] as! JSONDictionary), options: .prettyPrinted),
                    let invokeResponse = try? decoder.decode(BalanceOfResult.self, from: data) else {
                        completion(.failure(.invalidData))
                        return
                }
                if invokeResponse.stack?.count == 1 {
                    let v = invokeResponse.stack?.first
                    if v?.value == "" {
                        completion(.failure(.invalidData))
                        return
                    }
                    let byteArray = v?.value!.dataWithHexString()
                    let symbol = String(data:byteArray!,encoding: .utf8)
                    self.tokenInfoCache.setObject(symbol as AnyObject, forKey: cacheKey as NSString)
                    let result = NeoClientResult.success(symbol!)
                    completion(result)
                    return
                }
                completion(.failure(.invalidData))
            }
        }
    }
    
    public func getNEP5TokenDecimal(token hash: String, completion: @escaping (NeoClientResult<Int>) -> ()) {
        let cacheKey = hash + NEP5Method.decimals.rawValue
        if let v = tokenInfoCache.object(forKey: cacheKey as NSString) as? Int {
            let result = NeoClientResult.success(v)
            completion(result)
            return
        }
        
        var params:[Any] = []
        params.append(hash)
        params.append(NEP5Method.decimals.rawValue)
        sendRequest(.invokeFunction, params: params) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let response):
                let decoder = JSONDecoder()
                #if DEBUG
                    print(response)
                #endif
                guard let data = try? JSONSerialization.data(withJSONObject: (response["result"] as! JSONDictionary), options: .prettyPrinted),
                    let invokeResponse = try? decoder.decode(BalanceOfResult.self, from: data) else {
                        completion(.failure(.invalidData))
                        return
                }
                if invokeResponse.stack?.count == 1 {
                    let v = invokeResponse.stack?.first
                    if v?.value == "" {
                        completion(.failure(.invalidData))
                        return
                    }
                    let decimals = Int((v?.value)!)
                    self.tokenInfoCache.setObject(decimals as AnyObject, forKey: cacheKey as NSString)
                    let result = NeoClientResult.success(decimals!)
                    completion(result)
                    return
                }
                completion(.failure(.invalidData))
            }
        }
    }
    
    public func getNEP5TokenBalance(for address: String, tokenHash: String, completion: @escaping (NeoClientResult<TokenBalance>) -> ()) {
        
        var params:[Any] = []
        params.append(tokenHash)
        params.append(NEP5Method.balanceOf.rawValue)
        var args:[String:String] = [:]
        args["type"] = "Hash160"
        args["value"] = address.hash160()
        params.append([args])
        
        sendRequest(.invokeFunction, params: params) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let response):
                let decoder = JSONDecoder()
                #if DEBUG
                    print(response)
                #endif
                guard let data = try? JSONSerialization.data(withJSONObject: (response["result"] as! JSONDictionary), options: .prettyPrinted),
                    let invokeResponse = try? decoder.decode(BalanceOfResult.self, from: data) else {
                        completion(.failure(.invalidData))
                        return
                }
                if invokeResponse.stack?.count == 1 {
                    let v = invokeResponse.stack?.first
                    //NEO system is little endian. The hex returns here is little endian byte array so we have to reverse it to BigEndian
                    let tokenAmount = v!.value!.littleEndianHexToUInt
                    //TODO get decimal
                    print(tokenAmount)
                    let tokenBalance = TokenBalance(amount: 10)
                    let result = NeoClientResult.success(tokenBalance)
                    completion(result)
                    return
                }
                completion(.failure(.invalidData))
            }
        }
    }
    
    public func getNEP5TokenTotalSupply(token hash: String, completion: @escaping (NeoClientResult<UInt>) -> ()) {
        
        var params:[Any] = []
        params.append(hash)
        params.append(NEP5Method.totalSupply.rawValue)
        
        sendRequest(.invokeFunction, params: params) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let response):
                let decoder = JSONDecoder()
                #if DEBUG
                    print(response)
                #endif
                guard let data = try? JSONSerialization.data(withJSONObject: (response["result"] as! JSONDictionary), options: .prettyPrinted),
                    let invokeResponse = try? decoder.decode(BalanceOfResult.self, from: data) else {
                        completion(.failure(.invalidData))
                        return
                }
                if invokeResponse.stack?.count == 1 {
                    let v = invokeResponse.stack?.first
                    //NEO system is little endian. The hex returns here is little endian byte array so we have to reverse it to BigEndian
                    let tokenSupply = v!.value!.littleEndianHexToUInt
                    let result = NeoClientResult.success(tokenSupply)
                    completion(result)
                    return
                }
               completion(.failure(.invalidData))
            }
        }
    }
    
}
