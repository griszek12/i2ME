#import "LegacyMIDIPlayer.h"
#import <TargetConditionals.h>
@implementation LegacyMIDIPlayer
- (id)initWithData:(NSData *)data soundBankURL:(NSURL *)url error:(NSError **)error {
    if (!(self = [super init])) return nil;
#if TARGET_IPHONE_SIMULATOR
    // The legacy simulator can crash inside AudioToolbox when the VM has no audio device.
    fprintf(stderr, "[Legacy MIDI] Simulator playback muted (virtual machine audio unavailable)\n");
    return self;
#endif
    OSStatus status = NewMusicSequence(&sequence);
    if (!status) status = MusicSequenceFileLoadData(sequence, (__bridge CFDataRef)data, kMusicSequenceFile_MIDIType, kMusicSequenceLoadSMF_ChannelsToTracks);
    AUNode synthNode, outputNode;
    AudioUnit synth;
    AudioComponentDescription description = {kAudioUnitType_MusicDevice,kAudioUnitSubType_Sampler,kAudioUnitManufacturer_Apple,0,0};
    if (!status) status = NewAUGraph(&graph);
    if (!status) status = AUGraphAddNode(graph, &description, &synthNode);
    description.componentType = kAudioUnitType_Output;
    description.componentSubType = kAudioUnitSubType_RemoteIO;
    if (!status) status = AUGraphAddNode(graph, &description, &outputNode);
    if (!status) status = AUGraphOpen(graph);
    if (!status) status = AUGraphConnectNodeInput(graph,synthNode,0,outputNode,0);
    if (!status) status = AUGraphNodeInfo(graph,synthNode,NULL,&synth);
    if (!status && url) {
        AUSamplerInstrumentData instrument = {(__bridge CFURLRef)url,kInstrumentType_SF2Preset,kAUSampler_DefaultMelodicBankMSB,kAUSampler_DefaultBankLSB,0};
        status = AudioUnitSetProperty(synth,kAUSamplerProperty_LoadInstrument,kAudioUnitScope_Global,0,&instrument,sizeof(instrument));
    }
    if (!status) status = AUGraphInitialize(graph);
    if (!status) status = MusicSequenceSetAUGraph(sequence,graph);
    UInt32 count = 0;
    if (!status) status = MusicSequenceGetTrackCount(sequence,&count);
    for (UInt32 i = 0; !status && i < count; i++) {
        MusicTrack track;
        status = MusicSequenceGetIndTrack(sequence,i,&track);
        if (!status) status = MusicTrackSetDestNode(track,synthNode);
    }
    if (!status) status = NewMusicPlayer(&player);
    if (!status) status = MusicPlayerSetSequence(player,sequence);
    if (status) {
        if (error) *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        return nil;
    }
    return self;
}
- (void)prepareToPlay { if (player) MusicPlayerPreroll(player); }
- (void)play:(void (^)(void))completion { if (graph) AUGraphStart(graph); if (player) MusicPlayerStart(player); }
- (void)stop { if (player) MusicPlayerStop(player); if (graph) AUGraphStop(graph); }
- (void)dealloc {
    [self stop];
    if (player) DisposeMusicPlayer(player);
    if (sequence) DisposeMusicSequence(sequence);
    if (graph) DisposeAUGraph(graph);
}
@end
