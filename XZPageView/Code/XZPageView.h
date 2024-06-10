//
//  XZPageView.h
//  XZKit
//
//  Created by Xezun on 2021/9/7.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 翻页效果动画时长。
FOUNDATION_EXPORT NSTimeInterval const XZPageViewAnimationDuration;

@class XZPageView;

/// XZPageView 数据源。
@protocol XZPageViewDataSource <NSObject>

@required
/// 在此方法中返回元素的个数。
/// @param pageView 调用此方法的对象
- (NSInteger)numberOfPagesInPageView:(XZPageView *)pageView;

/// 加载视图。在此方法中创建或重用页面视图，配置并返回它们。
/// @discussion 在页面切换过程中，被切换掉的视图会保留在 XZPageView 中作为备用视图：
/// @discussion 1、切回原来的视图时，就不需要再次该视图。
/// @discussion 2、切换到其它视图时，该视图将作为 reusingView 加载目标视图。
/// @param pageView 调用此方法的对象
/// @param index 元素的索引
/// @param reusingView 可重用的视图
- (UIView *)pageView:(XZPageView *)pageView viewForPageAtIndex:(NSInteger)index reusingView:(nullable __kindof UIView *)reusingView;

/// 重置视图以备重用。
/// @discussion 当 XZPageView 不确定是否能够重用时，将调用此方法。
/// @discussion 比如，当方法 reloadData 被调用时，当前视图及备用视图，可能都无法重用，因此 XZPageView 将调用此方法，并将返回的视图缓存以备重用。
/// @discussion 直接重用的视图，不会调用的方法。
/// @param pageView 调用此方法的对象
/// @param reusingView 需要被重置的视图
- (nullable UIView *)pageView:(XZPageView *)pageView prepareForReusingView:(__kindof UIView *)reusingView;

@end

/// XZPageView 事件方法列表。
@protocol XZPageViewDelegate <NSObject>

@required
/// 翻页到某页时，此方法会被调用。
/// @discussion 只有用户操作或者自动翻页会触发此代理方法。
/// @param pageView 调用此方法的对象
/// @param index 被展示元素的索引，不会是 NSNotFound
- (void)pageView:(XZPageView *)pageView didPageToIndex:(NSInteger)index;

@end

/// 翻页视图：支持多视图横向滚动翻页的视图。
@interface XZPageView : UIView <UIScrollViewDelegate>

@property (nonatomic, strong, readonly) UIScrollView *scrollView;

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
@property (nonatomic, weak) id<XZPageViewDataSource> dataSource;

/// 重新加载。
/// @note 会保持尽量当前的 currentPage 但不会超过最大页数。
/// @note 自动翻页计时会重置。
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
