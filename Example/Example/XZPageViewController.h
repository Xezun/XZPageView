//
//  XZPageViewController.h
//  XZPageView
//
//  Created by Xezun on 2024/6/13.
//

#import <UIKit/UIKit.h>
#import <XZPageView/XZPageView.h>

NS_ASSUME_NONNULL_BEGIN

@class XZPageViewController, UIPageViewController;

@protocol XZPageViewControllerDataSource <NSObject>

- (NSInteger)numberOfPagesInPageViewController:(XZPageViewController *)pageViewController;
- (UIViewController *)pageViewController:(XZPageViewController *)pageViewController viewControllerForPageAtIndex:(NSInteger)index;

@end

@interface XZPageViewController : UIViewController

@property (nonatomic, readonly) XZPageView *pageView;

@property (nonatomic, weak) id<XZPageViewControllerDataSource> dataSource;
@property (nonatomic, weak) id<XZPageViewDataSource> delegate;


@end

NS_ASSUME_NONNULL_END
