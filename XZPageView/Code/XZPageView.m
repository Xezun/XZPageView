//
//  XZPageView.m
//  XZKit
//
//  Created by Xezun on 2021/9/7.
//

#import "XZPageView.h"
#import "XZPageViewManager.h"
#import "XZPageScrollView.h"
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

@interface XZPageView () {
    XZPageViewManager *_manager;
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

- (instancetype)initWithFrame:(CGRect)frame direction:(XZPageViewDirection)direction {
    self = [super initWithFrame:frame];
    if (self) {
        [self XZ_didInitialize:direction];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self XZ_didInitialize:XZPageViewDirectionHorizontal];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    return [self initWithFrame:frame direction:(XZPageViewDirectionHorizontal)];
}

#pragma mark - 重写方法

- (void)didMoveToWindow {
    [super didMoveToWindow];
    // 开启自动计时器
    [_manager scheduleAutoPagingTimerIfNeeded];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGRect const bounds = self.bounds;
    if (CGRectEqualToRect(_scrollView.frame, bounds)) {
        return;
    }
    
    // 布局子视图
    _scrollView.frame = bounds;
    [_manager layoutCurrentPageView:bounds];
    [_manager layoutReusingPageView:bounds];
    
    // 重新配置 _scrollView
    _scrollView.contentSize = bounds.size;
    [_manager adjustContentInsets:bounds];
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
    [_manager reloadCurrentPageView:bounds];
    [_manager layoutCurrentPageView:bounds];
    
    // 重载备用视图
    _reusingPage = NSNotFound;
    [_manager reloadReusingPageView:bounds];
    [_manager layoutReusingPageView:bounds];
    
    // 调整 contentInset 已适配当前状态，并重置页面位置
    [_manager adjustContentInsets:bounds];
    [_scrollView setContentOffset:CGPointZero animated:NO];
    
    // 如果当前页发生了改变，发送事件
    if (_currentPage != oldValue) {
        XZCallBlock(_didShowPageAtIndex, self, _currentPage);
    }
    
    // 重启自动翻页计时器
    [_manager scheduleAutoPagingTimerIfNeeded];
}

- (void)setCurrentPage:(NSInteger)currentPage {
    [self setCurrentPage:currentPage animated:NO];
}

- (void)setCurrentPage:(NSInteger)currentPage animated:(BOOL)animated {
    [_manager setCurrentPage:currentPage animated:animated];
    // 外部翻页，自动翻页重新计时
    [_manager resumeAutoPagingTimer];
}

- (void)setDelegate:(id<XZPageViewDelegate>)delegate {
    if (_delegate != delegate) {
        _delegate = delegate;
        
        _didShowPageAtIndex = nil;
        _didTransitionPage  = nil;
        
        if ([delegate conformsToProtocol:@protocol(XZPageViewDelegate)]) {
            Class const aClass = [delegate class];
            [_manager notifyDidShowPage:aClass];
            [_manager notifyDidTransitionPage:aClass];
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
        [_manager scheduleAutoPagingTimerIfNeeded];
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
            [_manager adjustContentInsets:bounds];
            if (_reusingPage != NSNotFound) {
                _reusingPageDirection = XZScrollDirection(_currentPage, _reusingPage, maxPage, _isLooped);
                [_manager layoutReusingPageView:bounds];
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
    [_manager scrollViewDidScroll:scrollView stopped:NO];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    if (scrollView != _scrollView || _numberOfPages <= 1) {
        return;
    }
    
    // 用户操作，暂停计时器
    [_manager holdOnAutoPagingTimer];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (scrollView != _scrollView) {
        return;
    }
    
    // 用户停止操作，恢复计时器
    if (_numberOfPages > 1) {
        [_manager resumeAutoPagingTimer];
    }
    
    // 检查翻页：用户停止操作
    if (decelerate) {
        return; // 进入减速状态，在减速停止后再决定
    }
    
    // 直接停止滚动了。
    [_manager scrollViewDidScroll:scrollView stopped:YES];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [_manager scrollViewDidScroll:scrollView stopped:YES];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    [_manager scrollViewDidScroll:scrollView stopped:YES];
}

#pragma mark - Timer Action

- (void)XZ_autoPagingTimerAction:(NSTimer *)timer {
    NSInteger const newPage = XZLoopPage(_currentPage, YES, _numberOfPages - 1, YES);
    [_manager setCurrentPage:newPage animated:YES];

    // 自动翻页，发送事件
    XZCallBlock(_didShowPageAtIndex, self, _currentPage);
}

#pragma mark - 私有方法

- (void)XZ_didInitialize:(XZPageViewDirection)direction {
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
    
    _manager = [XZPageViewManager managerForPageView:self direction:direction];
}

@end


@implementation XZPageView (XZPageViewDeprecated)
@dynamic isLoopable;
@end

