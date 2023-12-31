//
//  XZPageView.m
//  XZKit
//
//  Created by Xezun on 2021/9/7.
//

#import "XZPageView.h"

NSTimeInterval const XZPageViewAnimationDuration = 0.35;

/// 计算 index 自增或子减后的值。
/// 非循环模式时，不能增加或减小返回 NSNotFound 循环模式时最大值自增返回最小值，最小值自减返回最大值。
/// @param index 当前值
/// @param increases YES自增，NO自减
/// @param max 最大值
/// @param isLoopable 循环模式
static NSInteger XZLoopIndex(NSInteger index, BOOL increases, NSInteger max, BOOL isLoopable) {
    if (isLoopable) {
        return (increases ? ((index >= max) ? 0 : (index + 1)) : ((index <= 0) ? max : (index - 1)));
    }
    return (increases ? ((index == max) ? NSNotFound : (index + 1)) : ((index == 0) ? NSNotFound : (index - 1)));
}

/// 判断 from => to 变化的应该执行的滚动方向，YES正向，NO反向。
static BOOL XZScrollDirection(NSInteger from, NSInteger to, NSInteger max, BOOL isLoopable) {
    return (isLoopable ? (from < to || (from == max && to == 0)) : (from < to));
}

/// 交换两个变量的值
#define XZExchangeValue(var_1, var_2) { typeof(var_1) temp = var_1; var_1 = var_2; var_2 = temp; }


@interface XZPageView () {
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
}

@end

@implementation XZPageView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self _didInitialize];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self _didInitialize];
    }
    return self;
}

#pragma mark - 重写方法

- (void)didMoveToWindow {
    [super didMoveToWindow];
    
    // 添加到 window 时，尝试自动刷新下。
    if (_currentPage >= _numberOfPages && self.window != nil) {
        [self reloadData];
    } else {
        [self _scheduleAutoPagingTimer];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGRect const bounds = self.bounds;
    
    // 布局子视图
    _scrollView.frame = bounds;
    [self _layoutCurrentPageView:bounds];
    [self _layoutReusingPageView:bounds];
    
    // 重新配置 _scrollView
    _scrollView.contentSize = bounds.size;
    [self _adjustContentInset:bounds];
}

#pragma mark - 公开方法

- (void)reloadData {
    _numberOfPages = [self.dataSource numberOfPagesInPageView:self];
        
    CGRect const bounds = self.bounds;
    
    // 刷新时，优先保持当前页
    if (_numberOfPages == 0) {
        _currentPage = 0;
    } else if (_currentPage >= _numberOfPages) {
        _currentPage = _numberOfPages - 1;
    }
    [self _reloadCurrentPageView:bounds];
    
    // 重载备用视图
    _reusingPage = NSNotFound;
    [self _reloadReusingPageView:bounds];
    
    // 调整位置
    [_scrollView setContentOffset:CGPointZero animated:NO];
    [self _adjustContentInset:bounds];
    
    // 自动翻页
    [self _scheduleAutoPagingTimer];
}

- (void)setCurrentPage:(NSInteger)currentPage {
    [self setCurrentPage:currentPage animated:NO];
}

- (void)setCurrentPage:(NSInteger)currentPage animated:(BOOL)animated {
    [self _setCurrentPage:currentPage animated:animated isLoopable:NO];
    // 外部翻页，自动翻页重新计时
    [self _resumeAutoPagingTimer];
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
        [self _scheduleAutoPagingTimer];
    }
}

