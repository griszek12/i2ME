#import <UIKit/UIKit.h>
@interface SettingsController : UITableViewController
@end
@interface ProfileController : UITableViewController <UIAlertViewDelegate,UIActionSheetDelegate,UIImagePickerControllerDelegate,UINavigationControllerDelegate>
@property(nonatomic,copy) NSString *path;
@property(nonatomic,copy) void (^finished)(NSDictionary *profile);
@property(nonatomic,assign) BOOL firstLaunch;
@end
@interface SaveController : UITableViewController <UIAlertViewDelegate>
@property(nonatomic,copy) NSString *identifier;
@end
@interface GameCell : UITableViewCell <UIGestureRecognizerDelegate>
@property(nonatomic,strong) UIView *body;
@property(nonatomic,strong) UILabel *nameLabel;
@property(nonatomic,strong) UILabel *detailLabel;
@property(nonatomic,strong) UIImageView *gameIcon;
@property(nonatomic,copy) void (^onEdit)(void);
@property(nonatomic,copy) void (^onDelete)(void);
- (void)closeActions;
@end
