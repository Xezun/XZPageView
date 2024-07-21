//
//  XZPageView.m
//  XZKit
//
//  Created by Xezun on 2021/9/7.
//

#import "XZPageView.h"
@import ObjectiveC;
@import XZDefines;

NSTimeInterval const XZPageViewAnimationDuration = 0.35;

typedef void (*XZShowPageFunc)(id<XZPageViewDelegate>, SEL, XZPageView *, NSInteger);
typedef void (*XZTransitionPageFunc)(id<XZPageViewDelegate>, SEL, XZPageView *, CGFloat);

/// 计算 index 自增或子减后的值。
/// 非循环模式时，不能增加或减小返回 NSNotFound 循环模式时最大值自增返回最小值，最小值自减返回最大值。
/// @param index 当前值
/// @param increases YES自增，NO自减
/// @param max 最大值
/// @param isLooped 循环模式
UIKIT_STATIC_INLINE NSInteger XZLoopPage(NSInteger index, BOOL increases, NSInteger max, BOOL isLooped) {
    if (isLooped) {
        return (increases ? ((index >= max) ? 0 : (index + 1)) : ((index <= 0) ? max : (index - 1)));
    }
    return (increases ? ((index == max) ? NSNotFound : (index + 1)) : ((index == 0) ? NSNotFound : (index - 1)));
}

/// 判断 from => to 变化的应该执行的滚动方向，YES正向，NO反向。
UIKIT_STATIC_INLINE BOOL XZScrollDirection(NSInteger from, NSInteger to, NSInteger max, BOOL isLooped) {
    return (isLooped ? (from < to || (from == max && to == 0)) : (from < to));
}

/// 交换两个变量的值
#define XZExchangeValue(var_1, var_2)   { typeof(var_1) temp = var_1; var_1 = var_2; var_2 = temp; }
#define XZCallBlock(block, ...)         if (block != nil) { block(__VA_ARGS__); }

@interface XZPageScrollView : UIScrollView
- (instancetype)initWithFrame:(CGRect)frame pageView:(XZPageView *)pageView NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
@end


@interface XZPageView () {
    XZPageScrollView *_scrollView;
    /// 总数量。
    NSInteger _numberOfPages;
    
    /// 当前视图。
    UIView  * _currentPageView;
    NSInteger _currentPage;
    
    /// 重用视图。
    UIView  * _reusingPageView;
    NSInteger _reusingPage;
    /// YES 表示加载在正向滚动的方向上，NO 表示加载在反向滚动的方向上。
    BOOL      _reusingPageDirection;
    
    /// 自动翻页定时器，请使用方法操作计时器，而非直接使用变量。
    /// 1、视图必须添加到 window 上，才会创建定时器。
    /// 2、从 widow 上移除会销毁定时器，并在再次添加到 window 上时重建。
    /// 3、滚动的过程中，定时器会暂停，并在滚动后重新开始计时。
    /// 4、刷新数据，定时器会重新开始计时。
    /// 5、改变 currentPage 定时器会重新计时。
    NSTimer * __unsafe_unretained _autoPagingTimer;
    
    /// 代理方法
    void (^ _Nullable _didShowPageAtIndex)(XZPageView *pageView, NSInteger currentPage);
    void (^ _Nullable _didTransitionPage)(XZPageView *pageView, CGFloat x, CGFloat width, NSInteger from, NSInteger to);
}

@end

@implementation XZPageView

@synthesize scrollView = _scrollView;

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self XZ_didInitialize];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self XZ_didInitialize];
    }
    return self;
}

#pragma mark - 重写方法

- (void)didMoveToWindow {
    [super didMoveToWindow];
    // 开启自动计时器
    [self XZ_scheduleAutoPagingTimerIfNeeded];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGRect const bounds = self.bounds;
    if (CGRectEqualToRect(_scrollView.frame, bounds)) {
        return;
    }
    
    // 布局子视图
    _scrollView.frame = bounds;
    [self XZ_layoutCurrentPageView:bounds];
    [self XZ_layoutReusingPageView:bounds];
    
    // 重新配置 _scrollView
    _scrollView.contentSize = bounds.size;
    [self XZ_adjustContentInsets:bounds];
}

#pragma mark - 公开方法

