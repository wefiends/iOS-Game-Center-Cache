//
//  GCCache.m
//  GameCenterCache
//
//  Created by nikan on 3/12/11.
//  Copyright 2011 Anton Nikolaienko. All rights reserved.
//

#import "GCCache.h"


#if GCCACHE_ENABLE_LOGGING
#define GCLOG(...)
#else
#define GCLOG(...) NSLog(__VA_ARGS__)
#endif


static NSString *kGCProfilesProperty = @"GCProfiles";
static NSString *kGCDefaultProfileName = @"Default";


@interface GCCache (Internal)
- (id)initWithDictionary:(NSDictionary*)profileDict;
- (BOOL)isEqualToProfile:(NSDictionary*)profileDict;

+ (BOOL)isBetterScore:(NSNumber*)lscore thanScore:(NSNumber*)rscore inOrder:(NSString*)order;
+ (NSDictionary*)leaderboardWithName:(NSString*)leaderboardName;

+ (BOOL)isGameCenterAPIAvailable;
+ (void)authenticateLocalPlayerWithCompletionHandler:(void(^)(NSError *error))completionHandler;

@end


@implementation GCCache

static GCCache *activeCache_ = nil;
static NSArray *leaderboards_ = nil;
static NSArray *achievements_ = nil;

+ (NSArray*)cachedProfiles
{
    return [[NSUserDefaults standardUserDefaults] arrayForKey:kGCProfilesProperty];
}

+ (GCCache*)cacheForProfile:(NSDictionary*)profileDict
{
    return [[[GCCache alloc] initWithDictionary:profileDict] autorelease];
}

+ (GCCache*)activeCache
{
    @synchronized(self) {
        if (!activeCache_) {
            // Looking for default profile in cached
            NSArray *profiles = [GCCache cachedProfiles];
            for (NSDictionary *profile in profiles) {
                NSString *name = [profile valueForKey:@"Name"];
                NSNumber *local = [profile valueForKey:@"IsLocal"];
                if ([name isEqualToString:kGCDefaultProfileName] && [local boolValue]) {
                    activeCache_ = [[GCCache cacheForProfile:profile] retain];
                    GCLOG(@"Default profile found in cache.");
                    break;
                }
            }

            // Create new default profile
            if (!activeCache_) {
                activeCache_ = [[GCCache alloc] initWithDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                    kGCDefaultProfileName, @"Name",
                                                                    [NSNumber numberWithBool:YES], @"IsLocal",
                                                                    nil]];
                [activeCache_ synchronize];
                GCLOG(@"New Default profile created.");
            }
        }
    }
    return activeCache_;
}

+ (void)setActiveCache:(GCCache*)cache
{
    @synchronized(self) {
        if (activeCache_) {
            [activeCache_ release], activeCache_ = nil;
        }
        activeCache_ = [cache retain];
    }
}

+ (void)registerAchievements:(NSArray*)achievements
{
    @synchronized(self) {
        if (achievements_) {
            [achievements_ release], achievements_ = nil;
        }
        achievements_ = [achievements retain];
    }
}

+ (void)registerLeaderboards:(NSArray*)leaderboards
{
    @synchronized(self) {
        if (leaderboards_) {
            [leaderboards_ release], leaderboards_ = nil;
        }
        leaderboards_ = [leaderboards retain];
    }
}

+ (void)authenticateLocalPlayerWithCompletionHandler:(void(^)(NSError *error))completionHandler
{
    GKLocalPlayer *localPlayer = [GKLocalPlayer localPlayer];
    [localPlayer authenticateWithCompletionHandler:^(NSError *e) {
        if (localPlayer.isAuthenticated)
        {
            GCLOG(@"Local Player authenticated.");

            // Looking for player profile in cached
            BOOL profileFound = NO;
            NSArray *profiles = [GCCache cachedProfiles];
            for (NSDictionary *profile in profiles) {
                NSString *playerID = [profile valueForKey:@"PlayerID"];
                NSNumber *local = [profile valueForKey:@"IsLocal"];
                if (playerID && [playerID isEqualToString:[localPlayer playerID]] && ![local boolValue]) {
                    GCLOG(@"Player profile found in cache. Switching to it.");
                    [GCCache setActiveCache:[GCCache cacheForProfile:profile]];
                    profileFound = YES;
                    break;
                }
            }
            
            if (!profileFound) {
                GCCache *newCache = [[GCCache alloc] initWithDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                         [localPlayer alias], @"Name",
                                                                         [localPlayer playerID], @"PlayerID",
                                                                         [NSNumber numberWithBool:NO], @"IsLocal",
                                                                         nil]];
                [GCCache setActiveCache:newCache];
                [newCache release];
                
                GCLOG(@"New profile created for Player.");
            }
        }

        completionHandler(e);
    }];
}

+ (void)launchGameCenterWithCompletionTarget:(id)target action:(SEL)action
{
    if (![GCCache isGameCenterAPIAvailable]) {
        GCLOG(@"Game Center API not available on device. Working locally.");
        [target performSelectorOnMainThread:action withObject:nil waitUntilDone:NO];
    } else {
        [GCCache authenticateLocalPlayerWithCompletionHandler:^(NSError *e) {
            if (e) {
                GCLOG(@"Failed to authenticate Local Player. Working locally.");
            } else {
                GCLOG(@"Game Center launched.");
            }

            [target performSelectorOnMainThread:action withObject:nil waitUntilDone:NO];
        }];
    }
}

+ (void)shutdown
{
    @synchronized(self) {
        [activeCache_ release], activeCache_ = nil;
        [leaderboards_ release], leaderboards_ = nil;
        [achievements_ release], achievements_ = nil;
    }

    GCLOG(@"GCCache shut down.");
}


#pragma mark -

