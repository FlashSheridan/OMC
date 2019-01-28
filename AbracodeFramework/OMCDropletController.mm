//
//  OMCDropletController.m
//  CocoaApp
//
//  Created by Tomasz Kukielka on 4/17/08.
//  Copyright 2008 Abracode Inc. All rights reserved.
//

#import "OMCDropletController.h"
#import "OMCCommandExecutor.h"
#import "OMCWindow.h"
#include "DropletPreferences.h"
#include "CFObj.h"
#include "OMCFilePanels.h"
#include "OMC.h"
#import "OMCService.h"


extern CFStringRef kBundleIDString;
static OMCService *sOMCService = NULL;

@implementation OMCDropletController

- (id)init
{
//	NSLog( @"OMCDropletController init" );

	//not a problem in Xcode 4 anymore
	if( ![self respondsToSelector: @selector(ibPopulateKeyPaths:)] )//don't init NSDocumentController in IB
	{
		self = [super init];
		if(self == NULL)
			return NULL;
	}

	commandID = NULL;
	commandFilePath = @"Command.plist";
	[commandFilePath retain];
	_startingUp = YES;
	_startupModifiers = 0;
	_runningCommandCount = 0;
	
	NSAppleEventManager *eventManager = [NSAppleEventManager sharedAppleEventManager];
	[eventManager setEventHandler:self
					andSelector:@selector(handleGetURLEvent:withReplyEvent:)
					forEventClass:kInternetEventClass
					andEventID:kAEGetURL];

	return self;
}

- (void)dealloc
{
    [commandID release];
    [commandFilePath release];
	[super dealloc];
}

- (void)awakeFromNib
{
//	NSLog( @"OMCDropletController awakeFromNib " );

	_startupModifiers = 0;

	if( [self respondsToSelector: @selector(ibPopulateKeyPaths:)] )//running as plugin in IB?
		return;

	NSApplication *myApp = [NSApplication sharedApplication];
	if(myApp != NULL)
	{
		[myApp setDelegate:self];
		//NSEvent *currEvent = [myApp currentEvent];
		//if(currEvent)
		//	_startupModifiers = [currEvent modifierFlags];
	}

	NSBundle *appBundle = [NSBundle mainBundle];
	NSString *bunldeRefID = [appBundle bundleIdentifier];
	if(bunldeRefID == NULL)
		bunldeRefID = @"com.abracode.CommandDroplet";

	gPreferences = new DropletPreferences( (CFStringRef)bunldeRefID );
	gPreferences->Read();	


	CGEventRef eventRef = CGEventCreate(NULL /*default event source*/);
	if(eventRef != NULL)
	{
		_startupModifiers = CGEventGetFlags(eventRef);
		CFRelease(eventRef);
	}
}

- (NSArray *)URLsFromRunningOpenPanel
{
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	NSInteger result = [openPanel runModalForTypes:NULL /*(NSArray *)fileTypes*/];
	if(result == NSOKButton)
	{
		return [openPanel URLs];
	}
	return NULL;
}

//I assume the caller can handle NULL result and it is true in 10.5
-(id)openDocumentWithContentsOfURL:(NSURL *)absoluteURL display:(BOOL)displayDocument error:(NSError **)outError
{
	if(absoluteURL != NULL)
		[self noteNewRecentDocumentURL:absoluteURL];

	_runningCommandCount++;
	/*OSStatus err = */[OMCCommandExecutor runCommand:commandID forCommandFile:commandFilePath withContext:absoluteURL useNavDialog:YES delegate:self];
	_runningCommandCount--;
	return NULL;
}


-(void)openFiles:(NSArray *)absoluteURLArray
{
	if(absoluteURLArray == NULL)
		return;
	
	NSUInteger fileCount = [absoluteURLArray count];
	NSUInteger i;
	for( i = 0; i < fileCount; i++ )
	{
		id oneFileURL = [absoluteURLArray objectAtIndex:i];
		[self noteNewRecentDocumentURL:oneFileURL];
	}
	
	_runningCommandCount++;
	/*OSStatus err = */[OMCCommandExecutor runCommand:commandID forCommandFile:commandFilePath withContext:absoluteURLArray useNavDialog:YES delegate:self];
	_runningCommandCount--;
}


