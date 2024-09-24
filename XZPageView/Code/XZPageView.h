//
//  XZPageView.h
//  XZKit
//
//  Created by Xezun on 2021/9/7.
//

#import <UIKit/UIKit.h>
#import <XZPageView/XZPageViewDefines.h>

NS_ASSUME_NONNULL_BEGIN

/// 翻页视图：支持多视图横向滚动翻页的视图。
@interface XZPageView : UIScrollView <UIScrollViewDelegate> {
    @package
    BOOL                _isLooped;
    NSInteger           _numberOfPages;
    UIView  * _Nullable _currentPageView;
    NSInteger           _currentPage;
    UIView  * _Nullable _reusingPageView;
    NSInteger           _reusingPage;
    BOOL                _reusingPageDirection; ///< YES 表示加载在正向滚动的方向上，NO 表示加载在反向滚动的方向上。
    
    NSTimeInterval      _autoPagingInterval;
    /// 自动翻页定时器，请使用方法操作计时器，而非直接使用变量。
    /// 1、视图必须添加到 window 上，才会创建定时器。
    /// 2、从 widow 上移除会销毁定时器，并在再次添加到 window 上时重建。
    /// 3、滚动的过程中，定时器会暂停，并在滚动后重新开始计时。
    /// 4、刷新数据，定时器会重新开始计时。
    /// 5、改变 currentPage 定时器会重新计时。
    NSTimer * _Nullable __unsafe_unretained _autoPagingTimer;
    
    void (^ _Nullable _didShowPage)(XZPageView *pageView, NSInteger currentPage);
    void (^ _Nullable _didTurnPage)(XZPageView *pageView, CGFloat x, CGFloat width, NSInteger from, NSInteger to);
}

- (instancetype)initWithFrame:(CGRect)frame orientation:(XZPageViewOrientation)orientation NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;

/// 翻页方向，默认横向。支持在 IB 中设置，使用 0 表示横向，使用 1 表示纵向。
#if TARGET_INTERFACE_BUILDER
@property (nonatomic) IBInspectable NSUInteger orientation;
#else
@property (nonatomic) XZPageViewOrientation orientation;
#endif

/// 是否为循环模式。默认 YES 。
/// @discussion 循环模式下，不管在任何位置都可以向前或者向后翻页。
/// @discussion 在最大页向后翻页会到第一页，在第一页向前翻页则会到最后一页。
@property (nonatomic, setter=setLooped:) BOOL isLooped;

/// 页面的数量。
@property (nonatomic, readonly) NSInteger numberOfPages;

/// 当前页面，默认值 0 。
/// @attention 设置此属性不会触发代理方法。
@property (nonatomic) NSInteger currentPage;

/// 设置当前展示视图。
/// @discussion 调用此方法改变当前页，会重置自动翻页计时。
/// @discussion 调用此方法不会触发代理事件。
/// @discussion 翻页动画时长 XZPageViewAnimationDuration 为 0.35 秒，与原生控制器转场时长相同。
/// @discussion 动画时长，可以通过如下方式覆盖。
/// @code
/// [UIView animateWithDuration:1.0 animations:^{
///     [self.pageView setCurrentPage:3 animated:YES];
/// }];
/// @endcode
/// @param currentPage 待展示的视图的索引
/// @param animated 是否动画
- (void)setCurrentPage:(NSInteger)currentPage animated:(BOOL)animated;

/// 事件代理。
@property (nonatomic, weak) id<XZPageViewDelegate> delegate;
/// 数据源。
@property (nonatomic, weak) id<XZPageViewDataSource> dataSource;

/// 重新加载。
/// @discussion 会保持尽量当前的 currentPage 但不会超过最大页数。
/// @discussion 自动翻页计时会重置。
- (void)reloadData;

/// 自动翻到下一页的时间间隔，单位秒，不包括翻页动画时长。
@property (nonatomic) NSTimeInterval autoPagingInterval;

// MARK: - 重写父类的方法
- (void)didMoveToWindow NS_REQUIRES_SUPER;

// MARK: - UIScrollViewDelegate

// 由于属性 isDragging/isDecelerating 的更新在 contentOffset/bounds.origin 更新之后，
// 所以在无法判断 contentOffset/bounds.origin 变化时的滚动状态，继而无法判断翻页状态。
// 因此 XZPageView 监听了代理方法来解决相关问题：
// 默认 delegate 会被设置为自身；如果外部设置代理，则会通过运行时，向目标注入处理事件的逻辑。

- (void)scrollViewDidScroll:(UIScrollView *)scrollView NS_REQUIRES_SUPER;
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView NS_REQUIRES_SUPER;
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate NS_REQUIRES_SUPER;
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView NS_REQUIRES_SUPER;

@end

NS_ASSUME_NONNULL_END