- (void)reloadData {
    NSInteger const oldValue = _currentPage;
    
    _numberOfPages = [self.dataSource numberOfPagesInPageView:self];
        
    CGRect const bounds = self.bounds;
    
    // 刷新时，优先保持当前页
    if (_numberOfPages == 0) {
        _currentPage = 0;
    } else if (_currentPage >= _numberOfPages) {
        _currentPage = _numberOfPages - 1;
    }
    [self XZ_reloadCurrentPageView:bounds];
    [self XZ_layoutCurrentPageView:bounds];
    
    // 重载备用视图
    _reusingPage = NSNotFound;
    [self XZ_reloadReusingPageView:bounds];
    [self XZ_layoutReusingPageView:bounds];
    
    // 调整 contentInset 已适配当前状态，并重置页面位置
    [self XZ_adjustContentInsets:bounds];
    [_scrollView setContentOffset:CGPointZero animated:NO];
    
    // 如果当前页发生了改变，发送事件
    if (_currentPage != oldValue) {
        XZCallBlock(_didShowPageAtIndex, self, _currentPage);
    }
    
    // 重启自动翻页计时器
    [self XZ_scheduleAutoPagingTimerIfNeeded];
}

- (void)setCurrentPage:(NSInteger)currentPage {
    [self setCurrentPage:currentPage animated:NO];
}

- (void)setCurrentPage:(NSInteger)currentPage animated:(BOOL)animated {
    [self XZ_setCurrentPage:currentPage animated:animated];
    // 外部翻页，自动翻页重新计时
    [self XZ_resumeAutoPagingTimer];
}

- (void)setDelegate:(id<XZPageViewDelegate>)delegate {
    if (_delegate != delegate) {
        _delegate = delegate;
        
        _didShowPageAtIndex = nil;
        _didTransitionPage  = nil;
        
        if ([delegate conformsToProtocol:@protocol(XZPageViewDelegate)]) {
            Class const aClass = [delegate class];
            [self XZ_notifyDidShowPage:aClass];
            [self XZ_notifyDidTransitionPage:aClass];
        }
    }
}

- (BOOL)bounces {
    return _scrollView.alwaysBounceHorizontal;
}

- (void)setBounces:(BOOL)bounces {
    _scrollView.alwaysBounceHorizontal = bounces;
}

- (void)setAutoPagingInterval:(NSTimeInterval)autoPagingInterval {
    if (_autoPagingInterval != autoPagingInterval) {
        _autoPagingInterval = autoPagingInterval;
        [self XZ_scheduleAutoPagingTimerIfNeeded];
    }
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
            CGRect const bounds = self.bounds;
            [self XZ_adjustContentInsets:bounds];
            if (_reusingPage != NSNotFound) {
                _reusingPageDirection = XZScrollDirection(_currentPage, _reusingPage, maxPage, _isLooped);
                [self XZ_layoutReusingPageView:bounds];
            }
        }
    }
}

- (void)setDataSource:(id<XZPageViewDataSource>)dataSource {
    if (_dataSource != dataSource) {
        _dataSource = dataSource;
        [self reloadData];
    }
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [self XZ_scrollViewDidScroll:scrollView stopped:NO];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    if (scrollView != _scrollView || _numberOfPages <= 1) {
        return;
    }
    
    // 用户操作，暂停计时器
    [self XZ_holdOnAutoPagingTimer];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (scrollView != _scrollView || _numberOfPages <= 1) {
        return;
    }
    
    // 用户停止操作，恢复计时器
    [self XZ_resumeAutoPagingTimer];
    
    // 检查翻页：用户停止操作
    if (decelerate) {
        return; // 进入减速状态，在减速停止后再决定
    }
    
    // 直接停止滚动了。
    [self XZ_scrollViewDidScroll:scrollView stopped:YES];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [self XZ_scrollViewDidScroll:scrollView stopped:YES];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    [self XZ_scrollViewDidScroll:scrollView stopped:YES];
}

#pragma mark - Timer Action

- (void)XZ_autoPagingTimerAction:(NSTimer *)timer {
    NSInteger const newPage = XZLoopPage(_currentPage, YES, _numberOfPages - 1, YES);
    [self XZ_setCurrentPage:newPage animated:YES];

    // 自动翻页，发送事件
    XZCallBlock(_didShowPageAtIndex, self, _currentPage);
}

#pragma mark - 私有方法

