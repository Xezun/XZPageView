//
//  XZPageView.m
//  XZKit
//
//  Created by Xezun on 2021/9/7.
//

#import "XZPageView.h"
#import "XZPageViewContext.h"
@import ObjectiveC;
@import XZDefines;

@interface XZPageView () {
    XZPageViewContext *_context;
}

@end

@implementation XZPageView

- (instancetype)initWithFrame:(CGRect)frame orientation:(XZPageViewOrientation)orientation {
    self = [super initWithFrame:frame];
    if (self) {
        _context = [[XZPageViewContext contextWithPageView:self orientation:orientation] didInitialize];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    return [self initWithFrame:frame orientation:(XZPageViewOrientationHorizontal)];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        _context = [[XZPageViewContext contextWithPageView:self orientation:XZPageViewOrientationHorizontal] didInitialize];
    }
    return self;
}

#pragma mark - 重写方法

- (void)didMoveToWindow {
    [super didMoveToWindow];
    
    // 添加到 window 时，如果数据为空，则尝试自动刷新
    if (self.window != nil && _numberOfPages == 0 && _dataSource != nil) {
        [self reloadData];
    }
    
    // 开启自动计时器
    [_context scheduleAutoPagingTimerIfNeeded];
}

- (void)setFrame:(CGRect)frame {
    CGSize const old = self.frame.size;
    [super setFrame:frame];
    CGSize const new = self.frame.size;
    
    if (!CGSizeEqualToSize(old, new)) {
        [_context layoutSubviews:new];
    }
}

- (void)setBounds:(CGRect)bounds {
    CGRect const old = self.bounds;
    [super setBounds:bounds];
    CGRect const new = self.bounds;
    
    // setFrame 不会触发 setBounds
    if (!CGSizeEqualToSize(old.size, new.size)) {
        [_context layoutSubviews:new.size];
    }
}

#pragma mark - 公开方法

- (void)reloadData {
    NSInteger const oldValue = _currentPage;
    
    _numberOfPages = [self.dataSource numberOfPagesInPageView:self];
        
    CGSize const bounds = self.bounds.size;
    
    // 刷新时，优先保持当前页
    if (_numberOfPages == 0) {
        _currentPage = 0;
    } else if (_currentPage >= _numberOfPages) {
        _currentPage = _numberOfPages - 1;
    }
    [_context reloadCurrentPageView:bounds];
    [_context layoutCurrentPageView:bounds];
    
    // 重载备用视图
    _reusingPage = NSNotFound;
    [_context reloadReusingPageView:bounds];
    [_context layoutReusingPageView:bounds];
    
    // 调整 contentInset 已适配当前状态，并重置页面位置
    [_context adjustContentInsets:bounds];
    [self setContentOffset:CGPointZero animated:NO];
    
    // 如果当前页发生了改变，发送事件
    if (_currentPage != oldValue) {
        XZCallBlock(_didShowPage, self, _currentPage);
    }
    
    // 重启自动翻页计时器
    [_context scheduleAutoPagingTimerIfNeeded];
}

- (void)setCurrentPage:(NSInteger)currentPage {
    [self setCurrentPage:currentPage animated:NO];
}

- (void)setCurrentPage:(NSInteger)currentPage animated:(BOOL)animated {
    [_context setCurrentPage:currentPage animated:animated];
    // 外部翻页，自动翻页重新计时
    [_context resumeAutoPagingTimer];
}

@dynamic delegate;

- (void)setDelegate:(id<XZPageViewDelegate>)delegate {
    // 在调用 super 之前处理，这样 UIScrollView 可以获取到最新的 imp
    Class const aClass = [delegate class];
    [_context willSetDelegate:aClass];
    
    // kvo
    id const old = super.delegate;
    [super setDelegate:delegate];
    id const new = super.delegate;
    
    if (old == new) {
        return;
    }
    
    if (new == nil) {
        return [super setDelegate:self];
    }
    
    _didShowPage = nil;
    _didTurnPage = nil;
    if ([delegate conformsToProtocol:@protocol(XZPageViewDelegate)]) {
        [_context notifyDidShowPage:aClass];
        [_context notifyDidTurnPage:aClass];
    }
}

- (void)setAutoPagingInterval:(NSTimeInterval)autoPagingInterval {
    if (_autoPagingInterval != autoPagingInterval) {
        _autoPagingInterval = autoPagingInterval;
        [_context scheduleAutoPagingTimerIfNeeded];
    }
}

- (BOOL)isLooped {
    return _isLooped;
}

- (void)setLooped:(BOOL)isLooped {
    if (_isLooped != isLooped) {
        _isLooped = isLooped;
    
        // 不可循环
        if (_numberOfPages <= 1) {
            return;
        }
        
        // 只有当位置处于第一个或者最后一个时，才需要进行调整
        NSInteger const maxPage = _numberOfPages - 1;
        if (_currentPage == 0 || _currentPage == maxPage) {
            CGSize const bounds = self.bounds.size;
            [_context adjustContentInsets:bounds];
            if (_reusingPage != NSNotFound) {
                _reusingPageDirection = XZScrollDirection(_currentPage, _reusingPage, maxPage, _isLooped);
                [_context layoutReusingPageView:bounds];
            }
        }
    }
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView != self) {
        return;
    }
    [_context didScroll:NO];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    if (scrollView != self) {
        return;
    }
    
    if (_numberOfPages <= 1) {
        return;
    }
    
    // 用户操作，暂停计时器
    [_context holdOnAutoPagingTimer];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (scrollView != self) {
        return;
    }
    
    // 用户停止操作，恢复计时器
    if (_numberOfPages > 1) {
        [_context resumeAutoPagingTimer];
    }
    
    // 检查翻页：用户停止操作
    if (decelerate) {
        return; // 进入减速状态，在减速停止后再决定
    }
    
    // 直接停止滚动了。
    [_context didScroll:YES];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    if (scrollView != self) {
        return;
    }
    
    [_context didScroll:YES];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    if (scrollView != self) {
        return;
    }
    [_context didScroll:YES];
}

#pragma mark - Timer Action



#pragma mark - 私有方法





@end

