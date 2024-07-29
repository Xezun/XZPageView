//
//  XZPageViewManager.h
//  XZPageView
//
//  Created by 徐臻 on 2024/7/28.
//

#import <Foundation/Foundation.h>
#import <XZPageView/XZPageViewDefines.h>

NS_ASSUME_NONNULL_BEGIN

@class XZPageView;

typedef void (^XZPageViewDidShowBlock)(XZPageView *pageView, NSInteger currentPage);
typedef void (^XZPageViewDidTransitionBlock)(XZPageView *pageView, CGFloat distance, CGFloat pageWidth, NSInteger from, NSInteger to);

@interface XZPageViewManager : NSObject

+ (XZPageViewManager *)managerForPageView:(XZPageView *)pageView direction:(XZPageViewDirection)direction;

@property (nonatomic, readonly) UIScrollView *scrollView;

- (void)layoutSubviews:(CGRect const)bounds;
- (void)reloadData;
- (void)delegateDidChange:(id<XZPageViewDelegate>)delegate;
- (void)isLoopedDidChange:(BOOL)isLooped;

- (void)scrollViewDidScroll:(UIScrollView *)scrollView stopped:(BOOL)stopped;
- (void)didScrollToReusingPage:(CGRect const)bounds maxPage:(NSInteger const)maxPage direction:(BOOL const)direction;
- (void)reloadCurrentPageView:(CGRect const)bounds;
- (void)layoutCurrentPageView:(CGRect const)bounds;
- (void)reloadReusingPageView:(CGRect const)bounds;
- (void)layoutReusingPageView:(CGRect const)bounds;
- (void)scheduleAutoPagingTimerIfNeeded;
- (void)holdOnAutoPagingTimer;
- (void)resumeAutoPagingTimer;
- (void)setCurrentPage:(NSInteger)newPage animated:(BOOL)animated;
- (void)adjustContentInsets:(CGRect const)bounds;
- (nullable XZPageViewDidShowBlock)notifyDidShowPage:(nonnull Class)aClass;
- (nullable XZPageViewDidTransitionBlock)notifyDidTransitionPage:(nonnull Class)aClass;

@end

NS_ASSUME_NONNULL_END
