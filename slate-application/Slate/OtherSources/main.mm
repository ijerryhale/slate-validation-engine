//
//  main.mm
//  Slate
//
//  Created by Jerry Hale on 3/20/26
//  Copyright (c) 2026 Jerry Hale All rights reserved.


#import "DictionaryKeys.h"

int main(int argc, char *argv[])
{
    //  create plist file from chameleon ratings table
    #if 0
        NSString *strBundle = [[NSBundle mainBundle] pathForResource:@"rating" ofType:@"strings"];
        NSString *fileObj = [NSString stringWithContentsOfFile:strBundle
                                                      encoding:NSUnicodeStringEncoding
                                                         error:nil];
        NSArray *objectArray = [fileObj componentsSeparatedByString:@"\n"];
        NSLog(@"%@", objectArray);
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory , NSUserDomainMask, YES);
        NSString *documentsDir = [paths objectAtIndex:0];
        
        [objectArray writeToFile:[documentsDir stringByAppendingPathComponent:@"rating.plist"] atomically:YES];
    #else
        return NSApplicationMain(argc, (const char **) argv);
    #endif

}
