#import "INViewController.h"
#import <OpenEars/PocketsphinxController.h> // Please note that unlike in previous versions of OpenEars, we now link the headers through the framework.
#import <OpenEars/FliteController.h>
#import <OpenEars/LanguageModelGenerator.h>
#import <OpenEars/OpenEarsLogging.h>

@implementation INViewController

@synthesize pocketsphinxController;
@synthesize fliteController;
@synthesize openEarsEventsObserver;
@synthesize usingStartLanguageModel;
@synthesize pathToGrammarToStartAppWith;
@synthesize pathToDictionaryToStartAppWith;
@synthesize pathToDynamicallyGeneratedGrammar;
@synthesize pathToDynamicallyGeneratedDictionary;
@synthesize firstVoiceToUse;
@synthesize secondVoiceToUse;

#define kLevelUpdatesPerSecond 18 // We'll have the ui update 18 times a second to show some fluidity without hitting the CPU too hard.

//#define kGetNbest // Uncomment this if you want to try out nbest
#pragma mark - 
#pragma mark Memory Management

#pragma mark -
#pragma mark Lazy Allocation

// Lazily allocated PocketsphinxController.
- (PocketsphinxController *)pocketsphinxController { 
	if (pocketsphinxController == nil) {
		pocketsphinxController = [[PocketsphinxController alloc] init];
        //  pocketsphinxController.verbosePocketSphinx = TRUE; // Uncomment me for verbose debug output
#ifdef kGetNbest        
        pocketsphinxController.returnNbest = TRUE;
        pocketsphinxController.nBestNumber = 5;
#endif        
	}
	return pocketsphinxController;
}

// Lazily allocated FliteController.
- (FliteController *)fliteController {
	if (fliteController == nil) {
		fliteController = [[FliteController alloc] init];
	}
	return fliteController;
}

// Lazily allocated OpenEarsEventsObserver.
- (OpenEarsEventsObserver *)openEarsEventsObserver {
	if (openEarsEventsObserver == nil) {
		openEarsEventsObserver = [[OpenEarsEventsObserver alloc] init];
	}
	return openEarsEventsObserver;
}

- (void)scheduleDeliveryOfResultsRemotely:(NSDictionary *)dict {

    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:nil];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@""]];   
    request.HTTPBody = jsonData;
    request.HTTPMethod = @"POST";
    
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:
     ^(NSURLResponse *response, NSData *data, NSError *error)
     {
         NSLog(@"Info Sent");
     }];

}

// The last class we're using here is LanguageModelGenerator but I don't think it's advantageous to lazily instantiate it. You can see how it's used below.

