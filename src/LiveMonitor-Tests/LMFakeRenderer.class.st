"
I stand for the SDL2 form renderer of the OS window: same lock and deferred updates flag,
and I record what the monitor asks me while it paints directly.
"
Class {
	#name : #LMFakeRenderer,
	#superclass : #Object,
	#instVars : [
		'mutex',
		'deferUpdates',
		'calls'
	],
	#category : #'LiveMonitor-Tests'
}

{ #category : #accessing }
LMFakeRenderer >> calls [

	^ calls
]

{ #category : #initialization }
LMFakeRenderer >> initialize [

	super initialize.
	mutex := Mutex new.
	deferUpdates := false.
	calls := OrderedCollection new
]

{ #category : #accessing }
LMFakeRenderer >> mutex [

	^ mutex
]

{ #category : #updating }
LMFakeRenderer >> updateAreas: allDamage immediate: forceToScreen [
	"The real one presents only the damaged area, unless updates are deferred"

	calls add: (deferUpdates
			 ifTrue: [ #upload ]
			 ifFalse: [ #presentArea ])
]

{ #category : #updating }
LMFakeRenderer >> useDeferredUpdates [

	mutex critical: [ calls add: #presentAll ]
]
