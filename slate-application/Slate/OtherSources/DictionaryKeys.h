//
//  DictionaryKeys.h
//  Slate
//
//  Created by Jerry Hale on 5/3/26.
//  Copyright (c) 2026 Jerry Hale. All rights reserved.
//
//  Proprietary and confidential.
//  This file is part of Slate and is not open source software.
//
//  No license is granted to copy, modify, distribute, sublicense, or use this
//  source code except under a written agreement with the copyright holder.
//  Unauthorized use, disclosure, reproduction, or distribution is prohibited.
//

#import <Foundation/Foundation.h>

extern NSString* const KEY_PACKAGE;

extern NSString* const KEY_AVASSETS;

//	in 'avAssets'
extern NSString* const KEY_VIDEOWIDTH;
extern NSString* const KEY_VIDEOHEIGHT;
extern NSString* const KEY_FRAMERATE;
extern NSString* const KEY_FILENAME;
extern NSString* const KEY_ASSETTYPEID;
extern NSString* const KEY_AUDIOTRACKS;

//	in 'audioTracks'
extern NSString* const KEY_TRACKNAME;
extern NSString* const KEY_TRACKLANGUAGE;
extern NSString* const KEY_CHANNELLAYOUT;

extern NSString* const KEY_CHANNELNUMBER;
extern NSString* const KEY_CHANNELASSIGN;


//	in 'package'
extern NSString* const KEY_ID;                     //  there is only one ID key constant
extern NSString* const KEY_TYPE;
extern NSString* const KEY_CLIENT;
extern NSString* const KEY_VENDORID;
extern NSString* const KEY_ISAN;
extern NSString* const KEY_PRODCOMPANY;
extern NSString* const KEY_COPYRIGHT;
extern NSString* const KEY_COUNTRY;
extern NSString* const KEY_ORIGINALSPOKENLANG;
//  extern NSString* const KEY_PREVIEWFILE;
//  extern NSString* const KEY_PREVIEWTERRITORY;

extern NSString* const KEY_CLIENTGENRES;

extern NSString* const KEY_GENRE;               //  there is only one genre Key constant


extern NSString* const KEY_PLATFORMDATA;

//	in 'platformData'
extern NSString* const KEY_PLATFORMID;
extern NSString* const KEY_PLATFORMPROJNUM;
extern NSString* const KEY_CHAPTERTIMECODEFMT;
extern NSString* const KEY_GENRES;

extern NSString* const KEY_CHAPTERASSETS;

//	in 'chapterAssets'
extern NSString* const KEY_IMAGEFILEPATH;

extern NSString* const KEY_CROPLEFT;
extern NSString* const KEY_CROPTOP;
extern NSString* const KEY_CROPRIGHT;
extern NSString* const KEY_CROPBTM;


extern NSString* const KEY_ABS_CHAPSMPTE;   //  absolute time is calculated
extern NSString* const KEY_ABS_IMGSMPTE;    //  from media time

extern NSString* const KEY_MEDIA_CHAPSMPTE;
extern NSString* const KEY_MEDIA_IMGSMPTE;

extern NSString* const KEY_CHAPTIME;
extern NSString* const KEY_IMAGETIME;

extern NSString* const KEY_LOCALES;

//	in 'locales'
extern NSString* const KEY_NAME;
extern NSString* const KEY_SHORTSYNOPSIS;
extern NSString* const KEY_LONGSYNOPSIS;
extern NSString* const KEY_THEATRICALRELDATE;
extern NSString* const KEY_RATINGSYSTEM;
extern NSString* const KEY_RATING;


extern NSString* const KEY_POSTERART;
extern NSString* const KEY_POSTERARTTERRITORY;

extern NSString* const KEY_CAST;
extern NSString* const KEY_CREW;

//	in 'cast' and 'crew'
extern NSString* const KEY_PREFIX;
extern NSString* const KEY_FIRSTNAME;
extern NSString* const KEY_MIDDLENAME;
extern NSString* const KEY_LASTNAME;
extern NSString* const KEY_SUFFIX;

//	in 'cast'
extern NSString* const KEY_CHARACTER;

//	in 'crew'
extern NSString* const KEY_CREDIT;

extern NSString* const KEY_CHAPTITLES;

//	in 'chapterTitles'
extern NSString* const KEY_CHAPTITLE;

//	--------------------------------------------

extern NSString* const KEY_BASE_URL;
extern NSString* const KEY_FILTER_DIR_LIST;
extern NSString* const KEY_MOD_DATE;
extern NSString* const KEY_CHAPTER_COUNT;
extern NSString* const KEY_CROP;
extern NSString* const KEY_ISVALIDIMG;

extern NSString* const KEY_IMAGE_OFFSET;
extern NSString* const KEY_CHAPTER_LEADIN;
extern NSString* const KEY_CHAPTER_LEADOUT;
extern NSString* const KEY_CONN_PING_INTERVAL;
extern NSString* const KEY_ASSET_TYPE;

extern NSString* const ZOOM_TO_CORNER;
extern NSString* const LAYER_BACK_COLOR;
extern NSString* const BOTTOM_PANE;

extern NSString* const REFRESH_CROP_VALUES;

// Media Type
extern NSString *const MP42MediaTypeVideo;
extern NSString *const MP42MediaTypeAudio;
extern NSString *const MP42MediaTypeText;
extern NSString *const MP42MediaTypeClosedCaption;
extern NSString *const MP42MediaTypeSubtitle;
extern NSString *const MP42MediaTypeTimecode;

extern NSString *const MP42VideoFormatProRes_422HQ;
extern NSString *const MP42VideoFormatProRes_422SD;
extern NSString *const MP42VideoFormatProRes_422LT;
extern NSString *const MP42VideoFormatProRes_422PR;
extern NSString *const MP42VideoFormatProRes_4444;
