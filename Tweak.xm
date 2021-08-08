#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

#define NSLog(args...) NSLog(@"[BonjourSafari] "args)

static NSString * const BonjourSafariLocaleChangedNotification = @"BonjourSafariLocaleChangedNotification";
static SEL _actionSelector;

static NSString *BonjourSafari_GetLocale(void) {
	NSString *locale = [[NSUserDefaults standardUserDefaults] objectForKey:@"BonjourSafari_Locale"];
	if (![locale length]) {
		return nil;
	}
	return locale;
}

static void BonjourSafari_SetLocale(NSString *newLocale) {
	[[NSUserDefaults standardUserDefaults] setObject:newLocale forKey:@"BonjourSafari_Locale"];
	[[NSNotificationCenter defaultCenter]
		postNotificationName:BonjourSafariLocaleChangedNotification
		object:nil
	];
}

static NSString *BonjourSafari_GetHTTPLocale(void) {
	NSString *locale = BonjourSafari_GetLocale();
	if (!locale) return nil;
	NSArray *components = [locale componentsSeparatedByString:@"-"];
	NSString *value = [NSString stringWithFormat:@"%@,%@", locale, components[0]];
	return value;
}

static NSURLRequest *BonjourSafari_CreateRequest(NSURLRequest *oldRequest) {
	NSString *locale = BonjourSafari_GetLocale();
	if (!locale) return oldRequest;
	NSMutableURLRequest *mutableRequest = [oldRequest mutableCopy];
	[mutableRequest setValue:BonjourSafari_GetHTTPLocale() forHTTPHeaderField:@"Accept-Language"];
	return [mutableRequest copy];
}

@interface BonjourSafari_ChangeLocaleActivity : UIActivity<UITextFieldDelegate>
@end

@implementation BonjourSafari_ChangeLocaleActivity

- (UIActivityType)activityType {
	return @"com.pixelomer.ohayoo-safari.change-locale";
}

- (NSString *)activityTitle {
	return @"Change Locale";
}

- (UIImage *)activityImage {
	return [UIImage systemImageNamed:@"globe"];
}

- (BOOL)canPerformWithActivityItems:(NSArray *)items {
	return YES;
}

- (void)prepareWithActivityItems:(NSArray *)activityItems {

}

- (UIActivityCategory)activityCategory {
	return UIActivityCategoryAction;
}

- (void)textFieldTextDidChange:(UITextField *)textField {
	NSRegularExpression *expression = [NSRegularExpression
		regularExpressionWithPattern:@"^(?:[a-z]{2}-[A-Z]{2})?$"
		options:0
		error:nil
	];
	NSTextCheckingResult *result = [expression
		firstMatchInString:textField.text
		options:0
		range:NSMakeRange(0, textField.text.length)
	];
	UIAlertAction *action = objc_getAssociatedObject(textField, _actionSelector);
	action.enabled = (result != nil);
}

- (UIViewController *)activityViewController {
	static dispatch_once_t token;
	static NSArray *titles;
	dispatch_once(&token, ^{
		titles = @[
			@"Bonjour, Safari!",
			@"Hallo, Safari!",
			@"Salve, Safari!",
			@"Pozdravljeni, Safari!",
			@"Dia duit, Safari!",
			@"Ciao, Safari!",
			@"こんにちは、サファリ！",
			@"你好，Safari！",
			@"¡Hola, Safari!",
			@"Merhaba, Safari!"
		];
	});
	UIAlertController *alert = [UIAlertController
		alertControllerWithTitle:titles[arc4random_uniform(titles.count)]
		message:@"Type the locale you want to use (example: en-US). Make the locale empty to use system defaults."
		preferredStyle:UIAlertControllerStyleAlert
	];
	UIAlertAction *changeAction = [UIAlertAction
		actionWithTitle:@"Change"
		style:UIAlertActionStyleDefault
		handler:^(UIAlertAction *action) {
			BonjourSafari_SetLocale([alert.textFields firstObject].text);
		}
	];
	[alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
		textField.text = BonjourSafari_GetLocale();
		textField.placeholder = @"(unset)";
		textField.delegate = self;
		[textField addTarget:self action:@selector(textFieldTextDidChange:) forControlEvents:UIControlEventEditingChanged];
		objc_setAssociatedObject(textField, _actionSelector, changeAction, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}];
	[alert addAction:changeAction];
	[alert addAction:[UIAlertAction
		actionWithTitle:@"Cancel"
		style:UIAlertActionStyleCancel
		handler:nil
	]];
	return alert;
}

