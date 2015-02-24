#import "BitPacker.h"
#import "FrameDataBinaryEncoder.h"
#import "HexConverter.h"
#import "NibbleBitReverser.h"
#import "NibbleSwitcher.h"
#import "HexByteBinaryEncoder.h"
#import "CodingTable.h"
#import "BitHelpers.h"

@implementation BitPacker

+(NSString *)pack:(NSArray *)frameData {
    NSArray *binary   = [FrameDataBinaryEncoder process:frameData];
    NSArray *hex      = [HexConverter process:binary];
    NSArray *reversed = [NibbleBitReverser process:hex];
    NSArray *switched = [NibbleSwitcher process:reversed];
    
    return [switched componentsJoinedByString:@","];
}

+(NSArray *)unpack:(NSString *)packedData options:(NSDictionary *)options {
    NSArray *bytes    = [packedData componentsSeparatedByString:@","];
    NSArray *switched = [NibbleSwitcher process:bytes];
    NSArray *reversed = [NibbleBitReverser process:switched];
    NSString *binary  = [[HexByteBinaryEncoder process:reversed] componentsJoinedByString:@""];
    return [self frameDataFor:binary];
}

+(NSArray *)frameDataFor:(NSString *)binary {
    NSMutableArray *frames = [NSMutableArray arrayWithCapacity:[binary length]];
    
    __block NSString *binaryString = binary;
    while ([binaryString length]) {
        NSMutableDictionary *frame = [NSMutableDictionary dictionaryWithCapacity:13];
        [[CodingTable parameters] enumerateObjectsUsingBlock:^(NSString *parameter, NSUInteger idx, BOOL *stop) {
            NSUInteger bits = [[[CodingTable bits] objectAtIndex:idx] integerValue];
            NSUInteger length = [binary length];
            NSUInteger shift  = length < bits ? (bits - length) : 0;
            NSUInteger value  = [BitHelpers valueForBinary:[binaryString substringToIndex:bits]] << shift;
            binaryString = [binaryString substringFromIndex:bits];
            
            [frame setObject:[NSNumber numberWithUnsignedInteger:value] forKey:parameter];
            
            if ([self frameHasNoGain:frame] ||
                [self frameIsUnvoiced:frame] ||
                [self frameIsRepeated:frame]) *stop = YES;
        }];

        [frames addObject:frame];
    }
    return frames;
}

+(BOOL)frameHasNoGain:(NSDictionary *)frame {
    return ![[frame objectForKey:kParameterGain] unsignedIntegerValue];
}

+(BOOL)frameIsUnvoiced:(NSDictionary *)frame {
    return ![[frame objectForKey:kParameterPitch] unsignedIntegerValue] &&
            [self frameHasExactKeys:[self unvoicedKeys] frame:frame];
}

+(BOOL)frameIsRepeated:(NSDictionary *)frame {
    return [[frame objectForKey:kParameterRepeat] unsignedIntegerValue] == 1 &&
            [self frameHasExactKeys:[self repeatKeys] frame:frame];
}

+(BOOL)frameHasExactKeys:(NSArray *)keys frame:(NSDictionary *)frame {
    NSArray *allKeys = [frame allKeys];
    if ([keys count] != [allKeys count]) return NO;
    
    for (NSString *key in allKeys) {
        if (![keys containsObject:key]) return NO;
    }
    return YES;
}

+(NSArray *)unvoicedKeys {
    static NSArray *_unvoicedKeys;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _unvoicedKeys = @[kParameterGain,
                          kParameterRepeat,
                          kParameterPitch,
                          kParameterK1,
                          kParameterK2,
                          kParameterK3,
                          kParameterK4];
    });
    return _unvoicedKeys;
}

+(NSArray *)repeatKeys {
    static NSArray *_repeatKeys;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _repeatKeys = @[kParameterGain,
                        kParameterRepeat,
                        kParameterPitch];
    });
    return _repeatKeys;
}

@end