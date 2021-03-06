// Objective-C API for talking to github.com/o3labs/neo-wallet-address-go Go package.
//   gobind -lang=objc github.com/o3labs/neo-wallet-address-go
//
// File is generated by gobind. Do not edit.

#ifndef __Neowallet_H__
#define __Neowallet_H__

@import Foundation;
#include "Universe.objc.h"


@class NeowalletBlockCountResponse;
@class NeowalletFetchSeedRequest;
@class NeowalletNodeList;
@class NeowalletSeedNodeResponse;
@class NeowalletWallet;

@interface NeowalletBlockCountResponse : NSObject <goSeqRefInterface> {
}
@property(strong, readonly) id _ref;

- (instancetype)initWithRef:(id)ref;
- (instancetype)init;
- (NSString*)jsonrpc;
- (void)setJsonrpc:(NSString*)v;
- (long)id_;
- (void)setID:(long)v;
- (long)result;
- (void)setResult:(long)v;
- (int64_t)responseTime;
- (void)setResponseTime:(int64_t)v;
@end

@interface NeowalletFetchSeedRequest : NSObject <goSeqRefInterface> {
}
@property(strong, readonly) id _ref;

- (instancetype)initWithRef:(id)ref;
- (instancetype)init;
- (NeowalletBlockCountResponse*)response;
- (void)setResponse:(NeowalletBlockCountResponse*)v;
- (NSString*)url;
- (void)setURL:(NSString*)v;
@end

@interface NeowalletNodeList : NSObject <goSeqRefInterface> {
}
@property(strong, readonly) id _ref;

- (instancetype)initWithRef:(id)ref;
- (instancetype)init;
// skipped field NodeList.URL with unsupported type: *types.Slice

@end

@interface NeowalletSeedNodeResponse : NSObject <goSeqRefInterface> {
}
@property(strong, readonly) id _ref;

- (instancetype)initWithRef:(id)ref;
- (instancetype)init;
- (NSString*)url;
- (void)setURL:(NSString*)v;
- (long)blockCount;
- (void)setBlockCount:(long)v;
- (int64_t)responseTime;
- (void)setResponseTime:(int64_t)v;
@end

@interface NeowalletWallet : NSObject <goSeqRefInterface> {
}
@property(strong, readonly) id _ref;

- (instancetype)initWithRef:(id)ref;
- (instancetype)init;
- (NSData*)publicKey;
- (void)setPublicKey:(NSData*)v;
- (NSData*)privateKey;
- (void)setPrivateKey:(NSData*)v;
- (NSString*)address;
- (void)setAddress:(NSString*)v;
- (NSString*)wif;
- (void)setWIF:(NSString*)v;
- (NSData*)hashedSignature;
- (void)setHashedSignature:(NSData*)v;
- (NSData*)computeSharedSecret:(NSData*)publicKey;
@end

/**
 * decrypt from base64 to decrypted string
 */
FOUNDATION_EXPORT NSString* NeowalletDecrypt(NSData* key, NSString* cryptoText);

/**
 * encrypt string to base64 crypto using AES
 */
FOUNDATION_EXPORT NSString* NeowalletEncrypt(NSData* key, NSString* text);

FOUNDATION_EXPORT NeowalletBlockCountResponse* NeowalletFetchSeedNode(NSString* url);

FOUNDATION_EXPORT NeowalletWallet* NeowalletGenerateFromWIF(NSString* wif, NSError** error);

FOUNDATION_EXPORT NeowalletWallet* NeowalletGeneratePublicKeyFromPrivateKey(NSString* privateKey, NSError** error);

FOUNDATION_EXPORT NeowalletWallet* NeowalletNewWallet(NSError** error);

FOUNDATION_EXPORT NeowalletSeedNodeResponse* NeowalletSelectBestSeedNode(NSString* commaSeparatedURLs);

FOUNDATION_EXPORT NSData* NeowalletSign(NSData* data, NSString* key, NSError** error);

#endif