@end

@interface WKUserContentController(BonjourSafari)
- (WKUserScript *)BonjourSafari_script;
- (void)BonjourSafari_addScript;
- (void)setBonjourSafari_script:(WKUserScript *)script;
@end

%hook WKUserContentController
%property (nonatomic, strong) WKUserScript *BonjourSafari_script;

%new
- (void)BonjourSafari_addScript {
	if (!self.BonjourSafari_script) {
		NSString *locale = BonjourSafari_GetLocale();
		self.BonjourSafari_script = [[WKUserScript alloc]
			initWithSource:(locale ? [NSString stringWithFormat:@"Object.defineProperty(window.navigator, 'language', { value: '%@', writable: false });", locale] : @"")
			injectionTime:WKUserScriptInjectionTimeAtDocumentStart
			forMainFrameOnly:NO
		];
	}
	if (![[self userScripts] containsObject:self.BonjourSafari_script]) {
		[self addUserScript:self.BonjourSafari_script];
	}
}

%new
- (void)BonjourSafari_localeDidChange:(NSNotification *)notification {
	self.BonjourSafari_script = nil;
	[self removeAllUserScripts];
}

- (WKUserContentController *)init {
	WKUserContentController *controller = %orig;
	if (!controller) {
		return nil;
	}
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(BonjourSafari_localeDidChange:)
		name:BonjourSafariLocaleChangedNotification
		object:nil
	];
	[controller BonjourSafari_addScript];
	return controller;
}

- (void)removeAllUserScripts {
	%orig;
	[self BonjourSafari_addScript];
}

%end

%hook WKWebView

- (WKWebView *)initWithFrame:(CGRect)frame configuration:(WKWebViewConfiguration *)configuration {
	[[configuration userContentController] BonjourSafari_addScript];
	return %orig;
}

- (WKNavigation *)loadRequest:(NSURLRequest *)request {
	return %orig(BonjourSafari_CreateRequest(request));
}

%end

@interface _WKCustomHeaderFields : NSObject
@property (copy, nonatomic) NSDictionary *fields;
@end

@interface WKWebpagePreferences(Private)
- (_WKCustomHeaderFields *)_customHeaderFields;
- (void)_setCustomHeaderFields:(NSArray<_WKCustomHeaderFields *> *)customHeaderFields;
@end

%hook TabDocument

//FIXME: This doesn't work
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction preferences:(WKWebpagePreferences *)preferences decisionHandler:(void (^)(WKNavigationActionPolicy, WKWebpagePreferences *))decisionHandler {
	_WKCustomHeaderFields *fields = [_WKCustomHeaderFields new];
	fields.fields = @{ @"Accept-Language": BonjourSafari_GetHTTPLocale() };
	[preferences _setCustomHeaderFields:@[fields]];
	%orig;
}

%end

%hook UIActivityViewController

- (instancetype)initWithActivityItems:(NSArray *)activityItems applicationActivities:(NSArray<__kindof UIActivity *> *)applicationActivities {
	NSMutableArray *newApplicationActivities = [applicationActivities mutableCopy];
	[newApplicationActivities addObject:[BonjourSafari_ChangeLocaleActivity new]];
	return %orig(activityItems, [newApplicationActivities copy]);
}

%end

%ctor {
	_actionSelector = @selector(textField);
}