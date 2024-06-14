//
//  XZPageViewController.m
//  XZPageView
//
//  Created by Xezun on 2024/6/13.
//

#import "XZPageViewController.h"
#import "XZPageView.h"

@interface XZPageViewController () <XZPageViewDelegate, XZPageViewDataSource>

@end

@implementation XZPageViewController

- (void)loadView {
    super.view = [[XZPageView alloc] initWithFrame:UIScreen.mainScreen.bounds];
}

- (void)setView:(UIView *)view {
    NSParameterAssert([view isKindOfClass:[XZPageView class]]);
    [super setView:view];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    XZPageView *pageView = self.pageView;
    pageView.delegate = self;
    pageView.dataSource = self;
}

- (BOOL)shouldAutomaticallyForwardAppearanceMethods {
    return NO;
}

- (NSInteger)numberOfPagesInPageView:(XZPageView *)pageView {
    return [self.dataSource numberOfPagesInPageViewController:self];
}

- (UIView *)pageView:(XZPageView *)pageView viewForPageAtIndex:(NSInteger)index reusingView:(__kindof UIView *)reusingView {
    UIViewController *viewController = [self.dataSource pageViewController:self viewControllerForPageAtIndex:index];
    [self addChildViewController:viewController];
    return viewController.view;
}

- (void)pageView:(XZPageView *)pageView didShowPageAtIndex:(NSInteger)index {
    
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
