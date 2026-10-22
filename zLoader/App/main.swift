import UIKit

#if os(tvOS)
UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(AppDelegate.self))
#else
exit(ZLoaderRunContainerHost(CommandLine.argc, CommandLine.unsafeArgv))
#endif
