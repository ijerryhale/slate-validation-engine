//
//  CheckBoxTableColumn.h
//  Slate
//
//  Created by Jerry Hale on 3/19/26.
//  Copyright (c) 2026 Jerry Hale. All rights reserved.
//
//  Proprietary and confidential.
//  This file is part of Slate and is not open source software.
//
//  No license is granted to copy, modify, distribute, sublicense, or use this
//  source code except under a written agreement with the copyright holder.
//  Unauthorized use, disclosure, reproduction, or distribution is prohibited.
//

#import <Cocoa/Cocoa.h>

@protocol CheckBoxTableColumnDelegate <NSObject>
- (id)dataCellForRow:(int)row forTable:(NSTableView *)tableView;
@end

@interface  CheckBoxTableColumn : NSTableColumn
{
    IBOutlet id<CheckBoxTableColumnDelegate> delegate;
}
-(void)setDelegate:(id<CheckBoxTableColumnDelegate>)newDelegate;
-(id)dataCellForRow:(int)row;

@end
