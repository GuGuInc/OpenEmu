/*
 Copyright (c) 2011, OpenEmu Team
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
     * Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.
     * Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in the
       documentation and/or other materials provided with the distribution.
     * Neither the name of the OpenEmu Team nor the
       names of its contributors may be used to endorse or promote products
       derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
 EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "OEDBImage.h"
#import "OELibraryDatabase.h"

#import "OEDBImage.h"
#import "OELibraryDatabase.h"

@interface OEDBImage ()
@end
#pragma mark -
@implementation OEDBImage
@dynamic source, width, height, format, Box, relativePath;

+ (instancetype)createImageWithNSImage:(NSImage*)image
{
    return [self createImageWithNSImage:image type:OEBitmapImageFileTypeDefault];
}

+ (instancetype)createImageWithNSImage:(NSImage*)image type:(OEBitmapImageFileType)type
{
    OECoreDataMainThreadAssertion();

    NSManagedObjectContext *context = [[OELibraryDatabase defaultDatabase] mainThreadContext];
    return [self createImageWithNSImage:image type:type inContext:context];
}

+ (instancetype)createImageWithNSImage:(NSImage*)nsimage type:(OEBitmapImageFileType)type inContext:(NSManagedObjectContext *)context
{
    const NSSize size = [nsimage size];
    OEDBImage *image = [OEDBImage createObjectInContext:context];
    NSBitmapImageFileType format;
    NSURL *fileUrl = [image OE_writeImage:nsimage withType:type usedFormat:&format inContext:context];
    if(fileUrl != nil)
    {
        [image setWidth:size.width];
        [image setHeight:size.height];
        [image setRelativePath:[fileUrl relativeString]];
        [image setFormat:format];

        [image save];
        return image;
    }
    else
    {
        [image setBox:nil];
        [image delete];
        [image save];

        return nil;
    }
}

+ (instancetype)createImageWithURL:(NSURL*)url
{
    return [self createImageWithURL:url type:OEBitmapImageFileTypeDefault];
}

+ (instancetype)createImageWithURL:(NSURL*)url type:(OEBitmapImageFileType)type
{
    OECoreDataMainThreadAssertion();

    NSManagedObjectContext *context = [[OELibraryDatabase defaultDatabase] mainThreadContext];
    return [self createImageWithURL:url type:type inContext:context];
}

+ (instancetype)createImageWithURL:(NSURL*)url type:(OEBitmapImageFileType)type inContext:(NSManagedObjectContext *)context
{
    OEDBImage *image = [OEDBImage createObjectInContext:context];
    NSSize size = NSZeroSize;
    NSBitmapImageFileType format;
    NSURL *fileUrl = [image OE_writeURL:url withType:type usedFormat:&format outSize:&size inContext:context];

    if(fileUrl != nil)
    {
        [image setWidth:size.width];
        [image setHeight:size.height];
        [image setRelativePath:[fileUrl relativeString]];
        [image setSourceURL:url];
        [image setFormat:format];
        // [image save];

        return image;
    }
    else
    {

        [image setBox:nil];
        [image delete];
        // [image save];
        return nil;
    }
}

+ (instancetype)createImageWithData:(NSData*)data
{
    return [self createImageWithData:data type:OEBitmapImageFileTypeDefault];
}
+ (instancetype)createImageWithData:(NSData*)data type:(OEBitmapImageFileType)type
{
    OECoreDataMainThreadAssertion();

    NSManagedObjectContext *context = [[OELibraryDatabase defaultDatabase] mainThreadContext];

    return [self createImageWithData:data type:type inContext:context];
}
+ (instancetype)createImageWithData:(NSData*)data type:(OEBitmapImageFileType)type inContext:(NSManagedObjectContext *)context
{
    OEDBImage *image = [OEDBImage createObjectInContext:context];
    NSSize size = NSZeroSize;
    NSBitmapImageFileType format;
    NSURL *fileUrl = [image OE_writeData:data withType:type usedFormat:&format outSize:&size inContext:context];
    if(fileUrl != nil)
    {
        [image setWidth:size.width];
        [image setHeight:size.height];
        [image setRelativePath:[fileUrl relativeString]];
        [image setFormat:format];
        [image save];

        return image;
    }
    else
    {
        [image setBox:nil];
        [image delete];
        [image save];

        return nil;
    }

    return image;
}

#pragma mark -
- (NSURL*)OE_writeImage:(NSImage*)image withType:(OEBitmapImageFileType)type usedFormat:(NSBitmapImageFileType*)usedFormat inContext:(NSManagedObjectContext*)context
{
    const NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *properties = [standardUserDefaults dictionaryForKey:OEGameArtworkPropertiesKey];

    return [self OE_writeImage:image withType:type usedFormat:usedFormat withProperties:properties inContext:context];
}

- (NSURL*)OE_writeImage:(NSImage*)image withType:(OEBitmapImageFileType)type usedFormat:(NSBitmapImageFileType*)usedFormat withProperties:(NSDictionary*)properties inContext:(NSManagedObjectContext*)context
{
    if(image == nil)
    {
        DLog(@"No image passed in, exiting…");
        return nil;
    }

    const NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    const NSSize         imageSize             = [image size];
    NSString *fileName = [NSString stringWithUUID];

    if(type == OEBitmapImageFileTypeDefault || type==OEBitmapImageFileTypeOriginal)
        type = [standardUserDefaults integerForKey:OEGameArtworkFormatKey];

    __block NSBitmapImageRep *imageRep = nil;
    __block NSInteger maxArea = 0;
    [[image representations] enumerateObjectsUsingBlock:^(NSImageRep *rep, NSUInteger idx, BOOL *stop)
     {
         if([rep isKindOfClass:[NSBitmapImageRep class]])
         {
             NSInteger area = [rep pixelsHigh]*[rep pixelsWide];
             if(area >= maxArea)
             {
                 imageRep = (NSBitmapImageRep*)rep;
                 maxArea = area;
             }
         }
     }];


    if(imageRep == nil)
    {
        DLog(@"No NSBitmapImageRep found, creating one...");
        [image lockFocus];
        imageRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:(NSRect){{0,0}, imageSize}];
        [image unlockFocus];
    }

    if(imageRep == nil)
    {
        DLog(@"Could not draw NSImage in NSBitmapimage rep, exiting…");
        return nil;
    }

    NSData *data = [imageRep representationUsingType:type properties:properties];

    // TODO: get database from context
    OELibraryDatabase *database = [OELibraryDatabase defaultDatabase];

    NSURL *coverFolderURL = [database coverFolderURL];
    NSURL *imageURL = [NSURL URLWithString:fileName relativeToURL:coverFolderURL];
    
    if(![data writeToURL:imageURL atomically:YES])
    {
        [[NSFileManager defaultManager] removeItemAtURL:imageURL error:nil];
        DLog(@"Failed to write image file! Exiting…");
        return nil;
    }

    if(usedFormat != NULL)
        *usedFormat = type;

    return imageURL;
}

- (NSURL*)OE_writeURL:(NSURL*)url withType:(OEBitmapImageFileType)type usedFormat:(NSBitmapImageFileType*)usedFormat outSize:(NSSize*)size inContext:(NSManagedObjectContext*)context
{
    NSData *data = [NSData dataWithContentsOfURL:url];
    return [self OE_writeData:data withType:type usedFormat:usedFormat outSize:size inContext:context];
}

- (NSURL*)OE_writeData:(NSData*)data withType:(OEBitmapImageFileType)type usedFormat:(NSBitmapImageFileType*)usedFormat outSize:(NSSize*)size inContext:(NSManagedObjectContext*)context
{
    NSImage *image = [[NSImage alloc] initWithData:data];
    if(size != NULL)
        *size = [image size];

    return [self OE_writeImage:image withType:type usedFormat:usedFormat inContext:context];
}

#pragma mark -
- (BOOL)convertToFormat:(OEBitmapImageFileType)format withProperties:(NSDictionary*)attributes
{
    NSManagedObjectContext *context = [self managedObjectContext];
    NSURL *newURL = [self OE_writeImage:[self image] withType:format usedFormat:NULL withProperties:attributes inContext:context];
    if(newURL == nil)
    {
        DLog(@"converting image failed!");
        return NO;
    }
    else
    {
        NSManagedObjectContext *context = [self managedObjectContext];
        [context performBlockAndWait:^{
            NSURL *url = [self imageURL];
            if(url != nil) [[NSFileManager defaultManager] removeItemAtURL:url error:nil];

            NSString *relativePath = [newURL relativeString];

            [self setFormat:format];
            [self setRelativePath:relativePath];
            [self save];
        }];
        return YES;
    }
}
#pragma mark - Core Data utilities
+ (NSString *)entityName
{
    return @"Image";
}

+ (NSEntityDescription *)entityDescriptionInContext:(NSManagedObjectContext *)context
{
    return [NSEntityDescription entityForName:[self entityName] inManagedObjectContext:context];
}

- (void)prepareForDeletion
{
    if([[self managedObjectContext] parentContext] == nil)
    {
        NSURL *url = [self imageURL];
        [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
    }
}

#pragma mark -
- (NSString*)UUID
{
    return [self relativePath];
}

- (NSImage *)image
{
    NSURL *imageURL = [self imageURL];
    NSImage  *image = [[NSImage alloc] initWithContentsOfURL:imageURL];
    return image;
}

- (NSURL *)imageURL
{
    const OELibraryDatabase *database = [self libraryDatabase];
    const NSURL *coverFolderURL = [database coverFolderURL];
    NSString    *relativePath   = [self relativePath];

    if(relativePath == nil) return nil;
    return [coverFolderURL URLByAppendingPathComponent:relativePath];
}

- (NSURL *)sourceURL
{
    NSString *source = [self source];
    if(source == nil) return nil;
    return [NSURL URLWithString:source];
}

- (void)setSourceURL:(NSURL *)sourceURL
{
    [self setSource:[sourceURL absoluteString]];
}

- (BOOL)isLocalImageAvailable
{
    return [[self imageURL] checkResourceIsReachableAndReturnError:nil];
}
@end