- (void)XZ_didInitialize {
    CGRect const bounds = self.bounds;
    
    _isLooped      = YES;
    _currentPage   = 0;
    _reusingPage   = NSNotFound;
    _numberOfPages = 0;
    
    _scrollView = [[XZPageScrollView alloc] initWithFrame:bounds pageView:self];
    _scrollView.contentSize                    = bounds.size;
    _scrollView.contentInset                   = UIEdgeInsetsZero;
    _scrollView.pagingEnabled                  = YES;
    _scrollView.alwaysBounceVertical           = NO;
    _scrollView.alwaysBounceHorizontal         = NO;
    _scrollView.showsVerticalScrollIndicator   = NO;
    _scrollView.showsHorizontalScrollIndicator = NO;
    _scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    [self addSubview:_scrollView];
    
    [_scrollView setDelegate:self];
}

/// 发生滚动
/// @param stopped 滚动是否停止
- (void)XZ_scrollViewDidScroll:(UIScrollView *)scrollView stopped:(BOOL)stopped {
    if (scrollView != _scrollView || _numberOfPages <= 1) {
        return;
    }
    
    CGRect  const bounds         = _scrollView.bounds;
    CGFloat const contentOffsetX = bounds.origin.x;
    // 还在原点时，不需要处理
    if (contentOffsetX == 0) {
        return;
    }
    
    BOOL      const isLTR       = (self.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionLeftToRight);
    NSInteger const maxPage     = _numberOfPages - 1;
    BOOL      const direction   = isLTR ? contentOffsetX > 0 : contentOffsetX < 0;
    NSInteger const pendingPage = XZLoopPage(_currentPage, direction, maxPage, _isLooped);
    
    // 没有目标页面，就不需要处理加载及翻页了。
    if (pendingPage == NSNotFound) {
        if (stopped) {
            // 停止在非页面位置，自动归位
            [_scrollView setContentOffset:CGPointZero animated:YES];
        }
        return;
    }
    
    // 检查当前预加载的视图是否正确
    if (_reusingPage != pendingPage) {
        _reusingPage = pendingPage;
        _reusingPageDirection = direction;
        [self XZ_reloadReusingPageView:bounds];
        [self XZ_layoutReusingPageView:bounds];
    } else if (direction != _reusingPageDirection) {
        _reusingPageDirection = direction;
        [self XZ_layoutReusingPageView:bounds];
    }
    
    // @discussion
    // 当页面宽度不是整数时，比如 370.1 点，UIScrollView 会使用 370.0 点进行翻页，
    // 页面停止滚动时，滚动距离不足一个页面宽度，从而被认定为没有翻页，但是对于用户来说，从视觉上来讲，却已经完成了翻页。
    // 幸好的是，在这种情形下，由于页面位置十分接近，即使再次滚动修正位置，对实际体验也无影响。
    // 因此，我们需要监听停止滚动的方法，并在停止滚动时，对页面状态进行检测。
    // @discussion
    // 理论上在减速前，即 -scrollViewWillEndDragging:withVelocity:targetContentOffset: 方法中，
    // 检测停止时能否满足翻页效果更好，但是这个方法在 iOS 14 以下系统中存在BUG，
    // 参数 targetContentOffset 的值，可能并非不是最终停止的位置，似乎未进行像素取整。
    // 另外，在代理方法中，修改 targetContentOffset 不会结束原有的减速效果，
    // 而调用 -setContentOffset:animated: 方法修正位置，需要需要异步才能生效。
    
    CGFloat const PageWidth = bounds.size.width;
    
    // 滚动满足一页
    if (contentOffsetX <= -PageWidth || contentOffsetX >= +PageWidth) {
        // 执行翻页：_currentPage 与 _reusingPage 交换
        [self XZ_didScrollToReusingPage:bounds maxPage:maxPage direction:direction];
        
        // 用户翻页，发送代理事件：中间已经展示的是当前页内容，但是 offset 未修改。
        // 此时已经完成翻页，直接发送了 show 事件，而没有转场进度 100% 的事件。
        // 1、即使发送进度 100% 的事件，事件也会被 show 事件所覆盖，因为这两个事件是串行的。
        // 2、此时，新页面可能已经进入转场，旧页面应该属于退场状态。
        XZCallBlock(_didShowPageAtIndex, self, _currentPage);
        
        // 恢复翻页前的展示位置，如果 x 不为零，会加载下一页，并发送转场进度
        CGFloat const x = fmod(contentOffsetX, PageWidth);
        // 不能使用 setContentOffset:animated:NO 方法，会触发 scrollViewDidEndDecelerating 代理方法
        _scrollView.contentOffset = CGPointMake(x, 0);
        return;
    }
    
    // 滚动不足一页
    
    // 滚动已停止，且不足一页：检查翻页情况。
    // @discussion
    // 在某些极端情况下，可能会发生，翻页停在中间的情况。
    if (stopped) {
        if (PageWidth - contentOffsetX < 1.0 || -PageWidth - contentOffsetX > -1.0) {
            // 小于一个点，可能是因为 width 不是整数，翻页宽度与 width 不一致，认为翻页完成
            XZLog(@"翻页修复：停止滚动，距翻页不足一个点，%@", NSStringFromCGRect(bounds));
            [self XZ_didScrollToReusingPage:bounds maxPage:maxPage direction:direction];
            XZCallBlock(_didShowPageAtIndex, self, _currentPage);
            // 这里不取模，认为是正好完成翻页
            _scrollView.contentOffset = CGPointZero;
        } else {
            // 发送转场进度
            XZCallBlock(_didTransitionPage, self, contentOffsetX, PageWidth, _currentPage, _reusingPage);
            // 滚动停止，滚动未过半，不执行翻页，退回原点，否则执行翻页
            CGFloat const halfPageWidth = PageWidth * 0.5;
            if (contentOffsetX >= +halfPageWidth) {
                XZLog(@"翻页修复：停止滚动，向右滚动距离超过一半，翻页，%@", NSStringFromCGRect(bounds));
                [_scrollView setContentOffset:CGPointMake(PageWidth, 0) animated:YES];
            } else if (contentOffsetX <= -halfPageWidth) {
                XZLog(@"翻页修复：停止滚动，向左滚动距离超过一半，翻页，%@", NSStringFromCGRect(bounds));
                [_scrollView setContentOffset:CGPointMake(-PageWidth, 0) animated:YES];
            } else {
                // 滚动未超过一半，不翻页，回到原点
                XZLog(@"翻页修复：停止滚动，滚动距离未超过一半，不翻页，%@", NSStringFromCGRect(bounds));
                [_scrollView setContentOffset:CGPointZero animated:YES];
            }
        }
    } else {
        // 发送转场进度
        XZCallBlock(_didTransitionPage, self, contentOffsetX, PageWidth, _currentPage, _reusingPage);
    }
}

