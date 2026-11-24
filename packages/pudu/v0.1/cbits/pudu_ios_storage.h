#ifndef PUDU_IOS_STORAGE_H
#define PUDU_IOS_STORAGE_H

/* Key-value storage. Plain values live in the application's user defaults,
   kept until the application is removed. Secure values live in the keychain
   as generic passwords under the application's identifier, readable only
   after the device's first unlock and never migrated to another device or
   into a backup. Every instruction runs on the main thread in stream order,
   so a read answers after every earlier write and removal. */
#import <Foundation/Foundation.h>
#import <Security/Security.h>
#include <stdint.h>
#include "pudu_ios_events.h"
#include "pudu_ios_stream.h"

enum { PUDU_STORE_PLAIN, PUDU_STORE_SECURE, PUDU_STORE_PLACES };

static uint32_t pudu_store_place(pudu_reader *reader) {
  uint32_t place = pudu_word(reader);
  if (place >= PUDU_STORE_PLACES) pudu_stream_defect("used unknown store", place);
  return place;
}

/* The keychain query naming `key` in this application's service. */
static NSMutableDictionary *pudu_keychain_item(NSString *key) {
  return [@{
    (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
    (__bridge id)kSecAttrService : NSBundle.mainBundle.bundleIdentifier ?: @"org.pudu",
    (__bridge id)kSecAttrAccount : key,
  } mutableCopy];
}

static NSString *pudu_keychain_read(NSString *key) {
  NSMutableDictionary *query = pudu_keychain_item(key);
  query[(__bridge id)kSecReturnData] = @YES;
  query[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;
  CFTypeRef found = NULL;
  if (SecItemCopyMatching((__bridge CFDictionaryRef)query, &found) != errSecSuccess || found == NULL) return nil;
  NSData *bytes = (__bridge_transfer NSData *)found;
  return [[NSString alloc] initWithData:bytes encoding:NSUTF8StringEncoding];
}

static void pudu_keychain_write(NSString *key, NSString *value) {
  NSData *bytes = [value dataUsingEncoding:NSUTF8StringEncoding];
  NSMutableDictionary *query = pudu_keychain_item(key);
  NSDictionary *change = @{ (__bridge id)kSecValueData : bytes };
  OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)query, (__bridge CFDictionaryRef)change);
  if (status == errSecItemNotFound) {
    query[(__bridge id)kSecValueData] = bytes;
    query[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly;
    status = SecItemAdd((__bridge CFDictionaryRef)query, NULL);
  }
  if (status != errSecSuccess) fprintf(stderr, "pudu: the keychain refused a write, status %d\n", (int)status);
}

/* STORE_READ: the tag, the place, then the key; STORED answers with the value
   and 1, or an empty text and 0 when nothing is kept. */
static void pudu_do_store_read(pudu_reader *reader) {
  uint32_t tag = pudu_word(reader);
  uint32_t place = pudu_store_place(reader);
  NSString *key = pudu_text(reader);
  NSString *value = place == PUDU_STORE_PLAIN ? [NSUserDefaults.standardUserDefaults stringForKey:key] : pudu_keychain_read(key);
  pudu_queue(PUDU_UI_STORED, tag, value ?: @"", value != nil ? 1 : 0);
}

/* STORE_WRITE: the place, the key, then the value. */
static void pudu_do_store_write(pudu_reader *reader) {
  uint32_t place = pudu_store_place(reader);
  NSString *key = pudu_text(reader);
  NSString *value = pudu_text(reader);
  if (place == PUDU_STORE_PLAIN) [NSUserDefaults.standardUserDefaults setObject:value forKey:key];
  else pudu_keychain_write(key, value);
}

/* STORE_REMOVE: the place, then the key. */
static void pudu_do_store_remove(pudu_reader *reader) {
  uint32_t place = pudu_store_place(reader);
  NSString *key = pudu_text(reader);
  if (place == PUDU_STORE_PLAIN) [NSUserDefaults.standardUserDefaults removeObjectForKey:key];
  else SecItemDelete((__bridge CFDictionaryRef)pudu_keychain_item(key));
}

#endif
