//
//  XZPageViewContext.m
//  XZPageView
//
//  Created by 徐臻 on 2024/9/24.
//

#import "XZPageViewContext.h"
#import "XZPageView.h"
@import XZDefines;
@import ObjectiveC;

@implementation XZPageViewContext

+ (XZPageViewContext *)contextWithPageView:(XZPageView *)pageView orientation:(XZPageViewOrientation)orientation {
    switch (orientation) {
        case XZPageViewOrientationHorizontal:
            return [[self alloc] initWithPageView:pageView];
            break;
        case XZPageViewOrientationVertical:
            
            break;
    }
    NSString *reason = [NSString stringWithFormat:@"参数 orientation=%ld 不是合法的枚举值", (long)orientation];
    @throw [NSException exceptionWithName:NSInvalidArgumentException reason:reason userInfo:nil];
}

- (instancetype)initWithPageView:(XZPageView *)pageView {
    self = [super init];
    if (self) {
        _pageView = pageView;
    }
    return self;
}

- (instancetype)didInitialize {
    // 默认以自身为代理
    struct objc_super super = {
        .receiver = _pageView,
        .super_class = class_getSuperclass(object_getClass(_pageView))
    };
    ((void(*)(struct objc_super *, SEL, id<UIScrollViewDelegate>))objc_msgSendSuper)(&super, @selector(setDelegate:), _pageView);
    
    _pageView->_isLooped      = YES;
    _pageView->_currentPage   = 0;
    _pageView->_reusingPage   = NSNotFound;
    _pageView->_numberOfPages = 0;
    
    _pageView.contentSize                    = _pageView.bounds.size;
    _pageView.contentInset                   = UIEdgeInsetsZero;
    _pageView.pagingEnabled                  = YES;
    _pageView.alwaysBounceVertical           = NO;
    _pageView.alwaysBounceHorizontal         = NO;
    _pageView.showsVerticalScrollIndicator   = NO;
    _pageView.showsHorizontalScrollIndicator = NO;
    _pageView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    return self;
}

- (void)layoutSubviews:(CGSize)size {
    // 布局子视图
    [self layoutCurrentPageView:size];
    [self layoutReusingPageView:size];
    // 重新配置 _scrollView
    _pageView.contentSize = size;
    [self adjustContentInsets:size];
}

- (void)reloadCurrentPageView:(CGSize const)bounds {
    [_pageView->_currentPageView removeFromSuperview];
    
    // 没有 Page 时
    if (_pageView->_currentPage >= _pageView->_numberOfPages) {
        if (_pageView->_currentPageView != nil) {
            _pageView->_currentPageView = [_pageView.dataSource pageView:_pageView prepareForReusingView:_pageView->_currentPageView];
        }
        return;
    }
    
    _pageView->_currentPageView = [_pageView.dataSource pageView:_pageView viewForPageAtIndex:_pageView->_currentPage reusingView:_pageView->_currentPageView];
    [_pageView addSubview:_pageView->_currentPageView];
}

- (void)layoutCurrentPageView:(CGSize const)bounds {
    _pageView->_currentPageView.frame = CGRectMake(0, 0, bounds.width, bounds.height);
}

- (void)reloadReusingPageView:(CGSize const)bounds {
    [_pageView->_reusingPageView removeFromSuperview];
    
    if (_pageView->_reusingPage == NSNotFound) {
        if (_pageView->_reusingPageView != nil) {
            _pageView->_reusingPageView = [_pageView.dataSource pageView:_pageView prepareForReusingView:_pageView->_reusingPageView];
        }
        return;
    }
    
    _pageView->_reusingPageView = [_pageView.dataSource pageView:_pageView viewForPageAtIndex:_pageView->_reusingPage reusingView:_pageView->_reusingPageView];
    [_pageView addSubview:_pageView->_reusingPageView];
}

- (void)layoutReusingPageView:(CGSize const)bounds {
    switch (_pageView.effectiveUserInterfaceLayoutDirection) {
        case UIUserInterfaceLayoutDirectionRightToLeft: {
            CGFloat const x = (_pageView->_reusingPageDirection ? -bounds.width : +bounds.width);
            _pageView->_reusingPageView.frame = CGRectMake(x, 0, bounds.width, bounds.height);
            break;
        }
        case UIUserInterfaceLayoutDirectionLeftToRight:
        default: {
            CGFloat const x = (_pageView->_reusingPageDirection ? +bounds.width : -bounds.width);
            _pageView->_reusingPageView.frame = CGRectMake(x, 0, bounds.width, bounds.height);
            break;
        }
    }
}

