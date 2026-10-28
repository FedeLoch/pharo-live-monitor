"
I accumulate stack samples of processes to tell where they spend their time.

- The hot method is the one most often on top of the stack (where the CPU actually is).
- The loop method is the innermost method present in most samples: if a process is spinning,
  that is the method containing the loop (or the call that never returns).
"
Class {
	#name : #LMStackTally,
	#superclass : #Object,
	#classVars : [
		'WaitingMethods'
	],
	#instVars : [
		'samples',
		'inclusive',
		'depthSums',
		'exclusive',
		'processes',
		'lastStack'
	],
	#category : #LiveMonitor
}

{ #category : #testing }
LMStackTally class >> isJustWoken: aProcess [
	"A process that the same timer tick woke up from a wait (an event loop polling every few ms,
	the UI pacing its frames) is runnable when we look, but it was not using the CPU.
	Such a process is stopped right after a wait send: the code on top of its stack (the method,
	or the block when it is a block, not its enclosing method) sends #wait or #wait..."

	| code |
	code := (aProcess suspendedContext ifNil: [ ^ true ]) compiledCode.
	WaitingMethods ifNil: [ WaitingMethods := WeakIdentityKeyDictionary new ].
	^ WaitingMethods at: code ifAbsentPut: [
		  code messages anySatisfy: [ :selector | selector beginsWith: 'wait' ] ]
]

{ #category : #printing }
LMStackTally class >> labelFor: aCompiledMethod [

	aCompiledMethod ifNil: [ ^ nil ].
	^ aCompiledMethod methodClass name , '>>' , aCompiledMethod selector
]

{ #category : #accessing }
LMStackTally class >> loopThreshold [
	"Fraction of the samples a method must be on the stack to be considered the loop"

	^ 0.8
]

{ #category : #accessing }
LMStackTally class >> maxDepth [

	^ 40
]

{ #category : #sampling }
LMStackTally >> addProcess: aProcess [
	"aProcess must not be the active process: we read its suspended stack"

	| context depth seen |
	context := aProcess suspendedContext ifNil: [ ^ self ].
	samples := samples + 1.
	processes at: aProcess put: (processes at: aProcess ifAbsent: [ 0 ]) + 1.
	seen := IdentitySet new.
	lastStack := OrderedCollection new.
	depth := 0.
	[ context notNil and: [ depth < self class maxDepth ] ] whileTrue: [
		| method |
		method := context method.
		depth = 0 ifTrue: [ exclusive at: method put: (exclusive at: method ifAbsent: [ 0 ]) + 1 ].
		(seen includes: method) ifFalse: [
			seen add: method.
			inclusive at: method put: (inclusive at: method ifAbsent: [ 0 ]) + 1.
			depthSums at: method put: (depthSums at: method ifAbsent: [ 0 ]) + depth.
			lastStack size < 6 ifTrue: [ lastStack add: method ] ].
		depth := depth + 1.
		context := context sender ]
]

{ #category : #accessing }
LMStackTally >> hotLabel [

	^ self class labelFor: self hotMethod
]

{ #category : #accessing }
LMStackTally >> hotMethod [

	| best bestCount |
	bestCount := 0.
	exclusive keysAndValuesDo: [ :method :count |
		count > bestCount ifTrue: [
			best := method.
			bestCount := count ] ].
	^ best
]

{ #category : #accessing }
LMStackTally >> hotRatio [

	samples = 0 ifTrue: [ ^ 0 ].
	^ (exclusive at: self hotMethod ifAbsent: [ 0 ]) / samples
]

{ #category : #initialization }
LMStackTally >> initialize [

	super initialize.
	samples := 0.
	inclusive := IdentityDictionary new.
	depthSums := IdentityDictionary new.
	exclusive := IdentityDictionary new.
	processes := IdentityDictionary new.
	lastStack := #(  )
]

{ #category : #testing }
LMStackTally >> isEmpty [

	^ samples = 0
]

{ #category : #accessing }
LMStackTally >> lastStackLabels [

	^ (lastStack collect: [ :method | self class labelFor: method ]) asArray
]

{ #category : #accessing }
LMStackTally >> loopLabel [

	^ self class labelFor: self loopMethod
]

{ #category : #accessing }
LMStackTally >> loopMethod [

	| best bestDepth minimum |
	samples = 0 ifTrue: [ ^ nil ].
	minimum := samples * self class loopThreshold.
	inclusive keysAndValuesDo: [ :method :count |
		count >= minimum ifTrue: [
			| averageDepth |
			averageDepth := (depthSums at: method) / count.
			(best isNil or: [ averageDepth < bestDepth ]) ifTrue: [
				best := method.
				bestDepth := averageDepth ] ] ].
	^ best
]

{ #category : #accessing }
LMStackTally >> busiestProcess [
	"The process seen most often"

	| best bestCount |
	bestCount := 0.
	processes keysAndValuesDo: [ :process :count |
		count > bestCount ifTrue: [
			best := process.
			bestCount := count ] ].
	^ best
]

{ #category : #accessing }
LMStackTally >> processLabel [
	"Name of the process seen most often"

	| best |
	best := self busiestProcess ifNil: [ ^ nil ].
	best == UIManager default uiProcess ifTrue: [ ^ 'UI' ].
	^ best name ifNil: [ 'process' ]
]

{ #category : #accessing }
LMStackTally >> samples [

	^ samples
]
