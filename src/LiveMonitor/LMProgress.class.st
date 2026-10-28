"
I am how far a running computation is, as published in an `LMSample`.

- fraction: between 0 and 1, read like an odometer from the outermost loop that moves
  down to the innermost one, so a 10-iteration outer loop still advances smoothly.
- loops: the `LMLoopPosition`s it is computed from, outermost first.
- elapsedMs: how long we have been watching the outer loop.
- etaMs: the estimated time left at the average speed so far, nil until we know enough.
"
Class {
	#name : #LMProgress,
	#superclass : #Object,
	#instVars : [
		'fraction',
		'loops',
		'elapsedMs',
		'etaMs'
	],
	#category : #LiveMonitor
}

{ #category : #'instance creation' }
LMProgress class >> fraction: aNumber loops: anArray elapsedMs: elapsed etaMs: eta [

	^ self new
		  setFraction: aNumber
		  loops: anArray
		  elapsedMs: elapsed
		  etaMs: eta
]

{ #category : #accessing }
LMProgress >> elapsedMs [

	^ elapsedMs
]

{ #category : #accessing }
LMProgress >> etaMs [

	^ etaMs
]

{ #category : #accessing }
LMProgress >> fraction [

	^ fraction
]

{ #category : #accessing }
LMProgress >> loops [

	^ loops
]

{ #category : #initialization }
LMProgress >> setFraction: aNumber loops: anArray elapsedMs: elapsed etaMs: eta [

	fraction := aNumber.
	loops := anArray.
	elapsedMs := elapsed.
	etaMs := eta
]
