"
I am a loop in a compiled method or block, and I know where its counter and its bound live in a running frame.

I read stack frames only: temps by index, instance variables of the receiver, literals.
I never send messages to user objects, so reading me from the sampler process is safe.

A reference to a value is one of:
- `#(#temp index)` a temp of the frame
- `#(#remote vectorIndex index)` a temp captured by a closure, stored in a temp vector
- `#(#ivar name)` an instance variable of the receiver
- `#(#receiver)` the receiver itself
- `#(#literal value)` a constant

Kinds:
- `#toDo` an inlined `to:do:` / `to:by:do:`: counter, start, limit and step
- `#while` a counter `[i < n] whileTrue: [... i := i + 1]`: counter and limit. `offset` is what to take
  from the counter to get the iterations done: 1 for `<=` (counting from 1), 1 more when the counter
  is incremented before the work of the iteration
- `#stream` `[stream atEnd] whileFalse: [...]` on a positionable stream: position and read limit
"
Class {
	#name : #LMLoopSite,
	#superclass : #Object,
	#instVars : [
		'kind',
		'name',
		'methodLabel',
		'counter',
		'limit',
		'start',
		'step',
		'offset'
	],
	#category : #LiveMonitor
}

{ #category : #'instance creation' }
LMLoopSite class >> kind: aSymbol name: aString methodLabel: anotherString [

	^ self new
		  setKind: aSymbol
		  name: aString
		  methodLabel: anotherString
]

{ #category : #accessing }
LMLoopSite >> counter: aReference [

	counter := aReference
]

{ #category : #accessing }
LMLoopSite >> offset: aNumber [

	offset := aNumber
]

{ #category : #accessing }
LMLoopSite >> kind [

	^ kind
]

{ #category : #accessing }
LMLoopSite >> label [

	^ name , ' in ' , methodLabel
]

{ #category : #accessing }
LMLoopSite >> limit: aReference [

	limit := aReference
]

{ #category : #accessing }
LMLoopSite >> name [

	^ name
]

{ #category : #reading }
LMLoopSite >> positionIn: aContext key: aKey [
	"Answer where the loop is in aContext as an LMLoopPosition, or nil when the frame does not hold
	a sensible counter (the loop has not started, or the values are not numbers)"

	| done total |
	kind == #stream ifTrue: [
		| stream |
		stream := self read: counter in: aContext.
		(stream isKindOf: PositionableStream) ifFalse: [ ^ nil ].
		done := stream instVarNamed: #position.
		total := stream instVarNamed: #readLimit ].
	kind == #while ifTrue: [
		| value bound |
		value := self read: counter in: aContext.
		bound := self read: limit in: aContext.
		(value isNumber and: [ bound isNumber ]) ifFalse: [ ^ nil ].
		done := value - offset.
		total := bound ].
	kind == #toDo ifTrue: [
		| value first last |
		value := self read: counter in: aContext.
		last := self read: limit in: aContext.
		first := start ifNil: [ 1 ] ifNotNil: [ self read: start in: aContext ].
		(value isNumber and: [ last isNumber and: [ first isNumber ] ]) ifFalse: [ ^ nil ].
		step > 0
			ifTrue: [
				done := value - first.
				total := last - first + 1 ]
			ifFalse: [
				done := first - value.
				total := first - last + 1 ].
		total := total / step abs ].
	(done isNumber and: [ total isNumber and: [ total > 0 ] ]) ifFalse: [ ^ nil ].
	(done < 0 or: [ done > total ]) ifTrue: [ ^ nil ].
	^ LMLoopPosition key: aKey site: self done: done total: total
]

{ #category : #reading }
LMLoopSite >> read: aReference in: aContext [

	| tag |
	aReference ifNil: [ ^ nil ].
	tag := aReference first.
	tag == #literal ifTrue: [ ^ aReference second ].
	tag == #temp ifTrue: [
		aReference second > aContext numTemps ifTrue: [ ^ nil ].
		^ aContext tempAt: aReference second ].
	tag == #remote ifTrue: [
		| vector |
		aReference second > aContext numTemps ifTrue: [ ^ nil ].
		vector := aContext tempAt: aReference second.
		(vector class == Array and: [ aReference third <= vector size ]) ifFalse: [ ^ nil ].
		^ vector at: aReference third ].
	tag == #receiver ifTrue: [ ^ aContext receiver ].
	tag == #ivar ifTrue: [ ^ aContext receiver instVarNamed: aReference second ].
	^ nil
]

{ #category : #initialization }
LMLoopSite >> setKind: aSymbol name: aString methodLabel: anotherString [

	kind := aSymbol.
	name := aString.
	methodLabel := anotherString.
	step := 1.
	offset := 0
]

{ #category : #accessing }
LMLoopSite >> start: aReference [

	start := aReference
]

{ #category : #accessing }
LMLoopSite >> step: aNumber [

	step := aNumber
]
