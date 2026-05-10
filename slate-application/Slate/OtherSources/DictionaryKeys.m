//
//  DictionaryKeys.m
//  Slate
//
//  Created by Jerry Hale on 3/20/26
//  Copyright (c) 2026 Jerry Hale All rights reserved.

#import "DictionaryKeys.h"

//	keys in package.json
NSString* const KEY_PACKAGE = @"package";

NSString* const KEY_AVASSETS = @"avAssets";

//	in 'avAssets'
NSString* const KEY_VIDEOWIDTH = @"videoWidth";
NSString* const KEY_VIDEOHEIGHT = @"videoHeight";
NSString* const KEY_FRAMERATE = @"frameRate";
NSString* const KEY_FILENAME = @"fileName";
NSString* const KEY_ASSETTYPEID = @"assetTypeID";
NSString* const KEY_AUDIOTRACKS = @"audioTracks";

//	in 'audioTracks'
NSString* const KEY_TRACKNAME = @"trackName";
NSString* const KEY_TRACKLANGUAGE = @"trackLanguage";
NSString* const KEY_CHANNELLAYOUT = @"channelLayout";

NSString* const KEY_CHANNELNUMBER = @"channelNumber";
NSString* const KEY_CHANNELASSIGN = @"channelAssignment";


//	in 'package'
NSString* const KEY_ID = @"id";                         //  there is only one ID Key constant

NSString* const KEY_TYPE = @"type";
NSString* const KEY_CLIENT = @"client";
NSString* const KEY_VENDORID = @"vendor_id";
NSString* const KEY_ISAN = @"isan";
NSString* const KEY_PRODCOMPANY = @"productionCompany";
NSString* const KEY_COPYRIGHT = @"copyright";
NSString* const KEY_COUNTRY = @"country";
NSString* const KEY_ORIGINALSPOKENLANG = @"originalSpokenLanguage";

NSString* const KEY_CLIENTGENRES = @"clientGenres";

//	in 'clientGenres'
NSString* const KEY_GENRE = @"genre";                   //  there is only one genre Key constant


NSString* const KEY_PLATFORMDATA = @"platformData";

//	in 'platformData'
NSString* const KEY_PLATFORMID = @"platformID";
NSString* const KEY_PLATFORMPROJNUM = @"platformProjectNumber";
NSString* const KEY_CHAPTERTIMECODEFMT = @"chapterTimecodeFormat";
NSString* const KEY_GENRES = @"genres";


NSString* const KEY_CHAPTERASSETS = @"chapterAssets";

//	in 'chapterAssets'
NSString* const KEY_IMAGEFILEPATH = @"imageFilePath";

NSString* const KEY_CROPLEFT = @"cropLeft";             //  there is only one set of Crop Keys constants
NSString* const KEY_CROPTOP = @"cropTop";
NSString* const KEY_CROPRIGHT = @"cropRight";
NSString* const KEY_CROPBTM = @"cropBtm";


NSString* const KEY_LOCALES = @"locales";

//	in 'locales'
NSString* const KEY_NAME = @"name";

NSString* const KEY_SHORTSYNOPSIS = @"shortSynopsis";
NSString* const KEY_LONGSYNOPSIS = @"longSynopsis";
NSString* const KEY_THEATRICALRELDATE = @"theatricalReleaseDate";
NSString* const KEY_RATINGSYSTEM = @"ratingSystem";
NSString* const KEY_RATING = @"rating";

NSString* const KEY_POSTERART = @"posterArt";
NSString* const KEY_POSTERARTTERRITORY = @"posterArtTerritory";

NSString* const KEY_CAST = @"cast";
NSString* const KEY_CREW = @"crew";

//	in 'cast' and 'crew'
NSString* const KEY_PREFIX = @"prefix";
NSString* const KEY_FIRSTNAME = @"firstName";
NSString* const KEY_MIDDLENAME = @"middleName";
NSString* const KEY_LASTNAME = @"lastName";
NSString* const KEY_SUFFIX = @"suffix";

//	in 'cast'
NSString* const KEY_CHARACTER = @"character";

//	in 'crew'
NSString* const KEY_CREDIT = @"credit";


NSString* const KEY_CHAPTITLES = @"chapterTitles";

//	in 'chapterTitles'
NSString* const KEY_CHAPTITLE = @"chapterTitle";
NSString* const KEY_ABS_CHAPSMPTE = @"chapterTimecode";
NSString* const KEY_ABS_IMGSMPTE = @"imageTimecode";

NSString* const KEY_MEDIA_CHAPSMPTE = @"mediaChapterTimecode";
NSString* const KEY_MEDIA_IMGSMPTE = @"mediaImageTimecode";

NSString* const KEY_CHAPTIME = @"chapterTimeValue";
NSString* const KEY_IMAGETIME = @"imageTimeValue";

//	--------------------------------------------

//  keys not in package json

NSString* const KEY_BASE_URL = @"BASE_URL";
NSString* const KEY_FILTER_DIR_LIST = @"FILTER_DIR_LIST";
NSString* const KEY_MOD_DATE = @"moddate";

NSString* const KEY_CROP = @"CROP";
NSString* const KEY_ISVALIDIMG = @"ISVALIDIMG";

NSString* const KEY_IMAGE_OFFSET = @"IMAGE_OFFSET";

NSString* const KEY_CHAPTER_COUNT = @"CHAPTER_COUNT";
NSString* const KEY_CHAPTER_LEADIN = @"CHAPTER_LEADIN";
NSString* const KEY_CHAPTER_LEADOUT = @"CHAPTER_LEADOUT";
NSString* const KEY_CONN_PING_INTERVAL = @"CONN_PING_INTERVAL";
NSString* const KEY_ASSET_TYPE = @"ASSET_TYPE";


NSString* const ZOOM_TO_CORNER = @"ZOOMTOCORNER";
NSString* const LAYER_BACK_COLOR = @"LAYERBACKCOLOR";
NSString* const BOTTOM_PANE = @"BOTTOMPANE";

NSString* const REFRESH_CROP_VALUES = @"REFRESHCROPVALUES";


// Media Type
NSString *const MP42MediaTypeVideo = @"Video Track";
NSString *const MP42MediaTypeAudio = @"Sound Track";
NSString *const MP42MediaTypeText = @"Text Track";
NSString *const MP42MediaTypeClosedCaption = @"Closed Caption Track";
NSString *const MP42MediaTypeSubtitle = @"Subtitle Track";
NSString *const MP42MediaTypeTimecode = @"TimeCode Track";

NSString *const MP42VideoFormatProRes_422HQ = @"Apple ProRes 422 (HQ)";
NSString *const MP42VideoFormatProRes_422SD = @"Apple ProRes 422 (SD)";
NSString *const MP42VideoFormatProRes_422LT = @"Apple ProRes 422 (LT)";
NSString *const MP42VideoFormatProRes_422PR = @"Apple ProRes 422 Proxy";
NSString *const MP42VideoFormatProRes_4444 = @"Apple ProRes 4444";
