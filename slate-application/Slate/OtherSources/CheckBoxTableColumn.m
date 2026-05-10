//
//  CheckBoxTableColumn.m
//  Slate
//
//  Created by Jerry Hale on 3/20/26
//  Copyright (c) 2026 Jerry Hale All rights reserved.

#import "CheckBoxTableColumn.h"

@implementation CheckBoxTableColumn

-(void)setDelegate:(id<CheckBoxTableColumnDelegate>)newDelegate
{
	delegate = newDelegate;
}

// Let our delegate handle
// the population of the cells in this column
-(id)dataCellForRow:(int)row
{
	if (delegate != nil)
	{
		return (id)[delegate dataCellForRow:row forTable:[self tableView]];
	}
	else
	{
		return (id) nil;
	}
}

@end
