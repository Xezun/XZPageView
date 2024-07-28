//
//  XZPageScrollView.h
//  XZPageView
//
//  Created by 徐臻 on 2024/7/28.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class XZPageView;

@interface XZPageScrollView : UIScrollView
- (instancetype)initWithFrame:(CGRect)frame pageView:(XZPageView *)pageView NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
@end

NS_ASSUME_NONNULL_END
