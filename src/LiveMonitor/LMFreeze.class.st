"
I describe a period during which the UI process did not answer: how long, and where its stack was spinning.
"
Class {
	#name : #LMFreeze,
	#superclass : #Object,
	#instVars : [
		'durationMs',
		'loopLabel',
		'hotLabel',
		'stackLabels',
		'endedAt'
	],
	#category : #LiveMonitor
}

{ #category : #accessing }
LMFreeze >> age [
	"Milliseconds since the freeze ended"

	^ endedAt ifNil: [ 0 ] ifNotNil: [ Time millisecondClockValue - endedAt ]
]

{ #category : #accessing }
LMFreeze >> durationMs [

	^ durationMs ifNil: [ 0 ]
]

{ #category : #accessing }
LMFreeze >> durationMs: anObject [

	durationMs := anObject
]

{ #category : #accessing }
LMFreeze >> endedAt [

	^ endedAt
]

{ #category : #accessing }
LMFreeze >> endedAt: anObject [

	endedAt := anObject
]

{ #category : #accessing }
LMFreeze >> hotLabel [

	^ hotLabel
]

{ #category : #accessing }
LMFreeze >> hotLabel: anObject [

	hotLabel := anObject
]

{ #category : #testing }
LMFreeze >> isOver [

	^ endedAt notNil
]

{ #category : #accessing }
LMFreeze >> loopLabel [

	^ loopLabel
]

{ #category : #accessing }
LMFreeze >> loopLabel: anObject [

	loopLabel := anObject
]

{ #category : #accessing }
LMFreeze >> stackLabels [

	^ stackLabels ifNil: [ #(  ) ]
]

{ #category : #accessing }
LMFreeze >> stackLabels: anObject [

	stackLabels := anObject
]
