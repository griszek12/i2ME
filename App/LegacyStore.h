#import <UIKit/UIKit.h>
NSString *L(NSString *key);
NSString *GameID(NSString *path);
NSString *SaveRoot(NSString *identifier);
NSMutableDictionary *GameProfile(NSString *path);
void SaveProfile(NSString *path,NSDictionary *profile);
UIImage *GameIcon(NSString *path);
void SaveIcon(NSString *path,UIImage *image);
NSArray *SupportedLanguages(void);
NSString *CurrentLanguage(void);
void SetLanguage(NSString *code);
NSString *CreateSaveBackup(NSString *identifier,NSError **error);
NSArray *SaveBackups(NSString *identifier);
BOOL RestoreSaveBackup(NSString *identifier,NSString *name,NSError **error);
BOOL DeleteSaveBackup(NSString *identifier,NSString *name,NSError **error);
