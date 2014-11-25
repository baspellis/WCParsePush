Pod::Spec.new do |s|
  s.name             = "WCParsePush"
  s.version          = "1.1"
  s.summary          = "Lightweight Push Notifications with Parse."
  s.description      = <<-DESC
                       This small library provides simple interface to the Parse Push Notification Service without the need to include the full Parse iOS SDK. It inlcudes:

                       * Device installation registration
                       * Channel subscribe/unsubscribe
                       * Async and synchoronous save methods
                       * Save eventually also after app restart
                       DESC
  s.homepage         = "https://github.com/baspellis/WCParsePush"
  s.license          = 'MIT'
  s.author           = { "Bas Pellis" => "bas@pellis.nl" }
  s.source           = { :git => "https://github.com/baspellis/WCParsePush.git", :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/baspellis'

  s.platform     = :ios, '7.0'
  s.requires_arc = true

  s.source_files = 'WCParsePush'

  s.dependency 'KSReachability', '~> 1.4'  
end
