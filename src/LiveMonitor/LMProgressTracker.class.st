"
I follow the loops of one busy process over time and answer an `LMProgress`.

The stack has loops that are not part of the work, like the Morphic loop dispatching the event
that started a doit: they never move. So the outer loop of the work is the outermost loop
I have seen move. Until a loop moves I have nothing to say.

Each loop is seen as an odometer wheel. The progress of the work is the position of the outer
loop, refined by the loops inside it. A wheel that goes back has wrapped around: it started again
for the next iteration of its parent, or, when it is the outer loop, a new run started.

The time left is extrapolated from the average speed since I first saw the outer loop.
"
Class {
	#name : #LMProgressTracker,
	#superclass : #Object,
	#instVars : [
		'finder',
		'process',
		'previous',
		'moved',
		'firstSeen'
	],
	#category : #LiveMonitor
}

{ #category : #accessing }
LMProgressTracker class >> etaDelayMs [
	"Do not guess the time left before watching the outer loop for this long"

	^ 2000
]

{ #category : #computing }
LMProgressTracker class >> fractionsOf: positions [
	"For each loop, the progress of that loop refined by the loops inside it"

	| fractions inner |
	fractions := Array new: positions size.
	inner := 0.
	positions size to: 1 by: -1 do: [ :index |
		| position |
		position := positions at: index.
		inner := position done + inner / position total min: 1.
		fractions at: index put: inner ].
	^ fractions
]

{ #category : #accessing }
LMProgressTracker >> finder [

	^ finder
]

{ #category : #initialization }
LMProgressTracker >> initialize [

	super initialize.
	finder := LMLoopFinder new.
	self reset
]

{ #category : #initialization }
LMProgressTracker >> reset [

	process := nil.
	previous := Dictionary new.
	moved := Set new.
	firstSeen := Dictionary new
]

{ #category : #computing }
LMProgressTracker >> update: aProcess at: now [
	"Look at the loops of aProcess now. Answer an LMProgress, or nil when no loop is known to move.
	aProcess must not be the active process."

	| positions fractions current root elapsed gained eta |
	aProcess == process ifFalse: [
		self reset.
		process := aProcess ].
	positions := finder loopsOf: aProcess.
	fractions := self class fractionsOf: positions.
	current := Dictionary new.
	positions withIndexDo: [ :position :index |
		| key |
		key := position key.
		current at: key put: position.
		(previous at: key ifAbsent: [ nil ]) ifNotNil: [ :before |
			before done = position done ifFalse: [ moved add: key ] ].
		(firstSeen at: key ifAbsent: [ nil ])
			ifNil: [ firstSeen at: key put: now -> (fractions at: index) ]
			ifNotNil: [ :first |
				(fractions at: index) < first value ifTrue: [ "wrapped: count from here"
					firstSeen at: key put: now -> (fractions at: index) ] ] ].
	"Forget the loops that ended"
	moved := moved select: [ :key | current includesKey: key ].
	firstSeen keys do: [ :key | (current includesKey: key) ifFalse: [ firstSeen removeKey: key ] ].
	previous := current.
	root := positions findFirst: [ :position | moved includes: position key ].
	root = 0 ifTrue: [ ^ nil ].
	elapsed := now - (firstSeen at: (positions at: root) key) key.
	gained := (fractions at: root) - (firstSeen at: (positions at: root) key) value.
	eta := (elapsed >= self class etaDelayMs and: [ gained > 0 ]) ifTrue: [
		       (1 - (fractions at: root)) * elapsed / gained ].
	^ LMProgress
		  fraction: (fractions at: root)
		  loops: (positions allButFirst: root - 1)
		  elapsedMs: elapsed
		  etaMs: eta
]