+ (BOOL)isGameCenterAPIAvailable
{
    // Check for presence of GKLocalPlayer class.
    BOOL localPlayerClassAvailable = (NSClassFromString(@"GKLocalPlayer")) != nil;
    
    // The device must be running iOS 4.1 or later.
    NSString *reqSysVer = @"4.1";
    NSString *currSysVer = [[UIDevice currentDevice] systemVersion];
    BOOL osVersionSupported = ([currSysVer compare:reqSysVer options:NSNumericSearch] != NSOrderedAscending);
    
    return (localPlayerClassAvailable && osVersionSupported);
}

+ (BOOL)isBetterScore:(NSNumber*)lscore thanScore:(NSNumber*)rscore inOrder:(NSString*)order
{
    if ([order isEqualToString:@"Ascending"]) {
        return [rscore compare:lscore] == NSOrderedAscending;
    } else if ([order isEqualToString:@"Descending"]) {
        return [rscore compare:lscore] == NSOrderedDescending;
    }
    
    return NO;
}

+ (NSDictionary*)leaderboardWithName:(NSString *)leaderboardName
{
    @synchronized(self) {
        if (leaderboards_) {
            NSUInteger idx = [leaderboards_ indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
                if ([leaderboardName isEqualToString:[obj valueForKey:@"Name"]]) {
                    *stop = YES;
                    return YES;
                }
                
                return NO;
            }];
            
            if (idx != NSNotFound) {
                return [leaderboards_ objectAtIndex:idx];
            }
        }
    }
    
    return nil;
}


#pragma mark -

- (NSString*)profileName
{
    return [data valueForKey:@"Name"];
}

- (BOOL)isLocal
{
    return [[data valueForKey:@"IsLocal"] boolValue];
}


#pragma mark -

- (id)initWithDictionary:(NSDictionary*)profileDict
{
    if ((self = [super init])) {
        data = [[NSMutableDictionary alloc] initWithDictionary:profileDict];
    }
    return self;
}

- (void)dealloc
{
    [self synchronize];

    [data release];
    [super dealloc];
}


#pragma mark -

- (BOOL)isEqualToProfile:(NSDictionary*)profileDict
{
    NSString *theName = [profileDict valueForKey:@"Name"];
    BOOL theIsLocal = [[profileDict valueForKey:@"IsLocal"] boolValue];
    
    return ([theName isEqualToString:self.profileName] && theIsLocal == self.isLocal) ? YES : NO;
}

- (void)synchronize
{
    NSMutableArray *allProfiles = [NSMutableArray arrayWithArray:
                                   [[NSUserDefaults standardUserDefaults] arrayForKey:kGCProfilesProperty]];
    // Looking for this profile
    BOOL replaced = NO;
    for (int i = 0; i < allProfiles.count; ++i) {
        NSDictionary *profile = [allProfiles objectAtIndex:i];
        if ([self isEqualToProfile:profile]) {
            [allProfiles replaceObjectAtIndex:i withObject:data];
            replaced = YES;
            break;
        }
    }
    
    if (!replaced) {
        [allProfiles addObject:data];
    }
    
    [[NSUserDefaults standardUserDefaults] setObject:allProfiles forKey:kGCProfilesProperty];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    GCLOG(@"GCCache synchronized.");
}

- (void)reset
{
    NSMutableDictionary *minData = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                    [data valueForKey:@"Name"], @"Name",
                                    [data valueForKey:@"IsLocal"], @"IsLocal",
                                    nil];
    [data release];
    data = [minData retain];

    GCLOG(@"GCCache reset.");
}

- (BOOL)submitScore:(NSNumber*)score toLeaderboard:(NSString*)board
{
    NSMutableDictionary *scoreDict = [NSMutableDictionary dictionaryWithDictionary:[data objectForKey:@"Scores"]];
    NSNumber *currScore = [scoreDict valueForKey:board];    
    if (currScore) {
        NSDictionary *leaderboard = [GCCache leaderboardWithName:board];
        if (!leaderboard || ![GCCache isBetterScore:score
                                          thanScore:currScore
                                            inOrder:[leaderboard valueForKey:@"Order"]])
        {
            return NO;
        }
    }

    // Rewriting current score
    [scoreDict setValue:score forKey:board];
    [data setObject:scoreDict forKey:@"Scores"];
    
    GCLOG(@"Score for '%@' leaderboard updated to %@.", board, score);
    
    return YES;
}

- (NSNumber*)scoreForLeaderboard:(NSString*)board
{
    NSDictionary *scoreDict = [data objectForKey:@"Scores"];
    return [scoreDict valueForKey:board];
}

- (NSDictionary*)allScores
{
    return [data objectForKey:@"Scores"];
}

- (BOOL)unlockAchievement:(NSString*)achievement
{
    NSMutableDictionary *achievementDict = [NSMutableDictionary dictionaryWithDictionary:
                                            [data objectForKey:@"Achievements"]];
    NSNumber *currValue = [achievementDict valueForKey:achievement];
    if (currValue && [currValue boolValue]) {
        return NO;
    }
    
    [achievementDict setValue:[NSNumber numberWithBool:YES] forKey:achievement];
    [data setObject:achievementDict forKey:@"Achievements"];
    
    GCLOG(@"Achievement '%@' unlocked.", achievement);

    return YES;
}

- (BOOL)isUnlockedAchievement:(NSString*)achievement
{
    NSDictionary *achievementDict = [data objectForKey:@"Achievements"];
    NSNumber *currValue = [achievementDict valueForKey:achievement];
    if (currValue && [currValue boolValue]) {
        return YES;
    }
    
    return NO;
}

- (NSDictionary*)allAchievements
{
    return [data objectForKey:@"Achievements"];
}


@end
