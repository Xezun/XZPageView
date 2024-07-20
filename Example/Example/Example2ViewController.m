//
//  Example2ViewController.m
//  Example
//
//  Created by 徐臻 on 2024/7/13.
//

#import "Example2ViewController.h"
@import XZSegmentedControl;
@import XZPageView;

@interface Example2ViewController () <XZPageViewDelegate, XZPageViewDataSource>

@property (weak, nonatomic) IBOutlet XZSegmentedControl *segmentedControl;
@property (weak, nonatomic) IBOutlet XZPageView *pageView;

@property (nonatomic, copy) NSArray *titles;

@end

@implementation Example2ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.titles = @[@"业界", @"手机", @"电脑", @"测评", @"视频", @"AI", @"苹果", @"鸿蒙", @"软件", @"数码"];
    
    self.segmentedControl.backgroundColor = UIColor.whiteColor;
    self.segmentedControl.indicatorSize = CGSizeMake(20, 4.0);
    self.segmentedControl.indicatorColor = UIColor.redColor;
    self.segmentedControl.interitemSpacing = 10;
    self.segmentedControl.headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
    self.segmentedControl.footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
    self.segmentedControl.titles = self.titles;
    [self.segmentedControl addTarget:self action:@selector(segmentedControlValueChanged:) forControlEvents:(UIControlEventValueChanged)];
    
    self.pageView.isLooped = NO;
    self.pageView.delegate = self;
    self.pageView.dataSource = self;
}

- (void)segmentedControlValueChanged:(XZSegmentedControl *)sender {
    [self.pageView setCurrentPage:sender.selectedIndex animated:YES];
}

- (void)pageView:(XZPageView *)pageView didShowPageAtIndex:(NSInteger)index {
    NSLog(@"didPageToIndex: %ld", index);
    [self.segmentedControl setSelectedIndex:index animated:YES];
}

- (void)pageView:(XZPageView *)pageView didTransitionPage:(CGFloat)transition {
    NSLog(@"didTransitionPage: %f", transition);
    [self.segmentedControl updateInteractiveTransition:transition];
}

- (NSInteger)numberOfPagesInPageView:(XZPageView *)pageView {
    return self.titles.count;
}

- (UIView *)pageView:(XZPageView *)pageView viewForPageAtIndex:(NSInteger)index reusingView:(UILabel *)reusingView {
    if (reusingView == nil) {
        reusingView = [[UILabel alloc] init];
        reusingView.font = [UIFont boldSystemFontOfSize:32];
        reusingView.textAlignment = NSTextAlignmentCenter;
        reusingView.numberOfLines = 0;
    }
    reusingView.text = [NSString stringWithFormat:@"%@\n\n- 第 %ld 页 -", self.titles[index], (long)index];
    return reusingView;
}

- (nullable UIView *)pageView:(nonnull XZPageView *)pageView prepareForReusingView:(nonnull __kindof UIView *)reusingView {
    return reusingView;
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