- (IBAction)newDocument:(id)sender
{
	_runningCommandCount++;
	/*OSStatus err = */[OMCCommandExecutor runCommand:commandID forCommandFile:commandFilePath withContext:NULL useNavDialog:YES delegate:self];
	_runningCommandCount--;
	
}

- (IBAction)openDocument:(id)sender
{
	_runningCommandCount++;
	/*OSStatus err = */[OMCCommandExecutor runCommand:commandID forCommandFile:commandFilePath withContext:NULL useNavDialog:YES delegate:self];
	_runningCommandCount--;
}


//- (id)makeUntitledDocumentOfType:(NSString *)typeName error:(NSError **)outError
//{
//	return NULL;
//}

- (BOOL)validateUserInterfaceItem:(id < NSValidatedUserInterfaceItem >)anItem
{
	SEL actonSel = [anItem action];

//check if default command is file-based and enable openDocument
//if not, enable newDocument

	NSString* selectorStr = NSStringFromSelector( actonSel );
	if( [selectorStr isEqualToString: @"newDocument:"] )
		return YES;

	if( [selectorStr isEqualToString: @"openDocument:"] )
		return YES;

/* 10.5-only
	if( sel_isEqual(actonSel, @selector(newDocument:)) )
		return YES;
	
	if( sel_isEqual(actonSel, @selector(openDocument:)) )
		return YES;
*/

//	const char* actionName = sel_getName(actonSel);
//	printf(actionName); printf("\n");
	return [super validateUserInterfaceItem:anItem];
}

- (void)showPrefsDialog:(id)sender
{
	NSString *commandName = @"DropletPreferences.plist";
	NSBundle *appBundle = [NSBundle mainBundle];
	NSString *commandPath = [appBundle pathForResource:commandName ofType:NULL];
	if(commandPath == NULL)
	{
		NSBundle *frameworkBundle = [NSBundle bundleWithIdentifier:(NSString *)kBundleIDString];
		commandPath = [frameworkBundle pathForResource:commandName ofType:NULL];
	}

	if(commandPath != NULL)
	{
		_runningCommandCount++;
		[OMCCommandExecutor runCommand:NULL forCommandFile:commandPath withContext:NULL useNavDialog:NO delegate:self];
		_runningCommandCount--;
	}
	else
		NSLog(@"Cannot find DropletPreferences.plist");

	if(gPreferences != NULL)
		gPreferences->Read();

#if _DEBUG_
	if( gPreferences != NULL )
	{
		NSLog(@"showNavDialogOnStartup=%d", (int)gPreferences->mPrefs.showNavDialogOnStartup);
		NSLog(@"quitAfterDropExecution=%d", (int)gPreferences->mPrefs.quitAfterDropExecution);
		NSLog(@"runCommandOnReopenEvent=%d", (int)gPreferences->mPrefs.runCommandOnReopenEvent);
	}
#endif
}

#pragma mark --- NSApplication delegate methods ---

