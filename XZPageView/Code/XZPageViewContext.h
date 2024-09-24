//
//  XZPageViewContext.h
//  XZPageView
//
//  Created by 徐臻 on 2024/9/24.
//

#import <Foundation/Foundation.h>
#import <XZPageView/XZPageViewDefines.h>

NS_ASSUME_NONNULL_BEGIN

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

@interface XZPageViewContext : NSObject {
    @package
    XZPageView * __unsafe_unretained _pageView;
}

- (instancetype)init NS_UNAVAILABLE;
+ (XZPageViewContext *)contextWithPageView:(XZPageView *)pageView orientation:(XZPageViewOrientation)orientation;

// 以下方法作为 XZPageView 的私有方法，子类不应重写它们。

/// 辅助 XZPageView 初始化，仅在初始化方法中才可以调用。
- (instancetype)didInitialize;

- (void)layoutSubviews:(CGSize)size;
- (void)reloadCurrentPageView:(CGSize const)bounds;
- (void)reloadReusingPageView:(CGSize const)bounds;

- (void)scheduleAutoPagingTimerIfNeeded;
- (void)autoPagingTimerAction:(NSTimer *)timer;
- (void)holdOnAutoPagingTimer;
- (void)resumeAutoPagingTimer;

- (void)willSetDelegate:(nullable Class)aClass;
- (void)notifyDidTurnPage:(nonnull Class)aClass;
- (void)notifyDidShowPage:(nonnull Class)aClass;

// 子类需要重写的方法。

- (void)layoutCurrentPageView:(CGSize const)bounds;
- (void)layoutReusingPageView:(CGSize const)bounds;
- (void)adjustContentInsets:(CGSize const)bounds;

- (void)didScroll:(BOOL)stopped;
- (void)didScrollToReusingPage:(CGSize const)bounds maxPage:(NSInteger const)maxPage direction:(BOOL const)direction;

/// 不处理、发送事件。
- (void)setCurrentPage:(NSInteger)newPage animated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