/// 调整 contentInset 以适配 currentPage 和 isLooped 状态。
/// @note 仅在需要调整 contentInset 的地方调用此方法。
- (void)adjustContentInsets:(CGSize const)bounds {
    UIEdgeInsets newInsets = UIEdgeInsetsZero;
    if (_pageView->_numberOfPages <= 1) {
        // 只有一个 page 不可滚动。
    } else if (_pageView->_isLooped) {
        // 循环模式下，可左右滚动，设置左右边距作为滚动区域。
        newInsets = UIEdgeInsetsMake(0, bounds.width, 0, bounds.width);
    } else if (_pageView->_currentPage == 0) {
        // 非循环模式下，展示第一页时，不能向后滚动。
        switch (_pageView.effectiveUserInterfaceLayoutDirection) {
            case UIUserInterfaceLayoutDirectionRightToLeft:
                newInsets = UIEdgeInsetsMake(0, bounds.width, 0, 0);
                break;
            case UIUserInterfaceLayoutDirectionLeftToRight:
            default:
                newInsets = UIEdgeInsetsMake(0, 0, 0, bounds.width);
                break;
        }
    } else if (_pageView->_currentPage == _pageView->_numberOfPages - 1) {
        // 非循环模式下，展示最后一页时，不能向前滚动。
        switch (_pageView.effectiveUserInterfaceLayoutDirection) {
            case UIUserInterfaceLayoutDirectionRightToLeft:
                newInsets = UIEdgeInsetsMake(0, 0, 0, bounds.width);
                break;
            case UIUserInterfaceLayoutDirectionLeftToRight:
            default:
                newInsets = UIEdgeInsetsMake(0, bounds.width, 0, 0);
                break;
        }
    } else {
        // 非循环模式下，展示的不是第一页，也不是最后一页，可以前后滚动。
        newInsets = UIEdgeInsetsMake(0, bounds.width, 0, bounds.width);
    }
    
    if (UIEdgeInsetsEqualToEdgeInsets(newInsets, _pageView.contentInset)) {
        return;
    }
    
    // TODO: 会导致 didScroll 事件，尚未验证是否会引起问题
    _pageView.contentInset = newInsets;
}

