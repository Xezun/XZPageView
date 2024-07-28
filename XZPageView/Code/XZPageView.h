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
@interface XZPageView : UIView <UIScrollViewDelegate>

@property (nonatomic, strong, readonly) UIScrollView *scrollView;

/// 翻页方向。支持在 IB 中设置，使用 0 表示横向，使用 1 表示纵向。
#if TARGET_INTERFACE_BUILDER
@property (nonatomic) IBInspectable NSInteger direction;
#else
@property (nonatomic) XZPageViewDirection direction;
#endif

- (instancetype)initWithFrame:(CGRect)frame direction:(XZPageViewDirection)direction NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;
/// 是否为循环模式。默认 YES 。
/// @discussion 循环模式下，不管在任何位置都可以向前或者向后翻页。
/// @discussion 在最大页向后翻页会到第一页，在第一页向前翻页则会到最后一页。
@property (nonatomic, setter=setLooped:) BOOL isLooped;

/// 弹簧效果，默认 NO 关闭弹簧效果。
/// @discussion 只有在单页时才有效果。
@property (nonatomic) BOOL bounces;

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
/// @discussion 设置数据源立即调用 `-reloadData` 方法。
@property (nonatomic, weak) id<XZPageViewDataSource> dataSource;

/// 重新加载。
/// @discussion 会保持尽量当前的 currentPage 但不会超过最大页数。
/// @discussion 自动翻页计时会重置。
- (void)reloadData;

/// 自动翻到下一页的时间间隔，单位秒，不包括翻页动画时长。
@property (nonatomic) NSTimeInterval autoPagingInterval;

// MARK: - 重写父类的方法
- (void)didMoveToWindow NS_REQUIRES_SUPER;
- (void)layoutSubviews NS_REQUIRES_SUPER;

// MARK: - UIScrollViewDelegate
- (void)scrollViewDidScroll:(UIScrollView *)scrollView NS_REQUIRES_SUPER;
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView NS_REQUIRES_SUPER;
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate NS_REQUIRES_SUPER;
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView NS_REQUIRES_SUPER;

@end

@interface XZPageView (XZPageViewDeprecated)
@property (nonatomic, getter=isLooped, setter=setLooped:) BOOL isLoopable API_DEPRECATED_WITH_REPLACEMENT("isLooped", ios(1.0, 1.0), watchos(1.0, 1.0), tvos(1.0, 1.0));
@end

NS_ASSUME_NONNULL_END
