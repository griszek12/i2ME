#import "LegacySettings.h"
#import "LegacyStore.h"
static void Error(NSError *error){if(error)[[[UIAlertView alloc] initWithTitle:L(@"error") message:error.localizedDescription delegate:nil cancelButtonTitle:L(@"ok") otherButtonTitles:nil] show];}
@implementation SettingsController
- (void)viewDidLoad{[super viewDidLoad];self.title=L(@"settings");}
- (NSString *)tableView:(UITableView *)table titleForFooterInSection:(NSInteger)section{return @"i2ME\nMade by Griszek (with help of ChatGPT 6.1)\nVERSION: 1.0.2";}
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section{return SupportedLanguages().count;}
- (NSString *)tableView:(UITableView *)table titleForHeaderInSection:(NSInteger)section{return L(@"language");}
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)index{
    UITableViewCell *cell=[table dequeueReusableCellWithIdentifier:@"language"];if(!cell)cell=[[UITableViewCell alloc]initWithStyle:0 reuseIdentifier:@"language"];
    NSArray *language=[SupportedLanguages() objectAtIndex:index.row];cell.textLabel.text=[language objectAtIndex:1];cell.accessoryType=[[language objectAtIndex:0] isEqual:CurrentLanguage()]?UITableViewCellAccessoryCheckmark:0;return cell;
}
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)index{SetLanguage([[SupportedLanguages() objectAtIndex:index.row] objectAtIndex:0]);self.title=L(@"settings");[table reloadData];}
@end