/// 发生滚动
- (void)didScroll:(BOOL)stopped {
    CGRect  const bounds         = _pageView.bounds;
    CGSize  const size           = bounds.size;
    CGFloat const contentOffsetX = bounds.origin.x;
    
    // 只有一张图时，只有原点是合法位置
    if (_pageView->_numberOfPages <= 1) {
        if (stopped && contentOffsetX != 0) {
            [_pageView setContentOffset:CGPointZero animated:YES];
        }
        return;
    }
    
    // 还在原点时，不需要处理
    if (contentOffsetX == 0) {
        return;
    }
    
    BOOL      const isLTR       = (_pageView.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionLeftToRight);
    NSInteger const maxPage     = _pageView->_numberOfPages - 1;
    BOOL      const direction   = isLTR ? contentOffsetX > 0 : contentOffsetX < 0;
    NSInteger const pendingPage = XZLoopPage(_pageView->_currentPage, direction, maxPage, _pageView->_isLooped);
    
    // 没有目标页面，就不需要处理加载及翻页了。
    if (pendingPage == NSNotFound) {
        if (stopped) {
            // 停止在非页面位置，自动归位
            [_pageView setContentOffset:CGPointZero animated:YES];
        }
        return;
    }
    
    // 检查当前预加载的视图是否正确
    if (_pageView->_reusingPage != pendingPage) {
        _pageView->_reusingPage = pendingPage;
        _pageView->_reusingPageDirection = direction;
        [self reloadReusingPageView:size];
        [self layoutReusingPageView:size];
    } else if (direction != _pageView->_reusingPageDirection) {
        _pageView->_reusingPageDirection = direction;
        [self layoutReusingPageView:size];
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
    
    CGFloat const PageWidth = size.width;
    
    // 滚动满足一页
    if (contentOffsetX <= -PageWidth || contentOffsetX >= +PageWidth) {
        // 执行翻页：_currentPage 与 _reusingPage 交换
        [self didScrollToReusingPage:size maxPage:maxPage direction:direction];
        
        // 用户翻页，发送代理事件：中间已经展示的是当前页内容，但是 offset 未修改。
        // 此时已经完成翻页，直接发送了 show 事件，而没有转场进度 100% 的事件。
        // 1、即使发送进度 100% 的事件，事件也会被 show 事件所覆盖，因为这两个事件是串行的。
        // 2、此时，新页面可能已经进入转场，旧页面应该属于退场状态。
        XZCallBlock(_pageView->_didShowPage, _pageView, _pageView->_currentPage);
        
        // 恢复翻页前的展示位置，如果 x 不为零，会加载下一页，并发送转场进度
        CGFloat const x = fmod(contentOffsetX, PageWidth);
        // 不能使用 setContentOffset:animated:NO 方法，会触发 scrollViewDidEndDecelerating 代理方法
        _pageView.contentOffset = CGPointMake(x, 0);
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
            [self didScrollToReusingPage:size maxPage:maxPage direction:direction];
            XZCallBlock(_pageView->_didShowPage, _pageView, _pageView->_currentPage);
            // 这里不取模，认为是正好完成翻页
            _pageView.contentOffset = CGPointZero;
        } else {
            // 发送转场进度
            XZCallBlock(_pageView->_didTurnPage, _pageView, contentOffsetX, PageWidth, _pageView->_currentPage, _pageView->_reusingPage);
            // 滚动停止，滚动未过半，不执行翻页，退回原点，否则执行翻页
            CGFloat const halfPageWidth = PageWidth * 0.5;
            if (contentOffsetX >= +halfPageWidth) {
                XZLog(@"翻页修复：停止滚动，向右滚动距离超过一半，翻页，%@", NSStringFromCGRect(bounds));
                [_pageView setContentOffset:CGPointMake(PageWidth, 0) animated:YES];
            } else if (contentOffsetX <= -halfPageWidth) {
                XZLog(@"翻页修复：停止滚动，向左滚动距离超过一半，翻页，%@", NSStringFromCGRect(bounds));
                [_pageView setContentOffset:CGPointMake(-PageWidth, 0) animated:YES];
            } else {
                // 滚动未超过一半，不翻页，回到原点
                XZLog(@"翻页修复：停止滚动，滚动距离未超过一半，不翻页，%@", NSStringFromCGRect(bounds));
                [_pageView setContentOffset:CGPointZero animated:YES];
            }
        }
    } else {
        // 发送转场进度
        XZCallBlock(_pageView->_didTurnPage, _pageView, contentOffsetX, PageWidth, _pageView->_currentPage, _pageView->_reusingPage);
    }
}

- (void)didScrollToReusingPage:(CGSize const)bounds maxPage:(NSInteger const)maxPage direction:(BOOL const)direction {
    XZExchangeValue(_pageView->_currentPage, _pageView->_reusingPage);
    XZExchangeValue(_pageView->_currentPageView, _pageView->_reusingPageView);
    
    [self layoutCurrentPageView:bounds];
    _pageView->_reusingPageDirection = !direction;
    [self layoutReusingPageView:bounds];
    
    // 调整 contentInset
    if (_pageView->_isLooped) {
        // 循环模式不需要调整 contentInset
    } else if (_pageView->_currentPage == 0 || _pageView->_currentPage == maxPage || _pageView->_reusingPage == 0 || _pageView->_reusingPage == maxPage) {
        [self adjustContentInsets:bounds];
    }
}

/// 启动自动翻页计时器。
/// @discussion 1、若不满足启动条件，则销毁当前计时器；
/// @discussion 2、满足条件，若计时器已开始，则重置当前开始计时；
/// @discussion 3、满足条件，若计时器没创建，则自动创建。
- (void)scheduleAutoPagingTimerIfNeeded {
    if (_pageView->_numberOfPages <= 1 || _pageView.window == nil || _pageView->_autoPagingInterval <= 0) {
        // 不满足计时器启动条件，销毁当前计时器。
        [_pageView->_autoPagingTimer invalidate];
        _pageView->_autoPagingTimer = nil;
    } else {
        NSTimeInterval const timeInterval = _pageView->_autoPagingInterval + XZPageViewAnimationDuration;
        if (_pageView->_autoPagingTimer.timeInterval != timeInterval) {
            [_pageView->_autoPagingTimer invalidate];
            _pageView->_autoPagingTimer = [NSTimer scheduledTimerWithTimeInterval:timeInterval target:self selector:@selector(autoPagingTimerAction:) userInfo:nil repeats:YES];
        }
        // 定时器首次触发的时间
        _pageView->_autoPagingTimer.fireDate = [NSDate dateWithTimeIntervalSinceNow:_pageView->_autoPagingInterval];
    }
}