#pragma mark -
#pragma mark View Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
	
    // [OpenEarsLogging startOpenEarsLogging]; // Uncomment me for OpenEarsLogging
    
	[self.openEarsEventsObserver setDelegate:self]; // Make this class the delegate of OpenEarsObserver so we can get all of the messages about what OpenEars is doing.
    
	// The following strings could be set to any of the following voices:
	// cmu_us_awb8k // 8k version of the us_awb voice
	// cmu_us_rms8k // 8k version of the us_rms voice
	// cmu_us_slt8k // 8k version of the us_slt voice
	// cmu_time_awb // 16k awb time voice, unlikely to do much unless used to read time
	// cmu_us_awb //  16k us_awb voice
	// cmu_us_kal //  8k us_kal voice
	// cmu_us_kal16 // 16k us_kal voice
	// cmu_us_rms // 16k us_rms voice
	// cmu_us_slt // 16k us_slt voice
    
	self.firstVoiceToUse = @"cmu_us_slt";
	self.secondVoiceToUse = @"cmu_us_rms"; 
	
    // Now, OpenEars ships with all 9 voices enabled, which causes the app binaries to be very large. Before shipping, you want to open up the OpenEars.xcodeproj project and comment out the voices you aren't using in the file OpenEarsConfig.h so that your app binary will be reasonably sized, and then build the project. If you aren't using FliteController at all, you can comment out all the voices and save even more space.
	
    // This is the language model we're going to start up with. The only reason I'm making it a class property is that I reuse it a bunch of times in this example, 
	// but you can pass the string contents directly to PocketsphinxController:startListeningWithLanguageModelAtPath:dictionaryAtPath:languageModelIsJSGF:
	
	self.pathToGrammarToStartAppWith = [NSString stringWithFormat:@"%@/%@",[[NSBundle mainBundle] resourcePath], @"OpenEars1.languagemodel"]; 
    
	// This is the dictionary we're going to start up with. The only reason I'm making it a class property is that I reuse it a bunch of times in this example, 
	// but you can pass the string contents directly to PocketsphinxController:startListeningWithLanguageModelAtPath:dictionaryAtPath:languageModelIsJSGF:
	self.pathToDictionaryToStartAppWith = [NSString stringWithFormat:@"%@/%@",[[NSBundle mainBundle] resourcePath], @"OpenEars1.dic"]; 
    
	self.usingStartLanguageModel = TRUE; // This is not an OpenEars thing, this is just so I can switch back and forth between the two models in this sample app.
	
	// Here is an example of dynamically creating an in-app grammar.
	
	// We want it to be able to response to the speech "CHANGE MODEL" and a few other things.  Items we want to have recognized as a whole phrase (like "CHANGE MODEL") 
	// we put into the array as one string (e.g. "CHANGE MODEL" instead of "CHANGE" and "MODEL"). This increases the probability that they will be recognized as a phrase. This works even better starting with version 1.0 of OpenEars.
	
	NSArray *languageArray = [[NSArray alloc] initWithArray:[NSArray arrayWithObjects: // All capital letters.
                                                             @"SUNDAY",
                                                             @"MONDAY",
                                                             @"TUESDAY",
                                                             @"WEDNESDAY",
                                                             @"THURSDAY",
                                                             @"FRIDAY",
                                                             @"SATURDAY",
                                                             @"QUIDNUNC",
                                                             @"CHANGE MODEL",
                                                             nil]];
    
	// The last entry, quidnunc, is an example of a word which will not be found in the lookup dictionary and will be passed to the fallback method. The fallback method is slower,
	// so, for instance, creating a new language model from dictionary words will be pretty fast, but a model that has a lot of unusual names in it or invented/rare/recent-slang
	// words will be slower to generate. You can use this information to give your users good UI feedback about what the expectations for wait times should be.
	
	// Turning on OPENEARSLOGGING in the OpenEars.xcodeproj OpenEarsConfig.h header and recompiling the framework will tell you how long the language model took to generate.
    
	// I don't think it's beneficial to lazily instantiate LanguageModelGenerator because you only need to give it a single message and then release it.
	// If you need to create a very large model or any size of model that has many unusual words that have to make use of the fallback generation method,
	// you will want to run this on a background thread so you can give the user some UI feedback that the task is in progress.
    
	LanguageModelGenerator *languageModelGenerator = [[LanguageModelGenerator alloc] init]; 
    
    //    languageModelGenerator.verboseLanguageModelGenerator = TRUE; // Uncomment me for verbose debug output
    
    // generateLanguageModelFromArray:withFilesNamed returns an NSError which will either have a value of noErr if everything went fine or a specific error if it didn't.
	NSError *error = [languageModelGenerator generateLanguageModelFromArray:languageArray withFilesNamed:@"OpenEarsDynamicGrammar"];
    
	NSDictionary *dynamicLanguageGenerationResultsDictionary = nil;
	if([error code] != noErr) {
		NSLog(@"Dynamic language generator reported error %@", [error description]);	
	} else {
		dynamicLanguageGenerationResultsDictionary = [error userInfo];
		
		// A useful feature of the fact that generateLanguageModelFromArray:withFilesNamed: always returns an NSError is that when it returns noErr (meaning there was
		// no error, or an [NSError code] of zero), the NSError also contains a userInfo dictionary which contains the path locations of your new files.
		
		// What follows demonstrates how to get the paths for your created dynamic language models out of that userInfo dictionary.
		NSString *lmFile = [dynamicLanguageGenerationResultsDictionary objectForKey:@"LMFile"];
		NSString *dictionaryFile = [dynamicLanguageGenerationResultsDictionary objectForKey:@"DictionaryFile"];
		NSString *lmPath = [dynamicLanguageGenerationResultsDictionary objectForKey:@"LMPath"];
		NSString *dictionaryPath = [dynamicLanguageGenerationResultsDictionary objectForKey:@"DictionaryPath"];
		
		NSLog(@"Dynamic language generator completed successfully, you can find your new files %@\n and \n%@\n at the paths \n%@ \nand \n%@", lmFile,dictionaryFile,lmPath,dictionaryPath);	
		
		// pathToDynamicallyGeneratedGrammar/Dictionary aren't OpenEars things, they are just the way I'm controlling being able to switch between the grammars in this sample app.
		self.pathToDynamicallyGeneratedGrammar = lmPath; // We'll set our new .languagemodel file to be the one to get switched to when the words "CHANGE MODEL" are recognized.
		self.pathToDynamicallyGeneratedDictionary = dictionaryPath; // We'll set our new dictionary to be the one to get switched to when the words "CHANGE MODEL" are recognized.
	}
	
	
    // Next, an informative message.
    
	NSLog(@"\n\nWelcome to the OpenEars sample project. This project understands the words:\nBACKWARD,\nCHANGE,\nFORWARD,\nGO,\nLEFT,\nMODEL,\nRIGHT,\nTURN,\nand if you say \"CHANGE MODEL\" it will switch to its dynamically-generated model which understands the words:\nCHANGE,\nMODEL,\nMONDAY,\nTUESDAY,\nWEDNESDAY,\nTHURSDAY,\nFRIDAY,\nSATURDAY,\nSUNDAY,\nQUIDNUNC");
	
	// This is how to start the continuous listening loop of an available instance of PocketsphinxController. We won't do this if the language generation failed since it will be listening for a command to change over to the generated language.
	if(dynamicLanguageGenerationResultsDictionary) {
        
		// startListeningWithLanguageModelAtPath:dictionaryAtPath:languageModelIsJSGF always needs to know the grammar file being used, 
		// the dictionary file being used, and whether the grammar is a JSGF. You must put in the correct value for languageModelIsJSGF.
		// Inside of a single recognition loop, you can only use JSGF grammars or ARPA grammars, you can't switch between the two types.
		
		// An ARPA grammar is the kind with a .languagemodel or .DMP file, and a JSGF grammar is the kind with a .gram file.
        
		// If you wanted to just perform recognition on an isolated wav file for testing, you could do it as follows:
        
        // NSString *wavPath = [NSString stringWithFormat:@"%@/%@",[[NSBundle mainBundle] resourcePath], @"test.wav"];         
        //[self.pocketsphinxController runRecognitionOnWavFileAtPath:wavPath usingLanguageModelAtPath:self.pathToGrammarToStartAppWith dictionaryAtPath:self.pathToDictionaryToStartAppWith languageModelIsJSGF:FALSE];  // Starts the recognition loop.
        
        // But under normal circumstances you'll probably want to do continuous recognition as follows:
        
        [self.pocketsphinxController startListeningWithLanguageModelAtPath:self.pathToGrammarToStartAppWith dictionaryAtPath:self.pathToDictionaryToStartAppWith languageModelIsJSGF:FALSE];
        
	}
    
    
    
    
	// [self startDisplayingLevels] is not an OpenEars method, just an approach for level reading
	// that I've included with this sample app. My example implementation does make use of two OpenEars
	// methods:	the pocketsphinxInputLevel method of PocketsphinxController and the fliteOutputLevel
	// method of fliteController. 
	//
	// The example is meant to show one way that you can read those levels continuously without locking the UI, 
	// by using an NSTimer, but the OpenEars level-reading methods 
	// themselves do not include multithreading code since I believe that you will want to design your own 
	// code approaches for level display that are tightly-integrated with your interaction design and the  
	// graphics API you choose. 
	// 
	// Please note that if you use my sample approach, you should pay attention to the way that the timer is always stopped in
	// dealloc. This should prevent you from having any difficulties with deallocating a class due to a running NSTimer process.
	    
}

