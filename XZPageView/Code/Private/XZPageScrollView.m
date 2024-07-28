//
//  XZPageScrollView.m
//  XZPageView
//
//  Created by 徐臻 on 2024/7/28.
//

#import "XZPageScrollView.h"
#import "XZPageView.h"

@implementation XZPageScrollView {
    XZPageView * __unsafe_unretained _pageView;
}

- (instancetype)initWithFrame:(CGRect)frame pageView:(XZPageView *)pageView {
    self = [super initWithFrame:frame];
    if (self) {
        _pageView = pageView;
    }
    return self;
}

- (void)setDelegate:(id<UIScrollViewDelegate>)delegate {
    NSAssert(delegate == nil || delegate == _pageView, @"%@ 的 delegate 已由 XZPageView 管理，外部不允许修改", self);
    [super setDelegate:delegate];
}

@end
