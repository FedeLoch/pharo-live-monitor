"
I find the loops running in a process by looking at its stack, with no help from the code.

Every `do:`, `collect:`, `select:`, `withIndexDo:`... of the collections, and every `to:do:`
written by hand, ends up as an inlined `to:do:` whose counter is a temp of the frame. The compiler
even keeps the bound in a hidden temp (`0limit_<counter>`) when it is not a constant.
`Interval>>do:` and `timesRepeat:` are counter `whileTrue:` loops, and `[stream atEnd] whileFalse:`
reads a stream: I know these too (see `LMLoopSite`).

For each frame I map its pc to the loop nodes around it, using a private parse tree of the method
and the IR to know which temp holds what. That work is done once per method and pc and cached,
and limited to a few new methods per call, so the sampler stays cheap. I never use the shared
AST caches of the image: the process I preempted might be in the middle of updating them.
"
Class {
	#name : #LMLoopFinder,
	#superclass : #Object,
	#instVars : [
		'trees',
		'codes',
		'blockLabels',
		'budget'
	],
	#category : #LiveMonitor
}

{ #category : #accessing }
LMLoopFinder class >> analysisBudget [
	"How many methods never seen before we analyze per call. The others wait for the next call."

	^ 10
]

{ #category : #accessing }
LMLoopFinder class >> maxFrames [

	^ 10000
]

{ #category : #analysis }
LMLoopFinder >> analyze: aCompiledCode [
	"Answer { root node. IR. pc -> sites. loop node -> site } for aCompiledCode, or nil when it has no loop"

	| root |
	root := self nodeFor: aCompiledCode.
	(root allChildren anySatisfy: [ :node | self isLoop: node ]) ifFalse: [ ^ nil ].
	^ {
		  root.
		  root ir.
		  Dictionary new.
		  IdentityDictionary new }
]

{ #category : #analysis }
LMLoopFinder >> build: aLoopNode in: info label: aString [
	"Answer the LMLoopSite of aLoopNode, or nil when we cannot tell its progress"

	aLoopNode isInlineToDo ifTrue: [ ^ self buildToDo: aLoopNode ir: info second label: aString ].
	(self isTimesRepeat: aLoopNode) ifTrue: [ ^ self buildTimesRepeat: aLoopNode in: info label: aString ].
	^ self buildWhile: aLoopNode ir: info second label: aString
]

{ #category : #analysis }
LMLoopFinder >> buildTimesRepeat: aLoopNode in: info label: aString [
	"An inlined timesRepeat: counts in hidden temps named after its rank in the code:
	'01iterator' and '01limit' for the first one, '02...' for the second..."

	| ir loops prefix limit site |
	ir := info second.
	loops := (info first allChildren select: [ :node |
		          (self isTimesRepeat: node) and: [ (self codeNodeOf: node) == info first ] ]) asSortedCollection: [
		         :a
		         :b | a start <= b start ].
	prefix := '0' , (loops indexOf: aLoopNode) printString.
	limit := aLoopNode receiver.
	site := LMLoopSite kind: #while name: 'timesRepeat' methodLabel: aString.
	site counter: ((self temp: prefix , 'iterator' ir: ir) ifNil: [ ^ nil ]).
	site limit: (((limit isLiteralNode or: [ limit isVariable and: [ limit variable isWritable not ] ])
			  ifTrue: [ self reference: limit ir: ir ]
			  ifFalse: [ self temp: prefix , 'limit' ir: ir ]) ifNil: [ ^ nil ]).
	site offset: 1.
	^ site
]

{ #category : #analysis }
LMLoopFinder >> buildToDo: aLoopNode ir: anIR label: aString [

	| counter limit site |
	counter := aLoopNode arguments last arguments first.
	limit := aLoopNode arguments first.
	site := LMLoopSite kind: #toDo name: counter name methodLabel: aString.
	site counter: ((self reference: counter ir: anIR) ifNil: [ ^ nil ]).
	"The compiler keeps the bound in a hidden temp unless it is a constant or a read-only variable"
	site limit: (((limit isLiteralNode or: [ limit isVariable and: [ limit variable isWritable not ] ])
			  ifTrue: [ self reference: limit ir: anIR ]
			  ifFalse: [ self temp: '0limit_' , counter name ir: anIR ]) ifNil: [ ^ nil ]).
	site start: (self reference: aLoopNode receiver ir: anIR).
	aLoopNode arguments size = 3 ifTrue: [ site step: aLoopNode arguments second value ].
	^ site
]

{ #category : #analysis }
LMLoopFinder >> buildWhile: aLoopNode ir: anIR label: aString [
	"[i < n] whileTrue: [... i := i + 1] and [stream atEnd] whileFalse: [...]"

	| statements condition counter limit site body increment |
	statements := aLoopNode receiver body statements.
	statements size = 1 ifFalse: [ ^ nil ].
	condition := statements first.
	condition isMessage ifFalse: [ ^ nil ].
	(condition selector == #atEnd and: [ (aLoopNode selector beginsWith: 'whileFalse') and: [ condition receiver isVariable ] ])
		ifTrue: [
			site := LMLoopSite kind: #stream name: condition receiver name methodLabel: aString.
			site counter: ((self reference: condition receiver ir: anIR) ifNil: [ ^ nil ]).
			^ site ].
	(aLoopNode selector beginsWith: 'whileTrue') ifFalse: [ ^ nil ].
	(#( #< #<= ) includes: condition selector)
		ifTrue: [
			counter := condition receiver.
			limit := condition arguments first ]
		ifFalse: [
			(#( #> #>= ) includes: condition selector) ifFalse: [ ^ nil ].
			counter := condition arguments first.
			limit := condition receiver ].
	counter isVariable ifFalse: [ ^ nil ].
	"Only a counter the loop changes, otherwise the loop is waiting for something else"
	(aLoopNode allChildren anySatisfy: [ :node | node isAssignment and: [ node variable name = counter name ] ])
		ifFalse: [ ^ nil ].
	site := LMLoopSite kind: #while name: counter name methodLabel: aString.
	site counter: ((self reference: counter ir: anIR) ifNil: [ ^ nil ]).
	site limit: ((self reference: limit ir: anIR) ifNil: [ ^ nil ]).
	"Interval>>do: increments first and then works, a hand written loop usually works first"
	body := aLoopNode arguments ifEmpty: [ #(  ) ] ifNotEmpty: [ :arguments | arguments first body statements ].
	increment := body findFirst: [ :statement | statement isAssignment and: [ statement variable name = counter name ] ].
	site offset: ((#( #<= #>= ) includes: condition selector)
			 ifTrue: [ 1 ]
			 ifFalse: [ 0 ]) + ((increment between: 1 and: body size - 1)
			 ifTrue: [ 1 ]
			 ifFalse: [ 0 ]).
	^ site
]

{ #category : #analysis }
LMLoopFinder >> blockLabelOf: aContext calledFrom: aLoopContext [
	"When the loop of aLoopContext evaluates a block, the block's argument and home method, or nil"

	| code |
	(aContext sender == aLoopContext and: [ aContext closure notNil ]) ifFalse: [ ^ nil ].
	code := aContext compiledCode.
	^ blockLabels at: code ifAbsent: [
		  budget <= 0 ifTrue: [ ^ nil ].
		  budget := budget - 1.
		  blockLabels at: code put: ([
				   | node |
				   node := self nodeFor: code.
				   (node isBlock and: [ node arguments notEmpty ]) ifTrue: [
					   node arguments first name , ' in ' , (self labelFor: code) ] ]
				   on: Error
				   do: [ :error | nil ]) ]
]

{ #category : #analysis }
LMLoopFinder >> codeNodeOf: aNode [
	"The method or real block whose compiled code runs aNode"

	| node |
	node := aNode parent.
	[ node isNil or: [ node isMethod or: [ node isBlock and: [ node isInlined not ] ] ] ] whileFalse: [
		node := node parent ].
	^ node
]

{ #category : #analysis }
LMLoopFinder >> infoFor: aCompiledCode [
	"The cached analysis of aCompiledCode, nil when it has no loop or we are out of budget for now"

	| info |
	info := codes at: aCompiledCode ifAbsent: [
		        budget <= 0 ifTrue: [ ^ nil ].
		        budget := budget - 1.
		        codes at: aCompiledCode put: ([ self analyze: aCompiledCode ]
				         on: Error
				         do: [ :error | nil ]) ].
	^ info
]

{ #category : #initialization }
LMLoopFinder >> initialize [

	super initialize.
	trees := WeakIdentityKeyDictionary new.
	codes := WeakIdentityKeyDictionary new.
	blockLabels := WeakIdentityKeyDictionary new.
	budget := 0
]

{ #category : #testing }
LMLoopFinder >> is: aChild inBodyOf: aLoopNode [
	"The counter of a loop is only meaningful while running its body or its test,
	not while computing its bounds"

	aChild ifNil: [ ^ true ].
	aLoopNode isInlineToDo ifTrue: [ ^ aChild == aLoopNode arguments last ].
	(self isTimesRepeat: aLoopNode) ifTrue: [ ^ aChild == aLoopNode arguments first ].
	^ aChild == aLoopNode receiver or: [ aLoopNode arguments notEmpty and: [ aChild == aLoopNode arguments first ] ]
]

{ #category : #testing }
LMLoopFinder >> isLoop: aNode [

	^ aNode isMessage and: [ aNode isInlineToDo or: [ aNode isInlineWhile or: [ self isTimesRepeat: aNode ] ] ]
]

{ #category : #testing }
LMLoopFinder >> isTimesRepeat: aNode [
	"Pharo 14 inlines timesRepeat:, older versions call Integer>>timesRepeat:, a while loop"

	^ aNode isMessage and: [ (aNode respondsTo: #isInlineTimesRepeat) and: [ aNode isInlineTimesRepeat ] ]
]

{ #category : #accessing }
LMLoopFinder >> labelFor: aCompiledCode [

	| method |
	method := aCompiledCode method.
	method isDoIt ifTrue: [ ^ 'DoIt' ].
	^ LMStackTally labelFor: method
]

{ #category : #finding }
LMLoopFinder >> loopsOf: aProcess [
	"Answer the loops running in aProcess as LMLoopPositions, outermost first.
	aProcess must not be the active process."

	| frames context positions |
	context := aProcess suspendedContext ifNil: [ ^ #(  ) ].
	frames := OrderedCollection new.
	[ context notNil and: [ frames size < self class maxFrames ] ] whileTrue: [
		frames addFirst: context.
		context := context sender ].
	budget := self class analysisBudget.
	positions := OrderedCollection new.
	frames withIndexDo: [ :frame :depth |
		| inFrame |
		inFrame := (self sitesIn: frame) collect: [ :site | site positionIn: frame key: { site. depth } ] thenSelect: [ :position | position notNil ].
		"(1 to: 40) do: [ :epoch | ...] reads better as 'epoch in DoIt' than 'index in Interval>>do:'"
		(inFrame notEmpty and: [ depth < frames size ]) ifTrue: [
			(self blockLabelOf: (frames at: depth + 1) calledFrom: frame) ifNotNil: [ :label | inFrame last label: label ] ].
		positions addAll: inFrame ].
	^ positions asArray
]

{ #category : #analysis }
LMLoopFinder >> nodeFor: aCompiledCode [
	"A parse tree of our own: a block is found in the tree of its outer code, at the pc that creates it.
	A doit has no source to parse again, so we take the tree it was compiled from."

	aCompiledCode isCompiledBlock ifTrue: [
		^ (self nodeFor: aCompiledCode outerCode) sourceNodeForPC: aCompiledCode pcInOuter ].
	^ trees at: aCompiledCode ifAbsentPut: [
		  aCompiledCode isDoIt
			  ifTrue: [ aCompiledCode ast ]
			  ifFalse: [ aCompiledCode parseTree ] ]
]

{ #category : #analysis }
LMLoopFinder >> reference: aNode ir: anIR [
	"Where to read the value of aNode in a frame, see LMLoopSite"

	| variable |
	aNode isLiteralNode ifTrue: [
		^ aNode value isNumber ifTrue: [ { #literal. aNode value } ] ].
	aNode isVariable ifFalse: [ ^ nil ].
	variable := aNode variable.
	variable isSelfVariable ifTrue: [ ^ { #receiver } ].
	variable isInstanceVariable ifTrue: [ ^ { #ivar. aNode name } ].
	variable isLocalVariable ifTrue: [ ^ self temp: aNode name ir: anIR ].
	^ nil
]

{ #category : #finding }
LMLoopFinder >> sitesIn: aContext [
	"The loops around the pc of aContext, outermost first"

	| info pc |
	info := (self infoFor: aContext compiledCode) ifNil: [ ^ #(  ) ].
	pc := aContext executedPC.
	^ info third at: pc ifAbsentPut: [
		  [ self sitesIn: info at: pc label: (self labelFor: aContext compiledCode) ]
			  on: Error
			  do: [ :error | #(  ) ] ]
]

{ #category : #analysis }
LMLoopFinder >> sitesIn: info at: pc label: aString [

	| root node child sites |
	root := info first.
	node := root sourceNodeForPC: pc.
	sites := OrderedCollection new.
	[ node notNil and: [ node ~~ root ] ] whileTrue: [
		((self isLoop: node) and: [ self is: child inBodyOf: node ]) ifTrue: [
			(info fourth at: node ifAbsentPut: [ self build: node in: info label: aString ])
				ifNotNil: [ :site | sites addFirst: site ] ].
		child := node.
		node := node parent ].
	^ sites asArray
]

{ #category : #analysis }
LMLoopFinder >> temp: aString ir: anIR [
	"The temp named aString in the frame, directly or inside a temp vector when a closure captures it"

	(anIR tempMap at: aString ifAbsent: [ nil ]) ifNotNil: [ :index | ^ { #temp. index } ].
	anIR allInstructions do: [ :instruction |
		(instruction isTempVector and: [ (instruction indexForVarNamed: aString) > 0 ]) ifTrue: [
			(anIR tempMap at: instruction name ifAbsent: [ nil ]) ifNotNil: [ :index |
				^ {
					  #remote.
					  index.
					  (instruction indexForVarNamed: aString) } ] ] ].
	^ nil
]