#pragma mark -
#pragma mark OpenEarsEventsObserver delegate methods

// What follows are all of the delegate methods you can optionally use once you've instantiated an OpenEarsEventsObserver and set its delegate to self. 
// I've provided some pretty granular information about the exact phase of the Pocketsphinx listening loop, the Audio Session, and Flite, but I'd expect 
// that the ones that will really be needed by most projects are the following:
//
//- (void) pocketsphinxDidReceiveHypothesis:(NSString *)hypothesis recognitionScore:(NSString *)recognitionScore utteranceID:(NSString *)utteranceID;
//- (void) audioSessionInterruptionDidBegin;
//- (void) audioSessionInterruptionDidEnd;
//- (void) audioRouteDidChangeToRoute:(NSString *)newRoute;
//- (void) pocketsphinxDidStartListening;
//- (void) pocketsphinxDidStopListening;
//
// It isn't necessary to have a PocketsphinxController or a FliteController instantiated in order to use these methods.  If there isn't anything instantiated that will
// send messages to an OpenEarsEventsObserver, all that will happen is that these methods will never fire.  You also do not have to create a OpenEarsEventsObserver in
// the same class or view controller in which you are doing things with a PocketsphinxController or FliteController; you can receive updates from those objects in
// any class in which you instantiate an OpenEarsEventsObserver and set its delegate to self.

