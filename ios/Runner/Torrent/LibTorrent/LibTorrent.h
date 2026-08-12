//
//  LibTorrent.h
//  LibTorrent
//
//  Created by Daniil Vinogradov on 23/10/2023.
//

#import <Foundation/Foundation.h>

//! Project version number for LibTorrent.
FOUNDATION_EXPORT double LibTorrentVersionNumber;

//! Project version string for LibTorrent.
FOUNDATION_EXPORT const unsigned char LibTorrentVersionString[];

#import "Core/Session/Session.h"
#import "Core/FileEntry/FileEntry.h"
#import "Core/FileEntry/FilePriority.h"
#import "Core/TorrentTracker/TorrentTracker.h"
#import "Core/TorrentHandleSnapshot/TorrentHandleSnapshot.h"
#import "Core/TorrentHandle/TorrentHandle.h"
#import "Core/TorrentHandle/TorrentHandleState.h"
#import "Core/TorrentFile/Downloadable/Downloadable.h"
#import "Core/TorrentFile/File/TorrentFile.h"
#import "Core/TorrentFile/Magnet/MagnetURI.h"
#import "Utils/NSData+Hex.h"
#import "Utils/ExceptionCatcher.h"
#import "Utils/LibTorrentVersion.h"


