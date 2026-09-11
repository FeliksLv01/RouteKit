Pod::Spec.new do |s|
  pod_macro_flags = '-load-plugin-executable ${PODS_TARGET_SRCROOT}/Prebuilt/RouteKitMacros#RouteKitMacros -enable-experimental-feature SymbolLinkageMarkers'
  user_macro_flags = '-load-plugin-executable ${PODS_ROOT}/RouteKit/Prebuilt/RouteKitMacros#RouteKitMacros -enable-experimental-feature SymbolLinkageMarkers'

  s.name = 'RouteKit'
  s.version = '0.0.1'
  s.summary = 'A type-safe Swift URL router with macro-based automatic registration'
  s.homepage = 'https://github.com/FeliksLv01/RouteKit'
  s.license = { :type => 'MIT', :file => 'LICENSE' }
  s.author = { 'FeliksLv01' => 'felikslv@163.com' }
  s.source = { :git => 'https://github.com/FeliksLv01/RouteKit.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'
  s.swift_version = '6.0'
  s.source_files = 'Sources/RouteKit/**/*.swift', 'RouteKitMacros/Sources/RouteKitMacro/**/*.swift'
  s.preserve_paths = 'Prebuilt/RouteKitMacros'
  s.pod_target_xcconfig = {
    'OTHER_SWIFT_FLAGS' => pod_macro_flags
  }
  s.user_target_xcconfig = {
    'OTHER_SWIFT_FLAGS' => user_macro_flags
  }

  s.test_spec 'Tests' do |ts|
    ts.source_files = 'Tests/RouteKitTests/**/*.swift'
    ts.pod_target_xcconfig = {
      'OTHER_SWIFT_FLAGS' => pod_macro_flags
    }
  end
end