// An optional delegate method of OpenEarsEventsObserver which delivers the text of speech that Pocketsphinx heard and analyzed, along with its accuracy score and utterance ID.
- (void) pocketsphinxDidReceiveHypothesis:(NSString *)hypothesis recognitionScore:(NSString *)recognitionScore utteranceID:(NSString *)utteranceID {
    
    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:hypothesis, @"hypothesis", recognitionScore, @"score", utteranceID,  @"id", nil];
    [self scheduleDeliveryOfResultsRemotely:dict];
    
    
	NSLog(@"The received hypothesis is %@ with a score of %@ and an ID of %@", hypothesis, recognitionScore, utteranceID); // Log it.
	if([hypothesis isEqualToString:@"CHANGE MODEL"]) { // If the user says "CHANGE MODEL", we will switch to the alternate model (which happens to be the dynamically generated model).
        
		// Here is an example of language model switching in OpenEars. Deciding on what logical basis to switch models is your responsibility.
		// For instance, when you call a customer service line and get a response tree that takes you through different options depending on what you say to it,
		// the models are being switched as you progress through it so that only relevant choices can be understood. The construction of that logical branching and 
		// how to react to it is your job, OpenEars just lets you send the signal to switch the language model when you've decided it's the right time to do so.
		
		if(self.usingStartLanguageModel == TRUE) { // If we're on the starting model, switch to the dynamically generated one.
			
			// You can only change language models with ARPA grammars in OpenEars (the ones that end in .languagemodel or .DMP). 
			// Trying to switch between JSGF models (the ones that end in .gram) will return no result.
			[self.pocketsphinxController changeLanguageModelToFile:self.pathToDynamicallyGeneratedGrammar withDictionary:self.pathToDynamicallyGeneratedDictionary]; 
			self.usingStartLanguageModel = FALSE;
		} else { // If we're on the dynamically generated model, switch to the start model (this is just an example of a trigger and method for switching models).
			[self.pocketsphinxController changeLanguageModelToFile:self.pathToGrammarToStartAppWith withDictionary:self.pathToDictionaryToStartAppWith];
			self.usingStartLanguageModel = TRUE;
		}
	}
	
//	self.heardTextView.text = [NSString stringWithFormat:@"Heard: \"%@\"", hypothesis]; // Show it in the status box.
	
	// This is how to use an available instance of FliteController. We're going to repeat back the command that we heard with the voice we've chosen.
	[self.fliteController say:[NSString stringWithFormat:@"You said %@",hypothesis] withVoice:self.secondVoiceToUse];
}

#ifdef kGetNbest   
- (void) pocketsphinxDidReceiveNBestHypothesisArray:(NSArray *)hypothesisArray { // Pocketsphinx has an n-best hypothesis dictionary.
    NSLog(@"hypothesisArray is %@",hypothesisArray);   
}
#endif
// An optional delegate method of OpenEarsEventsObserver which informs that there was an interruption to the audio session (e.g. an incoming phone call).
- (void) audioSessionInterruptionDidBegin {
	NSLog(@"AudioSession interruption began."); // Log it.
//	self.statusTextView.text = @"Status: AudioSession interruption began."; // Show it in the status box.
	[self.pocketsphinxController stopListening]; // React to it by telling Pocketsphinx to stop listening since it will need to restart its loop after an interruption.
}

// An optional delegate method of OpenEarsEventsObserver which informs that the interruption to the audio session ended.
- (void) audioSessionInterruptionDidEnd {
	NSLog(@"AudioSession interruption ended."); // Log it.
//	self.statusTextView.text = @"Status: AudioSession interruption ended."; // Show it in the status box.
    // We're restarting the previously-stopped listening loop.
	[self.pocketsphinxController startListeningWithLanguageModelAtPath:self.pathToGrammarToStartAppWith dictionaryAtPath:self.pathToDictionaryToStartAppWith languageModelIsJSGF:FALSE];
}

