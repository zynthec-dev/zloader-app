#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
int ZLoaderRunContainerHost(int argc, char * _Nullable * _Nonnull argv);
UIViewController *ZLoaderContainerAppsController(UIColor *background);
UIViewController *ZLoaderContainerSettingsController(void (^onClose)(void));
NSArray<UIBarButtonItem *> *ZLoaderContainerToolbarItems(void);
BOOL ZLoaderHandleContainerURL(NSURL *url);
void ZLoaderImportContainerIPA(NSURL *url);
BOOL ZLoaderSetContainerSigningIdentity(NSData *data, NSString *password, NSError * _Nullable * _Nullable error);
BOOL ZLoaderContainerSigningAvailable(void);
void ZLoaderClearContainerSigningIdentity(void);
NS_ASSUME_NONNULL_END
