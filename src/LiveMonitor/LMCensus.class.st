"
I count the instances of every class in the heap. Comparing two censuses tells which classes
are being created in bulk:

	| before |
	before := LMCensus take.
	50000 timesRepeat: [ 3 @ 4 ].
	(LMCensus take growthSince: before) first.	""Point -> 50000 (until the next GC)""

Counts include objects that are already garbage but not yet collected, so I show
allocation churn as well as leaks.
"
Class {
	#name : #LMCensus,
	#superclass : #Object,
	#instVars : [
		'counts',
		'cost'
	],
	#category : #LiveMonitor
}

{ #category : #'instance creation' }
LMCensus class >> take [

	^ self new take
]

{ #category : #accessing }
LMCensus >> cost [
	"Milliseconds it took to walk the heap"

	^ cost
]

{ #category : #accessing }
LMCensus >> countOf: aClass [

	^ counts occurrencesOf: aClass
]

{ #category : #comparing }
LMCensus >> growthSince: anOlderCensus [
	"Classes whose instance count grew, biggest growth first, as class -> delta"

	| grown |
	grown := OrderedCollection new.
	counts doWithOccurrences: [ :class :count |
		| delta |
		delta := count - (anOlderCensus countOf: class).
		delta > 0 ifTrue: [ grown add: class -> delta ] ].
	^ ((grown asArray sort: [ :a :b | a value >= b value ]) first: (grown size min: 8))
]

{ #category : #sampling }
LMCensus >> take [

	| start object |
	start := Time millisecondClockValue.
	counts := Bag new: 8192.
	object := Object someObject.
	[ object == 0 ] whileFalse: [
		counts add: object class.
		object := object nextObject ].
	cost := Time millisecondClockValue - start
]
