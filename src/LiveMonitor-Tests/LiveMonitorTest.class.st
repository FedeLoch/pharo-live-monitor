Class {
	#name : #LiveMonitorTest,
	#superclass : #TestCase,
	#instVars : [
		'monitor',
		'keep'
	],
	#category : #'LiveMonitor-Tests'
}

{ #category : #helpers }
LiveMonitorTest >> spin [
	"Never returns: the method a 'buggy' process loops in"

	| sum |
	sum := 0.
	[ true ] whileTrue: [ sum := sum + (OrderedCollection new add: 1; yourself) size ]
]

{ #category : #running }
LiveMonitorTest >> tearDown [

	monitor ifNotNil: [ monitor stopSampling ].
	keep := nil.
	super tearDown
]

{ #category : #tests }
LiveMonitorTest >> testCensusSeesNewInstances [

	| before growth |
	before := LMCensus take.
	keep := (1 to: 20000) collect: [ :i | LMFreeze new ].
	growth := LMCensus take growthSince: before.
	self assert: (growth detect: [ :each | each key == LMFreeze ]) value >= 20000
]

{ #category : #tests }
LiveMonitorTest >> testCountObjects [

	self assert: LiveMonitor new countObjects > 10000
]

{ #category : #tests }
LiveMonitorTest >> testFormatting [

	self assert: (LMPanelPainter formatBytes: 512) equals: '512 B'.
	self assert: (LMPanelPainter formatBytes: 3 * 1048576) equals: '3.0 MB'.
	self assert: (LMPanelPainter formatCount: 1234) equals: '1.2K'.
	self assert: (LMPanelPainter formatCount: 2500000) equals: '2.50M'.
	self assert: (LMPanelPainter formatSignedCount: -1500) equals: '-1.5K'.
	self assert: (LMPanelPainter formatPercent: 0.426) equals: '43%'.
	self assert: (LMPanelPainter formatMs: 4200) equals: '4.2s'
]

{ #category : #helpers }
LiveMonitorTest >> click: aMorph at: aPoint [

	aMorph mouseDown: (self mouseEvent: #mouseDown at: aPoint).
	aMorph mouseUp: (self mouseEvent: #mouseUp at: aPoint)
]

{ #category : #helpers }
LiveMonitorTest >> mouseEvent: aType at: aPoint [

	^ MouseButtonEvent new
		  setType: aType
		  position: aPoint
		  which: MouseButtonEvent redButton
		  buttons: (aType = #mouseDown
				   ifTrue: [ MouseButtonEvent redButton ]
				   ifFalse: [ 0 ])
		  hand: nil
		  stamp: 0
]

{ #category : #tests }
LiveMonitorTest >> testClickingMinimizesAndRestores [

	| panel button wasMinimized |
	monitor := LiveMonitor new.
	wasMinimized := monitor minimized.
	[
	monitor minimized: false.
	panel := LMMonitorMorph on: monitor.
	"a click in the body does nothing"
	self click: panel at: panel bounds center.
	self deny: monitor minimized.
	button := monitor painter minimizeButtonOf: monitor in: panel bounds.
	self click: panel at: button center.
	self assert: monitor minimized.
	self assert: panel bounds width < 60.
	self click: panel at: panel bounds center.
	self deny: monitor minimized.
	self assert: panel bounds width equals: monitor painter width ] ensure: [ monitor minimized: wasMinimized ]
]

{ #category : #tests }
LiveMonitorTest >> testPainterDrawsAllStates [

	| form freeze |
	monitor := LiveMonitor new.
	12 timesRepeat: [ monitor closeWindowAt: Time millisecondClockValue ].
	form := Form extent: 300 @ 400 depth: 32.
	monitor painter draw: monitor on: form getCanvas in: (0 @ 0 extent: 300 @ (monitor painter heightFor: monitor)).
	self deny: (form colorAt: 150 @ 3) isTransparent.
	freeze := LMFreeze new
		          durationMs: 4200;
		          loopLabel: 'Foo>>bar';
		          hotLabel: 'OrderedCollection>>add:';
		          stackLabels: #( 'a' 'b' 'c' );
		          yourself.
	monitor instVarNamed: 'freeze' put: freeze.
	monitor instVarNamed: 'growth' put: { LMFreeze -> 20000 }.
	monitor instVarNamed: 'growthTime' put: Time millisecondClockValue.
	self assert: (monitor painter detailLinesFor: monitor) size >= 7.
	monitor painter draw: monitor on: form getCanvas in: (0 @ 0 extent: 300 @ (monitor painter heightFor: monitor)).
	monitor painter
		draw: monitor
		on: (ScalingCanvas formCanvas: (Form extent: 600 @ 800 depth: 32) getCanvas scale: 2)
		in: (0 @ 0 extent: 300 @ 400).
	monitor instVarNamed: 'freeze' put: nil.
	monitor minimized: true.
	self assert: (monitor painter extentFor: monitor) < (60 @ 30).
	self assert: (monitor painter minimizeButtonOf: monitor in: (0 @ 0 extent: 300 @ 30)) isNil.
	monitor painter draw: monitor on: form getCanvas in: (0 @ 0 extent: (monitor painter extentFor: monitor)).
	monitor minimized: false
]

{ #category : #tests }
LiveMonitorTest >> testPainterWithFullHistoryAndFractionalBounds [
	"Regression: a fractional panel position made the sparkline ask for 'last: 96.0'"

	monitor := LiveMonitor new.
	130 timesRepeat: [ monitor closeWindowAt: Time millisecondClockValue ].
	monitor painter draw: monitor on: (Form extent: 400 @ 400 depth: 32) getCanvas in: (10.5 @ 10.25 extent: 300 @ 200)
]

{ #category : #tests }
LiveMonitorTest >> testSamplerMeasuresAllocation [

	| sample |
	monitor := LiveMonitor new.
	(Delay forMilliseconds: 20) wait.
	monitor tick.
	keep := (1 to: 100000) collect: [ :i | Array new: 10 ].
	monitor closeWindowAt: Time millisecondClockValue + 1.
	sample := monitor latest.
	self assert: sample allocRate > 0.
	self assert: sample heapUsed > 0.
	self assert: sample heapSize >= sample heapUsed.
	self assert: sample objects > 10000.
	self assert: monitor history size equals: 1
]

{ #category : #tests }
LiveMonitorTest >> testSamplerProcessRunsAboveUserCode [

	monitor := LiveMonitor new.
	monitor startSampling.
	[ (Delay forMilliseconds: 1200) wait ] value.
	self assert: monitor history notEmpty.
	self assert: monitor lastError isNil.
	self assert: (monitor instVarNamed: 'process') priority > Processor userSchedulingPriority
]

{ #category : #tests }
LiveMonitorTest >> testSamplerSurvivesHighPriorityHog [
	"Experiments forked above the UI (even at 75) must not starve the monitor"

	| done before during |
	monitor := LiveMonitor new.
	monitor startSampling.
	(Delay forMilliseconds: 600) wait.
	before := monitor version.
	done := Semaphore new.
	[
	| end |
	end := Time millisecondClockValue + 1500.
	[ Time millisecondClockValue < end ] whileTrue: [ OrderedCollection new add: 1 ].
	during := monitor version.
	done signal ] forkAt: 75.
	done wait.
	self assert: during - before >= 2.
	self assert: monitor latest cpu > 0.5.
	self assert: monitor lastError isNil
]

{ #category : #tests }
LiveMonitorTest >> testStarvationIsReported [

	| now |
	now := Time millisecondClockValue.
	monitor := LiveMonitor new.
	self assert: monitor starvation isNil.
	monitor noteStarvationAt: now - 4020.
	monitor noteStarvationAt: now - 4000.
	self assert: monitor starvation isNil.
	monitor noteStarvationAt: now.
	self assert: monitor starvation key equals: 4000.
	self assert: ((monitor painter detailLinesFor: monitor) anySatisfy: [ :line |
			 line key includesSubstring: 'blocked' ])
]

{ #category : #tests }
LiveMonitorTest >> testTallyFindsTheLoop [

	| tally spinner |
	tally := LMStackTally new.
	spinner := [ self spin ] forkAt: Processor userBackgroundPriority.
	[
	30 timesRepeat: [
		(Delay forMilliseconds: 3) wait.
		"we preempted the spinner, its stack is frozen while we look"
		tally addProcess: spinner ] ] ensure: [ spinner terminate ].
	self assert: tally samples equals: 30.
	self assert: tally loopLabel equals: 'LiveMonitorTest>>spin'.
	self assert: tally hotRatio > 0
]