@implementation ProfileController {
    NSMutableDictionary *profile;
    NSArray *resolutions;
}
- (void)viewDidLoad{
    [super viewDidLoad];profile=GameProfile(self.path);self.title=L(@"gameSettings");
    resolutions=@[@[@128,@160],@[@176,@208],@[@176,@220],@[@240,@320],@[@320,@240],@[@360,@640],@[@480,@800]];
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc]initWithTitle:L(self.firstLaunch?@"start":@"save") style:UIBarButtonItemStyleDone target:self action:@selector(done)];
}
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section{return 5;}
- (NSString *)tableView:(UITableView *)table titleForHeaderInSection:(NSInteger)section{return self.firstLaunch?L(@"firstLaunch"):nil;}
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)index{
    UITableViewCell *cell=[table dequeueReusableCellWithIdentifier:@"profile"];if(!cell)cell=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"profile"];
    NSArray *labels=@[L(@"name"),L(@"resolution"),L(@"fps"),L(@"icon"),L(@"saveBackups")];cell.textLabel.text=[labels objectAtIndex:index.row];cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;cell.imageView.image=nil;
    if(index.row==0)cell.detailTextLabel.text=[profile objectForKey:@"name"];
    else if(index.row==1)cell.detailTextLabel.text=[NSString stringWithFormat:@"%@ × %@",[profile objectForKey:@"width"],[profile objectForKey:@"height"]];
    else if(index.row==2)cell.detailTextLabel.text=[[profile objectForKey:@"fps"] intValue]?[[profile objectForKey:@"fps"] description]:L(@"unlimited");
    else {cell.detailTextLabel.text=@"";if(index.row==3)cell.imageView.image=GameIcon(self.path);}
    return cell;
}
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)index{
    [table deselectRowAtIndexPath:index animated:YES];
    if(index.row==0){UIAlertView *alert=[[UIAlertView alloc]initWithTitle:L(@"name") message:nil delegate:self cancelButtonTitle:L(@"cancel") otherButtonTitles:L(@"save"),nil];alert.tag=1;alert.alertViewStyle=UIAlertViewStylePlainTextInput;[alert textFieldAtIndex:0].text=[profile objectForKey:@"name"];[alert show];}
    else if(index.row==1){UIActionSheet *sheet=[[UIActionSheet alloc]initWithTitle:L(@"resolution") delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];sheet.tag=1;for(NSArray *r in resolutions)[sheet addButtonWithTitle:[NSString stringWithFormat:@"%@ × %@",[r objectAtIndex:0],[r objectAtIndex:1]]];[sheet addButtonWithTitle:L(@"custom")];sheet.cancelButtonIndex=[sheet addButtonWithTitle:L(@"cancel")];[sheet showInView:self.view];}
    else if(index.row==2){UIActionSheet *sheet=[[UIActionSheet alloc]initWithTitle:L(@"fps") delegate:self cancelButtonTitle:L(@"cancel") destructiveButtonTitle:nil otherButtonTitles:@"15",@"30",@"60",L(@"unlimited"),nil];sheet.tag=2;[sheet showInView:self.view];}
    else if(index.row==3){UIImagePickerController *picker=[UIImagePickerController new];picker.delegate=self;picker.sourceType=UIImagePickerControllerSourceTypePhotoLibrary;picker.allowsEditing=YES;[self presentViewController:picker animated:YES completion:nil];}
    else {SaveController *saves=[SaveController new];saves.identifier=GameID(self.path);[self.navigationController pushViewController:saves animated:YES];}
}
- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index{
    if(index==sheet.cancelButtonIndex||index<0)return;
    if(sheet.tag==2){int fps[]={15,30,60,0};if(index<4)[profile setObject:@(fps[index]) forKey:@"fps"];}
    else if(index<resolutions.count){NSArray *r=[resolutions objectAtIndex:index];[profile setObject:[r objectAtIndex:0] forKey:@"width"];[profile setObject:[r objectAtIndex:1] forKey:@"height"];}
    else {UIAlertView *a=[[UIAlertView alloc]initWithTitle:L(@"resolution") message:L(@"resolutionHint") delegate:self cancelButtonTitle:L(@"cancel") otherButtonTitles:L(@"save"),nil];a.tag=2;a.alertViewStyle=UIAlertViewStyleLoginAndPasswordInput;[a textFieldAtIndex:0].text=[[profile objectForKey:@"width"] description];[a textFieldAtIndex:1].text=[[profile objectForKey:@"height"] description];[a textFieldAtIndex:1].secureTextEntry=NO;[a textFieldAtIndex:0].keyboardType=UIKeyboardTypeNumberPad;[a textFieldAtIndex:1].keyboardType=UIKeyboardTypeNumberPad;[a show];}
    [self.tableView reloadData];
}
- (void)alertView:(UIAlertView *)alert clickedButtonAtIndex:(NSInteger)index{
    if(index==alert.cancelButtonIndex)return;
    if(alert.tag==1){NSString *name=[[alert textFieldAtIndex:0].text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];if(name.length)[profile setObject:name forKey:@"name"];}
    else {int w=[alert textFieldAtIndex:0].text.intValue,h=[alert textFieldAtIndex:1].text.intValue;if(w<64||h<64||w>1024||h>1024){[[[UIAlertView alloc]initWithTitle:L(@"error") message:L(@"resolutionHint") delegate:nil cancelButtonTitle:L(@"ok") otherButtonTitles:nil]show];return;}[profile setObject:@(w) forKey:@"width"];[profile setObject:@(h) forKey:@"height"];}
    [self.tableView reloadData];
}
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info{
    UIImage *image=[info objectForKey:UIImagePickerControllerEditedImage]?:[info objectForKey:UIImagePickerControllerOriginalImage];SaveIcon(self.path,image);[self dismissViewControllerAnimated:YES completion:^{[self.tableView reloadData];}];
}
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker{[self dismissViewControllerAnimated:YES completion:nil];}
- (void)done{[profile setObject:@YES forKey:@"configured"];SaveProfile(self.path,profile);void(^completion)(NSDictionary *)=self.finished;[self.navigationController popViewControllerAnimated:!self.firstLaunch];if(completion)completion(profile);}
@end

@implementation SaveController {
    NSArray *backups;
    NSString *selected;
}
- (void)viewDidLoad{[super viewDidLoad];self.title=L(@"saveBackups");self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(create)];}
- (void)viewWillAppear:(BOOL)animated{[super viewWillAppear:animated];[self refresh];}
- (void)refresh{backups=SaveBackups(self.identifier);[self.tableView reloadData];}
- (void)create{NSError *error=nil;CreateSaveBackup(self.identifier,&error);Error(error);[self refresh];}
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section{return backups.count;}
- (NSString *)tableView:(UITableView *)table titleForFooterInSection:(NSInteger)section{return L(@"backupHint");}
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)index{UITableViewCell *cell=[table dequeueReusableCellWithIdentifier:@"backup"];if(!cell)cell=[[UITableViewCell alloc]initWithStyle:0 reuseIdentifier:@"backup"];cell.textLabel.text=[backups objectAtIndex:index.row];return cell;}
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)index{selected=[backups objectAtIndex:index.row];UIAlertView *alert=[[UIAlertView alloc]initWithTitle:L(@"restore") message:L(@"restoreHint") delegate:self cancelButtonTitle:L(@"cancel") otherButtonTitles:L(@"restore"),nil];[alert show];}
- (void)alertView:(UIAlertView *)alert clickedButtonAtIndex:(NSInteger)index{if(index==alert.cancelButtonIndex)return;NSError *error=nil;RestoreSaveBackup(self.identifier,selected,&error);Error(error);[self refresh];}
- (BOOL)tableView:(UITableView *)table canEditRowAtIndexPath:(NSIndexPath *)index{return YES;}
- (void)tableView:(UITableView *)table commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)index{NSError *error=nil;DeleteSaveBackup(self.identifier,[backups objectAtIndex:index.row],&error);Error(error);[self refresh];}
@end

