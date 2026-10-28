"
Tests of the loop progress: processes stop on a semaphore at a known iteration, so their stack
is frozen at a known place while we read it.
"
Class {
	#name : #LMProgressTest,
	#superclass : #TestCase,
	#instVars : [
		'process',
		'semaphore',
		'monitor'
	],
	#category : #'LiveMonitor-Tests'
}

{ #category : #helpers }
LMProgressTest >> loopsWhenStopped: aBlock [
	"Run aBlock in a process until it waits on the semaphore, and answer its loops"

	process := aBlock forkAt: Processor activePriority + 1.
	^ LMLoopFinder new loopsOf: process
]

{ #category : #helpers }
LMProgressTest >> loopNamed: aString in: positions [

	^ positions detect: [ :each | each name = aString ]
]

{ #category : #helpers }
LMProgressTest >> ten [

	^ 10
]

{ #category : #running }
LMProgressTest >> setUp [

	super setUp.
	semaphore := Semaphore new
]

{ #category : #running }
LMProgressTest >> tearDown [

	process ifNotNil: [ process terminate ].
	monitor ifNotNil: [ monitor stopSampling ].
	super tearDown
]

{ #category : #tests }
LMProgressTest >> testCapturedCounter [
	"A counter captured by a closure lives in a temp vector"

	| loops blocks |
	blocks := OrderedCollection new.
	loops := self loopsWhenStopped: [
		         1 to: 10 do: [ :i |
			         blocks add: [ i ].
			         i = 6 ifTrue: [ semaphore wait ] ] ].
	self assert: (self loopNamed: 'i' in: loops) current equals: 6.
	self assert: (self loopNamed: 'i' in: loops) total equals: 10
]

{ #category : #tests }
LMProgressTest >> testCollectionLoop [
	"do: on a collection is an inlined to:do: inside OrderedCollection>>do:"

	| loops collection index |
	collection := (1 to: 10) asOrderedCollection.
	loops := self loopsWhenStopped: [ collection do: [ :each | each = 7 ifTrue: [ semaphore wait ] ] ].
	index := self loopNamed: 'index' in: loops.
	self assert: index current equals: 7.
	self assert: index total equals: 10.
	"named after the block it runs"
	self assert: index label equals: 'each in LMProgressTest>>testCollectionLoop'
]

{ #category : #tests }
LMProgressTest >> testFormatDuration [

	self assert: (LMPanelPainter formatDuration: 42400) equals: '42s'.
	self assert: (LMPanelPainter formatDuration: 192000) equals: '3m12s'.
	self assert: (LMPanelPainter formatDuration: 3900000) equals: '1h05m'
]

{ #category : #tests }
LMProgressTest >> testFractionsReadLikeAnOdometer [

	| site positions |
	site := LMLoopSite kind: #toDo name: 'i' methodLabel: 'Foo>>bar'.
	positions := {
		             (LMLoopPosition key: 1 site: site done: 2 total: 10).
		             (LMLoopPosition key: 2 site: site done: 5 total: 10) }.
	self assert: (LMProgressTracker fractionsOf: positions) equals: { 1 / 4. 1 / 2 }
]

{ #category : #tests }
LMProgressTest >> testIntervalLoop [
	"Interval>>do: is a counter whileTrue: loop"

	| loops |
	loops := self loopsWhenStopped: [ (1 to: 8) do: [ :x | x = 5 ifTrue: [ semaphore wait ] ] ].
	self assert: (self loopNamed: 'index' in: loops) current equals: 5.
	self assert: (self loopNamed: 'index' in: loops) total equals: 8
]

{ #category : #tests }
LMProgressTest >> testNestedLoopsWithComputedBound [
	"A bound that is not a constant is kept by the compiler in a hidden temp"

	| loops |
	loops := self loopsWhenStopped: [
		         1 to: self ten do: [ :i |
			         1 to: 4 do: [ :j | (i = 3 and: [ j = 2 ]) ifTrue: [ semaphore wait ] ] ] ].
	self assert: (loops collect: [ :each | each name ]) equals: #( 'i' 'j' ).
	self assert: (loops collect: [ :each | each current ]) equals: #( 3 2 ).
	self assert: (loops collect: [ :each | each total ]) equals: #( 10 4 )
]

{ #category : #tests }
LMProgressTest >> testPainterShowsProgress [

	| site progress form heightBefore |
	monitor := LiveMonitor new.
	monitor closeWindowAt: Time millisecondClockValue.
	heightBefore := monitor painter heightFor: monitor.
	site := LMLoopSite kind: #toDo name: 'epoch' methodLabel: 'DoIt'.
	progress := LMProgress
		            fraction: 0.43
		            loops: { (LMLoopPosition key: 1 site: site done: 8 total: 20) }
		            elapsedMs: 5000
		            etaMs: 130000.
	monitor latest progress: progress.
	self assert: (monitor painter heightFor: monitor) > heightBefore.
	self assert: (monitor painter progressTextFor: progress) equals: '43%  eta 2m10s'.
	self assert: ((monitor painter loopLinesFor: progress) first includesSubstring: '9/20  epoch in DoIt').
	form := Form extent: 300 @ 400 depth: 32.
	monitor painter draw: monitor on: form getCanvas in: (0 @ 0 extent: (monitor painter extentFor: monitor)).
	monitor minimized: true.
	[ monitor painter draw: monitor on: form getCanvas in: (0 @ 0 extent: (monitor painter extentFor: monitor)) ]
		ensure: [ monitor minimized: false ]
]

{ #category : #tests }
LMProgressTest >> testSamplerReportsProgressOfBusyProcess [
	"Nothing to do but run the code: the sampler finds the loop and how far it is"

	| progress |
	LiveMonitor default ifNotNil: [ :running | running stopSampling ].
	[
	monitor := LiveMonitor new.
	monitor startSampling.
	process := [ 1 to: 100000000 do: [ :i | 30 factorial ] ] forkAt: Processor userBackgroundPriority.
	(Delay forMilliseconds: 2000) wait.
	progress := (monitor history reverse detect: [ :sample | sample progress notNil ] ifNone: [ nil ])
		            ifNotNil: [ :sample | sample progress ].
	self assert: progress notNil.
	self assert: progress loops first name equals: 'i'.
	self assert: progress fraction > 0.
	self assert: monitor lastError isNil ] ensure: [
		LiveMonitor default ifNotNil: [ :running | running startSampling ] ]
]

{ #category : #tests }
LMProgressTest >> testStreamLoop [

	| loops stream |
	stream := ReadStream on: (1 to: 20) asArray.
	loops := self loopsWhenStopped: [ [ stream atEnd ] whileFalse: [ stream next = 5 ifTrue: [ semaphore wait ] ] ].
	self assert: (self loopNamed: 'stream' in: loops) done equals: 5.
	self assert: (self loopNamed: 'stream' in: loops) total equals: 20
]

{ #category : #tests }
LMProgressTest >> testTimesRepeat [

	| loops count |
	count := 0.
	loops := self loopsWhenStopped: [
		         6 timesRepeat: [
			         count := count + 1.
			         count = 4 ifTrue: [ semaphore wait ] ] ].
	self assert: (self loopNamed: 'timesRepeat' in: loops) current equals: 4.
	self assert: (self loopNamed: 'timesRepeat' in: loops) total equals: 6
]

{ #category : #tests }
LMProgressTest >> testTrackerFollowsTheOuterLoopThatMoves [
	"The loop around the work (here #(1 2 3) do:, like Morphic dispatching an event) never moves:
	progress is read from the loop of the work, with the time left from its speed"

	| tracker now progress |
	tracker := LMProgressTracker new.
	process := [ #( 1 2 3 ) do: [ :x | x = 2 ifTrue: [ 1 to: 10 do: [ :step | semaphore wait ] ] ] ]
		           forkAt: Processor activePriority + 1.
	now := 100000.
	self assert: (tracker update: process at: now) isNil.
	semaphore signal.
	progress := tracker update: process at: now + 1000.
	self assert: progress loops first name equals: 'step'.
	self assert: progress fraction equals: 1 / 10.
	self assert: progress etaMs isNil.
	3 timesRepeat: [ semaphore signal ].
	progress := tracker update: process at: now + 3000.
	self assert: progress fraction equals: 4 / 10.
	"0.4 done in 3s: 0.6 left takes 4.5s"
	self assert: progress etaMs equals: 4500
]