- (void)autoPagingTimerAction:(NSTimer *)timer {
    NSInteger const newPage = XZLoopPage(_pageView->_currentPage, YES, _pageView->_numberOfPages - 1, YES);
    [self setCurrentPage:newPage animated:YES];

    // 自动翻页，发送事件
    XZCallBlock(_pageView->_didShowPage, _pageView, _pageView->_currentPage);
}

/// 暂停计时
- (void)holdOnAutoPagingTimer {
    if (_pageView->_autoPagingTimer != nil) {
        _pageView->_autoPagingTimer.fireDate = NSDate.distantFuture;
    }
}

/// 重新开始计时。
- (void)resumeAutoPagingTimer {
    if (_pageView->_autoPagingTimer != nil) {
        _pageView->_autoPagingTimer.fireDate = [NSDate dateWithTimeIntervalSinceNow:_pageView->_autoPagingInterval];
    }
}


/// 本方法不发送事件。
- (void)setCurrentPage:(NSInteger)newPage animated:(BOOL)animated {
    if (_pageView->_currentPage == newPage) {
        return;
    }
    NSParameterAssert(newPage >= 0 && newPage < _pageView->_numberOfPages);
    
    // 动画思路：
    // 1、将目标加载到 reusingPage 上，并计算从 currentPage 到 reusingPage 的滚动方向。
    // 2、将 reusingPage 与 currentPage 互换，然后按照滚动方向，调整它们的位置，然后将窗口移动到原始视图。
    // 3、然后执行动画到目标视图。
    
    CGSize    const bounds  = _pageView.bounds.size;
    NSInteger const maxPage = _pageView->_numberOfPages - 1;
    
    [UIView performWithoutAnimation:^{
        // 加载目标视图
        if (_pageView->_reusingPage != newPage) {
            _pageView->_reusingPage = newPage;
            [self reloadReusingPageView:bounds];
        }
        
        // 滚动方向
        BOOL const scrollDirection = XZScrollDirection(_pageView->_currentPage, _pageView->_reusingPage, maxPage, _pageView->_isLooped);
        
        // 交换 currentPage 与 reusingPage
        XZExchangeValue(_pageView->_currentPage, _pageView->_reusingPage);
        XZExchangeValue(_pageView->_currentPageView, _pageView->_reusingPageView);
        
        [self layoutCurrentPageView:bounds];
        // 从 A => B 的滚动方向，并不一定与 B => A 相反，这里为了保证滚动方向不变，
        // 使用原始到目标的滚动方向取反，而不是直接计算从目标到原始的方向。
        _pageView->_reusingPageDirection = !scrollDirection;
        [self layoutReusingPageView:bounds];
        
        // 根据当前情况调整边距
        if (_pageView->_isLooped) {
            // 循环模式，不需要调整边距
        } else if (_pageView->_currentPage == 0 || _pageView->_currentPage == maxPage || _pageView->_reusingPage == 0 || _pageView->_reusingPage == maxPage) {
            [self adjustContentInsets:bounds];
        }
    }];
    
    // 不需要动画的话，直接重新加载当前页视图即可，预加载页会在滚动时判断。
    if (animated) {
        CGRect __block bounds = _pageView.bounds;
        // 将窗口恢复到原始视图上
        [UIView performWithoutAnimation:^{
            bounds.origin.x = _pageView->_reusingPageView.frame.origin.x + _pageView.contentOffset.x;
            [_pageView setBounds:bounds]; // 使用 super 避免触发滚动事件
        }];
        
        // 动画到当前视图上。
        // 修改 bounds 不会触发 -scrollViewDidScroll: 方法，但是会触发 -layoutSubviews 方法。
        [UIView animateWithDuration:XZPageViewAnimationDuration animations:^{
            bounds.origin = CGPointZero;
            [self->_pageView setBounds:bounds];
        }];
    }
}



- (void)notifyDidShowPage:(nonnull Class)aClass {
    typedef void (*MethodType)(id<XZPageViewDelegate>, SEL, XZPageView *, NSInteger);
    
    MethodType const didShowPageAtIndex = (MethodType)class_getMethodImplementation(aClass, @selector(pageView:didShowPageAtIndex:));
    if (didShowPageAtIndex == NULL) return;
    
    _pageView->_didShowPage = ^(XZPageView * const self, NSInteger currentPage) {
        id const delegate = self.delegate;
        if (delegate == nil || delegate == self) return;
        didShowPageAtIndex(delegate, @selector(pageView:didShowPageAtIndex:), self, currentPage);
    };
}