- (void)setLoopable:(BOOL)isLoopable {
    if (_isLoopable != isLoopable) {
        _isLoopable = isLoopable;
    
        // 不可循环
        if (_numberOfPages <= 1) {
            return;
        }
        
        // 只有当位置处于第一个或者最后一个时，才需要进行调整
        NSInteger const maxPage = _numberOfPages - 1;
        if (_currentPage == 0 || _currentPage == maxPage) {
            CGRect const bounds = self.bounds;
            [self _adjustContentInset:bounds];
            if (_reusingPage != NSNotFound) {
                _reusingPageDirection = XZScrollDirection(_currentPage, _reusingPage, maxPage, _isLoopable);
                [self _layoutReusingPageView:bounds];
            }
        }
    }
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [self _scrollViewDidScroll:scrollView willStopScrolling:NO];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    if (scrollView != _scrollView || _numberOfPages <= 1) {
        return;
    }
    
    // 用户操作，暂停计时器
    [self _holdOnAutoPagingTimer];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (scrollView != _scrollView || _numberOfPages <= 1) {
        return;
    }
    
    // 用户停止操作，恢复计时器
    [self _resumeAutoPagingTimer];
    
    // 检查翻页：用户停止操作，滚动也停止了
    if (!decelerate) {
        [self _scrollViewDidScroll:scrollView willStopScrolling:YES];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [self _scrollViewDidScroll:scrollView willStopScrolling:YES];
}

#pragma mark - Timer Action

- (void)_autoPagingTimerAction:(NSTimer *)timer {
    NSInteger const newPage = XZLoopIndex(_currentPage, YES, _numberOfPages - 1, YES);
    [self _setCurrentPage:newPage animated:YES isLoopable:_isLoopable];

    // 自动翻页，发送事件
    [self.delegate pageView:self didPageToIndex:_currentPage];
}

#pragma mark - 私有方法

- (void)_didInitialize {
    CGRect const bounds = self.bounds;
    
    _isLoopable    = YES;
    _currentPage   = 0;
    _reusingPage   = NSNotFound;
    _numberOfPages = 0;
    
    _scrollView = [[UIScrollView alloc] initWithFrame:bounds];
    _scrollView.contentSize   = bounds.size;
    _scrollView.contentInset  = UIEdgeInsetsZero;
    _scrollView.pagingEnabled = YES;
    _scrollView.alwaysBounceVertical   = NO;
    _scrollView.alwaysBounceHorizontal = NO;
    _scrollView.showsVerticalScrollIndicator   = NO;
    _scrollView.showsHorizontalScrollIndicator = NO;
    if (@available(iOS 11.0, *)) {
        _scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    } else {
        // Fallback on earlier versions
    }
    [self addSubview:_scrollView];
    
    _scrollView.delegate = self;
}

- (void)_scrollViewDidScroll:(UIScrollView *)scrollView willStopScrolling:(BOOL)willStopScrolling {
    if (scrollView != _scrollView || _numberOfPages <= 1) {
        return;
    }
    
    CGRect const bounds = _scrollView.bounds;
    
    if (bounds.origin.x == 0) {
        return;
    }
    
    BOOL      const isLTR       = (self.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionLeftToRight);
    NSInteger const maxPage     = _numberOfPages - 1;
    BOOL      const direction   = isLTR ? bounds.origin.x > 0 : bounds.origin.x < 0;
    NSInteger const pendingPage = XZLoopIndex(_currentPage, direction, maxPage, _isLoopable);
    
    // 没有目标页面，就不需要处理加载及翻页了。
    if (pendingPage == NSNotFound) {
        return;
    }
    
    // 检查当前预加载的视图是否正确
    if (_reusingPage != pendingPage) {
        _reusingPage = pendingPage;
        _reusingPageDirection = direction;
        [self _reloadReusingPageView:bounds];
    } else if (direction != _reusingPageDirection) {
        _reusingPageDirection = direction;
        [self _layoutReusingPageView:bounds];
    }
    
    // 滚动满足一页
    if (bounds.origin.x <= -bounds.size.width || bounds.origin.x >= +bounds.size.width) {
        // 执行翻页
        [self _didScrollToReusingPage:bounds maxPage:maxPage direction:direction];
        // 恢复翻页前的展示位置
        CGFloat const x = fmod(bounds.origin.x, bounds.size.width);
        _scrollView.contentOffset = CGPointMake(x, 0);
        // 用户翻页，发送代理事件
        [self.delegate pageView:self didPageToIndex:_currentPage];
        return;
    }
    
    // 滚动不足一页
    if (!willStopScrolling) {
        return;
    }
    
    /// 停止滚动时，检查翻页情况。
    /// @discussion
    /// 当视图停止拖拽时，检查是否会停止在原点上，如果不在原点上，则根据目标位置判断是否需要执行翻页。
    /// 当页面宽度不是整像素数时，比如 370.1 点，UIScrollView 会使用 370.0 点进行翻页。
    /// 即页面停止时滚动距离不足一个页面长度，从而被认定为没有翻页，而对于用户，实际效果却已经完成了翻页。
    /// 因此需要在页面停止滚动时，判断当前是否已经翻页。
    /// @discussion
    /// 理论上在减速前，即-scrollViewWillEndDragging:withVelocity:targetContentOffset:方法中，
    /// 检测停止时能否满足翻页效果更好，但是这个方法在 iOS 14 以下系统中存在BUG，
    /// 参数 targetContentOffset 的值，可能并非不是最终停止的位置（未进行像素取整），且在代理方法中，
    /// 需要异步调用 -setContentOffset:animated: 方法来修正位置，似乎是因为修复 targetContentOffset 的
    /// 坐标没有停止原有的减速效果。
    /// @discussion
    /// 幸好的是，在 UIScrollView 开启整页翻页效果时，scrollView 每次停止位置都是接近于页面实际宽度，
    /// 即使在停止后再次滚动修正位置，对实际体验并无影响。
    
    // 滚动停止，滚动未过半，不执行翻页，退回原点
    CGFloat const PageHalf = bounds.size.width * 0.5;
    if (bounds.origin.x < +PageHalf && bounds.origin.x > -PageHalf) {
        [_scrollView setContentOffset:CGPointZero animated:YES];
        return;
    }
    
    // 滚动停止，滚动过半，翻页
    [self _didScrollToReusingPage:bounds maxPage:maxPage direction:direction];
    
    _scrollView.delegate = nil;
    if (isLTR) {
        CGFloat const x = bounds.origin.x + (direction ? (-bounds.size.width) : (+bounds.size.width));
        [_scrollView setContentOffset:CGPointMake(x, 0) animated:NO];
    } else {
        CGFloat const x = bounds.origin.x + (direction ? (+bounds.size.width) : (-bounds.size.width));
        [_scrollView setContentOffset:CGPointMake(x, 0) animated:NO];
    }
    _scrollView.delegate = self;
    
    // 动画画到目的位置。
    [_scrollView setContentOffset:CGPointZero animated:NO];
    
    // 用户翻页，发送代理事件
    [self.delegate pageView:self didPageToIndex:_currentPage];
}

- (void)_didScrollToReusingPage:(CGRect const)bounds maxPage:(NSInteger const)maxPage direction:(BOOL const)direction {
    XZExchangeValue(_currentPage, _reusingPage);
    XZExchangeValue(_currentPageView, _reusingPageView);
    
    [self _layoutCurrentPageView:bounds];
    _reusingPageDirection = !direction;
    [self _layoutReusingPageView:bounds];
    
    // 调整 contentInset
    if (_isLoopable) {
        // 循环模式不需要调整 contentInset
    } else if (_currentPage == 0 || _currentPage == maxPage || _reusingPage == 0 || _reusingPage == maxPage) {
        [self _adjustContentInset:bounds];
    }
}

- (void)_reloadCurrentPageView:(CGRect const)bounds {
    [_currentPageView removeFromSuperview];
    
    if (_currentPage >= _numberOfPages) {
        if (_currentPageView != nil) {
            _currentPageView = [self.dataSource pageView:self prepareForReusingView:_currentPageView];
        }
        return;
    }
    
    _currentPageView = [self.dataSource pageView:self viewForPageAtIndex:_currentPage reusingView:_currentPageView];
    [_scrollView addSubview:_currentPageView];
    
    [self _layoutCurrentPageView:bounds];
}

- (void)_layoutCurrentPageView:(CGRect const)bounds {
    _currentPageView.frame = CGRectMake(0, 0, bounds.size.width, bounds.size.height);
}

- (void)_reloadReusingPageView:(CGRect const)bounds {
    [_reusingPageView removeFromSuperview];
    
    if (_reusingPage == NSNotFound) {
        if (_reusingPageView != nil) {
            _reusingPageView = [self.dataSource pageView:self prepareForReusingView:_reusingPageView];
        }
        return;
    }
    
    _reusingPageView = [self.dataSource pageView:self viewForPageAtIndex:_reusingPage reusingView:_reusingPageView];
    [_scrollView addSubview:_reusingPageView];
    
    [self _layoutReusingPageView:bounds];
}

- (void)_layoutReusingPageView:(CGRect const)bounds {
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
- (void)_scheduleAutoPagingTimer {
    if (_numberOfPages <= 1 || self.window == nil || _autoPagingInterval <= 0) {
        // 不满足计时器启动条件，销毁当前计时器。
        [_autoPagingTimer invalidate];
        _autoPagingTimer = nil;
    } else {
        NSTimeInterval const timeInterval = _autoPagingInterval + XZPageViewAnimationDuration;
        if (_autoPagingTimer.timeInterval != timeInterval) {
            [_autoPagingTimer invalidate];
            _autoPagingTimer = [NSTimer scheduledTimerWithTimeInterval:timeInterval target:self selector:@selector(_autoPagingTimerAction:) userInfo:nil repeats:YES];
        }
        // 定时器首次触发的时间
        _autoPagingTimer.fireDate = [NSDate dateWithTimeIntervalSinceNow:_autoPagingInterval];
    }
}

/// 暂停计时
- (void)_holdOnAutoPagingTimer {
    if (_autoPagingTimer != nil) {
        _autoPagingTimer.fireDate = NSDate.distantFuture;
    }
}

/// 重新开始计时。
- (void)_resumeAutoPagingTimer {
    if (_autoPagingTimer != nil) {
        _autoPagingTimer.fireDate = [NSDate dateWithTimeIntervalSinceNow:_autoPagingInterval];
    }
}

/// 本方法不发送事件。
- (void)_setCurrentPage:(NSInteger)newPage animated:(BOOL)animated isLoopable:(BOOL const)isLoopable {
    NSParameterAssert(newPage >= 0 && newPage < _numberOfPages);
    if (_currentPage == newPage) {
        return;
    }
    
    CGRect const bounds  = self.bounds;
    NSInteger const maxPage = _numberOfPages - 1;
    
    // 不需要动画的话，直接重新加载当前页视图即可，预加载页会在滚动时判断。
    if (animated) {
        [UIView performWithoutAnimation:^{
            
            
            // 将 reusingPage 加载为 newPage
            if (_reusingPage != newPage) {
                _reusingPage = newPage;
                [self _reloadReusingPageView:bounds];
            }
            
            // 将 currentPage 与 reusingPage 交换
            XZExchangeValue(_currentPage, _reusingPage);
            XZExchangeValue(_currentPageView, _reusingPageView);
            
            // 布局视图：变量交换后，currentPage 到 reusingPage 滚动关系，与原来相反。
            [self _layoutCurrentPageView:bounds];
            // 在循环模式下，在首尾时，A => B 的方向与 B => A 不同，因此使用原方向取反。
            _reusingPageDirection = !XZScrollDirection(_reusingPage, _currentPage, maxPage, isLoopable);
            [self _layoutReusingPageView:bounds];
            
            // 修改 bounds 不会触发 -scrollViewDidScroll: 方法，但是会触发 -layoutSubviews 方法。
            
            _scrollView.delegate = nil;
            if (_isLoopable) {
                // 循环模式，不需要调整边距
            } else if (_currentPage == 0 || _currentPage == maxPage || _reusingPage == 0 || _reusingPage == maxPage) {
                [self _adjustContentInset:bounds];
            }
            // 将视图滚动到 reusingPage 上，即交换前的 currentPage 上，这样看起来，位置没变。
            switch (self.effectiveUserInterfaceLayoutDirection) {
                case UIUserInterfaceLayoutDirectionRightToLeft: {
                    CGFloat x = bounds.size.width;
                    x = _scrollView.contentOffset.x + (_reusingPageDirection ? -x : x);
                    [_scrollView setContentOffset:CGPointMake(x, 0) animated:NO];
                    break;
                }
                case UIUserInterfaceLayoutDirectionLeftToRight:
                default: {
                    CGFloat x = bounds.size.width;
                    x = _scrollView.contentOffset.x + (_reusingPageDirection ? x : -x);
                    [_scrollView setContentOffset:CGPointMake(x, 0) animated:NO];
                    break;
                }
            }
            _scrollView.delegate = self;
        }];
        
        // 动画到当前视图上。
        [UIView animateWithDuration:XZPageViewAnimationDuration animations:^{
            self->_scrollView.delegate = nil;
            [self->_scrollView setContentOffset:CGPointZero animated:NO];
            self->_scrollView.delegate = self;
        }];
    } else {
        _currentPage = newPage;
        [self _reloadCurrentPageView:bounds];
        
        if (_reusingPage != NSNotFound) {
            _reusingPageDirection = XZScrollDirection(_currentPage, _reusingPage, maxPage, _isLoopable);
            [self _layoutReusingPageView:bounds];
        }
        
        if (_isLoopable) {
            // 循环模式，不需要调整边距
        } else if (_currentPage == 0 || _currentPage == maxPage) {
            [self _adjustContentInset:bounds];
        }
    }
}

/// 调整 contentInset 以适配 currentPage 和 isLoopable 状态。
/// @note 仅在需要调整 contentInset 的地方调用此方法。
- (void)_adjustContentInset:(CGRect const)bounds {
    id const delegate = _scrollView.delegate;
    _scrollView.delegate = nil;
    if (_numberOfPages <= 1) {
        // 只有一个 page 不可滚动。
        _scrollView.contentInset = UIEdgeInsetsZero;
    } else if (_isLoopable) {
        // 循环模式下，可左右滚动，设置左右边距作为滚动区域。
        CGFloat const width = bounds.size.width;
        _scrollView.contentInset = UIEdgeInsetsMake(0, width, 0, width);
    } else if (_currentPage == 0) {
        // 非循环模式下，展示第一页时，不能向后滚动。
        switch (self.effectiveUserInterfaceLayoutDirection) {
            case UIUserInterfaceLayoutDirectionRightToLeft:
                _scrollView.contentInset = UIEdgeInsetsMake(0, bounds.size.width, 0, 0);
                break;
            case UIUserInterfaceLayoutDirectionLeftToRight:
            default:
                _scrollView.contentInset = UIEdgeInsetsMake(0, 0, 0, bounds.size.width);
                break;
        }
    } else if (_currentPage == _numberOfPages - 1) {
        // 非循环模式下，展示最后一页时，不能向前滚动。
        switch (self.effectiveUserInterfaceLayoutDirection) {
            case UIUserInterfaceLayoutDirectionRightToLeft:
                _scrollView.contentInset = UIEdgeInsetsMake(0, 0, 0, bounds.size.width);
                break;
            case UIUserInterfaceLayoutDirectionLeftToRight:
            default:
                _scrollView.contentInset = UIEdgeInsetsMake(0, bounds.size.width, 0, 0);
                break;
        }
    } else {
        // 非循环模式下，展示的不是第一页，也不是最后一页，可以前后滚动。
        CGFloat const width = bounds.size.width;
        _scrollView.contentInset = UIEdgeInsetsMake(0, width, 0, width);
    }
    _scrollView.delegate = delegate;
}

@end