- (void)XZ_didScrollToReusingPage:(CGRect const)bounds maxPage:(NSInteger const)maxPage direction:(BOOL const)direction {
    XZExchangeValue(_currentPage, _reusingPage);
    XZExchangeValue(_currentPageView, _reusingPageView);
    
    [self XZ_layoutCurrentPageView:bounds];
    _reusingPageDirection = !direction;
    [self XZ_layoutReusingPageView:bounds];
    
    // 调整 contentInset
    if (_isLooped) {
        // 循环模式不需要调整 contentInset
    } else if (_currentPage == 0 || _currentPage == maxPage || _reusingPage == 0 || _reusingPage == maxPage) {
        [self XZ_adjustContentInsets:bounds];
    }
}

- (void)XZ_reloadCurrentPageView:(CGRect const)bounds {
    [_currentPageView removeFromSuperview];
    
    // 没有 Page 时
    if (_currentPage >= _numberOfPages) {
        if (_currentPageView != nil) {
            _currentPageView = [self.dataSource pageView:self prepareForReusingView:_currentPageView];
        }
        return;
    }
    
    _currentPageView = [self.dataSource pageView:self viewForPageAtIndex:_currentPage reusingView:_currentPageView];
    [_scrollView addSubview:_currentPageView];
}

- (void)XZ_layoutCurrentPageView:(CGRect const)bounds {
    _currentPageView.frame = CGRectMake(0, 0, bounds.size.width, bounds.size.height);
}

- (void)XZ_reloadReusingPageView:(CGRect const)bounds {
    [_reusingPageView removeFromSuperview];
    
    if (_reusingPage == NSNotFound) {
        if (_reusingPageView != nil) {
            _reusingPageView = [self.dataSource pageView:self prepareForReusingView:_reusingPageView];
        }
        return;
    }
    
    _reusingPageView = [self.dataSource pageView:self viewForPageAtIndex:_reusingPage reusingView:_reusingPageView];
    [_scrollView addSubview:_reusingPageView];
}