- (void)notifyDidTurnPage:(nonnull Class)aClass {
    typedef void (*MethodType)(id<XZPageViewDelegate>, SEL, XZPageView *, CGFloat);
    
    MethodType const didTransitionPage = (MethodType)class_getMethodImplementation(aClass, @selector(pageView:didTurnPageWithTransition:));
    if (didTransitionPage == NULL) return;
    
    _pageView->_didTurnPage = ^(XZPageView * const self, CGFloat x, CGFloat width, NSInteger fromPage, NSInteger toPage) {
        id const delegate = self.delegate;
        if (delegate == nil || delegate == self) return;
        CGFloat const transition = x / width;
        // 一次翻多页的情况，在当前设计模式下不存在。
        // 如果有，可以根据 transition 的正负判断翻页方向，再根据 fromPage 和 toPage 以及它们之差，计算出翻页进度。
        didTransitionPage(delegate, @selector(pageView:didTurnPageWithTransition:), self, transition);
    };
}

- (void)willSetDelegate:(nullable Class)aClass {
    if (aClass == Nil || [aClass isSubclassOfClass:[XZPageView class]]) {
        return;
    }
    
    static const void * const _isHandled = &_isHandled;
    if (objc_getAssociatedObject(aClass, _isHandled)) {
        return;
    }
    objc_setAssociatedObject(aClass, _isHandled, @(YES), OBJC_ASSOCIATION_COPY_NONATOMIC);
    
    {
        typedef void (*MethodType)(id, SEL, UIScrollView *);
        SEL          const sel   = @selector(scrollViewDidScroll:);
        MethodType   const imp   = (MethodType)class_getMethodImplementation([XZPageView class], sel);
        const char * const types = protocol_getMethodDescription(@protocol(UIScrollViewDelegate), sel, NO, YES).types;
        xz_objc_class_addMethodWithBlock(aClass, sel, types, ^(id self, XZPageView *scrollView) {
            if ([scrollView isKindOfClass:[XZPageView class]]) {
                imp(scrollView, sel, scrollView);
            }
        }, ^(id self, XZPageView *scrollView) {
            if ([scrollView isKindOfClass:[XZPageView class]]) {
                imp(scrollView, sel, scrollView);
            }
            struct objc_super super = {
                .receiver = self,
                .super_class = class_getSuperclass(object_getClass(self))
            };
            ((void(*)(struct objc_super *, SEL, UIScrollView *))objc_msgSendSuper)(&super, sel, scrollView);
        }, ^id _Nonnull(SEL  _Nonnull selector) {
            return ^(id self, XZPageView *scrollView) {
                if ([scrollView isKindOfClass:[XZPageView class]]) {
                    [scrollView scrollViewDidScroll:scrollView];
                }
                ((void(*)(id, SEL, UIScrollView *))objc_msgSend)(self, selector, scrollView);
            };
        });
    }
    
    {
        typedef void (*MethodType)(id, SEL, UIScrollView *);
        SEL          const sel   = @selector(scrollViewWillBeginDragging:);
        MethodType   const imp   = (MethodType)class_getMethodImplementation([XZPageView class], sel);
        const char * const types = protocol_getMethodDescription(@protocol(UIScrollViewDelegate), sel, NO, YES).types;
        xz_objc_class_addMethodWithBlock(aClass, sel, types, ^(id self, XZPageView *scrollView) {
            if ([scrollView isKindOfClass:[XZPageView class]]) {
                imp(scrollView, sel, scrollView);
            }
        }, ^(id self, XZPageView *scrollView) {
            if ([scrollView isKindOfClass:[XZPageView class]]) {
                imp(scrollView, sel, scrollView);
            }
            struct objc_super super = {
                .receiver = self,
                .super_class = class_getSuperclass(object_getClass(self))
            };
            ((void(*)(struct objc_super *, SEL, UIScrollView *))objc_msgSendSuper)(&super, sel, scrollView);
        }, ^id _Nonnull(SEL  _Nonnull selector) {
            return ^(id self, XZPageView *scrollView) {
                if ([scrollView isKindOfClass:[XZPageView class]]) {
                    imp(scrollView, sel, scrollView);
                }
                ((void(*)(id, SEL, UIScrollView *))objc_msgSend)(self, selector, scrollView);
            };
        });
    }
    
    {
        typedef void (*MethodType)(id, SEL, UIScrollView *, BOOL);
        SEL          const sel   = @selector(scrollViewDidEndDragging:willDecelerate:);
        MethodType   const imp   = (MethodType)class_getMethodImplementation([XZPageView class], sel);
        const char * const types = protocol_getMethodDescription(@protocol(UIScrollViewDelegate), sel, NO, YES).types;
        xz_objc_class_addMethodWithBlock(aClass, sel, types, ^(id self, XZPageView *scrollView, BOOL decelerate) {
            if ([scrollView isKindOfClass:[XZPageView class]]) {
                imp(scrollView, sel, scrollView, decelerate);
            }
        }, ^(id self, XZPageView *scrollView, BOOL decelerate) {
            if ([scrollView isKindOfClass:[XZPageView class]]) {
                imp(scrollView, sel, scrollView, decelerate);
            }
            struct objc_super super = {
                .receiver = self,
                .super_class = class_getSuperclass(object_getClass(self))
            };
            ((void(*)(struct objc_super *, SEL, UIScrollView *, BOOL))objc_msgSendSuper)(&super, sel, scrollView, decelerate);
        }, ^id _Nonnull(SEL  _Nonnull selector) {
            return ^(id self, XZPageView *scrollView, BOOL decelerate) {
                if ([scrollView isKindOfClass:[XZPageView class]]) {
                    imp(scrollView, sel, scrollView, decelerate);
                }
                ((void(*)(id, SEL, UIScrollView *, BOOL))objc_msgSend)(self, selector, scrollView, decelerate);
            };
        });
    }
    
    {
        typedef void (*MethodType)(id, SEL, UIScrollView *);
        SEL          const sel   = @selector(scrollViewDidEndDecelerating:);
        MethodType   const imp   = (MethodType)class_getMethodImplementation([XZPageView class], sel);
        const char * const types = protocol_getMethodDescription(@protocol(UIScrollViewDelegate), sel, NO, YES).types;
        xz_objc_class_addMethodWithBlock(aClass, sel, types, ^(id self, XZPageView *scrollView) {
            if ([scrollView isKindOfClass:[XZPageView class]]) {
                imp(scrollView, sel, scrollView);
            }
        }, ^(id self, XZPageView *scrollView) {
            if ([scrollView isKindOfClass:[XZPageView class]]) {
                imp(scrollView, sel, scrollView);
            }
            struct objc_super super = {
                .receiver = self,
                .super_class = class_getSuperclass(object_getClass(self))
            };
            ((void(*)(struct objc_super *, SEL, UIScrollView *))objc_msgSendSuper)(&super, sel, scrollView);
        }, ^id _Nonnull(SEL  _Nonnull selector) {
            return ^(id self, XZPageView *scrollView) {
                if ([scrollView isKindOfClass:[XZPageView class]]) {
                    imp(scrollView, sel, scrollView);
                }
                ((void(*)(id, SEL, UIScrollView *))objc_msgSend)(self, selector, scrollView);
            };
        });
    }
    
    {
        typedef void (*MethodType)(id, SEL, UIScrollView *);
        SEL          const sel   = @selector(scrollViewDidEndScrollingAnimation:);
        MethodType   const imp   = (MethodType)class_getMethodImplementation([XZPageView class], sel);
        const char * const types = protocol_getMethodDescription(@protocol(UIScrollViewDelegate), sel, NO, YES).types;
        xz_objc_class_addMethodWithBlock(aClass, sel, types, ^(id self, XZPageView *scrollView) {
            if ([scrollView isKindOfClass:[XZPageView class]]) {
                imp(scrollView, sel, scrollView);
            }
        }, ^(id self, XZPageView *scrollView) {
            if ([scrollView isKindOfClass:[XZPageView class]]) {
                imp(scrollView, sel, scrollView);
            }
            struct objc_super super = {
                .receiver = self,
                .super_class = class_getSuperclass(object_getClass(self))
            };
            ((void(*)(struct objc_super *, SEL, UIScrollView *))objc_msgSendSuper)(&super, sel, scrollView);
        }, ^id _Nonnull(SEL  _Nonnull selector) {
            return ^(id self, XZPageView *scrollView) {
                if ([scrollView isKindOfClass:[XZPageView class]]) {
                    imp(scrollView, sel, scrollView);
                }
                ((void(*)(id, SEL, UIScrollView *))objc_msgSend)(self, selector, scrollView);
            };
        });
    }
}

@end
