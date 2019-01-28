/*
	OMCQCView.m
*/

#import "OMCQCView.h"
#import "OMCDialogController.h"

@implementation OMCQCView

@synthesize commandID, tag = _omcTag, escapingMode;

- (id)init
{
    self = [super init];
	if(self == NULL)
		return NULL;
    _omcTag = 0;
	escapingMode = @"esc_none";
	[escapingMode retain];
	commandID = NULL;

	compositionPath = NULL;
	_omcTarget = NULL;
	_omcTargetSelector = NULL;

	return self;
}

- (void)dealloc
{
	[escapingMode release];
	[commandID release];

	if(compositionPath != NULL)
		[compositionPath release];

	[_omcTarget release];

    [super dealloc];
}

- (id)target
{
	return _omcTarget;
}

- (void)setTarget:(id)anObject;
{
	[anObject retain];
	[_omcTarget release];
	_omcTarget = anObject;	
}

- (void)setAction:(SEL)aSelector
{
	_omcTargetSelector = aSelector;
}

//legacy encoder/decoder support - custom control data no longer serialized into nibs
//custom properties get set later on nib load by calling proprty setters

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
	if(self == NULL)
		return NULL;

    if( ![coder allowsKeyedCoding] )
		[NSException raise:NSInvalidArgumentException format:@"Unexpected coder not supporting keyed decoding"];

	_omcTag = [coder decodeIntForKey:@"omcTag"];
	escapingMode = [[coder decodeObjectForKey:@"omcEscapingMode"] retain];
	if(escapingMode == NULL)
	{
		escapingMode = @"esc_none";//use default if key not present
		[escapingMode retain];
	}

	compositionPath = NULL;
	_omcTarget = NULL;
	_omcTargetSelector = NULL;

/*
	BOOL isOK = [self loadCompositionFromFile:@"/Users/tom/Desktop/Introduction.qtz"];
	if(!isOK)
		NSLog(@"OMCQCView failed to load composition at \"/Users/tom/Desktop/Introduction.qtz\"");
*/

    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];

    if ( ![coder allowsKeyedCoding] )
		[NSException raise:NSInvalidArgumentException format:@"Unexpected coder not supporting keyed encoding"];

	[coder encodeInt:_omcTag forKey:@"omcTag"];

	if(escapingMode == NULL)
	{
		escapingMode = @"esc_none";
		[escapingMode retain];
	}
	
	[coder encodeObject:escapingMode forKey:@"omcEscapingMode"];
}

- (NSString *)stringValue
{
	return compositionPath;
}

- (void)setStringValue:(NSString *)aString
{
	if(compositionPath != NULL)
	{
		[self stopRendering];
		[self unloadComposition];
		[compositionPath release];
		compositionPath = NULL;
	}

	if(aString == NULL)
		return;

	compositionPath = [aString retain];


	BOOL isOK = [self loadCompositionFromFile:compositionPath];
	if(!isOK)
		NSLog(@"OMCQCView failed to load composition at \"%@\"", compositionPath);

	NSMutableDictionary* userInfo = [self userInfo];
	if( (userInfo != NULL) && (_omcTarget != NULL) && [_omcTarget respondsToSelector:@selector(getCFContext)])
	{
		id contextInfo = [_omcTarget getCFContext];
		[userInfo setValue:contextInfo forKey:@"com.abracode.context"];
	}

	[self setAutostartsRendering:YES];
	[self setEventForwardingMask:NSAnyEventMask];
	[self startRendering];
}

- (BOOL) renderAtTime:(NSTimeInterval)time arguments:(NSDictionary*)arguments
{
	BOOL isOK = [super renderAtTime:time arguments:arguments];
	if(isOK)
	{
		NSMutableDictionary* userInfo = [self userInfo];
		if(userInfo != NULL)
		{
			id subcommand = [userInfo objectForKey:@"com.abracode.omc.subcommandId"];
			if( (subcommand != NULL) &&  [subcommand isKindOfClass:[NSString class]] )
			{
				[self setCommandID: (NSString *)subcommand];
				[userInfo removeObjectForKey:@"com.abracode.omc.subcommandId"];//we used it up, now remove from dictionary

				if( (_omcTarget != NULL) && (_omcTargetSelector != NULL) )
				{
					[_omcTarget performSelector:_omcTargetSelector withObject:self]; // = [(OMCDialogController*)_omcTarget handleAction:self];
				}
			}
		}
	}
	return isOK;
}

/*
- (BOOL) renderAtTime:(NSTimeInterval)time arguments:(NSDictionary*)arguments
{
	NSEvent *currentEvent = [NSApp currentEvent];

	if( currentEvent != NULL )
	{
		NSPoint mousePoint = [self convertPoint: [currentEvent locationInWindow] fromView:nil];
		NSRect myRect = [self bounds];

		mousePoint.x /= myRect.size.width;
		mousePoint.y /= myRect.size.height;

		NSMutableDictionary* newArguments = [NSMutableDictionary dictionaryWithDictionary:arguments];
		[newArguments setObject:[NSValue valueWithPoint:mousePoint] forKey:QCRendererMouseLocationKey];
		[newArguments setObject:currentEvent forKey:QCRendererEventKey];
		
		//NSLog(@"renderAtTime (with event) with arguments=%@", newArguments);

		return [super renderAtTime:time arguments:newArguments];
	}

	NSPoint mousePoint = [[self window] mouseLocationOutsideOfEventStream];
	NSRect myRect = [self bounds];

	mousePoint.x /= myRect.size.width;
	mousePoint.y /= myRect.size.height;
	NSMutableDictionary* newArguments = [NSMutableDictionary dictionaryWithDictionary:arguments];
	[newArguments setObject:[NSValue valueWithPoint:mousePoint] forKey:QCRendererMouseLocationKey];
	NSLog(@"renderAtTime (no event) with arguments=%@", newArguments);
	return [super renderAtTime:time arguments:newArguments];
}
*/

@end