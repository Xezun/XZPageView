//
//  ViewController.m
//  Example
//
//  Created by Xezun on 2023/7/27.
//

#import "ViewController.h"
@import XZPageControl;
@import XZPageView;
@import SDWebImage;

@interface ViewController () <XZPageViewDelegate, XZPageViewDataSource>
@property (weak, nonatomic) IBOutlet XZPageView *pageView;
@property (weak, nonatomic) IBOutlet XZPageControl *pageControl;

@property (nonatomic) NSInteger count;
@property (nonatomic, copy) NSArray *imageURLs;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.imageURLs = @[
        [NSURL URLWithString:@"https://img.ithome.com/newsuploadfiles/focus/df38e2b4-31bb-447f-9987-ce04368696c5.jpg"],
        [NSURL URLWithString:@"https://img.ithome.com/newsuploadfiles/focus/3b1ef5df-f143-44dd-9d36-c93867b2529c.jpg"],
        [NSURL URLWithString:@"https://img.ithome.com/newsuploadfiles/focus/108363a8-ff04-4784-9640-981183e81066.jpg"],
        [NSURL URLWithString:@"https://img.ithome.com/newsuploadfiles/focus/4677eadf-99bf-4112-8bc6-68a487a427eb.jpg"],
        [NSURL URLWithString:@"https://img.ithome.com/newsuploadfiles/focus/dd138b93-a114-4c27-b96d-e9853319907f.jpg"]
    ];
    self.count = self.imageURLs.count;
    
    self.pageView.isLoopable = YES;
    // self.pageView.autoPagingInterval = 5.0;
    
    self.pageView.delegate = self;
    self.pageView.dataSource = self;
    
    self.pageControl.numberOfPages = self.count;
    self.pageControl.indicatorFillColor = UIColor.whiteColor;
    self.pageControl.currentIndicatorFillColor = UIColor.orangeColor;
    [self.pageControl addTarget:self action:@selector(pageControlDidChangeValue:) forControlEvents:(UIControlEventValueChanged)];
}

- (NSInteger)numberOfPagesInPageView:(XZPageView *)pageView {
    return self.count;
}

- (UIView *)pageView:(XZPageView *)pageView viewForPageAtIndex:(NSInteger)index reusingView:(UIImageView *)reusingView {
    if (reusingView == nil) {
        reusingView = [[UIImageView alloc] initWithFrame:pageView.bounds];
    }
    [reusingView sd_setImageWithURL:self.imageURLs[index]];
    return reusingView;
}

- (nullable UIView *)pageView:(XZPageView *)pageView prepareForReusingView:(UIImageView *)reusingView {
    reusingView.image = nil;
    return reusingView;
}

- (void)pageView:(XZPageView *)pageView didPageToIndex:(NSInteger)index {
    NSLog(@"didPageToIndex: %ld", index);
    self.pageControl.currentPage = index;
}

- (void)pageControlDidChangeValue:(XZPageControl *)pageControl {
    [self.pageView setCurrentPage:pageControl.currentPage animated:YES];
}

- (IBAction)loopableSwitchAction:(UISwitch *)sender {
    self.pageView.isLoopable = sender.isOn;
}

- (IBAction)autoPagingSwitchAction:(UISwitch *)sender {
    self.pageView.autoPagingInterval = sender.isOn ? 3.0 : 0;
}

- (IBAction)countSegmentAction:(UISegmentedControl *)sender {
    self.count = sender.selectedSegmentIndex;
    [self.pageView reloadData];
    self.pageControl.numberOfPages = self.count;
}

- (IBAction)bouncesSwitchAction:(UISwitch *)sender {
    self.pageView.bounces = sender.isOn;
}

@end