- (void)XZ_layoutReusingPageView:(CGRect const)bounds {
    switch (self.effectiveUserInterfaceLayoutDirection) {
        case UIUserInterfaceLayoutDirectionRightToLeft: {
            CGFloat const x = (_reusingPageDirection ? -bounds.size.width : +bounds.size.width);
            _reusingPageView.frame = CGRectMake(x, 0, bounds.size.width, bounds.size.height);
            break;
        }
        case UIUserInterfaceLayoutDirectionLeftToRight:
        default: {
            CGFloat const x = (_reusingPageDirection ? +bounds.size.width : -bounds.size.width);
            _reusingPageView.frame = CGRectMake(x, 0, bounds.size.width, bounds.size.height);
            break;
        }
    }
    
}

/// 启动自动翻页计时器。
/// @discussion 1、若不满足启动条件，则销毁当前计时器；
/// @discussion 2、满足条件，若计时器已开始，则重置当前开始计时；
/// @discussion 3、满足条件，若计时器没创建，则自动创建。
- (void)XZ_scheduleAutoPagingTimerIfNeeded {
    if (_numberOfPages <= 1 || self.window == nil || _autoPagingInterval <= 0) {
        // 不满足计时器启动条件，销毁当前计时器。
        [_autoPagingTimer invalidate];
        _autoPagingTimer = nil;
    } else {
        NSTimeInterval const timeInterval = _autoPagingInterval + XZPageViewAnimationDuration;
        if (_autoPagingTimer.timeInterval != timeInterval) {
            [_autoPagingTimer invalidate];
            _autoPagingTimer = [NSTimer scheduledTimerWithTimeInterval:timeInterval target:self selector:@selector(XZ_autoPagingTimerAction:) userInfo:nil repeats:YES];
        }
        // 定时器首次触发的时间
        _autoPagingTimer.fireDate = [NSDate dateWithTimeIntervalSinceNow:_autoPagingInterval];
    }
}

/// 暂停计时
- (void)XZ_holdOnAutoPagingTimer {
    if (_autoPagingTimer != nil) {
        _autoPagingTimer.fireDate = NSDate.distantFuture;
    }
}

/// 重新开始计时。
- (void)XZ_resumeAutoPagingTimer {
    if (_autoPagingTimer != nil) {
        _autoPagingTimer.fireDate = [NSDate dateWithTimeIntervalSinceNow:_autoPagingInterval];
    }
}

/// 本方法不发送事件。
- (void)XZ_setCurrentPage:(NSInteger)newPage animated:(BOOL)animated {
    if (_currentPage == newPage) {
        return;
    }
    NSParameterAssert(newPage >= 0 && newPage < _numberOfPages);
    
    // 动画思路：
    // 1、将目标加载到 reusingPage 上，并计算从 currentPage 到 reusingPage 的滚动方向。
    // 2、将 reusingPage 与 currentPage 互换，然后按照滚动方向，调整它们的位置，然后将窗口移动到原始视图。
    // 3、然后执行动画到目标视图。
    
    CGRect    const bounds  = self.bounds;
    NSInteger const maxPage = _numberOfPages - 1;
    
    [UIView performWithoutAnimation:^{
        // 加载目标视图
        if (_reusingPage != newPage) {
            _reusingPage = newPage;
            [self XZ_reloadReusingPageView:bounds];
        }
        // 滚动方向
        BOOL const scrollDirection = XZScrollDirection(_currentPage, _reusingPage, maxPage, _isLooped);;
        
        // 交换 currentPage 与 reusingPage
        XZExchangeValue(_currentPage, _reusingPage);
        XZExchangeValue(_currentPageView, _reusingPageView);
        
        [self XZ_layoutCurrentPageView:bounds];
        // 从 A => B 的滚动方向，并不一定与 B => A 相反，这里为了保证滚动方向不变，
        // 使用原始到目标的滚动方向取反，而不是直接计算从目标到原始的方向。
        _reusingPageDirection = !scrollDirection;
        [self XZ_layoutReusingPageView:bounds];
        
        // 根据当前情况调整边距
        if (_isLooped) {
            // 循环模式，不需要调整边距
        } else if (_currentPage == 0 || _currentPage == maxPage || _reusingPage == 0 || _reusingPage == maxPage) {
            [self XZ_adjustContentInsets:bounds];
        }
    }];
    
    // 不需要动画的话，直接重新加载当前页视图即可，预加载页会在滚动时判断。
    if (animated) {
        // 将窗口恢复到原始视图上
        [UIView performWithoutAnimation:^{
            [_scrollView setDelegate:nil];
            CGFloat const x = _reusingPageView.frame.origin.x + _scrollView.contentOffset.x;
            [_scrollView setContentOffset:CGPointMake(x, 0) animated:NO];
            [_scrollView setDelegate:self];
        }];
        
        // 动画到当前视图上。
        // 修改 bounds 不会触发 -scrollViewDidScroll: 方法，但是会触发 -layoutSubviews 方法。
        [UIView animateWithDuration:XZPageViewAnimationDuration animations:^{
            [self->_scrollView setDelegate:nil];
            [self->_scrollView setContentOffset:CGPointZero animated:NO];
            [self->_scrollView setDelegate:self];
        }];
    }
}

