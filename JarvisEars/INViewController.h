#import <UIKit/UIKit.h>

@class PocketsphinxController;
@class FliteController;
#import <OpenEars/OpenEarsEventsObserver.h> // We need to import this here in order to use the delegate.

@interface INViewController : UIViewController <OpenEarsEventsObserverDelegate> {
	
	// These three are important OpenEars classes that ViewController demonstrates the use of. There is a fourth important class (LanguageModelGenerator) demonstrated
	// inside the ViewController implementation in the method viewDidLoad.
	
	OpenEarsEventsObserver *openEarsEventsObserver; // A class whose delegate methods which will allow us to stay informed of changes in the Flite and Pocketsphinx statuses.
	PocketsphinxController *pocketsphinxController; // The controller for Pocketsphinx (voice recognition).
	FliteController *fliteController; // The controller for Flite (speech).
        
	BOOL usingStartLanguageModel;
	
	// Strings which aren't required for OpenEars but which will help us show off the dynamic language features in this sample app.
	NSString *pathToGrammarToStartAppWith;
	NSString *pathToDictionaryToStartAppWith;
	
	NSString *pathToDynamicallyGeneratedGrammar;
	NSString *pathToDynamicallyGeneratedDictionary;
	
	// Strings which aren't required for OpenEars but which will help us show off the dynamic voice features in this sample app.
	NSString *firstVoiceToUse;
	NSString *secondVoiceToUse;
	
	// Our NSTimer that will help us read and display the input and output levels without locking the UI
	NSTimer *uiUpdateTimer;
    
    Float32 currentVolume;
    
    Float32 lastPeakVolume;
    
    BOOL recordVolume;
}

// These three are the important OpenEars objects that this class demonstrates the use of.

@property (nonatomic, strong) OpenEarsEventsObserver *openEarsEventsObserver;
@property (nonatomic, strong) PocketsphinxController *pocketsphinxController;
@property (nonatomic, strong) FliteController *fliteController;

@property (nonatomic, assign) BOOL usingStartLanguageModel;

// Things which help us show off the dynamic language features.
@property (nonatomic, copy) NSString *pathToGrammarToStartAppWith;
@property (nonatomic, copy) NSString *pathToDictionaryToStartAppWith;
@property (nonatomic, copy) NSString *pathToDynamicallyGeneratedGrammar;
@property (nonatomic, copy) NSString *pathToDynamicallyGeneratedDictionary;

// Things which will help us to show off the dynamic voice feature
@property (nonatomic, copy) NSString *firstVoiceToUse;
@property (nonatomic, copy) NSString *secondVoiceToUse;

// Our NSTimer that will help us read and display the input and output levels without locking the UI
@property (nonatomic, strong) 	NSTimer *uiUpdateTimer;


@end

