Pod::Spec.new do |s|
  macro_flags = '-load-plugin-executable ${PODS_ROOT}/TKMacros/Prebuilt/TKMacrosExecutable#TKMacrosExecutable -enable-experimental-feature SymbolLinkageMarkers'

  s.name = 'TKRouter'
  s.version = '0.1.0'
  s.summary = 'A type-safe Swift URL router with macro-based automatic registration'
  s.homepage = 'https://github.com/FeliksLv01/TKRouter'
  s.license = { :type => 'MIT', :file => 'LICENSE' }
  s.author = { 'FeliksLv01' => 'felikslv@163.com' }
  s.source = { :git => 'https://github.com/FeliksLv01/TKRouter.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'
  s.swift_version = '6.0'
  s.source_files = 'Sources/TKRouter/**/*.swift'
  s.user_target_xcconfig = {
    'OTHER_SWIFT_FLAGS' => macro_flags
  }

  s.dependency 'TKMacros', '>= 0.0.4'

  s.test_spec 'Tests' do |ts|
    ts.source_files = 'Tests/TKRouterTests/**/*.swift'
    ts.pod_target_xcconfig = {
      'OTHER_SWIFT_FLAGS' => macro_flags
    }
  end
end
