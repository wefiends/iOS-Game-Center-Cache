//
//  GCCache.h
//  GameCenterCache
//
//  Created by nikan on 3/12/11.
//  Copyright 2011 Anton Nikolaienko. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GCCache : NSObject {
    NSMutableDictionary *data;
    BOOL connected;
}

+ (NSArray*)cachedProfiles;
+ (GCCache*)cacheForProfile:(NSDictionary*)profileDict;
+ (BOOL)removeProfile: (NSDictionary*) profile;

+ (NSArray*)registeredAchievements;
+ (void)registerAchievements:(NSArray*)achievements;

+ (NSArray*)registeredLeaderboards;
+ (void)registerLeaderboards:(NSArray*)leaderboards;

+ (GCCache*)authenticatedCache;
+ (GCCache*)activeCache;
+ (void)activateCache:(GCCache*)cache;

+ (void)launchGameCenterWithCompletionTarget:(id)target action:(SEL)action;
+ (void)shutdown;

- (id)initWithDictionary:(NSDictionary*)profileDict;

- (BOOL)isEqualToProfile:(NSDictionary*)profileDict;
- (BOOL)renameProfile:(NSString*)newName;

- (BOOL)submitScore:(NSNumber*)score toLeaderboard:(NSString*)board;
- (NSNumber*)scoreForLeaderboard:(NSString*)board;
- (NSDictionary*)allScores;

- (BOOL)unlockAchievement:(NSString*)achievement;
- (BOOL)isUnlockedAchievement:(NSString*)achievement;
- (BOOL)submitProgress:(double)progress toAchievement:(NSString*)achievement;
- (double)progressOfAchievement:(NSString*)achievement;
- (NSDictionary*)allAchievements;

- (void)save;
- (BOOL)remove;
- (void)synchronize;
- (void)reset;

@property (retain) NSMutableDictionary *data;
@property (readonly) NSString *profileName;
@property (readonly) BOOL isLocal;
@property (readonly) NSString *playerID;
@property (readonly) BOOL isDefault;
@property (assign, getter = isConnected) BOOL connected;

@end
