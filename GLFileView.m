//
//  GLFileView.m
//  GitX
//
//  Created by German Laullon on 14/09/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "GLFileView.h"
#import "PBGitGradientBarView.h"

#define GROUP_LABEL				@"Label"			// string
#define GROUP_SEPARATOR			@"HasSeparator"		// BOOL as NSNumber
#define GROUP_SELECTION_MODE	@"SelectionMode"	// MGScopeBarGroupSelectionMode (int) as NSNumber
#define GROUP_ITEMS				@"Items"			// array of dictionaries, each containing the following keys:
#define ITEM_IDENTIFIER			@"Identifier"		// string
#define ITEM_NAME				@"Name"				// string

@implementation GLFileView

- (void) awakeFromNib
{
	startFile = @"fileview";
	//repository = historyController.repository;
	[super awakeFromNib];
	[historyController.treeController addObserver:self forKeyPath:@"selection" options:0 context:@"treeController"];
	
	self.groups = [NSMutableArray arrayWithCapacity:0];
	
	NSArray *items = [NSArray arrayWithObjects:
					  [NSDictionary dictionaryWithObjectsAndKeys:
					   startFile, ITEM_IDENTIFIER, 
					   @"Source", ITEM_NAME, 
					   nil], 
					  [NSDictionary dictionaryWithObjectsAndKeys:
					   @"blame", ITEM_IDENTIFIER, 
					   @"Blame", ITEM_NAME, 
					   nil], 
					  nil];
	[self.groups addObject:[NSDictionary dictionaryWithObjectsAndKeys:
							[NSNumber numberWithBool:NO], GROUP_SEPARATOR, 
							[NSNumber numberWithInt:MGRadioSelectionMode], GROUP_SELECTION_MODE, // single selection group.
							items, GROUP_ITEMS, 
							nil]];
	[typeBar reloadData];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	//NSLog(@"keyPath=%@ change=%@ context=%@ object=%@ \n %@",keyPath,change,context,object,[historyController.treeController selectedObjects]);
	[self showFile];
}

- (void) showFile
{
	NSArray *files=[historyController.treeController selectedObjects];
	if ([files count]>0) {
		PBGitTree *file=[files objectAtIndex:0];

		NSString *fileTxt=@"";
		if(startFile==@"fileview")
			fileTxt=[file textContents];
		if(startFile==@"blame")
			fileTxt=[self parseBlame:[file blame]];

		id script = [view windowScriptObject];
		[script callWebScriptMethod:@"showFile" withArguments:[NSArray arrayWithObject:fileTxt]];
	}
}

#pragma mark MGScopeBarDelegate methods


- (int)numberOfGroupsInScopeBar:(MGScopeBar *)theScopeBar
{
	return [self.groups count];
}


- (NSArray *)scopeBar:(MGScopeBar *)theScopeBar itemIdentifiersForGroup:(int)groupNumber
{
	return [[self.groups objectAtIndex:groupNumber] valueForKeyPath:[NSString stringWithFormat:@"%@.%@", GROUP_ITEMS, ITEM_IDENTIFIER]];
}


- (NSString *)scopeBar:(MGScopeBar *)theScopeBar labelForGroup:(int)groupNumber
{
	return [[self.groups objectAtIndex:groupNumber] objectForKey:GROUP_LABEL]; // might be nil, which is fine (nil means no label).
}


- (NSString *)scopeBar:(MGScopeBar *)theScopeBar titleOfItem:(NSString *)identifier inGroup:(int)groupNumber
{
	NSArray *items = [[self.groups objectAtIndex:groupNumber] objectForKey:GROUP_ITEMS];
	if (items) {
		for (NSDictionary *item in items) {
			if ([[item objectForKey:ITEM_IDENTIFIER] isEqualToString:identifier]) {
				return [item objectForKey:ITEM_NAME];
				break;
			}
		}
	}
	return nil;
}


- (MGScopeBarGroupSelectionMode)scopeBar:(MGScopeBar *)theScopeBar selectionModeForGroup:(int)groupNumber
{
	return [[[self.groups objectAtIndex:groupNumber] objectForKey:GROUP_SELECTION_MODE] intValue];
}

- (void)scopeBar:(MGScopeBar *)theScopeBar selectedStateChanged:(BOOL)selected forItem:(NSString *)identifier inGroup:(int)groupNumber
{
	startFile=identifier;
	NSString *path = [NSString stringWithFormat:@"html/views/%@", identifier];
	NSString *html = [[NSBundle mainBundle] pathForResource:@"index" ofType:@"html" inDirectory:path];
	//NSLog(@"[FileViewerController scopeBar:selectedStateChanged] -> file: '%@' (%@)",html,identifier);
	NSURLRequest * request = [NSURLRequest requestWithURL:[NSURL fileURLWithPath:html]];
	[[view mainFrame] loadRequest:request];
}

- (void) didLoad
{
	[self showFile];
}

- (NSString *) parseBlame:(NSString *)txt
{
	txt=[txt stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
	txt=[txt stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"];
	
	NSArray *lines = [txt componentsSeparatedByString:@"\n"];
	NSString *line;
	NSMutableDictionary *headers=[NSMutableDictionary dictionary];
	NSMutableString *res=[NSMutableString string];
	
	[res appendString:@"<table class='blocks'>\n"];
	int i=0;
	while(i<[lines count]){
		line=[lines objectAtIndex:i];
		NSArray *header=[line componentsSeparatedByString:@" "];
		if([header count]==4){
			int nLines=[(NSString *)[header objectAtIndex:3] intValue];
			[res appendFormat:@"<tr class='block l%d'>\n",nLines];
			line=[lines objectAtIndex:++i];
			if([[[line componentsSeparatedByString:@" "] objectAtIndex:0] isEqual:@"author"]){
				NSString *author=line;
				NSString *summary=nil;
				while(summary==nil){
					line=[lines objectAtIndex:i++];
					if([[[line componentsSeparatedByString:@" "] objectAtIndex:0] isEqual:@"summary"]){
						summary=line;
					}
				}
				NSString *block=[NSString stringWithFormat:@"<td><p class='author'>%@</p><p class='summary'>%@</p></td>\n<td>\n",author,summary];
				[headers setObject:block forKey:[header objectAtIndex:0]];
			}
			[res appendString:[headers objectForKey:[header objectAtIndex:0]]];
			
			NSMutableString *code=[NSMutableString string];
			do{
				line=[lines objectAtIndex:i++];
			}while([line characterAtIndex:0]!='\t');
			line=[line stringByReplacingOccurrencesOfString:@"\t" withString:@"&nbsp;&nbsp;&nbsp;&nbsp;"];
			[code appendString:line];
			[code appendString:@"\n"];
			
			int n;
			for(n=1;n<nLines;n++){
				line=[lines objectAtIndex:i++];
				do{
					line=[lines objectAtIndex:i++];
				}while([line characterAtIndex:0]!='\t');
				line=[line stringByReplacingOccurrencesOfString:@"\t" withString:@"&nbsp;&nbsp;&nbsp;&nbsp;"];
				[code appendString:line];
				[code appendString:@"\n"];
			}
			[res appendFormat:@"<pre class='first-line: %@;brush: objc'>%@</pre>",[header objectAtIndex:2],code];
			[res appendString:@"</td>\n"];
		}else{
			break;
		}
		[res appendString:@"</tr>\n"];
	}  
	[res appendString:@"</table>\n"];
	//NSLog(@"%@",res);
	
	return (NSString *)res;
}

@synthesize groups;

@end
