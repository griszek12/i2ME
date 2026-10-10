#import "LegacyStore.h"
#import <CommonCrypto/CommonDigest.h>
#include "miniz.h"
static NSString *Docs(void){return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) objectAtIndex:0];}
static NSString *Directory(NSString *name){NSString *path=[Docs() stringByAppendingPathComponent:name];[[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];return path;}
NSArray *SupportedLanguages(void){return @[@[@"pl",@"Polski"],@[@"en",@"English"],@[@"de",@"Deutsch"],@[@"fr",@"Français"],@[@"es",@"Español"],@[@"it",@"Italiano"],@[@"pt",@"Português"],@[@"uk",@"Українська"],@[@"ru",@"Русский"],@[@"ja",@"日本語"],@[@"zh",@"中文"]];}
NSString *CurrentLanguage(void){NSString *lang=[[NSUserDefaults standardUserDefaults] stringForKey:@"Language"];return lang?:@"pl";}
void SetLanguage(NSString *code){[[NSUserDefaults standardUserDefaults] setObject:code forKey:@"Language"];[[NSUserDefaults standardUserDefaults] synchronize];[[NSNotificationCenter defaultCenter] postNotificationName:@"LegacyLanguageChanged" object:nil];}
NSString *L(NSString *key){
    static NSDictionary *strings=nil;if(!strings)strings=[NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Languages" ofType:@"plist"]];
    NSString *value=[[strings objectForKey:CurrentLanguage()] objectForKey:key];return value?:[[strings objectForKey:@"en"] objectForKey:key]?:key;
}
NSString *GameID(NSString *path){
    static NSMutableDictionary *cache=nil;if(!cache)cache=[NSMutableDictionary dictionary];NSString *cached=[cache objectForKey:path];if(cached)return cached;
    CC_SHA256_CTX context;CC_SHA256_Init(&context);NSInputStream *stream=[NSInputStream inputStreamWithFileAtPath:path];[stream open];uint8_t buffer[8192];NSInteger count;
    while((count=[stream read:buffer maxLength:sizeof(buffer)])>0)CC_SHA256_Update(&context,buffer,(CC_LONG)count);[stream close];unsigned char digest[CC_SHA256_DIGEST_LENGTH];CC_SHA256_Final(digest,&context);
    NSMutableString *identifier=[NSMutableString string];for(int i=0;i<sizeof(digest);i++)[identifier appendFormat:@"%02x",digest[i]];[cache setObject:identifier forKey:path];return identifier;
}
static NSData *JarEntry(NSString *path,NSString *entry){
    mz_zip_archive zip={0};NSData *data=nil;if(mz_zip_reader_init_file(&zip,[path fileSystemRepresentation],0)){
        size_t size=0;void *bytes=mz_zip_reader_extract_file_to_heap(&zip,[entry UTF8String],&size,0);
        if(bytes){data=[NSData dataWithBytes:bytes length:size];mz_free(bytes);}mz_zip_reader_end(&zip);
    }return data;
}
static NSDictionary *Manifest(NSString *path){
    NSString *manifest=[[NSString alloc] initWithData:JarEntry(path,@"META-INF/MANIFEST.MF") encoding:NSUTF8StringEncoding];NSMutableDictionary *fields=[NSMutableDictionary dictionary];NSString *last=nil;
    for(NSString *raw in [manifest componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]){
        if([raw hasPrefix:@" "]&&last){[fields setObject:[[fields objectForKey:last] stringByAppendingString:[raw substringFromIndex:1]] forKey:last];continue;}
        NSRange colon=[raw rangeOfString:@":"];if(colon.location==NSNotFound)continue;last=[raw substringToIndex:colon.location];[fields setObject:[[raw substringFromIndex:colon.location+1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] forKey:last];
    }return fields;
}
static NSString *ProfilePath(NSString *path){return [Directory(@"Profiles") stringByAppendingPathComponent:[GameID(path) stringByAppendingPathExtension:@"plist"]];}
NSMutableDictionary *GameProfile(NSString *path){NSMutableDictionary *profile=[NSMutableDictionary dictionaryWithContentsOfFile:ProfilePath(path)];if(profile)return profile;NSString *name=[Manifest(path) objectForKey:@"MIDlet-Name"]?:[[path lastPathComponent] stringByDeletingPathExtension];return [NSMutableDictionary dictionaryWithDictionary:@{@"name":name,@"width":@240,@"height":@320,@"fps":@30,@"configured":@NO}];}
void SaveProfile(NSString *path,NSDictionary *profile){[profile writeToFile:ProfilePath(path) atomically:YES];}
UIImage *GameIcon(NSString *path){
    UIImage *custom=[UIImage imageWithContentsOfFile:[Directory(@"Icons") stringByAppendingPathComponent:[GameID(path) stringByAppendingPathExtension:@"png"]]];if(custom)return custom;
    NSDictionary *fields=Manifest(path);NSString *icon=[fields objectForKey:@"MIDlet-Icon"];
    if(!icon){NSArray *midlet=[[fields objectForKey:@"MIDlet-1"] componentsSeparatedByString:@","];if(midlet.count>1)icon=[[midlet objectAtIndex:1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];}
    while([icon hasPrefix:@"/"])icon=[icon substringFromIndex:1];return icon.length?[UIImage imageWithData:JarEntry(path,icon)]:nil;
}
void SaveIcon(NSString *path,UIImage *image){[UIImagePNGRepresentation(image) writeToFile:[Directory(@"Icons") stringByAppendingPathComponent:[GameID(path) stringByAppendingPathExtension:@"png"]] atomically:YES];}
NSString *SaveRoot(NSString *identifier){NSString *path=[Directory(@"SavedGames") stringByAppendingPathComponent:identifier];[[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];return path;}
static NSString *BackupRoot(NSString *identifier){return Directory([@"SaveBackups" stringByAppendingPathComponent:identifier]);}
NSString *CreateSaveBackup(NSString *identifier,NSError **error){
    NSDateFormatter *format=[NSDateFormatter new];format.dateFormat=@"yyyy-MM-dd HH-mm-ss";NSString *name=[format stringFromDate:[NSDate date]],*dest=[BackupRoot(identifier) stringByAppendingPathComponent:name];
    if([[NSFileManager defaultManager] fileExistsAtPath:dest])dest=[dest stringByAppendingFormat:@"-%u",arc4random()%10000];
    return [[NSFileManager defaultManager] copyItemAtPath:SaveRoot(identifier) toPath:dest error:error]?[dest lastPathComponent]:nil;
}
NSArray *SaveBackups(NSString *identifier){return [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:BackupRoot(identifier) error:nil] sortedArrayUsingSelector:@selector(compare:)];}
BOOL RestoreSaveBackup(NSString *identifier,NSString *name,NSError **error){
    NSFileManager *files=[NSFileManager defaultManager];NSString *root=SaveRoot(identifier),*source=[BackupRoot(identifier) stringByAppendingPathComponent:[name lastPathComponent]],*staging=[root stringByAppendingString:@".restore"],*old=[root stringByAppendingString:@".previous"];
    if([files fileExistsAtPath:staging]&&![files removeItemAtPath:staging error:error])return NO;
    if(![files copyItemAtPath:source toPath:staging error:error])return NO;
    if([files fileExistsAtPath:old]&&![files removeItemAtPath:old error:error])return NO;
    if(![files moveItemAtPath:root toPath:old error:error])return NO;
    if(![files moveItemAtPath:staging toPath:root error:error]){[files moveItemAtPath:old toPath:root error:nil];return NO;}
    return YES;
}
BOOL DeleteSaveBackup(NSString *identifier,NSString *name,NSError **error){return [[NSFileManager defaultManager] removeItemAtPath:[BackupRoot(identifier) stringByAppendingPathComponent:[name lastPathComponent]] error:error];}