@implementation GameCell {
    UIButton *editButton,*deleteButton;
}
- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier{
    if(!(self=[super initWithStyle:style reuseIdentifier:identifier]))return nil;
    self.contentView.clipsToBounds=YES;
    editButton=[UIButton buttonWithType:UIButtonTypeCustom];editButton.backgroundColor=[UIColor colorWithRed:.1 green:.45 blue:.95 alpha:1];[editButton addTarget:self action:@selector(edit) forControlEvents:UIControlEventTouchUpInside];[self.contentView addSubview:editButton];
    deleteButton=[UIButton buttonWithType:UIButtonTypeCustom];deleteButton.backgroundColor=[UIColor colorWithRed:.9 green:.16 blue:.2 alpha:1];[deleteButton addTarget:self action:@selector(remove) forControlEvents:UIControlEventTouchUpInside];[self.contentView addSubview:deleteButton];
    self.body=[UIView new];self.body.backgroundColor=[UIColor whiteColor];[self.contentView addSubview:self.body];
    self.gameIcon=[UIImageView new];self.gameIcon.contentMode=UIViewContentModeScaleAspectFit;[self.body addSubview:self.gameIcon];
    self.nameLabel=[UILabel new];self.nameLabel.font=[UIFont boldSystemFontOfSize:16];[self.body addSubview:self.nameLabel];self.detailLabel=[UILabel new];self.detailLabel.font=[UIFont systemFontOfSize:12];self.detailLabel.textColor=[UIColor grayColor];[self.body addSubview:self.detailLabel];
    UIPanGestureRecognizer *pan=[[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(pan:)];pan.delegate=self;[self addGestureRecognizer:pan];return self;
}
- (void)layoutSubviews{[super layoutSubviews];CGFloat w=self.contentView.bounds.size.width,h=self.contentView.bounds.size.height;editButton.frame=CGRectMake(0,0,80,h);deleteButton.frame=CGRectMake(w-80,0,80,h);[editButton setTitle:L(@"edit") forState:0];[deleteButton setTitle:L(@"delete") forState:0];self.body.bounds=CGRectMake(0,0,w,h);self.body.center=CGPointMake(w/2,h/2);self.gameIcon.frame=CGRectMake(10,8,44,44);self.nameLabel.frame=CGRectMake(64,8,w-74,24);self.detailLabel.frame=CGRectMake(64,34,w-74,18);}
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gesture{CGPoint v=[(UIPanGestureRecognizer *)gesture velocityInView:self];return fabs(v.x)>fabs(v.y);}
- (void)pan:(UIPanGestureRecognizer *)gesture{CGFloat x=[gesture translationInView:self].x;if(gesture.state==UIGestureRecognizerStateChanged)self.body.transform=CGAffineTransformMakeTranslation(MAX(-80,MIN(80,x)),0);else if(gesture.state==UIGestureRecognizerStateEnded||gesture.state==UIGestureRecognizerStateCancelled){CGFloat target=gesture.state==UIGestureRecognizerStateCancelled?0:(x>35?80:x<-35?-80:0);[UIView animateWithDuration:.2 animations:^{self.body.transform=CGAffineTransformMakeTranslation(target,0);}];}}
- (void)closeActions{self.body.transform=CGAffineTransformIdentity;}
- (void)prepareForReuse{[super prepareForReuse];[self closeActions];self.onEdit=nil;self.onDelete=nil;}
- (void)edit{if(self.onEdit)self.onEdit();}
- (void)remove{if(self.onDelete)self.onDelete();}
@end
