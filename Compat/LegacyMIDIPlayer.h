#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
@interface LegacyMIDIPlayer : NSObject {
    MusicSequence sequence;
    MusicPlayer player;
    AUGraph graph;
}
- (id)initWithData:(NSData *)data soundBankURL:(NSURL *)url error:(NSError **)error;
- (void)prepareToPlay;
- (void)play:(void (^)(void))completion;
- (void)stop;
@end
