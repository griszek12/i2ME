#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "jvm_bridge.h"
#import "j2me_render.h"
#import "j2me_input.h"
#import "j2me_ui.h"
#import "LegacyStore.h"
#import "LegacySettings.h"
#include <pthread.h>
#include <unistd.h>

extern const char *j2me_ui_get_form_title(void);
extern int j2me_ui_get_form_item_count(void);
extern const char *j2me_ui_get_form_item_label(int);
extern const char *j2me_ui_get_form_item_text(int);
extern int j2me_ui_get_command_count(void);
extern const char *j2me_ui_get_command_label(int);
extern int j2me_ui_get_command_id(int);
extern int j2me_ui_get_list_item_count(void);
extern const char *j2me_ui_get_list_item(int);
extern const char *j2me_ui_get_alert_text(void);

static NSString *text(const char *s) { return s ? [NSString stringWithUTF8String:s] : @""; }
static NSString *documents(void) { return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) objectAtIndex:0]; }
@interface GameController : UIViewController {
    UIImageView *screen;
    UIScrollView *form;
    CADisplayLink *clock;
    BOOL running;
    BOOL saveRequested;
}
@property(nonatomic,copy) NSString *jar;
- (void)showPayload:(NSDictionary *)payload;
@end
@interface TouchScreen : UIImageView
@property(nonatomic,assign) int virtualWidth;
@property(nonatomic,assign) int virtualHeight;
@end
@implementation TouchScreen
- (void)sendTouch:(NSSet *)touches type:(int)type{CGPoint p=[[touches anyObject] locationInView:self];int x=MAX(0,MIN(self.virtualWidth-1,(int)(p.x*self.virtualWidth/self.bounds.size.width)));int y=MAX(0,MIN(self.virtualHeight-1,(int)(p.y*self.virtualHeight/self.bounds.size.height)));j2me_input_post_touch(type,x,y);}
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event{[self sendTouch:touches type:J2ME_INPUT_POINTER_PRESSED];}
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event{[self sendTouch:touches type:J2ME_INPUT_POINTER_DRAGGED];}
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event{[self sendTouch:touches type:J2ME_INPUT_POINTER_RELEASED];}
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event{[self sendTouch:touches type:J2ME_INPUT_POINTER_RELEASED];}
@end
static __weak GameController *activeGame;
static pthread_mutex_t frameLock=PTHREAD_MUTEX_INITIALIZER;
static CGImageRef nextFrame;
static void flushFrame(void *frame,int width,int height) {
    static unsigned long frames=0;
    if(frames++==0) fprintf(stderr,"[i2ME] First rendered frame: %dx%d, image=%p\n",width,height,frame);
    pthread_mutex_lock(&frameLock);
    if(nextFrame) CGImageRelease(nextFrame);
    nextFrame=(CGImageRef)frame;
    pthread_mutex_unlock(&frameLock);
}
static void showUI(int action,const char *data) {
    if(action==J2ME_UI_ACTION_SHOW_CANVAS){
        fprintf(stderr,"[i2ME] Queueing Canvas UI\n");
        dispatch_async(dispatch_get_main_queue(),^{ [activeGame showPayload:@{@"action":@(action)}]; });
        fprintf(stderr,"[i2ME] Canvas UI queued\n");
        return;
    }
    NSMutableArray *items=[NSMutableArray array],*commands=[NSMutableArray array];
    if(action==J2ME_UI_ACTION_SHOW_LIST) {
        for(int i=0;i<j2me_ui_get_list_item_count();i++) [items addObject:text(j2me_ui_get_list_item(i))];
    } else if(action==J2ME_UI_ACTION_SHOW_ALERT) [items addObject:text(j2me_ui_get_alert_text())];
    else for(int i=0;i<j2me_ui_get_form_item_count();i++) [items addObject:[NSString stringWithFormat:@"%@\n%@",text(j2me_ui_get_form_item_label(i)),text(j2me_ui_get_form_item_text(i))]];
    for(int i=0;i<j2me_ui_get_command_count();i++) [commands addObject:@{@"name":text(j2me_ui_get_command_label(i)),@"id":@(j2me_ui_get_command_id(i))}];
    NSDictionary *payload=@{@"action":@(action),@"title":text(j2me_ui_get_form_title()),@"items":items,@"commands":commands};
    dispatch_async(dispatch_get_main_queue(),^{ [activeGame showPayload:payload]; });
}
@implementation GameController
- (UIButton *)button:(NSString *)label frame:(CGRect)frame code:(int)code {
    UIButton *b=[UIButton buttonWithType:UIButtonTypeRoundedRect]; b.frame=frame; b.tag=code;
    [b setTitle:label forState:UIControlStateNormal];
    [b addTarget:self action:@selector(keyDown:) forControlEvents:UIControlEventTouchDown];
    [b addTarget:self action:@selector(keyUp:) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside|UIControlEventTouchCancel];
    [self.view addSubview:b]; return b;
}
- (void)viewDidLoad {
    [super viewDidLoad]; self.view.backgroundColor=[UIColor blackColor]; NSDictionary *profile=GameProfile(self.jar);self.title=[profile objectForKey:@"name"];
    self.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc] initWithTitle:L(@"stop") style:UIBarButtonItemStylePlain target:self action:@selector(stopGame)];
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc]initWithTitle:L(@"saveBackups") style:UIBarButtonItemStylePlain target:self action:@selector(backupAndStop)];
    CGFloat w=self.view.bounds.size.width,h=self.view.bounds.size.height-44;
    int virtualWidth=[[profile objectForKey:@"width"] intValue],virtualHeight=[[profile objectForKey:@"height"] intValue];
    CGFloat canvasHeight=MIN(h-180,(w-20)*virtualHeight/(CGFloat)virtualWidth), canvasWidth=canvasHeight*virtualWidth/(CGFloat)virtualHeight;
    TouchScreen *touchScreen=[[TouchScreen alloc] initWithFrame:CGRectMake((w-canvasWidth)/2,4,canvasWidth,canvasHeight)];touchScreen.virtualWidth=virtualWidth;touchScreen.virtualHeight=virtualHeight;touchScreen.userInteractionEnabled=YES;screen=touchScreen;
    screen.contentMode=UIViewContentModeScaleAspectFit; screen.backgroundColor=[UIColor darkGrayColor]; [self.view addSubview:screen];
    form=[[UIScrollView alloc] initWithFrame:screen.frame];form.backgroundColor=[UIColor whiteColor];form.hidden=YES;[self.view addSubview:form];
    CGFloat y=canvasHeight+8;
    [self button:L(@"left") frame:CGRectMake(8,y,w/2-12,30) code:-6];
    [self button:L(@"right") frame:CGRectMake(w/2+4,y,w/2-12,30) code:-7];y+=34;
    CGFloat cw=(w-16)/6.0;
    NSArray *labels=@[@"1",@"2",@"3",@"4",@"5",@"6",@"7",@"8",@"9",@"*",@"0",@"#"];
    int codes[]={49,50,51,52,53,54,55,56,57,42,48,35};
    for(int i=0;i<12;i++) [self button:[labels objectAtIndex:i] frame:CGRectMake(8+(i%3)*cw,y+(i/3)*30,cw-3,27) code:codes[i]];
    [self button:@"↑" frame:CGRectMake(8+4*cw,y,cw-3,27) code:-1];
    [self button:@"←" frame:CGRectMake(8+3*cw,y+30,cw-3,27) code:-3];
    [self button:@"OK" frame:CGRectMake(8+4*cw,y+30,cw-3,27) code:-5];
    [self button:@"→" frame:CGRectMake(8+5*cw,y+30,cw-3,27) code:-4];
    [self button:@"↓" frame:CGRectMake(8+4*cw,y+60,cw-3,27) code:-2];
    activeGame=self; running=YES; j2me_input_reset();j2me_input_set_canvas_size(virtualWidth,virtualHeight);
    j2me_render_set_flush_callback(flushFrame);j2me_ui_set_callback(showUI);
    clock=[CADisplayLink displayLinkWithTarget:self selector:@selector(updateFrame)]; clock.frameInterval=2;
    [clock addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    [NSThread detachNewThreadSelector:@selector(runMIDlet) toTarget:self withObject:nil];
}
- (void)runMIDlet {
    @autoreleasepool {
        fprintf(stderr,"[i2ME] MIDlet worker started\n");
        NSString *root=[[NSBundle mainBundle] resourcePath];NSString *save=SaveRoot(GameID(self.jar));NSDictionary *profile=GameProfile(self.jar);
        fprintf(stderr,"[i2ME] Starting JVM for %s\n",[self.jar.lastPathComponent UTF8String]);
        int result=jvm_bridge_init([root fileSystemRepresentation],[save fileSystemRepresentation],[self.jar fileSystemRepresentation],[[profile objectForKey:@"width"] intValue],[[profile objectForKey:@"height"] intValue],1,[[profile objectForKey:@"fps"] intValue]);
        if(!result) result=jvm_bridge_run_midlet([self.jar fileSystemRepresentation]);
        jvm_bridge_destroy();
        dispatch_async(dispatch_get_main_queue(),^{
            running=NO; [clock invalidate];clock=nil;activeGame=nil;
            pthread_mutex_lock(&frameLock);if(nextFrame)CGImageRelease(nextFrame);nextFrame=NULL;pthread_mutex_unlock(&frameLock);
            UINavigationController *navigation=self.navigationController;
            [navigation popViewControllerAnimated:!saveRequested];
            if(saveRequested){SaveController *saves=[SaveController new];saves.identifier=GameID(self.jar);[navigation pushViewController:saves animated:YES];}
            if(result) [[[UIAlertView alloc] initWithTitle:L(@"launchError") message:[NSString stringWithFormat:@"%@ %d",L(@"errorCode"),result] delegate:nil cancelButtonTitle:L(@"ok") otherButtonTitles:nil] show];
        });
    }
}
- (void)updateFrame {
    pthread_mutex_lock(&frameLock);CGImageRef frame=nextFrame;nextFrame=NULL;pthread_mutex_unlock(&frameLock);
    if(frame){screen.image=[UIImage imageWithCGImage:frame];CGImageRelease(frame);}
}
- (void)stopGame { if(running) {self.title=L(@"stopping");self.navigationItem.leftBarButtonItem.enabled=NO;self.navigationItem.rightBarButtonItem.enabled=NO;jvm_bridge_request_stop();} }
- (void)backupAndStop {saveRequested=YES;[self stopGame];}
- (void)keyDown:(UIButton *)b { j2me_input_post_key(J2ME_INPUT_KEY_PRESSED,(int)b.tag); }
- (void)keyUp:(UIButton *)b { j2me_input_post_key(J2ME_INPUT_KEY_RELEASED,(int)b.tag); }
- (void)command:(UIButton *)b {j2me_input_post_key(J2ME_UI_COMMAND_ACTION,(int)b.tag);}
- (void)selectItem:(UIButton *)b {j2me_input_post_key(J2ME_UI_LIST_SELECT,(int)b.tag);}
- (void)showPayload:(NSDictionary *)payload {
    int action=[[payload objectForKey:@"action"] intValue];form.hidden=(action==J2ME_UI_ACTION_SHOW_CANVAS);
    if(form.hidden)return;
    for(UIView *child in [form.subviews copy]) [child removeFromSuperview];
    CGFloat y=8,w=form.bounds.size.width;
    UILabel *title=[[UILabel alloc] initWithFrame:CGRectMake(8,y,w-16,30)];title.text=[payload objectForKey:@"title"];title.font=[UIFont boldSystemFontOfSize:17];[form addSubview:title];y+=34;
    int index=0;
    for(NSString *item in [payload objectForKey:@"items"]) {
        if(action==J2ME_UI_ACTION_SHOW_LIST){UIButton *b=[UIButton buttonWithType:UIButtonTypeRoundedRect];b.frame=CGRectMake(8,y,w-16,35);b.tag=index++;[b setTitle:item forState:0];[b addTarget:self action:@selector(selectItem:) forControlEvents:UIControlEventTouchUpInside];[form addSubview:b];y+=39;}
        else {UILabel *l=[[UILabel alloc] initWithFrame:CGRectMake(8,y,w-16,58)];l.text=item;l.numberOfLines=0;l.font=[UIFont systemFontOfSize:14];[form addSubview:l];y+=62;}
    }
    for(NSDictionary *command in [payload objectForKey:@"commands"]){UIButton *b=[UIButton buttonWithType:UIButtonTypeRoundedRect];b.frame=CGRectMake(8,y,w-16,32);b.tag=[[command objectForKey:@"id"] intValue];[b setTitle:[command objectForKey:@"name"] forState:0];[b addTarget:self action:@selector(command:) forControlEvents:UIControlEventTouchUpInside];[form addSubview:b];y+=36;}
    form.contentSize=CGSizeMake(w,y+8);
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {return orientation==UIInterfaceOrientationPortrait;}
@end

@interface LibraryController : UITableViewController <UIAlertViewDelegate>
@property(nonatomic,strong) NSArray *games;
@property(nonatomic,copy) NSString *pendingDelete;
- (void)refresh;
@end
@implementation LibraryController
- (void)viewDidLoad { [super viewDidLoad];self.title=@"i2ME";self.tableView.rowHeight=60;self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refresh)]; }
- (void)viewWillAppear:(BOOL)animated {[super viewWillAppear:animated];[self refresh];}
- (void)refresh {
    self.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc]initWithTitle:L(@"settings") style:UIBarButtonItemStylePlain target:self action:@selector(settings)];
    NSMutableArray *files=[NSMutableArray array];
    for(NSString *name in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:documents() error:nil]) if([[[name pathExtension] lowercaseString] isEqualToString:@"jar"]) [files addObject:name];
    self.games=[files sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];[self.tableView reloadData];
}
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {return MAX(1,self.games.count);}
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)index {
    GameCell *cell=(GameCell *)[table dequeueReusableCellWithIdentifier:@"jar"];if(!cell)cell=[[GameCell alloc] initWithStyle:0 reuseIdentifier:@"jar"];
    if(self.games.count){NSString *path=[documents() stringByAppendingPathComponent:[self.games objectAtIndex:index.row]];NSDictionary *p=GameProfile(path);cell.nameLabel.text=[p objectForKey:@"name"];cell.detailLabel.text=[NSString stringWithFormat:@"%@ × %@ • MIDP 2.0",[p objectForKey:@"width"],[p objectForKey:@"height"]];cell.gameIcon.image=GameIcon(path);
        __weak LibraryController *owner=self;cell.onEdit=^{[owner edit:path];};cell.onDelete=^{owner.pendingDelete=path;[[[UIAlertView alloc]initWithTitle:L(@"deleteGame") message:L(@"deleteHint") delegate:owner cancelButtonTitle:L(@"cancel") otherButtonTitles:L(@"delete"),nil]show];};
    }else{cell.nameLabel.text=L(@"addJar");cell.detailLabel.text=L(@"importHint");cell.gameIcon.image=nil;cell.onEdit=nil;cell.onDelete=nil;}return cell;
}
- (void)settings{[self.navigationController pushViewController:[SettingsController new] animated:YES];}
- (void)edit:(NSString *)path{ProfileController *editor=[ProfileController new];editor.path=path;[self.navigationController pushViewController:editor animated:YES];}
- (void)launch:(NSString *)path{GameController *game=[GameController new];game.jar=path;[self.navigationController pushViewController:game animated:YES];}
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)index {
    [table deselectRowAtIndexPath:index animated:YES];if(!self.games.count)return;GameCell *cell=(GameCell *)[table cellForRowAtIndexPath:index];if(cell.body.transform.tx){[cell closeActions];return;}
    NSString *path=[documents() stringByAppendingPathComponent:[self.games objectAtIndex:index.row]];
    if(![[GameProfile(path) objectForKey:@"configured"] boolValue]){ProfileController *editor=[ProfileController new];editor.path=path;editor.firstLaunch=YES;__weak LibraryController *owner=self;editor.finished=^(NSDictionary *profile){[owner launch:path];};[self.navigationController pushViewController:editor animated:YES];}else [self launch:path];
}
- (void)alertView:(UIAlertView *)alert clickedButtonAtIndex:(NSInteger)index{if(index==alert.cancelButtonIndex)return;NSError *error=nil;[[NSFileManager defaultManager] removeItemAtPath:self.pendingDelete error:&error];self.pendingDelete=nil;if(error)[[[UIAlertView alloc]initWithTitle:L(@"error") message:error.localizedDescription delegate:nil cancelButtonTitle:L(@"ok") otherButtonTitles:nil]show];[self refresh];}
@end
@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@property(nonatomic,strong) LibraryController *library;
@end
@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.library=[LibraryController new];self.window=[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController=[[UINavigationController alloc] initWithRootViewController:self.library];[self.window makeKeyAndVisible];
    NSString *sample=[[NSBundle mainBundle] pathForResource:@"Demo" ofType:@"jar"],*dest=[documents() stringByAppendingPathComponent:@"LegacyDemo.jar"];
    if(sample&&![[NSFileManager defaultManager] fileExistsAtPath:dest])[[NSFileManager defaultManager] copyItemAtPath:sample toPath:dest error:nil];
    [self.library refresh];
    if([[[NSProcessInfo processInfo] arguments] containsObject:@"--demo"]){
        dispatch_async(dispatch_get_main_queue(),^{GameController *game=[GameController new];game.jar=dest;[self.library.navigationController pushViewController:game animated:NO];});
    }
    NSArray *args=[[NSProcessInfo processInfo] arguments];NSUInteger jarIndex=[args indexOfObject:@"--jar"];
    if(jarIndex!=NSNotFound&&jarIndex+1<args.count){NSString *path=[documents() stringByAppendingPathComponent:[[args objectAtIndex:jarIndex+1] lastPathComponent]];dispatch_async(dispatch_get_main_queue(),^{[self.library launch:path];});}
    return YES;
}
- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url sourceApplication:(NSString *)source annotation:(id)annotation {
    if(!url.isFileURL||![[[url pathExtension] lowercaseString] isEqualToString:@"jar"])return NO;
    NSString *base=[[url lastPathComponent] stringByDeletingPathExtension],*dest=[documents() stringByAppendingPathComponent:[url lastPathComponent]];int count=1;
    while([[NSFileManager defaultManager] fileExistsAtPath:dest])dest=[documents() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%d.jar",base,count++]];
    NSError *error=nil;BOOL copied=[[NSFileManager defaultManager] copyItemAtPath:url.path toPath:dest error:&error];[self.library refresh];return copied;
}
@end
int main(int argc,char **argv){@autoreleasepool{
    NSString *path=[documents() stringByAppendingPathComponent:@"i2me.log"];
    freopen([path fileSystemRepresentation],"w",stdout);
    dup2(fileno(stdout),fileno(stderr));
    setvbuf(stdout,NULL,_IONBF,0);setvbuf(stderr,NULL,_IONBF,0);
    fprintf(stderr,"[i2ME diagnostic] iOS %s, model %s, pointer bits %lu\n",[[UIDevice currentDevice].systemVersion UTF8String],[[UIDevice currentDevice].model UTF8String],(unsigned long)(sizeof(void*)*8));
    return UIApplicationMain(argc,argv,nil,@"AppDelegate");
}}