- (void)application:(NSApplication *)sender openFiles:(NSArray *)filenames
{
	if( _startingUp && ((_startupModifiers & kCGEventFlagMaskAlternate) != 0) )
		return;
	
	NSUInteger fileCount = [filenames count];
	NSMutableArray *urlArray = [NSMutableArray arrayWithCapacity:fileCount];
	NSUInteger i;
	for( i = 0; i < fileCount; i++ )
	{
		id oneFileName = [filenames objectAtIndex:i];
		NSURL *fileURL = [NSURL fileURLWithPath:oneFileName];
		if(fileURL != NULL)
		{
			NSURL *absURL = [fileURL absoluteURL];
			if(absURL != NULL)
				[urlArray addObject:absURL];
		}
	}

	[self openFiles:urlArray];
	[sender replyToOpenOrPrint:NSApplicationDelegateReplySuccess];

	BOOL quitAfterDropExecution = NO;
	if(gPreferences != NULL)
		quitAfterDropExecution = (BOOL)gPreferences->mPrefs.quitAfterDropExecution;
	
	if(_startingUp && quitAfterDropExecution)
	{
		NSApplication *myApp = [NSApplication sharedApplication];
		if(myApp != NULL)
		{
			[myApp terminate:self];
		}
	}
}

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename
{
	if( _startingUp && ((_startupModifiers & kCGEventFlagMaskAlternate) != 0) )
		return FALSE;

	NSURL *fileURL = [NSURL fileURLWithPath:filename];
	NSError *error = NULL;
	[self openDocumentWithContentsOfURL:[fileURL absoluteURL] display:YES error:&error];

	BOOL quitAfterDropExecution = NO;
	if(gPreferences != NULL)
		quitAfterDropExecution = (BOOL)gPreferences->mPrefs.quitAfterDropExecution;
	
	if(_startingUp && quitAfterDropExecution)
	{
		NSApplication *myApp = [NSApplication sharedApplication];
		if(myApp != NULL)
		{
			[myApp terminate:self];
		}
	}

	return YES;
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)hasVisibleWindows
{
	if(_runningCommandCount > 0) //some command is running, do not reopen
		return NO;

	BOOL runCommandAtReopenEvent = NO;
	if(gPreferences != NULL)
		runCommandAtReopenEvent = gPreferences->mPrefs.runCommandOnReopenEvent;

	if(runCommandAtReopenEvent == NO) //prefs say: do not reopen
		return NO;

#ifndef __LP64__
	//remove this code when all windows are Cocoa:
	WindowRef oneCarbonWindow = ::GetWindowList();
	while(oneCarbonWindow != NULL)
	{
		if( GetWRefCon(oneCarbonWindow) == (SRefCon)'OMC!' )//Carbon window with 'OMC!' signature is up, do not reopen
			return NO;
		oneCarbonWindow = ::GetNextWindow(oneCarbonWindow);
	}
#endif //__LP64__

	if( !hasVisibleWindows ) //we don't trust hasVisibleWindows value, it probably only applies to document windows
	{
		if( [OMCWindow getWindowCount] > 0 )
			return NO;

		NSApplication *myApp = [NSApplication sharedApplication];
		if(myApp != NULL)
		{
			NSUInteger windowCount = [[myApp windows] count];
			if(windowCount == 0)
				return YES;
		}
	}
	return NO;
}

- (BOOL)applicationOpenUntitledFile:(NSApplication *)theApplication
{
	if( _startingUp && ((_startupModifiers & kCGEventFlagMaskAlternate) != 0) )
		return FALSE;

	BOOL showNavDialogOnStartup = YES;
	BOOL quitAfterDropExecution = NO;
	if(_startingUp && (gPreferences != NULL) )
	{
		showNavDialogOnStartup = (BOOL)gPreferences->mPrefs.showNavDialogOnStartup;
		quitAfterDropExecution = (BOOL)gPreferences->mPrefs.quitAfterDropExecution;
	}
		
	_runningCommandCount++;
	OSStatus err = [OMCCommandExecutor runCommand:commandID forCommandFile:commandFilePath withContext:NULL useNavDialog:showNavDialogOnStartup delegate:self];
	_runningCommandCount--;
	
	if( (err == noErr) && quitAfterDropExecution)
	{
		NSApplication *myApp = [NSApplication sharedApplication];
		if(myApp != NULL)
		{
			[myApp terminate:self];
		}
	}
	return (err == noErr);
}

//Apple docs state:
// If the user started up the application by double-clicking a file,
// the delegate receives the application:openFile: message before receiving applicationDidFinishLaunching:
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	_startingUp = NO;
	_startupModifiers = 0;
	
	if(sOMCService == NULL)
	{
		NSBundle *appBundle = [NSBundle mainBundle];
		NSDictionary *infoDictionary = [appBundle infoDictionary];
		NSArray *servicesArray = (NSArray *)[infoDictionary objectForKey:@"NSServices"];
		if( (servicesArray != NULL) &&
			[servicesArray isKindOfClass:[NSArray class]] &&
			([servicesArray count] > 0) )
		{
			sOMCService = [[OMCService alloc] init];
			[sOMCService applicationDidFinishLaunching:aNotification];
		}
	}
}

- (void)handleGetURLEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent
{
    // Extract the URL from the Apple event and handle it here.
	 NSString* urlString = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
	 if(urlString == NULL)
		return;

	_runningCommandCount++;
	OSStatus err = [OMCCommandExecutor runCommand:@"omc.app.handle-url" forCommandFile:commandFilePath withContext:urlString useNavDialog:NO delegate:self];
	(void)err;
	_runningCommandCount--;
}

#pragma mark --- OMC support ---

- (NSString *)commandID
{
	return commandID;
}

- (void)setCommandID:(NSString *)string
{
	[string retain];
	[commandID release];
	commandID = string;
}