// An optional delegate method of OpenEarsEventsObserver which informs that the audio input became unavailable.
- (void) audioInputDidBecomeUnavailable {
	NSLog(@"The audio input has become unavailable"); // Log it.
//	self.statusTextView.text = @"Status: The audio input has become unavailable"; // Show it in the status box.
	[self.pocketsphinxController stopListening]; // React to it by telling Pocketsphinx to stop listening since there is no available input
}

// An optional delegate method of OpenEarsEventsObserver which informs that the unavailable audio input became available again.
- (void) audioInputDidBecomeAvailable {
	NSLog(@"The audio input is available"); // Log it.
//	self.statusTextView.text = @"Status: The audio input is available"; // Show it in the status box.
	[self.pocketsphinxController startListeningWithLanguageModelAtPath:self.pathToGrammarToStartAppWith dictionaryAtPath:self.pathToDictionaryToStartAppWith languageModelIsJSGF:FALSE];
}

// An optional delegate method of OpenEarsEventsObserver which informs that there was a change to the audio route (e.g. headphones were plugged in or unplugged).
- (void) audioRouteDidChangeToRoute:(NSString *)newRoute {
	NSLog(@"Audio route change. The new audio route is %@", newRoute); // Log it.
//	self.statusTextView.text = [NSString stringWithFormat:@"Status: Audio route change. The new audio route is %@",newRoute]; // Show it in the status box.
    
	[self.pocketsphinxController stopListening]; // React to it by telling the Pocketsphinx loop to shut down and then start listening again on the new route
	[self.pocketsphinxController startListeningWithLanguageModelAtPath:self.pathToGrammarToStartAppWith dictionaryAtPath:self.pathToDictionaryToStartAppWith languageModelIsJSGF:FALSE];
}

// An optional delegate method of OpenEarsEventsObserver which informs that the Pocketsphinx recognition loop hit the calibration stage in its startup.
// This might be useful in debugging a conflict between another sound class and Pocketsphinx. Another good reason to know when you're in the middle of
// calibration is that it is a timeframe in which you want to avoid playing any other sounds including speech so the calibration will be successful.
- (void) pocketsphinxDidStartCalibration {
	NSLog(@"Pocketsphinx calibration has started."); // Log it.
//	self.statusTextView.text = @"Status: Pocketsphinx calibration has started."; // Show it in the status box.
}

// An optional delegate method of OpenEarsEventsObserver which informs that the Pocketsphinx recognition loop completed the calibration stage in its startup.
// This might be useful in debugging a conflict between another sound class and Pocketsphinx.
- (void) pocketsphinxDidCompleteCalibration {
	NSLog(@"Pocketsphinx calibration is complete."); // Log it.
//	self.statusTextView.text = @"Status: Pocketsphinx calibration is complete."; // Show it in the status box.
    
	self.fliteController.duration_stretch = .9; // Change the speed
	self.fliteController.target_mean = 1.2; // Change the pitch
	self.fliteController.target_stddev = 1.5; // Change the variance
	
    [self.fliteController say:@"Welcome to OpenEars." withVoice:self.firstVoiceToUse];
    // The same statement with the pitch and other voice values changed.
	
	self.fliteController.duration_stretch = 1.0; // Reset the speed
	self.fliteController.target_mean = 1.0; // Reset the pitch
	self.fliteController.target_stddev = 1.0; // Reset the variance
}

// An optional delegate method of OpenEarsEventsObserver which informs that the Pocketsphinx recognition loop has entered its actual loop.
// This might be useful in debugging a conflict between another sound class and Pocketsphinx.
- (void) pocketsphinxRecognitionLoopDidStart {
    
	NSLog(@"Pocketsphinx is starting up."); // Log it.
//	self.statusTextView.text = @"Status: Pocketsphinx is starting up."; // Show it in the status box.
}

// An optional delegate method of OpenEarsEventsObserver which informs that Pocketsphinx is now listening for speech.
- (void) pocketsphinxDidStartListening {
	
	NSLog(@"Pocketsphinx is now listening."); // Log it.
//	self.statusTextView.text = @"Status: Pocketsphinx is now listening."; // Show it in the status box.
//	
//	self.startButton.hidden = TRUE; // React to it with some UI changes.
//	self.stopButton.hidden = FALSE;
//	self.suspendListeningButton.hidden = FALSE;
//	self.resumeListeningButton.hidden = TRUE;
}

