#
# Be sure to run `pod lib lint XZPageView.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'XZPageView'
  s.version          = '1.2.4'
  s.summary          = 'XZPageView 是一款管理分页视图高效组件'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
                       组件 XZPageView 的分页，支持使用自定义视图，支持自动轮播、循环轮播。
                       DESC

  s.homepage         = 'https://github.com/Xezun/XZPageView'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Xezun' => 'developer@xezun.com' }
  s.source           = { :git => 'https://github.com/Xezun/XZPageView.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '11.0'
  s.pod_target_xcconfig = { 'GCC_PREPROCESSOR_DEFINITIONS' => 'XZPAGEVIEW_FRAMEWORK=1' }
  
  s.subspec 'Code' do |ss|
    ss.source_files = 'XZPageView/Code/**/*.{h,m}'
    # ss.project_header_files = 'XZPageView/Code/**/Private/*.{h,m}'
  end
  
  # s.resource_bundles = {
  #   'XZPageView' => ['XZPageView/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end