- (NSString *)commandFilePath
{
	return commandFilePath;
}

- (void)setCommandFilePath:(NSString *)inPath
{
	if(inPath != NULL)
	{
		if([inPath length] == 0)
		{
			inPath = NULL;
		}
	}

	if(inPath != NULL)
	{
		[inPath retain];
		[commandFilePath release];
		commandFilePath = inPath;
	}
	else
	{
		[commandFilePath release];
		commandFilePath = @"Command.plist";
		[commandFilePath retain];
	}
}

//legacy encoder/decoder support - custom control data no longer serialized into nibs
//custom properties get set later on nib load by calling proprty setters

- (id)initWithCoder:(NSCoder *)coder
{
	commandID = NULL;
	commandFilePath = @"Command.plist";
	[commandFilePath retain];
	_startingUp = YES;
	_startupModifiers = 0;
	_runningCommandCount = 0;
	
	//should never happen in Xcode 4 anymore
	if( ![self respondsToSelector: @selector(ibPopulateKeyPaths:)] )//don't init NSDocumentController in IB
	{
		self = [super init];
		if(self == NULL)
			return NULL;
	}

    if( ![coder allowsKeyedCoding] )
		[NSException raise:NSInvalidArgumentException format:@"Unexpected coder not supporting keyed decoding"];
	
	commandID = [[coder decodeObjectForKey:@"omcCommandID"] retain];

	NSString *myFilePath = [coder decodeObjectForKey:@"omcCommandFilePath"];
	[self setCommandFilePath:myFilePath];

    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    if ( ![coder allowsKeyedCoding] )
		[NSException raise:NSInvalidArgumentException format:@"Unexpected coder not supporting keyed encoding"];

	if(commandID != NULL)
		[coder encodeObject:commandID forKey:@"omcCommandID"];
	
	if( (commandFilePath != NULL) && ![commandFilePath isEqualToString:@"Command.plist"] )
	{
		[coder encodeObject:commandFilePath forKey:@"omcCommandFilePath"];
	}
}

#pragma mark --- STUBS ---

- (void)addDocument:(NSDocument *)document
{
}

- (id)currentDocument
{
	return NULL;
}

- (NSString *)defaultType
{
	return NULL;
}

- (id)documentForURL:(NSURL *)absoluteURL
{
	return NULL;
}

- (id)documentForWindow:(NSWindow *)window
{
	return NULL;
}

- (NSArray *)documents
{	
	return [NSArray array];
}

- (BOOL)hasEditedDocuments
{
	return NO;
}

- (id)makeDocumentForURL:(NSURL *)absoluteDocumentURL withContentsOfURL:(NSURL *)absoluteDocumentContentsURL ofType:(NSString *)typeName error:(NSError **)outError
{
	if(outError != NULL)
		*outError = [NSError errorWithDomain:@"Not implemented" code:-1 userInfo:NULL];

	return NULL;
}

- (id)makeDocumentWithContentsOfURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
	if(outError != NULL)
		*outError = [NSError errorWithDomain:@"Not implemented" code:-1 userInfo:NULL];

	return NULL;
}

- (id)makeUntitledDocumentOfType:(NSString *)typeName error:(NSError **)outError
{
	if(outError != NULL)
		*outError = [NSError errorWithDomain:@"Not implemented" code:-1 userInfo:NULL];

	return NULL;
}

- (id)openUntitledDocumentAndDisplay:(BOOL)displayDocument error:(NSError **)outError
{
	if(outError != NULL)
		*outError = [NSError errorWithDomain:@"Not implemented" code:-1 userInfo:NULL];
	return NULL;
}

- (BOOL)reopenDocumentForURL:(NSURL *)absoluteDocumentURL withContentsOfURL:(NSURL *)absoluteDocumentContentsURL error:(NSError **)outError
{
	if(outError != NULL)
		*outError = [NSError errorWithDomain:@"Not implemented" code:-1 userInfo:NULL];
	return NO;
}

- (void)reviewUnsavedDocumentsWithAlertTitle:(NSString *)title cancellable:(BOOL)cancellable delegate:(id)delegate didReviewAllSelector:(SEL)didReviewAllSelector contextInfo:(void *)contextInfo
{
}

- (IBAction)saveAllDocuments:(id)sender
{
}

@end