// An optional delegate method of OpenEarsEventsObserver which informs that Pocketsphinx detected speech and is starting to process it.
- (void) pocketsphinxDidDetectSpeech {
	NSLog(@"Pocketsphinx has detected speech."); // Log it.
//	self.statusTextView.text = @"Status: Pocketsphinx has detected speech."; // Show it in the status box.
}

// An optional delegate method of OpenEarsEventsObserver which informs that Pocketsphinx detected a second of silence, indicating the end of an utterance. 
// This was added because developers requested being able to time the recognition speed without the speech time. The processing time is the time between 
// this method being called and the hypothesis being returned.
- (void) pocketsphinxDidDetectFinishedSpeech {
	NSLog(@"Pocketsphinx has detected a second of silence, concluding an utterance."); // Log it.
//	self.statusTextView.text = @"Status: Pocketsphinx has detected finished speech."; // Show it in the status box.
}


// An optional delegate method of OpenEarsEventsObserver which informs that Pocketsphinx has exited its recognition loop, most 
// likely in response to the PocketsphinxController being told to stop listening via the stopListening method.
- (void) pocketsphinxDidStopListening {
	NSLog(@"Pocketsphinx has stopped listening."); // Log it.
//	self.statusTextView.text = @"Status: Pocketsphinx has stopped listening."; // Show it in the status box.
}

// An optional delegate method of OpenEarsEventsObserver which informs that Pocketsphinx is still in its listening loop but it is not
// Going to react to speech until listening is resumed.  This can happen as a result of Flite speech being
// in progress on an audio route that doesn't support simultaneous Flite speech and Pocketsphinx recognition,
// or as a result of the PocketsphinxController being told to suspend recognition via the suspendRecognition method.
- (void) pocketsphinxDidSuspendRecognition {
	NSLog(@"Pocketsphinx has suspended recognition."); // Log it.
//	self.statusTextView.text = @"Status: Pocketsphinx has suspended recognition."; // Show it in the status box.
}

// An optional delegate method of OpenEarsEventsObserver which informs that Pocketsphinx is still in its listening loop and after recognition
// having been suspended it is now resuming.  This can happen as a result of Flite speech completing
// on an audio route that doesn't support simultaneous Flite speech and Pocketsphinx recognition,
// or as a result of the PocketsphinxController being told to resume recognition via the resumeRecognition method.
- (void) pocketsphinxDidResumeRecognition {
	NSLog(@"Pocketsphinx has resumed recognition."); // Log it.
//	self.statusTextView.text = @"Status: Pocketsphinx has resumed recognition."; // Show it in the status box.
}

// An optional delegate method which informs that Pocketsphinx switched over to a new language model at the given URL in the course of
// recognition. This does not imply that it is a valid file or that recognition will be successful using the file.
- (void) pocketsphinxDidChangeLanguageModelToFile:(NSString *)newLanguageModelPathAsString andDictionary:(NSString *)newDictionaryPathAsString {
	NSLog(@"Pocketsphinx is now using the following language model: \n%@ and the following dictionary: %@",newLanguageModelPathAsString,newDictionaryPathAsString);
}

// An optional delegate method of OpenEarsEventsObserver which informs that Flite is speaking, most likely to be useful if debugging a
// complex interaction between sound classes. You don't have to do anything yourself in order to prevent Pocketsphinx from listening to Flite talk and trying to recognize the speech.
- (void) fliteDidStartSpeaking {
	NSLog(@"Flite has started speaking"); // Log it.
//	self.statusTextView.text = @"Status: Flite has started speaking."; // Show it in the status box.
}

// An optional delegate method of OpenEarsEventsObserver which informs that Flite is finished speaking, most likely to be useful if debugging a
// complex interaction between sound classes.
- (void) fliteDidFinishSpeaking {
	NSLog(@"Flite has finished speaking"); // Log it.
//	self.statusTextView.text = @"Status: Flite has finished speaking."; // Show it in the status box.
}

- (void) pocketSphinxContinuousSetupDidFail { // This can let you know that something went wrong with the recognition loop startup. Turn on OPENEARSLOGGING to learn why.
	NSLog(@"Setting up the continuous recognition loop has failed for some reason, please turn on OPENEARSLOGGING in OpenEarsConfig.h to learn more."); // Log it.
//	self.statusTextView.text = @"Status: Not possible to start recognition loop."; // Show it in the status box.	
}


@end