/// 调整 contentInset 以适配 currentPage 和 isLooped 状态。
/// @note 仅在需要调整 contentInset 的地方调用此方法。
- (void)XZ_adjustContentInsets:(CGRect const)bounds {
    UIEdgeInsets newInsets = UIEdgeInsetsZero;
    if (_numberOfPages <= 1) {
        // 只有一个 page 不可滚动。
    } else if (_isLooped) {
        // 循环模式下，可左右滚动，设置左右边距作为滚动区域。
        newInsets = UIEdgeInsetsMake(0, bounds.size.width, 0, bounds.size.width);
    } else if (_currentPage == 0) {
        // 非循环模式下，展示第一页时，不能向后滚动。
        switch (self.effectiveUserInterfaceLayoutDirection) {
            case UIUserInterfaceLayoutDirectionRightToLeft:
                newInsets = UIEdgeInsetsMake(0, bounds.size.width, 0, 0);
                break;
            case UIUserInterfaceLayoutDirectionLeftToRight:
            default:
                newInsets = UIEdgeInsetsMake(0, 0, 0, bounds.size.width);
                break;
        }
    } else if (_currentPage == _numberOfPages - 1) {
        // 非循环模式下，展示最后一页时，不能向前滚动。
        switch (self.effectiveUserInterfaceLayoutDirection) {
            case UIUserInterfaceLayoutDirectionRightToLeft:
                newInsets = UIEdgeInsetsMake(0, 0, 0, bounds.size.width);
                break;
            case UIUserInterfaceLayoutDirectionLeftToRight:
            default:
                newInsets = UIEdgeInsetsMake(0, bounds.size.width, 0, 0);
                break;
        }
    } else {
        // 非循环模式下，展示的不是第一页，也不是最后一页，可以前后滚动。
        newInsets = UIEdgeInsetsMake(0, bounds.size.width, 0, bounds.size.width);
    }
    
    if (UIEdgeInsetsEqualToEdgeInsets(newInsets, _scrollView.contentInset)) {
        return;
    }
    
    id const delegate = _scrollView.delegate;
    [_scrollView setDelegate:nil];
    _scrollView.contentInset = newInsets;
    [_scrollView setDelegate:delegate];
}

- (void)XZ_notifyDidShowPage:(nonnull Class)aClass {
    XZShowPageFunc const didShowPageAtIndex = (XZShowPageFunc)class_getMethodImplementation(aClass, @selector(pageView:didShowPageAtIndex:));
    if (didShowPageAtIndex == NULL) return;
    
    _didShowPageAtIndex = ^(XZPageView *self, NSInteger currentPage) {
        id<XZPageViewDelegate> const delegate = self.delegate;
        if (delegate == nil) return;
        didShowPageAtIndex(delegate, @selector(pageView:didShowPageAtIndex:), self, currentPage);
    };
}

- (void)XZ_notifyDidTransitionPage:(nonnull Class)aClass {
    XZTransitionPageFunc const didTransitionPage = (XZTransitionPageFunc)class_getMethodImplementation(aClass, @selector(pageView:didTransitionPage:));
    if (didTransitionPage == NULL) return;
    
    _didTransitionPage = ^(XZPageView *self, CGFloat x, CGFloat width, NSInteger fromPage, NSInteger toPage) {
        id<XZPageViewDelegate> const delegate = self.delegate;
        if (delegate == nil) return;
        CGFloat const transition = x / width;
        // 一次翻多页的情况，在当前设计模式下不存在。
        // 如果有，可以根据 transition 的正负判断翻页方向，再根据 fromPage 和 toPage 以及它们之差，计算出翻页进度。
        didTransitionPage(delegate, @selector(pageView:didTransitionPage:), self, transition);
    };
}

@end


@implementation XZPageView (XZPageViewDeprecated)
@dynamic isLoopable;
@end


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
